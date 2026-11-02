#!/usr/bin/env bash
# _common.sh — helpers compartilhados pelos transportes do liaison que usam um DIRETÓRIO como
# ponto de encontro (manual, fs, e o clone local do git). Não é um transporte: não define
# t_probe/t_push/t_pull, apenas as duas metades de cópia que todos eles repetiriam.
#
# Invariante que estes helpers preservam: o push publica APENAS o log do próprio remetente. Um
# participante nunca republica o log de terceiro — se o fizesse, publicaria a versão (possivelmente
# atrasada) que ele conhece, regredindo o hub e fazendo o dono do log perder mensagens já enviadas.
#
# PUBLICAÇÃO SEM TRAVA (design §2.4, opção C — causa raiz escolhida pelo dono em 2026-10-30):
# dois pushes do mesmo `self` em paralelo não são serializados por uma trava de rede (ela trouxe
# caso de vivacidade do dono em três rodadas seguidas de revisão). Em vez disso, cada tentativa
# usa tmp ÚNICO no hub, e depois do `mv` relê o arquivo do hub e o log próprio local NAQUELE
# INSTANTE, conferindo que o hub contém, como prefixo contíguo e com `content_sha` igual, tudo
# que o log próprio relido tem — se não contém, repete a tentativa inteira (nova leitura, nova
# união, novo `mv`) até o prazo (`FORGE_LIAISON_PUSH_DEADLINE_S`, default 300 s). `union-own` (em
# vez do antigo `cp "$hubf" "$own"`) garante que o log próprio é sempre superconjunto de tudo que
# qualquer push concorrente poderia ter escrito, então o ÚLTIMO push a fazer `mv` sempre encontra
# e repara a falta deixada por um concorrente mais antigo. `LIAISON_OBSERVED_FILE` carrega o
# conteúdo relido no hub depois da conferência bem-sucedida — `markPublished({ observedFile })`
# grava só o que foi visto lá, nunca o que o processo local acha que escreveu.

# _liaison_push_deadline_s — honra FORGE_LIAISON_PUSH_DEADLINE_S; default 300 s (sync manual). O
# processo destacado da renovação exporta 25 s antes de chamar `sync --push-only` (TASK-27).
_liaison_push_deadline_s() {
  local v="${FORGE_LIAISON_PUSH_DEADLINE_S:-300}"
  case "$v" in ''|*[!0-9]*) v=300 ;; esac
  printf '%s' "$v"
}

# _liaison_test_barrier <ponto> — ponto de injeção SÓ PARA TESTES (design §2.4, "verificação
# determinística das corridas"). Sem FORGE_LIAISON_TEST_BARRIER, não faz nada — custo zero fora
# de teste. Com a variável (um diretório), cria `<dir>/<ponto>.<pid>.ready` e espera (até 30 s)
# `<dir>/<ponto>.<pid>.go`, permitindo que o gate force intercalações específicas (push morto
# entre mv e conferência, push mais antigo fazendo o último mv, send entre blobs e união).
_liaison_test_barrier() {
  local point="$1"
  [ -n "${FORGE_LIAISON_TEST_BARRIER:-}" ] || return 0
  local dir="$FORGE_LIAISON_TEST_BARRIER"
  mkdir -p "$dir" 2>/dev/null || true
  local ready="$dir/$point.$$.ready" go="$dir/$point.$$.go"
  : > "$ready" 2>/dev/null || true
  local deadline=$(( $(date +%s) + 30 ))
  while [ ! -f "$go" ]; do
    [ "$(date +%s)" -lt "$deadline" ] || break
    sleep 0.1
  done
  rm -f "$ready" "$go" 2>/dev/null || true
}

