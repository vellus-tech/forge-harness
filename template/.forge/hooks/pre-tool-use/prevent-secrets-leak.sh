#!/usr/bin/env bash
set -uo pipefail

# Pre-tool-use hook do Claude Code: bloqueia Write/Edit/MultiEdit/NotebookEdit que contenha
# padrões típicos de secrets antes do arquivo ir para o disco.
#
# CONTRATO stdin-json (issue #125). O Claude Code entrega o payload do PreToolUse pelo STDIN,
# nunca por argv — antes desta correção o gancho só lia $1/$2, então argv chegava sempre vazio e o
# gancho aprovava (`exit 0`) qualquer conteúdo, mesmo registrado em `.claude/settings.json`. Uso
# legado por argv continua funcionando (chamada direta, ou um `dispatch-file-hook.sh` de
# consumidor que traduz stdin -> argv antes de invocar este script):
#   prevent-secrets-leak.sh <file> [<new-content>]
# Sem argv, lê o JSON do stdin e extrai `tool_input.file_path` e o conteúdo que ENTRA
# (`tool_input.content` do Write, `tool_input.new_string` do Edit, ou a concatenação de
# `tool_input.edits[].new_string` do MultiEdit). FAIL-CLOSED (exit 2, nunca exit 0): quando nem
# argv nem stdin trazem payload reconhecível, o gancho bloqueia — medido no Axis.PadSimulator, que
# trata "não consegui examinar o payload" como razão para reter, não para aprovar.
#
# EXIT 2, nunca exit 1, quando encontra violação: é o único código que o Claude Code trata como
# bloqueio real de PreToolUse — um gancho que sai 1 é tratado como falha não bloqueante, e a
# ferramenta segue mesmo assim (o próprio desarme desta issue, por outro caminho).

FILE="${1:-}"
CONTENT="${2:-}"

# b64dec — decodifica base64 de forma portátil: `base64 -d` (GNU/Linux) e `base64 -D` (BSD/macOS)
# não são a mesma flag, e nenhum ambiente deste gancho pode assumir qual dos dois está instalado.
b64dec() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys, base64; sys.stdout.write(base64.b64decode(sys.stdin.read()).decode("utf-8", "replace"))'
  else
    base64 -d 2>/dev/null || base64 -D 2>/dev/null || true
  fi
}

