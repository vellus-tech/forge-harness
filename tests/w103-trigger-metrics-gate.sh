#!/usr/bin/env bash
# Gate W10.3 — métricas determinísticas de triggering cobrem positivos e negativos.
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w103.XXXXXX)"
trap 'rm -rf "$T"' EXIT

cat > "$T/results.json" <<'EOF'
{
  "skill": "capability-dispatcher",
  "cases": [
    {"id":"P1","split":"train","expected":true,"triggered":true},
    {"id":"P2","split":"train","expected":true,"triggered":false},
    {"id":"N1","split":"test","expected":false,"triggered":true},
    {"id":"N2","split":"test","expected":false,"triggered":false}
  ]
}
EOF

out="$(bash "$WS/template/.forge/scripts/eval-trigger-metrics.sh" "$T/results.json")"
grep -q 'precision=0.5 recall=0.5 f1=0.5' <<<"$out"
node - "$T/trigger-metrics.json" <<'NODE'
const d=require(process.argv[2]);
if(d.metrics.all.true_positive!==1 || d.metrics.all.false_positive!==1 || d.metrics.all.false_negative!==1 || d.metrics.all.true_negative!==1) process.exit(1);
if(d.metrics.train.observations!==2 || d.metrics.test.observations!==2) process.exit(1);
NODE
echo "PASS w103-trigger-metrics-gate"
