#!/usr/bin/env bash
# Gate REQ-12/TASK-16 (design.md §2.2 "Extensão check-data-governance") — extensão do
# check-data-governance para código-fonte (exts ampliado além de .md):
#   [1] PAN (13-19 dígitos) em chamada de log.*(...)/logger.*(...) → CONFLICT, mesmo
#       sem nenhum bloco de mode declarado (REQ-12a é sempre enforce — REQ-16 AC3)
#   [2] PAN mascarado (sem corrida bruta de dígitos, ou via mask()) → PASS
#   [3] campo `// forge:sensitive-field="x"` sem entrada em data-classification.json → CONFLICT
#   [4] mesmo campo, COM entrada correspondente em data-classification.json → PASS
#   [5] retrocompat: gw3-data-governance-gate.sh continua verde (NFR-04)
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHK="$WS/template/.forge/scripts/lib/check-data-governance.mjs"
FIX="$WS/tests/fixtures/data-governance"
[ -f "$CHK" ]

echo "[1] PAN em log.Printf(...) → CONFLICT, nomeando o arquivo"
set +e
out="$(node "$CHK" "$FIX/log-pan-fail")"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [1]: esperava CONFLICT, obteve exit 0: $out"; exit 1; }
echo "$out" | grep -q 'CONFLICT' || { echo "FAIL [1]: saída sem CONFLICT: $out"; exit 1; }
echo "$out" | grep -q 'service.go' || { echo "FAIL [1]: saída não nomeia o arquivo: $out"; exit 1; }
echo "$out" | grep -q 'REQ-12a' || { echo "FAIL [1]: saída não referencia REQ-12a: $out"; exit 1; }
echo "OK [1] — $out"

echo "[2] PAN mascarado (literal sem corrida de dígitos + via mask()) → PASS"
out="$(node "$CHK" "$FIX/log-pan-masked-pass")"
echo "$out" | grep -q '^OK ' || { echo "FAIL [2]: esperava OK, obteve: $out"; exit 1; }
echo "OK [2] — $out"

echo "[3] campo sensível sem classificação → CONFLICT"
set +e
out="$(node "$CHK" "$FIX/sensitive-field-fail")"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [3]: esperava CONFLICT, obteve exit 0: $out"; exit 1; }
echo "$out" | grep -q 'CONFLICT' || { echo "FAIL [3]: saída sem CONFLICT: $out"; exit 1; }
echo "$out" | grep -q 'cpf' || { echo "FAIL [3]: saída não nomeia o campo: $out"; exit 1; }
echo "$out" | grep -q 'REQ-12b' || { echo "FAIL [3]: saída não referencia REQ-12b: $out"; exit 1; }
echo "OK [3] — $out"

echo "[4] campo sensível COM classificação correspondente → PASS"
out="$(node "$CHK" "$FIX/sensitive-field-pass")"
echo "$out" | grep -q '^OK ' || { echo "FAIL [4]: esperava OK, obteve: $out"; exit 1; }
echo "OK [4] — $out"

echo "[5] retrocompat: gw3-data-governance-gate.sh continua verde (NFR-04)"
bash "$WS/tests/gw3-data-governance-gate.sh" >/dev/null
echo "OK [5]"

echo "OK"