# _dir_refuse_link <caminho>... — rc 1 (com FAIL nomeando o caminho) se QUALQUER um dos caminhos
# for link simbólico; rc 0 caso contrário (inclusive quando o caminho ainda não existe). SEC-001:
# o conteúdo do ponto de encontro é escrito por peers, e um link simbólico plantado ali (`log`,
# `blobs`, o diretório do canal ou o arquivo-alvo) faz o `mkdir -p`, o `cp` e a união seguirem o
# link e gravarem fora do hub — reproduzido em revisão até `.git/hooks` do repositório de quem
# sincroniza. `[ -L ]` olha só o último componente, que é exatamente o que o peer controla; os
# componentes acima pertencem ao caminho configurado pelo operador.
_dir_refuse_link() {
  local p
  for p in "$@"; do
    if [ -L "$p" ]; then
      echo "FAIL: push RECUSADO — '$p' é um link simbólico no ponto de encontro. Conteúdo do hub é escrito por peers, e seguir o link gravaria fora do hub. Remova o link no hub (e investigue quem o plantou) antes de sincronizar de novo." >&2
      return 1
    fi
  done
  return 0
}

# _dir_hub_guard <hub_dir> — aplica `_dir_refuse_link` ao diretório do canal, a `log/`, a
# `blobs/` e ao log próprio no hub. O próprio `<hub_dir>` só é conferido quando NÃO é o caminho
# configurado pelo operador (`LIAISON_T_PATH`, caso do transporte `manual`): ali um link é escolha
# de quem configurou (um volume montado, por exemplo); abaixo dele, tudo é conteúdo de peer.
_dir_hub_guard() {
  local hub="$1"
  if [ "$hub" != "${LIAISON_T_PATH:-}" ]; then
    _dir_refuse_link "$hub" || return 1
  fi
  _dir_refuse_link "$hub/log" "$hub/blobs" "$hub/log/$LIAISON_SELF.jsonl"
}

# _dir_push_cleanup_own_tmp <hub_dir> — remove tmp ÓRFÃO do PRÓPRIO self no hub com mais de 10
# minutos (design §2.4): o vigia da renovação pode matar um push no meio, e o tmp único de cada
# tentativa não é recolhido por ninguém além do próximo push deste mesmo self. NUNCA toca tmp de
# outro remetente — o glob é `.${LIAISON_SELF}.jsonl.tmp.*`, que não casa com o de terceiro.
_dir_push_cleanup_own_tmp() {
  local hub="$1"
  [ -d "$hub/log" ] || return 0
  local f now cutoff mtime
  now="$(date +%s)"
  cutoff=$(( now - 600 ))
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    mtime="$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo "$now")"
    [ "$mtime" -lt "$cutoff" ] && rm -f "$f" 2>/dev/null || true
  done < <(find "$hub/log" -maxdepth 1 -type f -name ".${LIAISON_SELF}.jsonl.tmp.*" 2>/dev/null)
}

