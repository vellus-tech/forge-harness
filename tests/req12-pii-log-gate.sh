#!/usr/bin/env bash
# Gate REQ-12/TASK-16 (design.md §2.2 "Extensão check-data-governance") — extensão do
# check-data-governance para código-fonte (exts ampliado além de .md):
#   [1] PAN (13-19 dígitos) em chamada de log.*(...)/logger.*(...) → CONFLICT, mesmo
#       sem nenhum bloco de mode declarado (REQ-12a é sempre enforce — REQ-16 AC3)
#   [2] PAN mascarado (sem corrida bruta de dígitos, ou via mask()) → PASS
#   [3] campo `// forge:sensitive-field="x"` sem entrada em data-classification.json → CONFLICT
#   [4] mesmo campo, COM entrada correspondente em data-classification.json → PASS
#   [6] REQ-06: campo `-- forge:sensitive-field="x"` (.sql) sem data-classification.json → CONFLICT
#   [7] REQ-06: mesmo campo em .sql, COM entrada correspondente → PASS
#   [8] REQ-06: PAN em chamada de log embutida em comentário .sql → CONFLICT
#   [9] REQ-06: .sql limpo (DDL comum, sem marcador nem log) → PASS, sem falso positivo
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
grep -q 'CONFLICT' <<<"$out" || { echo "FAIL [1]: saída sem CONFLICT: $out"; exit 1; }
grep -q 'service.go' <<<"$out" || { echo "FAIL [1]: saída não nomeia o arquivo: $out"; exit 1; }
grep -q 'REQ-12a' <<<"$out" || { echo "FAIL [1]: saída não referencia REQ-12a: $out"; exit 1; }
echo "OK [1] — $out"

echo "[2] PAN mascarado (literal sem corrida de dígitos + via mask()) → PASS"
out="$(node "$CHK" "$FIX/log-pan-masked-pass")"
grep -q '^OK ' <<<"$out" || { echo "FAIL [2]: esperava OK, obteve: $out"; exit 1; }
echo "OK [2] — $out"

echo "[3] campo sensível sem classificação → CONFLICT"
set +e
out="$(node "$CHK" "$FIX/sensitive-field-fail")"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [3]: esperava CONFLICT, obteve exit 0: $out"; exit 1; }
grep -q 'CONFLICT' <<<"$out" || { echo "FAIL [3]: saída sem CONFLICT: $out"; exit 1; }
grep -q 'cpf' <<<"$out" || { echo "FAIL [3]: saída não nomeia o campo: $out"; exit 1; }
grep -q 'REQ-12b' <<<"$out" || { echo "FAIL [3]: saída não referencia REQ-12b: $out"; exit 1; }
echo "OK [3] — $out"

echo "[4] campo sensível COM classificação correspondente → PASS"
out="$(node "$CHK" "$FIX/sensitive-field-pass")"
grep -q '^OK ' <<<"$out" || { echo "FAIL [4]: esperava OK, obteve: $out"; exit 1; }
echo "OK [4] — $out"

echo "[6] REQ-06: .sql com marcador sem data-classification.json → CONFLICT"
set +e
out="$(node "$CHK" "$FIX/sql-sensitive-field-fail")"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [6]: esperava CONFLICT, obteve exit 0: $out"; exit 1; }
grep -q 'CONFLICT' <<<"$out" || { echo "FAIL [6]: saída sem CONFLICT: $out"; exit 1; }
grep -q 'cpf' <<<"$out" || { echo "FAIL [6]: saída não nomeia o campo: $out"; exit 1; }
grep -q 'REQ-12b' <<<"$out" || { echo "FAIL [6]: saída não referencia REQ-12b: $out"; exit 1; }
echo "OK [6] — $out"

echo "[7] REQ-06: .sql com marcador COM data-classification.json correspondente → PASS"
out="$(node "$CHK" "$FIX/sql-sensitive-field-pass")"
grep -q '^OK ' <<<"$out" || { echo "FAIL [7]: esperava OK, obteve: $out"; exit 1; }
echo "OK [7] — $out"

echo "[8] REQ-06: PAN em chamada de log embutida em comentário .sql → CONFLICT"
set +e
out="$(node "$CHK" "$FIX/sql-log-pan-fail")"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [8]: esperava CONFLICT, obteve exit 0: $out"; exit 1; }
grep -q 'CONFLICT' <<<"$out" || { echo "FAIL [8]: saída sem CONFLICT: $out"; exit 1; }
grep -q 'service.sql' <<<"$out" || { echo "FAIL [8]: saída não nomeia o arquivo: $out"; exit 1; }
grep -q 'REQ-12a' <<<"$out" || { echo "FAIL [8]: saída não referencia REQ-12a: $out"; exit 1; }
echo "OK [8] — $out"

echo "[9] REQ-06: .sql limpo (DDL comum) → PASS, sem falso positivo"
out="$(node "$CHK" "$FIX/sql-clean-pass")"
grep -q '^OK ' <<<"$out" || { echo "FAIL [9]: esperava OK, obteve: $out"; exit 1; }
echo "OK [9] — $out"

echo "[5] retrocompat: gw3-data-governance-gate.sh continua verde (NFR-04)"
bash "$WS/tests/gw3-data-governance-gate.sh" >/dev/null
echo "OK [5]"

echo "OK"
