#!/usr/bin/env bash
# Transporte `manual` — a PRIMITIVA de que todos os outros são casos particulares.
#
# O ponto de encontro é um diretório qualquer, com o mesmo layout de `liaison-ops.sh export`
# (`log/` + `blobs/`) — o que torna `export`/`import` e `sync --kind manual` literalmente
# intercambiáveis. É o transporte para quando o canal atravessa uma fronteira que nenhum script
# cruza sozinho: pendrive, anexo de e-mail, diretório de VPN montado à mão.
#
# A única diferença para o `fs` é deliberada: `manual` NUNCA cria o ponto de encontro. Se o
# diretório não existe, o probe REPROVA — porque quem opera manualmente precisa saber que está
# publicando num lugar que ninguém combinou, em vez de ver o sync passar contra um diretório
# recém-criado e vazio que o outro lado jamais vai olhar.
#
# Contrato (ver liaison-ops.sh): t_probe, t_push <src>, t_pull <staging>.

# shellcheck source=./_common.sh
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

t_probe() {
  [ -n "${LIAISON_T_PATH:-}" ] || { echo "FAIL: transporte manual exige 'path' no liaison.yaml" >&2; return 1; }
  [ -d "$LIAISON_T_PATH" ] || { echo "FAIL: ponto de encontro não existe: $LIAISON_T_PATH (transporte manual não cria o diretório — combine-o com o outro lado)" >&2; return 1; }
  return 0
}

t_push() { _dir_push "$LIAISON_T_PATH"; }

t_pull() { _dir_pull "$LIAISON_T_PATH" "$1"; }