# _dir_push_classify <hub_dir> <own_file> — em que RELAÇÃO o log do hub está com o local.
#
# O push era `cp` + `mv` INCONDICIONAL — issue #101: uma réplica atrasada substituía o log do hub
# pelo seu, com rc 0 e sem uma linha de aviso, apagando mensagens que só existiam lá. Num log
# append-only não há de onde restaurar.
#
# A primeira correção usou PREFIXO ESTRITO de linhas, e ela recusava DOIS fatos diferentes como se
# fossem um só. Não são, e os remédios são opostos. Tabela de desfechos (a decisão real é tomada em
# `_dir_push`, mais abaixo — este helper só classifica):
#
#   desfecho   | quando                                                            | ação
#   -----------|--------------------------------------------------------------------|----------
#   ff         | hub é subconjunto estrito do local (local tem tudo do hub e mais)  | une
#   equal      | hub e local têm exatamente os mesmos pares (msg_id, content_sha)   | une (no-op)
#   behind     | hub tem um `msg_id` que este local NÃO tem                         | une
#   diverged   | hub tem conteúdo DIFERENTE num `msg_id` que este local TAMBÉM tem  | recusa*
#
#   * recusa, exceto sob reparo declarado (`--repair-own-log`, caso 2 em `_dir_push`).
#
#   `ff` e `equal` chegam ao mesmo stdout ("ff", rc 0): `_dir_push_classify` não os distingue, porque
#   ambos deixam as listas `behind` e `diverged` vazias — e a união (`_dir_push_union`) trata os dois
#   de forma idêntica; para `equal` o resultado é um no-op de fato, já que unir um log com ele mesmo
#   não produz conteúdo novo.
#
#   `behind` é exatamente a issue #101 — mas o remédio é a UNIÃO, não a recusa: recusar sempre que o
#   hub tiver algo que este local não tem tornaria toda réplica atrasada num push que reprova, e
#   réplica atrasada é o estado NORMAL de uma máquina com múltiplos worktrees (`_dir_pull` nunca traz
#   o próprio log de volta, por desenho — não há "sincronizar primeiro" que o participante possa
#   executar sozinho). A recusa fica reservada à bifurcação real, `diverged`, que é ambígua por
#   construção — ver a seguir.
#
# Por que `diverged` não pode ser aceito automaticamente, e a medição que fecha o argumento. O
# caso é AMBÍGUO por construção: ou um terceiro reescreveu a história (e o dono é a única
# autoridade sobre `log/<self>.jsonl`, então republicar REPARA e nada se perde), ou duas réplicas
# da MESMA identidade compuseram mensagens diferentes no mesmo `seq` (e republicar DESTRÓI a da
# outra). Medido nesta base, com dois worktrees do mesmo repositório e sem sync entre eles: ambos
# chegam a `axis-0002`, com assuntos distintos; o par `(msg_id, content_sha)` do hub falta na
# outra réplica, e um predicado que olhasse só `msg_id` aceitaria a publicação e apagaria a
# mensagem da primeira — a issue #101 reaberta por outra porta. `_dir_pull` nunca traz o próprio
# log de volta ("a réplica local é a fonte da verdade dele"), então nenhuma das duas aprende sobre
# a outra: a colisão é silenciosa e o pull não a repara.
#
# Nada nos dois logs distingue reescrita de colisão — produzem exatamente o mesmo par de arquivos.
# Só o dono sabe qual das duas é, e por isso o reparo é um ATO EXPLÍCITO dele
# (`sync --repair-own-log`), nunca uma inferência do transporte. É a mesma disciplina que o resto
# do harness aplica à divergência: quarentena e resolução deliberada, jamais adivinhação.
#
# Um único `awk`, sem pipeline: `grep … | head` aqui morreria sob `pipefail` por SIGPIPE, que é
# exatamente a classe que `check-shell-pipeline.sh` existe para reprovar.
#
# stdout: "ff" | "behind <ids…>" | "diverged <ids…>".  rc: 0 | 1 | 2.
_dir_push_classify() {
  local hub="$1" own="$2"
  local hubf="$hub/log/$LIAISON_SELF.jsonl"
  # `-s`, não `-f`: log AUSENTE e log presente com ZERO byte são o mesmo fato — o hub não tem
  # linha nenhuma deste remetente, e um log vazio é prefixo de qualquer log. A distinção não é
  # teórica: o `awk` abaixo usa `NR == FNR` para separar os dois arquivos, e com o PRIMEIRO
  # vazio esse teste continua verdadeiro na primeira linha do SEGUNDO — o log local inteiro
  # entraria como se fosse o do hub, e a publicação ficaria recusada para sempre. Estado
  # alcançável por `mv` interrompido, por arquivo vazio commitado num hub `git` e por cópia manual.
  [ -s "$hubf" ] || { echo "ff"; return 0; }
  awk '
    function jfield(line, key,   s) {
      if (match(line, "\"" key "\"[[:space:]]*:[[:space:]]*\"[^\"]*\"")) {
        s = substr(line, RSTART, RLENGTH)
        sub(/^"[^"]*"[[:space:]]*:[[:space:]]*"/, "", s)
        sub(/"$/, "", s)
        return s
      }
      return ""
    }
    NR == FNR {
      if ($0 == "") next
      id = jfield($0, "msg_id"); sha = jfield($0, "content_sha")
      # Linha sem msg_id legível (log corrompido ou formato futuro): degrada para comparação
      # CRUA da linha inteira. Nunca para "aceita" — não saber ler é motivo de rigor, não de
      # frouxidão.
      if (id == "") { id = $0; sha = $0 }
      nh++; hid[nh] = id; hpair[nh] = id SUBSEP sha; seen_h[id] = 1
      next
    }
    {
      if ($0 == "") next
      id = jfield($0, "msg_id"); sha = jfield($0, "content_sha")
      if (id == "") { id = $0; sha = $0 }
      lid[id] = 1; lpair[id SUBSEP sha] = 1
    }
    END {
      behind = ""; diverged = ""
      for (i = 1; i <= nh; i++) {
        if (!(hid[i] in lid)) { behind = behind " " hid[i]; continue }
        if (!(hpair[i] in lpair)) diverged = diverged " " hid[i]
      }
      if (behind != "")   { printf "behind%s\n", behind;   exit 1 }
      if (diverged != "") { printf "diverged%s\n", diverged; exit 2 }
      print "ff"
      exit 0
    }
  ' "$hubf" "$own"
}

