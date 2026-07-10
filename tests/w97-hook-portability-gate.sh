#!/usr/bin/env bash
# Gate W-hook-portability — os hooks git rodam na máquina do desenvolvedor (macOS/BSD e Linux/GNU),
# não num runner controlado. Um `mktemp` com template inválido para BSD bloqueia TODO `git push`
# local (incidente real: `mktemp /tmp/forge-prepush-XXXXXX.log` — no BSD o template precisa TERMINAR
# nos X; qualquer sufixo depois do X faz o mktemp falhar e o hook aborta o push).
#   [1] nenhum `mktemp` nos hooks tem caractere após a sequência de X (footgun BSD)
#   [2] o pre-push é sintaticamente válido (bash -n) — o gate de docs não pode ter regressão de shell
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS="$WS/template/.forge/hooks"

echo "[1] mktemp portável (template termina nos X) em todos os hooks"
# procura `mktemp ... XXXX<algo>` onde <algo> não é X nem fim-de-token (aspas/espaço/paren/fim de linha)
if grep -rn 'mktemp' "$HOOKS" 2>/dev/null | grep -E 'X{3,}[^X[:space:]"'"'"')]'; then
  echo "FAIL [1] (mktemp com sufixo após os X — quebra no BSD/macOS; mova a extensão ou remova-a)"
  exit 1
fi
echo "OK [1] (nenhum mktemp com sufixo após os X)"

echo "[2] pre-push é shell válido"
bash -n "$HOOKS/git/pre-push" || { echo "FAIL [2] (pre-push com erro de sintaxe)"; exit 1; }
echo "OK [2] (bash -n limpo)"

echo "PASS w97-hook-portability-gate"
