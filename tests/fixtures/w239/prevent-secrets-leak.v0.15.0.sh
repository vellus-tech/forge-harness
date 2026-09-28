#!/usr/bin/env bash
set -euo pipefail

# Pre-tool-use hook do Claude Code: bloqueia Write/Edit que contenha
# padrões típicos de secrets antes do arquivo ir para o disco.
# Uso: prevent-secrets-leak.sh <file> [<new-content>]

FILE="${1:-}"
CONTENT="${2:-}"

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
  exit 1
fi

exit 0