# _liaison_unique_suffix — sufixo único por tentativa de push (pid + tempo + aleatório), para que
# nenhuma combinação de pushes concorrentes produza tmp colidente (design §2.4).
_liaison_unique_suffix() {
  printf '%s.%s.%s' "$$" "$(date +%s%N 2>/dev/null || date +%s)" "$RANDOM"
}

# _liaison_conference_ok <arquivo_observado> <log_proprio> — rc 0 se TODA mensagem do log próprio
# (relido agora) está no observado com o MESMO content_sha, na mesma posição relativa (prefixo
# contíguo: a ordem das linhas de um log append-only já é a ordem de seq). Sem node não há como
# conferir — trata como falha de conferência (nunca marca publicado sem saber).
_liaison_conference_ok() {
  local observed="$1" own="$2"
  command -v node >/dev/null 2>&1 || return 1
  node -e "
    const fs = require('fs');
    function recs(p) {
      if (!fs.existsSync(p)) return [];
      return fs.readFileSync(p, 'utf8').split('\n').map((l) => l.trim()).filter(Boolean)
        .map((l) => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);
    }
    const observed = recs(process.argv[1]);
    const own = recs(process.argv[2]);
    const bySha = new Map(observed.map((m) => [m.msg_id, m.content_sha]));
    for (const m of own) {
      if (!bySha.has(m.msg_id) || bySha.get(m.msg_id) !== m.content_sha) process.exit(1);
    }
    process.exit(0);
  " "$observed" "$own"
}