if [[ -z "$FILE" ]]; then
  input="$(cat 2>/dev/null || true)"
  if [[ -z "$input" ]]; then
    echo "[HOOK] prevent-secrets-leak: payload vazio (nem argv, nem stdin) — fail-closed" >&2
    exit 2
  fi
  CONTENT_B64=""
  if command -v jq >/dev/null 2>&1; then
    FILE="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
    CONTENT_B64="$(printf '%s' "$input" | jq -r '
      ((.tool_input.content // .tool_input.new_string
        // ((.tool_input.edits // []) | map(.new_string // "") | join("\n"))
        // "")) | @base64' 2>/dev/null || true)"
  fi
  if [[ -z "$FILE" ]] && command -v python3 >/dev/null 2>&1; then
    FILE="$(printf '%s' "$input" | python3 -c 'import sys, json
try:
    d = json.load(sys.stdin).get("tool_input", {}) or {}
except Exception:
    d = {}
print(d.get("file_path", "") or "")' 2>/dev/null || true)"
    CONTENT_B64="$(printf '%s' "$input" | python3 -c 'import sys, json, base64
try:
    d = json.load(sys.stdin).get("tool_input", {}) or {}
except Exception:
    d = {}
c = d.get("content")
if c is None:
    c = d.get("new_string")
if c is None:
    edits = d.get("edits") or []
    c = "\n".join((e.get("new_string") or "") for e in edits if isinstance(e, dict))
print(base64.b64encode((c or "").encode("utf-8")).decode("ascii"))' 2>/dev/null || true)"
  fi
  if [[ -z "$FILE" ]]; then
    echo "[HOOK] prevent-secrets-leak: não consegui extrair tool_input.file_path do payload stdin (sem jq/python3, ou JSON malformado) — fail-closed" >&2
    exit 2
  fi
  if [[ -n "$CONTENT_B64" ]]; then
    CONTENT="$(printf '%s' "$CONTENT_B64" | b64dec)"
  fi
fi

if [[ -z "$FILE" ]]; then
  exit 0
fi

# Arquivos de exemplo/template/teste — ignorados (falsos positivos esperados).
# Padrões intencionalmente conservadores — `manifest.json` ou `latest.config`
# NÃO devem casar (filtro anterior `(test|spec|mock|fixture)` era amplo demais).
case "$FILE" in
    *.example|*.tmpl|*.sample) exit 0 ;;
    */tests/*|*/test/*|tests/*|test/*) exit 0 ;;
    *.Tests/*|*Tests/*|*.Tests.csproj|*Tests.csproj) exit 0 ;;
    *.test.*|*.spec.*) exit 0 ;;
    */fixtures/*|*/fixture/*|*/mocks/*|*/mock/*) exit 0 ;;
esac

VIOLATIONS=()

TARGET_CONTENT=""
if [[ -f "$FILE" ]]; then
  TARGET_CONTENT=$(cat "$FILE" 2>/dev/null || true)
fi
CHECK_CONTENT="${CONTENT}${TARGET_CONTENT}"

if [[ -z "$CHECK_CONTENT" ]]; then
  exit 0
fi

# AWS Access Key ID
if echo "$CHECK_CONTENT" | grep -qE 'AKIA[0-9A-Z]{16}'; then
  VIOLATIONS+=("AWS Access Key ID detectada (padrão AKIA...)")
fi

# AWS Secret Access Key (heurística)
if echo "$CHECK_CONTENT" | grep -qE '[aA][wW][sS].{0,20}['\''"][0-9a-zA-Z/+]{40}['\''"]'; then
  VIOLATIONS+=("Possível AWS Secret Access Key")
fi

# aws_secret_access_key=... em texto puro (config/env)
if echo "$CHECK_CONTENT" | grep -qiE 'aws_secret_access_key\s*[:=]\s*[A-Za-z0-9/+=]{20,}'; then
  VIOLATIONS+=("aws_secret_access_key em atribuição")
fi

# JWT (3 partes base64 separadas por ponto, prefixo eyJ)
if echo "$CHECK_CONTENT" | grep -qE 'eyJ[a-zA-Z0-9_-]+\.eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+'; then
  VIOLATIONS+=("Token JWT detectado (eyJ...)")
fi

# Private key PEM (exige os 5 dashes do formato real para evitar auto-match em código)
if echo "$CHECK_CONTENT" | grep -qE '\-\-\-\-\-BEGIN [A-Z ]*PRIVATE KEY\-\-\-\-\-'; then
  VIOLATIONS+=("Chave privada PEM detectada")
fi

# Senha em atribuição
if echo "$CHECK_CONTENT" | grep -qiE '(password|senha|passwd|secret|api_key|apikey)\s*[=:]\s*['\''"][^'\''"\$\{][^'\''"\$\{]{4,}['\''"]'; then
  VIOLATIONS+=("Possível senha/secret hardcoded em atribuição")
fi

# Senha em connection string
if echo "$CHECK_CONTENT" | grep -qiE 'password=[^;$\{]{4,}'; then
  VIOLATIONS+=("Possível senha em connection string")
fi

# API key de LLM (sk-...)
if echo "$CHECK_CONTENT" | grep -qE 'sk-[a-zA-Z0-9]{20,}'; then
  VIOLATIONS+=("Possível API key de LLM (sk-...)")
fi

# GitHub tokens
if echo "$CHECK_CONTENT" | grep -qE 'gh[ps]_[a-zA-Z0-9]{36}'; then
  VIOLATIONS+=("Token do GitHub detectado (ghp_/ghs_)")
fi

if [[ ${#VIOLATIONS[@]} -gt 0 ]]; then
  echo "[HOOK] POSSÍVEL VAZAMENTO DE SECRET em: $FILE" >&2
  for v in "${VIOLATIONS[@]}"; do
    echo "[HOOK]   - $v" >&2
  done
  echo "[HOOK] Use AWS Secrets Manager / Parameter Store / variáveis de ambiente." >&2
  echo "[HOOK] Falso positivo? Revise manualmente e contorne explicitamente." >&2
  exit 2
fi

exit 0
