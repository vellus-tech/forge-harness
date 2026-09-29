#!/usr/bin/env bash
# Transporte `fs` — hub em diretório local compartilhado. Default do piloto.
#
# É o `manual` acrescido de duas coisas: o hub é criado sob demanda (auto-suficiente, sem passo
# humano) e é multi-canal — o layout é `<path>/<channel>/{log,blobs}`, então um mesmo diretório
# compartilhado hospeda vários canais sem colisão.
#
# TOPOLOGIA: hub único por canal, nunca par-a-par. Cada participante publica o próprio log no
# ponto de encontro e puxa os N-1 restantes; a configuração cresce como N (cada repo aponta para
# um lugar), não como N². Par-a-par deixaria dois participantes divergentes por tempo
# indeterminado sem ninguém perceber.
#
# CONFIDENCIALIDADE: quem alcança o hub lê o canal inteiro, todas as threads. A lista de
# participantes de uma thread roteia e cobra ack — não confina leitura. Separação real é canal
# separado, com hub separado.

# shellcheck source=./_common.sh
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_fs_hub() { printf '%s/%s' "$LIAISON_T_PATH" "$LIAISON_CHANNEL"; }

t_probe() {
  [ -n "${LIAISON_T_PATH:-}" ] || { echo "FAIL: transporte fs exige 'path' no liaison.yaml" >&2; return 1; }
  local hub; hub="$(_fs_hub)"
  mkdir -p "$hub/log" "$hub/blobs" 2>/dev/null \
    || { echo "FAIL: não foi possível criar o hub em $hub (permissão? caminho inválido?)" >&2; return 1; }
  [ -w "$hub/log" ] || { echo "FAIL: hub sem permissão de escrita: $hub/log" >&2; return 1; }
  return 0
}

t_push() { _dir_push "$(_fs_hub)"; }

t_pull() { _dir_pull "$(_fs_hub)" "$1"; }