# _dir_push_union <hub_dir> <own_snapshot_file> — publica a UNIÃO do log do hub com o
# INSTANTÂNEO local, atomicamente, com tmp único (design §2.4). Delega o cálculo (e a detecção
# de bifurcação) a lib/liaison-push-union.mjs: um só predicado de divergência no repositório, o
# mesmo que o `import` usa para decidir quarentena. Sem `node` não há união possível, e publicar
# sem unir é justamente o dano da issue #101 — então recusa.
_dir_push_union() {
  local hub="$1" own="$2"
  local hubf="$hub/log/$LIAISON_SELF.jsonl"
  # O `lib/` é o diretório-pai deste arquivo (`lib/transports/_common.sh`) — derivado do próprio
  # BASH_SOURCE em vez de variável exportada, para não depender de quem fez o source.
  local libdir; libdir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local mod="$libdir/liaison-push-union.mjs"
  if ! command -v node >/dev/null 2>&1 || [ ! -f "$mod" ]; then
    echo "FAIL: push RECUSADO — a união do log exige node e '$mod', e um dos dois não está disponível." >&2
    echo "      Publicar sem unir SUBSTITUIRIA o log do hub por esta réplica, apagando mensagem já" >&2
    echo "      publicada por outra réplica da mesma identidade (issue #101). Não saber unir é" >&2
    echo "      motivo de rigor, não de publicação." >&2
    return 1
  fi
  local tmp="$hub/log/.$LIAISON_SELF.jsonl.tmp.$(_liaison_unique_suffix)"
  _dir_refuse_link "$tmp" || return 1
  if ! node "$mod" "$own" "$hubf" "$tmp" "$LIAISON_SELF"; then
    rm -f "$tmp"
    return 1
  fi
  _liaison_test_barrier after-union
  mv "$tmp" "$hubf"
  _liaison_test_barrier after-mv
  # Escritor único do log próprio (design §2.4, "Escritor único da gravação"): em vez do antigo
  # `cp "$hubf" "$own"`, usa `liaison-append.mjs union-own` SOB A TRAVA do log próprio — relê o
  # log ATUAL (que pode ter avançado desde o instantâneo desta tentativa, por um `send`
  # concorrente) e une com o que acabou de ir para o hub, sem perder nada gravado nesse
  # intervalo. `FORGE_ROOT` já está exportado por quem chamou `liaison-ops.sh`.
  local append_mod="$libdir/liaison-append.mjs"
  if ! node "$append_mod" union-own "$LIAISON_CHANNEL_DIR" "$LIAISON_SELF" "$hubf" >/dev/null; then
    echo "FAIL: union-own falhou ao sincronizar o log próprio de volta — o hub foi atualizado, mas a réplica local pode ficar atrás até o próximo sync" >&2
    return 1
  fi
  return 0
}

# _dir_push_blobs <hub_dir> <src> — copia os blobs locais que o hub ainda não tem.
# Exclui `.recover-*.tmp`: nome temporário da passada de recuperação (liaison-import.mjs), nunca
# um blob de verdade. Um SIGKILL a meio de uma recuperação pode deixar esse arquivo órfão em
# `blobs/` (o `try/catch` que faz `unlinkSync` de melhor esforço não sobrevive à morte do
# processo) — sem a exclusão aqui, `find "$src/blobs" -type f` o varre como qualquer outro blob e
# `_dir_push` o publicaria no hub, contaminando toda réplica que sincronizar depois.
#
# SEC-001: recusa (rc 1) se `blobs/` do hub, o blob-alvo ou o tmp forem link simbólico — `[ -f ]`
# e `cp` seguem o link, e o blob local iria parar onde o peer apontou. Quem chama confere o rc.
_dir_push_blobs() {
  local hub="$1" src="$2"
  [ -d "$src/blobs" ] || return 0
  _dir_refuse_link "$hub/blobs" || return 1
  local b name
  while IFS= read -r b; do
    [ -n "$b" ] || continue
    name="$(basename "$b")"
    _dir_refuse_link "$hub/blobs/$name" "$hub/blobs/.$name.tmp" || return 1
    [ -f "$hub/blobs/$name" ] && continue
    cp "$b" "$hub/blobs/.$name.tmp" && mv "$hub/blobs/.$name.tmp" "$hub/blobs/$name"
  done < <(find "$src/blobs" -type f ! -name '.recover-*.tmp' 2>/dev/null | LC_ALL=C sort)
  return 0
}

