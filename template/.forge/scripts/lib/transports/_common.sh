#!/usr/bin/env bash
# _common.sh — helpers compartilhados pelos transportes do liaison que usam um DIRETÓRIO como
# ponto de encontro (manual, fs, e o clone local do git). Não é um transporte: não define
# t_probe/t_push/t_pull, apenas as duas metades de cópia que todos eles repetiriam.
#
# Invariante que estes helpers preservam: o push publica APENAS o log do próprio remetente. Um
# participante nunca republica o log de terceiro — se o fizesse, publicaria a versão (possivelmente
# atrasada) que ele conhece, regredindo o hub e fazendo o dono do log perder mensagens já enviadas.

# _dir_push <hub_dir> — publica log/<self>.jsonl e os blobs locais no ponto de encontro.
# Escrita atômica (tmp + mv) porque outro participante pode estar lendo o hub ao mesmo tempo.
_dir_push() {
  local hub="$1"
  local src="$LIAISON_CHANNEL_DIR"
  mkdir -p "$hub/log" "$hub/blobs"
  local own="$src/log/$LIAISON_SELF.jsonl"
  if [ -f "$own" ]; then
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
