#!/usr/bin/env bash
# Gate REQ-13/NFR-03 (§2.5, TASK-09) — proporcionalidade das 4 seções obrigatórias do
# template de requirements.md via `affects_surfaces` no manifest:
#   [1] affects_surfaces: [api] + requirements.md sem os mapas preenchidos → validate-spec FAIL
#       nomeando o mapa endpoint→policy e o mapa de eventos auditáveis
#   [2] affects_surfaces: [api] + requirements.md com os mapas preenchidos → validate-spec OK
#   [3] change trivial (sem affects_surfaces) → validate-spec OK, nenhuma exigência nova
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-req13.XXXXXX)"
trap 'rm -rf "$T"' EXIT

cp -R "$WS/template/.forge" "$T/.forge"
SPEC_NEW="$T/.forge/scripts/spec-new.sh"
VALIDATE="$T/.forge/scripts/validate-spec.sh"

mk_change() {
  local id="$1"
  (cd "$T" && bash "$SPEC_NEW" "$id" --type feature --scale 2 >/dev/null)
  # avança o manifest para requirements-ready — só ali a regra da TASK-09 é avaliada.
  sed -i '' 's/^status: proposed$/status: requirements-ready/' "$T/.forge/specs/active/$id/manifest.yaml"
}

echo "[1] affects_surfaces: [api] + mapas vazios (esqueleto do template) → FAIL"
mk_change "feat-api-empty"
cat >> "$T/.forge/specs/active/feat-api-empty/manifest.yaml" <<'EOF'
affects_surfaces:
  - api
EOF
set +e
out="$(cd "$T" && bash "$VALIDATE" --path "$T/.forge/specs/active/feat-api-empty")"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [1]: esperava reprovação, obteve: $out"; exit 1; }
echo "$out" | grep -q 'endpoint' || { echo "FAIL [1]: mensagem não cita o mapa endpoint→policy: $out"; exit 1; }
echo "$out" | grep -q 'auditable events map' || { echo "FAIL [1]: mensagem não cita o mapa de eventos auditáveis: $out"; exit 1; }
echo "OK [1] — $out"

echo "[2] affects_surfaces: [api] + mapas preenchidos → OK"
mk_change "feat-api-filled"
cat >> "$T/.forge/specs/active/feat-api-filled/manifest.yaml" <<'EOF'
affects_surfaces:
  - api
EOF
REQ="$T/.forge/specs/active/feat-api-filled/requirements.md"
python3 - "$REQ" <<'PYEOF'
import sys
p = sys.argv[1]
text = open(p, encoding="utf-8").read()
text = text.replace(
    "| `<método> <path>` | <ação, ex.: read/write/delete> | <recurso protegido> | <policy/regra PDP aplicada> | REQ-NN |",
    "| `POST /payments` | write | payment | policy-payments-write | REQ-01 |",
)
text = text.replace(
    "| <ação que muda estado> | <nome do evento auditável> | <campos do evento, mascarados> | REQ-NN |",
    "| criação de pagamento | payment.created | valor, moeda (sem PAN) | REQ-01 |",
)
open(p, "w", encoding="utf-8").write(text)
PYEOF
out="$(cd "$T" && bash "$VALIDATE" --path "$T/.forge/specs/active/feat-api-filled")"
echo "$out" | grep -q '^OK ' || { echo "FAIL [2]: esperava OK, obteve: $out"; exit 1; }
echo "OK [2] — $out"

echo "[3] change trivial (sem affects_surfaces) → OK, nenhuma exigência nova"
mk_change "feat-trivial"
grep -q '^affects_surfaces:' "$T/.forge/specs/active/feat-trivial/manifest.yaml" && { echo "FAIL [3]: manifest não deveria ter affects_surfaces"; exit 1; }
out="$(cd "$T" && bash "$VALIDATE" --path "$T/.forge/specs/active/feat-trivial")"
echo "$out" | grep -q '^OK ' || { echo "FAIL [3]: esperava OK, obteve: $out"; exit 1; }
echo "OK [3] — $out"

echo "OK"