# _dir_push <hub_dir> — publica log/<self>.jsonl e os blobs locais no ponto de encontro, SEM
# trava de rede (design §2.4, opção C). Cada tentativa segue a mesma sequência: (1) instantâneo
# do log próprio; (2) blobs que o instantâneo referencia (aqui, todos os blobs locais — cópia
# idempotente e content-addressed, então copiar de mais nunca corrompe); (3) união do
# instantâneo com o hub relido, por tmp único; (4) `mv` atômico. Depois do `mv`, relê o hub E o
# log próprio ATUAL (pode ter avançado durante a tentativa) e confere que o hub contém, como
# prefixo contíguo com `content_sha` igual, tudo que o log próprio relido tem. Sem a conferência
# bem-sucedida, repete a tentativa inteira até `FORGE_LIAISON_PUSH_DEADLINE_S` (default 300 s).
# Exporta `LIAISON_OBSERVED_FILE` (conteúdo observado no hub, para `markPublished`),
# `LIAISON_PUSH_ATTEMPTS` e `LIAISON_PUSH_REPAIRS`, e avisa em stderr
# "publicação: N tentativa(s), M reparo(s)".
_dir_push() {
  local hub="$1"
  local src="$LIAISON_CHANNEL_DIR"
  # SEC-001: a guarda vem ANTES do `mkdir -p`, que seguiria um link plantado no hub.
  _dir_hub_guard "$hub" || return 1
  mkdir -p "$hub/log" "$hub/blobs"
  local own="$src/log/$LIAISON_SELF.jsonl"
  local attempts=0 repairs=0 rc=1
  local deadline; deadline=$(( $(date +%s) + $(_liaison_push_deadline_s) ))
  LIAISON_OBSERVED_FILE=""

  if [ ! -f "$own" ]; then
    # Nada próprio a publicar ainda — mas blobs soltos (ex. de uma gravação anterior
    # interrompida) continuam indo, como no comportamento pré-existente.
    _dir_push_blobs "$hub" "$src" || return 1
    export LIAISON_PUSH_ATTEMPTS=0 LIAISON_PUSH_REPAIRS=0
    return 0
  fi

  while :; do
    attempts=$((attempts + 1))
    # Reconfere a cada tentativa: o hub é compartilhado e pode mudar entre uma e outra.
    _dir_hub_guard "$hub" || return 1
    _dir_push_cleanup_own_tmp "$hub"

    local snap; snap="$(mktemp "${TMPDIR:-/tmp}/liaison-push-snap.XXXXXX")"
    cp "$own" "$snap"
    if ! _dir_push_blobs "$hub" "$src"; then
      rm -f "$snap"
      return 1
    fi
    _liaison_test_barrier after-blobs

    local verdict cls_rc=0
    verdict="$(_dir_push_classify "$hub" "$snap")" || cls_rc=$?
    local did_union=1
    case "$cls_rc" in
      0) : ;; # ff/equal — une de qualquer forma (valida um escritor por arquivo)
      1) repairs=$((repairs + 1)) ;; # réplica atrasada: a união REPARA o hub
      2)
        did_union=0
        if [ "${LIAISON_PUSH_REPAIR:-0}" = "1" ]; then
          # Reparo DECLARADO, e declarado por extenso: reparo silencioso é indistinguível da
          # sobrescrita que a issue #101 fechou. O operador precisa ver o que está descartando
          # ANTES de o hub mudar, porque num log append-only não há segunda chance.
          echo "WARN: reparo do log próprio (--repair-own-log) — o hub diverge desta árvore em posição(ões) que ela também tem:" >&2
          echo "     ${verdict#diverged}" >&2
          echo "      A versão do HUB nessas posições será DESCARTADA e substituída pela desta árvore." >&2
          echo "      Você está afirmando que este log é a autoridade sobre '$LIAISON_SELF'. Se a" >&2
          echo "      divergência vier de outra réplica sua que publicou mensagem distinta no mesmo" >&2
          echo "      seq, ela se perde aqui." >&2
          local rtmp="$hub/log/.$LIAISON_SELF.jsonl.tmp.$(_liaison_unique_suffix)"
          _dir_refuse_link "$rtmp" || { rm -f "$snap"; return 1; }
          cp "$snap" "$rtmp" && mv "$rtmp" "$hub/log/$LIAISON_SELF.jsonl"
          _liaison_test_barrier after-mv
          repairs=$((repairs + 1))
        else
          echo "FAIL: push RECUSADO — DIVERGÊNCIA: o hub tem conteúdo diferente em posição(ões) que esta árvore também tem:" >&2
          echo "     ${verdict#diverged}" >&2
          echo "      Isto NÃO é réplica atrasada: nenhuma mensagem do hub falta aqui, então sincronizar" >&2
          echo "      não resolve e trazer o log do hub apagaria a versão desta árvore." >&2
          echo "      Duas causas produzem exatamente este estado, e nada nos logs as distingue:" >&2
          echo "        (a) um terceiro reescreveu a história no hub — republicar REPARA;" >&2
          echo "        (b) outra réplica da mesma identidade publicou mensagem distinta no mesmo seq" >&2
          echo "            — republicar DESTRÓI a mensagem dela." >&2
          echo "      Só o dono do log sabe qual é. Confirme e, se for (a), repare com:" >&2
          echo "        liaison-ops.sh sync <canal> --push-only --repair-own-log" >&2
          echo "      Hub: $hub/log/$LIAISON_SELF.jsonl" >&2
          rm -f "$snap"
          return 1
        fi
        ;;
      *)
        echo "FAIL: push RECUSADO — não foi possível classificar o log do hub (rc $cls_rc). Não saber ler o ponto de encontro é motivo de rigor, não de publicação." >&2
        rm -f "$snap"
        return 1
        ;;
    esac
    if [ "$did_union" -eq 1 ]; then
      if ! _dir_push_union "$hub" "$snap"; then
        rm -f "$snap"
        return 1
      fi
    fi
    rm -f "$snap"

    # Conferência pós-mv: o hub relido AGORA tem de conter, como prefixo contíguo com
    # content_sha igual, o log próprio relido AGORA (não o instantâneo — pode ter avançado).
    local hubf="$hub/log/$LIAISON_SELF.jsonl"
    local obs; obs="$(mktemp "${TMPDIR:-/tmp}/liaison-push-obs.XXXXXX")"
    cp "$hubf" "$obs" 2>/dev/null || : > "$obs"
    if _liaison_conference_ok "$obs" "$own"; then
      LIAISON_OBSERVED_FILE="$obs"
      export LIAISON_OBSERVED_FILE
      rc=0
      break
    fi
    rm -f "$obs"
    if [ "$(date +%s)" -ge "$deadline" ]; then
      rc=1
      echo "FAIL: push esgotou o prazo ($(_liaison_push_deadline_s)s) sem confirmar que o hub contém o log próprio" >&2
      break
    fi
  done

  export LIAISON_PUSH_ATTEMPTS="$attempts" LIAISON_PUSH_REPAIRS="$repairs"
  echo "publicação: $attempts tentativa(s), $repairs reparo(s)" >&2
  return "$rc"
}

# _dir_pull <hub_dir> <staging_dir> — materializa os logs ALHEIOS e os blobs do ponto de encontro
# num staging cru. Nunca traz de volta o próprio log: a réplica local é a fonte da verdade dele.
_dir_pull() {
  local hub="$1" staging="$2"
  mkdir -p "$staging/log" "$staging/blobs"
  [ -d "$hub/log" ] || return 0
  local f name
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    name="$(basename "$f")"
    [ "$name" = "$LIAISON_SELF.jsonl" ] && continue
    cp "$f" "$staging/log/$name"
  done < <(find "$hub/log" -type f -name '*.jsonl' 2>/dev/null | LC_ALL=C sort)
  if [ -d "$hub/blobs" ]; then
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      cp "$f" "$staging/blobs/$(basename "$f")"
    done < <(find "$hub/blobs" -type f 2>/dev/null | LC_ALL=C sort)
  fi
}
