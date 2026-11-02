#!/usr/bin/env bash
# _common.sh — helpers compartilhados pelos transportes do liaison que usam um DIRETÓRIO como
# ponto de encontro (manual, fs, e o clone local do git). Não é um transporte: não define
# t_probe/t_push/t_pull, apenas as duas metades de cópia que todos eles repetiriam.
#
# Invariante que estes helpers preservam: o push publica APENAS o log do próprio remetente. Um
# participante nunca republica o log de terceiro — se o fizesse, publicaria a versão (possivelmente
# atrasada) que ele conhece, regredindo o hub e fazendo o dono do log perder mensagens já enviadas.

# SEC-001 — O HUB É ESCRITO POR TERCEIROS. Quem tem push na branch do canal (`git`) ou escrita no
# diretório compartilhado (`fs`, `fs-union`, `manual`) controla tudo o que existe abaixo do ponto
# de encontro: pode plantar um symlink no lugar de `log/`, de `blobs/`, de um arquivo dentro
# deles, ou num nome temporário que o sync vá usar, e pode trocar um diretório por um link ENTRE a
# conferência e a escrita. Um único `cp`/`mv`/`writeFileSync` que siga um desses links escreve
# fora da árvore do canal — `.bashrc`, `.git/hooks/`, `.git/config` — e vira execução de código na
# máquina de quem sincroniza. As defesas abaixo são camadas independentes, e todas valem para
# todo transporte baseado em diretório:
#
#   1. `_dir_reject_symlink` recusa link já plantado em hub, `log/`, `blobs/` e nos arquivos-alvo;
#   2. o caminho FÍSICO é fixado uma vez (`_dir_phys_expected`): a raiz configurada é confiável e
#      pode ser symlink legítimo; abaixo dela, toda escrita entra no diretório por `cd -P` e
#      confere `pwd -P` contra o esperado (`_dir_anchor`), escrevendo só por nome RELATIVO;
#   3. nenhum temporário mora no hub com nome previsível: a união é calculada num diretório
#      PRIVADO (`mktemp -d`), e a publicação (`_dir_publish_file`) cria um temporário de nome
#      aleatório com `set -C` (O_EXCL: recusa nome existente, inclusive symlink pendente), sob
#      `umask 022` (nunca executável), e o instala por `rename(2)` — que substitui a entrada sem
#      segui-la e recusa diretório no destino.
#
# RISCO RESIDUAL, declarado: depois de `cd -P`, o processo está preso ao inode do diretório. Quem
# renomeia esse diretório para outro lugar no meio do sync só consegue movê-lo para onde ele mesmo
# já tem escrita (rename exige escrita nos dois pais, no mesmo filesystem) — não alcança arquivo da
# vítima. As LEITURAS do hub seguem por caminho: um link trocado no meio do pull faz a vítima ler
# um arquivo local dela para o staging privado; o que o import aceita dali é limitado pelo formato
# (JSON com remetente próprio) e pela conferência do blob (follow-up SEC-002). Em hub `fs`
# compartilhado entre usuários, aplique sticky bit (`chmod +t`) — ver `fs.sh`.

# _dir_reject_symlink <path> — recusa se <path> EXISTIR como link simbólico (arquivo ou
# diretório). Sem esta guarda, `mkdir -p` sobre um symlink-para-diretório já existente é um no-op
# silencioso, e todo `cp`/`mv` que viria depois escreve OBEDECENDO o link. Ausência do caminho não
# é recusada: é o estado normal de primeiro push/pull.
_dir_reject_symlink() {
  local p="$1"
  if [ -L "$p" ]; then
    echo "FAIL: '$p' é um link simbólico — recusado (SEC-001). Um ponto de encontro do liaison" >&2
    echo "      (o diretório do canal, 'log/', 'blobs/' ou um arquivo dentro deles) nunca pode ser" >&2
    echo "      symlink: segui-lo escreveria fora da árvore do canal. Se isto é inesperado, o canal" >&2
    echo "      pode estar comprometido — não sincronize até investigar quem publicou isto." >&2
    return 1
  fi
  return 0
}

