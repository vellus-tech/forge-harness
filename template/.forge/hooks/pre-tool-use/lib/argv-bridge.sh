#!/usr/bin/env bash
# argv-bridge.sh <gancho-alvo> [args-extras...] — ponte de contrato (issue #125).
#
# O Claude Code entrega TODO PreToolUse pelo STDIN, mas alguns ganchos deste diretório (contrato
# `argv` no hooks.manifest.default) ainda esperam receber o caminho do arquivo por `$1` — foi
# assim que já foram escritos, e reescrevê-los para ler stdin diretamente não é o escopo desta
# issue. Esta ponte lê o payload JSON do stdin, extrai `tool_input.file_path` e invoca o gancho
# alvo com esse valor como `$1`, sem alterar o gancho em si — que continua utilizável também por
# chamada direta (testes, ou o `dispatch-file-hook.sh` que um consumidor já tenha).
#
# FAIL-OPEN por design, e a razão é o alcance destes ganchos: os dois que esta ponte alcança hoje
# (check-language-policy.sh, validate-naming-conventions.sh) são convenção de nomenclatura/idioma,
# não segurança, e já saem 0 quando `$1` está vazio — um payload ilegível aqui produz o mesmo
# efeito neutro de uma chamada sem arquivo. O gancho de segurança (prevent-secrets-leak.sh) não
# passa por esta ponte: ele lê o stdin diretamente e é fail-CLOSED (ver o próprio arquivo).
set -uo pipefail

TARGET="${1:-}"
if [[ -n "$TARGET" ]]; then shift; fi

if [[ -z "$TARGET" ]]; then
  echo "[HOOK] argv-bridge: nenhum gancho-alvo informado (uso: argv-bridge.sh <gancho.sh>)" >&2
  exit 0
fi

input="$(cat 2>/dev/null || true)"
FILE=""
if [[ -n "$input" ]]; then
  if command -v jq >/dev/null 2>&1; then
    FILE="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
  fi
  if [[ -z "$FILE" ]] && command -v python3 >/dev/null 2>&1; then
    FILE="$(printf '%s' "$input" | python3 -c 'import sys, json
try:
    d = json.load(sys.stdin).get("tool_input", {}) or {}
except Exception:
    d = {}
print(d.get("file_path", "") or "")' 2>/dev/null || true)"
  fi
fi

exec "$TARGET" "$FILE" "$@"
