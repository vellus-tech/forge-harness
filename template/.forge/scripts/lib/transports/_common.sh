#!/usr/bin/env bash
# _common.sh — helpers compartilhados pelos transportes do liaison que usam um DIRETÓRIO como
# ponto de encontro (manual, fs, e o clone local do git). Não é um transporte: não define
# t_probe/t_push/t_pull, apenas as duas metades de cópia que todos eles repetiriam.
#
# Invariante que estes helpers preservam: o push publica APENAS o log do próprio remetente. Um
# participante nunca republica o log de terceiro — se o fizesse, publicaria a versão (possivelmente
# atrasada) que ele conhece, regredindo o hub e fazendo o dono do log perder mensagens já enviadas.

# _dir_push_is_fast_forward <hub_dir> <own_file> — 0 quando publicar o log local AVANÇA o hub.
#
# O push era `cp` + `mv` INCONDICIONAL (issue #101): uma réplica atrasada substituía o log do hub
# pelo seu, com rc 0 e sem uma linha de aviso, apagando mensagens que só existiam lá. Num log
# append-only não há de onde restaurar. Duas árvores do MESMO remetente é o caso real e comum —
# dois clones, ou tronco e worktree, cada um com sua réplica do canal.
#
# O predicado é o que a issue chama de comportamento certo: FAST-FORWARD OU RECUSA. O log do hub
# tem de ser PREFIXO do local, linha a linha e na ordem — que é a comparação exata para um log
# append-only de um único remetente. Não é o push que resolve divergência: `liaison-import.mjs` já
# é o caminho que trata log append-only como história que não se reescreve, e o push não pode ser
# mais frouxo que ele.
#
# Um único `awk`, sem pipeline: `grep … | head` aqui morreria sob `pipefail` por SIGPIPE, que é
# exatamente a classe que `check-shell-pipeline.sh` existe para reprovar.
_dir_push_is_fast_forward() {
  local hub="$1" own="$2"
  local hubf="$hub/log/$LIAISON_SELF.jsonl"
  [ -f "$hubf" ] || return 0        # hub ainda sem log deste remetente: qualquer publicação avança
  awk '
    NR == FNR { if ($0 != "") h[++nh] = $0; next }
    { if ($0 != "") l[++nl] = $0 }
    END {
      if (nh > nl) exit 1
      for (i = 1; i <= nh; i++) if (h[i] != l[i]) exit 1
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
    _dir_push_is_fast_forward "$hub" "$own" || {
      echo "FAIL: push RECUSADO — o log de '$LIAISON_SELF' no hub tem linha(s) que esta réplica não tem." >&2
      echo "      Publicar aqui SUBSTITUIRIA o log do hub pelo desta árvore, apagando mensagens já" >&2
      echo "      publicadas por outra réplica da mesma identidade. Log append-only não se reescreve," >&2
      echo "      e não há de onde restaurar o que se perde." >&2
      echo "      Rode 'liaison-ops.sh sync <canal>' na árvore que está em dia, ou traga o log do hub" >&2
      echo "      para esta réplica antes de publicar. Hub: $hub/log/$LIAISON_SELF.jsonl" >&2
      return 1
    }
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