# _dir_phys_expected <path> — o caminho FÍSICO esperado de <path>: o diretório-pai resolvido com
# `cd -P` (é configuração do operador ou diretório do próprio harness, e pode conter symlink
# legítimo) seguido do último componente LITERAL. O último componente nunca é resolvido aqui: é
# justamente ele que quem escreve no hub pode ter trocado por um link.
_dir_phys_expected() {
  local p="${1%/}" pai base
  pai="$(dirname -- "$p")"; base="$(basename -- "$p")"
  pai="$(cd -P -- "$pai" 2>/dev/null && pwd -P)" \
    || { echo "FAIL: diretório inacessível: $(dirname -- "$p")" >&2; return 1; }
  [ "$pai" = / ] && pai=""
  printf '%s/%s' "$pai" "$base"
}

# _dir_anchor <dir_phys> — para uso DENTRO de subshell: entra em <dir_phys> por `cd -P` e confere
# que o diretório físico em que entrou é exatamente o esperado. Daí em diante só se escreve por
# nome relativo, presos ao inode conferido — trocar um componente do caminho por um link depois
# deste ponto não muda mais para onde a escrita vai.
_dir_anchor() {
  cd -P -- "$1" 2>/dev/null \
    || { echo "FAIL: não foi possível entrar em '$1' — recusado sem escrever nada (SEC-001)." >&2; return 1; }
  if [ "$(pwd -P)" != "$1" ]; then
    echo "FAIL: '$1' não é o diretório físico esperado (SEC-001) — um componente do caminho virou" >&2
    echo "      link simbólico ou foi trocado durante o sync; recusado sem escrever nada." >&2
    return 1
  fi
}

# _dir_ensure_subdir <dir_phys> <nome> — garante <dir_phys>/<nome> como diretório REAL, criado
# por nome relativo dentro do diretório ancorado. Nunca `mkdir -p` sobre o caminho inteiro.
_dir_ensure_subdir() {
  ( _dir_anchor "$1" || exit 1
    if [ -L "$2" ]; then
      echo "FAIL: '$1/$2' é symlink na conferência ancorada — recusado (SEC-001)." >&2
      exit 1
    fi
    [ -d "$2" ] || mkdir -- "$2" 2>/dev/null || [ -d "$2" ] \
      || { echo "FAIL: não foi possível criar o diretório '$1/$2' do hub." >&2; exit 1; }
    if [ -L "$2" ]; then
      echo "FAIL: '$1/$2' é symlink na conferência ancorada — recusado (SEC-001)." >&2
      exit 1
    fi
  )
}

