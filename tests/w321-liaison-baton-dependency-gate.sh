#!/usr/bin/env bash
# Gate — TASK-01 de add-liaison-handoff-baton (portão de dependência):
#   [1] add-liaison-native-bridge está mesclado em origin/develop (ou, sem rede, já presente nos
#       contratos abaixo, que só esse change introduz)
#   [2] liaison-ops.sh expõe o subcomando `notify`
#   [3] lib/liaison-publish.mjs exporta `isPublished`
#   [4] lib/liaison-pointer.mjs exporta `resolvePointer`
#   [5] validateEnvelope (liaison-merge.mjs) valida `via` com o valor `cross-session`
#   [6] send aceita a flag `--session`
#   [7] fixture de identidade de sessão (tests/fixtures/liaison-baton/session-identity/) existe e
#       documenta as quatro medições exigidas pela TASK-01
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIAISON_OPS="$WS/template/.forge/scripts/liaison-ops.sh"
PUBLISH_MJS="$WS/template/.forge/scripts/lib/liaison-publish.mjs"
POINTER_MJS="$WS/template/.forge/scripts/lib/liaison-pointer.mjs"
MERGE_MJS="$WS/template/.forge/scripts/lib/liaison-merge.mjs"
FIXTURE_DIR="$WS/tests/fixtures/liaison-baton/session-identity"

fail=0

echo "[1] add-liaison-native-bridge mesclado (contratos presentes no código desta árvore)"
# Sem depender de rede: a presença dos quatro contratos abaixo, todos introduzidos só por aquele
# change, É a prova de que ele está mesclado nesta árvore (design §1, nota de rodapé). Checagem
# de rede é feita no onboarding humano (passo 0 do ship), não neste gate determinístico.

echo "[2] liaison-ops.sh expõe notify"
if ! grep -qE '^\s*notify\)' "$LIAISON_OPS" 2>/dev/null; then
  echo "FAIL [notify]: $LIAISON_OPS não declara o case 'notify)'"
  fail=1
else
  echo "OK [2]"
fi

echo "[3] liaison-publish.mjs exporta isPublished"
if ! grep -qE '^export function isPublished\(' "$PUBLISH_MJS" 2>/dev/null; then
  echo "FAIL [isPublished]: $PUBLISH_MJS não exporta isPublished"
  fail=1
else
  echo "OK [3]"
fi

echo "[4] liaison-pointer.mjs exporta resolvePointer"
if ! grep -qE '^export function resolvePointer\(' "$POINTER_MJS" 2>/dev/null; then
  echo "FAIL [resolvePointer]: $POINTER_MJS não exporta resolvePointer"
  fail=1
else
  echo "OK [4]"
fi

echo "[5] validateEnvelope valida via com cross-session"
if ! grep -qE "VIA_VALUES\s*=.*'cross-session'" "$MERGE_MJS" 2>/dev/null; then
  echo "FAIL [via-cross-session]: $MERGE_MJS não lista 'cross-session' em VIA_VALUES"
  fail=1
else
  echo "OK [5]"
fi

echo "[6] send aceita --session"
if ! grep -qE -- '--session\)' "$LIAISON_OPS" 2>/dev/null; then
  echo "FAIL [send-session]: $LIAISON_OPS não trata a flag --session"
  fail=1
else
  echo "OK [6]"
fi

echo "[7] fixture de identidade de sessão existe e documenta as quatro medições"
README="$FIXTURE_DIR/README.md"
if [ ! -f "$README" ]; then
  echo "FAIL [fixture-ausente]: $README não existe"
  fail=1
else
  need=(
    "subagente"
    "additionalContext"
    "resume"
    "clear"
  )
  for n in "${need[@]}"; do
    if ! grep -qi "$n" "$README"; then
      echo "FAIL [fixture-incompleta]: $README não documenta medição relacionada a '$n'"
      fail=1
    fi
  done
  [ "$fail" -eq 0 ] && echo "OK [7]"
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS — TASK-01: contratos do change dependente confirmados; fixture de identidade de sessão presente"
exit 0
