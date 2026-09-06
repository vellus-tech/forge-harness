#!/usr/bin/env bash
# _common.sh — helpers compartilhados pelos transportes do liaison que usam um DIRETÓRIO como
# ponto de encontro (manual, fs, e o clone local do git). Não é um transporte: não define
# t_probe/t_push/t_pull, apenas as duas metades de cópia que todos eles repetiriam.
#
# Invariante que estes helpers preservam: o push publica APENAS o log do próprio remetente. Um
# participante nunca republica o log de terceiro — se o fizesse, publicaria a versão (possivelmente
# atrasada) que ele conhece, regredindo o hub e fazendo o dono do log perder mensagens já enviadas.

# _dir_push_classify <hub_dir> <own_file> — em que RELAÇÃO o log do hub está com o local.
#
# O push era `cp` + `mv` INCONDICIONAL — issue #101: uma réplica atrasada substituía o log do hub
# pelo seu, com rc 0 e sem uma linha de aviso, apagando mensagens que só existiam lá. Num log
# append-only não há de onde restaurar.
#
# A primeira correção usou PREFIXO ESTRITO de linhas, e ela recusava DOIS fatos diferentes como se
# fossem um só. Não são, e os remédios são opostos:
#
#   behind   — o hub tem um `msg_id` que esta réplica NÃO tem. Publicar apaga uma mensagem que só
#              existe lá. É a issue #101, e recusar é a única saída — inclusive sob reparo.
#   diverged — o hub tem conteúdo DIFERENTE num `msg_id` que esta réplica TAMBÉM tem.
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

# _dir_push <hub_dir> — publica log/<self>.jsonl e os blobs locais no ponto de encontro.
# Escrita atômica (tmp + mv) porque outro participante pode estar lendo o hub ao mesmo tempo.
_dir_push() {
  local hub="$1"
  local src="$LIAISON_CHANNEL_DIR"
  mkdir -p "$hub/log" "$hub/blobs"
  local own="$src/log/$LIAISON_SELF.jsonl"
  if [ -f "$own" ]; then
    local verdict cls_rc=0
    verdict="$(_dir_push_classify "$hub" "$own")" || cls_rc=$?
    case "$cls_rc" in
      0) : ;;
      1)
        echo "FAIL: push RECUSADO — réplica ATRASADA: o log de '$LIAISON_SELF' no hub tem mensagem(ns) que esta árvore não tem:" >&2
        echo "     ${verdict#behind}" >&2
        echo "      Publicar aqui SUBSTITUIRIA o log do hub pelo desta árvore, apagando mensagem já" >&2
        echo "      publicada por outra réplica da mesma identidade. Log append-only não se reescreve," >&2
        echo "      e não há de onde restaurar o que se perde." >&2
        echo "      Rode 'liaison-ops.sh sync <canal>' na árvore que está em dia, ou traga o log do hub" >&2
        echo "      para esta réplica antes de publicar. Hub: $hub/log/$LIAISON_SELF.jsonl" >&2
        return 1
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
    cp "$own" "$hub/log/.$LIAISON_SELF.jsonl.tmp"
    mv "$hub/log/.$LIAISON_SELF.jsonl.tmp" "$hub/log/$LIAISON_SELF.jsonl"
  fi
  if [ -d "$src/blobs" ]; then
    local b name
    while IFS= read -r b; do
      [ -n "$b" ] || continue
      name="$(basename "$b")"
      [ -f "$hub/blobs/$name" ] && continue
      cp "$b" "$hub/blobs/.$name.tmp" && mv "$hub/blobs/.$name.tmp" "$hub/blobs/$name"
    done < <(find "$src/blobs" -type f 2>/dev/null | LC_ALL=C sort)
  fi
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