# _dir_publish_file <src> <dir_phys> <nome> — publica o conteúdo de <src> como <dir_phys>/<nome>,
# atomicamente e sem seguir link nenhum dentro do hub. <src> é sempre um arquivo da réplica local
# ou do diretório privado de trabalho, nunca do hub. O temporário tem nome aleatório e de
# comprimento FIXO, independente de <nome> (um blob de 250 caracteres com sufixo acrescentado
# estouraria NAME_MAX — ENAMETOOLONG, w219 [8]). Ele é criado com `set -C` (noclobber: O_EXCL
# quando o nome não existe; recusa quando existe, inclusive como symlink pendente), sob
# `umask 022` — sai 0644, sem `chmod` por caminho depois (chmod por caminho segue link). A
# instalação é `rename(2)` por nome relativo, via node: substitui um link plantado no nome final
# sem segui-lo e RECUSA quando o nome final é diretório — `mv` moveria o arquivo para DENTRO dele,
# e de um symlink-para-diretório, para fora do hub.
_dir_publish_file() {
  local src="$1" dir="$2" nome="$3"
  case "$src" in /*) ;; *) src="$PWD/$src" ;; esac
  ( _dir_anchor "$dir" || exit 1
    umask 022
    tmp=".liaison-publica.$$.$RANDOM$RANDOM.tmp"; set -C
    if ! cat -- "$src" > "$tmp"; then
      rm -f -- "$tmp" 2>/dev/null
      echo "FAIL: não foi possível criar o temporário de publicação em '$dir' (SEC-001: nada publicado)." >&2
      exit 1
    fi
    set +C
    if ! node -e 'require("fs").renameSync(process.argv[1], process.argv[2])' -- "$tmp" "$nome"; then
      rm -f -- "$tmp" 2>/dev/null
      echo "FAIL: não foi possível instalar '$dir/$nome' (nome final ocupado por diretório?) — nada publicado." >&2
      exit 1
    fi
  )
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

# _dir_push_union <hub_dir> <own_file> — publica a UNIÃO do log do hub com o local, atomicamente.
# Delega o cálculo (e a detecção de bifurcação) a lib/liaison-push-union.mjs: um só predicado de
# divergência no repositório, o mesmo que o `import` usa para decidir quarentena. Sem `node` não
# há união possível, e publicar sem unir é justamente o dano da issue #101 — então recusa.
#
# SEC-001: a união é escrita num diretório PRIVADO (`mktemp -d`, fora do hub) e só então publicada
# por `_dir_publish_file`. Antes, o node gravava `log/.<self>.jsonl.tmp` DENTRO do hub com
# `writeFileSync`, que segue link — um symlink plantado nesse nome previsível desviava a união para
# fora. A réplica local recebe a cópia do temporário privado, nunca relida do hub.
_dir_push_union() {
  local hub="$1" own="$2"
  hub="$(_dir_phys_expected "$hub")" || return 1
  local hubf="$hub/log/$LIAISON_SELF.jsonl"
  _dir_reject_symlink "$hub/log" || return 1
  _dir_reject_symlink "$hubf" || return 1
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
  local priv
  priv="$(mktemp -d "${TMPDIR:-/tmp}/forge-liaison-uniao.XXXXXX")" \
    || { echo "FAIL: push RECUSADO — não foi possível criar o diretório privado da união." >&2; return 1; }
  local tmp="$priv/uniao.jsonl"
  if ! node "$mod" "$own" "$hubf" "$tmp" "$LIAISON_SELF"; then
    rm -rf "$priv"
    return 1
  fi
  if ! _dir_publish_file "$tmp" "$hub/log" "$LIAISON_SELF.jsonl"; then
    rm -rf "$priv"
    return 1
  fi
  # A réplica local passa a conter a união também: sem isso ela continuaria atrás do hub que ela
  # mesma acabou de escrever, e o próximo push repetiria o trabalho. A cópia vem do temporário
  # PRIVADO — reler do hub seria ler de novo um lugar que terceiros escrevem.
  if ! cp "$tmp" "$own"; then
    rm -rf "$priv"
    echo "FAIL: a união foi publicada, mas não foi possível atualizar a réplica local '$own'." >&2
    return 1
  fi
  rm -rf "$priv"
  return 0
}

# _dir_push_blobs <hub_dir> <src> — copia os blobs locais que o hub ainda não tem.
# Exclui `.recover-*.tmp`: nome temporário da passada de recuperação (liaison-import.mjs), nunca
# um blob de verdade. Um SIGKILL a meio de uma recuperação pode deixar esse arquivo órfão em
# `blobs/` (o `try/catch` que faz `unlinkSync` de melhor esforço não sobrevive à morte do
# processo) — sem a exclusão aqui, `find "$src/blobs" -type f` o varre como qualquer outro blob e
# `_dir_push` o publicaria no hub, contaminando toda réplica que sincronizar depois.
#
# SEC-001: um symlink em `blobs/<nome>` é RECUSA com rc≠0, nunca `continue` silencioso — engolir a
# recusa deixava o sync verde e gravava marca d'água de publicação para o que não foi publicado. A
# cópia passa por `_dir_publish_file`: nada de `blobs/.<nome>.tmp` previsível, nada de bit de
# execução herdado da origem.
_dir_push_blobs() {
  local hub="$1" src="$2"
  [ -d "$src/blobs" ] || return 0
  hub="$(_dir_phys_expected "$hub")" || return 1
  _dir_reject_symlink "$hub/blobs" || return 1
  _dir_ensure_subdir "$hub" blobs || return 1
  local b name
  while IFS= read -r b; do
    [ -n "$b" ] || continue
    name="$(basename "$b")"
    _dir_reject_symlink "$hub/blobs/$name" || return 1
    [ -f "$hub/blobs/$name" ] && continue
    _dir_publish_file "$b" "$hub/blobs" "$name" || return 1
  done < <(find "$src/blobs" -type f ! -name '.recover-*.tmp' 2>/dev/null | LC_ALL=C sort)
  return 0
}

# _dir_push <hub_dir> — publica log/<self>.jsonl e os blobs locais no ponto de encontro.
# Escrita atômica (temporário aleatório + rename) porque outro participante pode estar lendo o hub
# ao mesmo tempo. O hub é fixado no caminho físico uma vez; `log/` e `blobs/` são criados por nome
# relativo dentro dele, nunca por `mkdir -p` sobre o caminho inteiro.
_dir_push() {
  local hub="$1"
  local src="$LIAISON_CHANNEL_DIR"
  _dir_reject_symlink "$hub" || return 1
  _dir_reject_symlink "$hub/log" || return 1
  _dir_reject_symlink "$hub/blobs" || return 1
  hub="$(_dir_phys_expected "$hub")" || return 1
  _dir_ensure_subdir "$(dirname -- "$hub")" "$(basename -- "$hub")" || return 1
  _dir_ensure_subdir "$hub" log || return 1
  _dir_ensure_subdir "$hub" blobs || return 1
  local own="$src/log/$LIAISON_SELF.jsonl"
  if [ -f "$own" ]; then
    local verdict cls_rc=0
    verdict="$(_dir_push_classify "$hub" "$own")" || cls_rc=$?
    case "$cls_rc" in
      0)
        # `ff` também passa pela união. Quando o local é superconjunto do hub o resultado é o
        # mesmo do `cp` que havia aqui — mas o caminho ganha a validação de UM ESCRITOR POR
        # ARQUIVO, que o `cp` nunca fez: um log próprio contaminado com mensagem de terceiro era
        # publicado com rc 0, sobrescrevendo no hub a versão do dono por uma cópia alheia.
        if ! _dir_push_union "$hub" "$own"; then
          return 1
        fi
        _dir_push_blobs "$hub" "$src" || return 1
        return 0
        ;;
      1)
        # Réplica ATRASADA: o hub tem mensagem que esta árvore não tem. NÃO se recusa — UNE-SE.
        # Recusar também evitaria a perda, mas transformaria toda réplica atrasada em push que
        # reprova, e réplica atrasada é o estado NORMAL de uma máquina com worktrees; além disso
        # "sincronize primeiro" não é operação que o participante consiga executar sozinho,
        # porque `_dir_pull` não traz o próprio log de volta, por desenho. A união publica o que
        # esta árvore tem de novo sem derrubar o que só o hub tem, e a recusa fica reservada à
        # bifurcação real, que o próprio módulo detecta por `detectForks`.
        if ! _dir_push_union "$hub" "$own"; then
          return 1
        fi
        _dir_push_blobs "$hub" "$src" || return 1
        return 0
        ;;
      2)
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
          return 1
        fi
        ;;
      *)
        echo "FAIL: push RECUSADO — não foi possível classificar o log do hub (rc $cls_rc). Não saber ler o ponto de encontro é motivo de rigor, não de publicação." >&2
        return 1
        ;;
    esac
    # Só o REPARO DECLARADO (caso 2 sob --repair-own-log) chega aqui: é o único caminho em que a
    # substituição integral é o efeito pretendido, porque o operador afirmou por flag que esta
    # árvore é a autoridade sobre o log e viu por extenso o que está descartando.
    # Publicação pelo mesmo helper da união: temporário aleatório com O_EXCL e rename, nunca o
    # `log/.<self>.jsonl.tmp` previsível que um symlink plantado desviava para fora (SEC-001).
    _dir_publish_file "$own" "$hub/log" "$LIAISON_SELF.jsonl" || return 1
  fi
  _dir_push_blobs "$hub" "$src" || return 1
  return 0
}

# _dir_pull <hub_dir> <staging_dir> — materializa os logs ALHEIOS e os blobs do ponto de encontro
# num staging cru. Nunca traz de volta o próprio log: a réplica local é a fonte da verdade dele.
_dir_pull() {
  local hub="$1" staging="$2"
  _dir_reject_symlink "$hub" || return 1
  _dir_reject_symlink "$hub/log" || return 1
  _dir_reject_symlink "$hub/blobs" || return 1
  mkdir -p "$staging/log" "$staging/blobs"
  [ -d "$hub/log" ] || return 0
  local f name
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    name="$(basename "$f")"
    [ "$name" = "$LIAISON_SELF.jsonl" ] && continue
    cp "$f" "$staging/log/$name" && chmod 0644 "$staging/log/$name" 2>/dev/null
  done < <(find "$hub/log" -type f -name '*.jsonl' 2>/dev/null | LC_ALL=C sort)
  if [ -d "$hub/blobs" ]; then
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      name="$(basename "$f")"
      cp "$f" "$staging/blobs/$name" && chmod 0644 "$staging/blobs/$name" 2>/dev/null
    done < <(find "$hub/blobs" -type f 2>/dev/null | LC_ALL=C sort)
  fi
}
