#!/usr/bin/env bash
# Gate W5.2 — eval harness opt-in (§17.8):
#   [1] runners.yaml tem >=1 runner com captura tokens/duração e degradação serial
#   [2] schemas grading + evals são JSON válidos
#   [3] agentes quality executor/grader/comparator/analyzer existem com frontmatter
#   [4] comando /forge:skill existe com subcomandos create|eval|optimize e marca opt-in
#   [5] grading.json sintético valida contra grading.schema.json (ajv, draft 2020)
#   [6] eval-aggregate.sh produz aggregate.json com mean±stddev e deltas
#   [7] eval-holdout.sh seleciona pela pontuação de TESTE (anti-overfitting)
#   [8] holdout recusa candidata com description > 1024 chars
#   [9] camada Quality é opt-in (evals_enabled: false por default em FORGE.md)
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w52.XXXXXX)"
trap 'rm -rf "$T"' EXIT

cp -R "$WS/template/.forge" "$T/.forge"
export FORGE_ROOT="$T"

echo "[1] runners.yaml: runner com captura + serial fallback"
RUN="$T/.forge/runners.yaml"
[ -f "$RUN" ]
grep -q 'claude-code:' "$RUN"
grep -q 'captures:' "$RUN"
grep -q 'tokens' "$RUN"
grep -q 'duration_ms' "$RUN"
grep -q 'serial_fallback' "$RUN"
grep -q 'timeout_s' "$RUN"
echo "OK [1]"

echo "[2] schemas grading + evals são JSON válidos"
for s in grading evals; do
  f="$T/.forge/schemas/${s}.schema.json"
  [ -f "$f" ]
  node -e "JSON.parse(require('fs').readFileSync('$f','utf8'))"
done
echo "OK [2]"

echo "[3] agentes quality executor/grader/comparator/analyzer"
for a in executor grader comparator analyzer; do
  p="$T/.forge/agents/quality/$a.md"
  [ -f "$p" ]
  head -1 "$p" | grep -q '^---'
  grep -q "name: eval-$a" "$p"
  grep -q 'description:' "$p"
done
echo "OK [3]"

echo "[4] /forge:skill-lifecycle com create|eval|optimize + opt-in"
CMD="$T/.forge/commands/skills/skill-lifecycle.md"
[ -f "$CMD" ]
head -1 "$CMD" | grep -q '^---'
grep -q 'description:' "$CMD"
grep -qi '## create' "$CMD"
grep -qi '## eval' "$CMD"
grep -qi '## optimize' "$CMD"
grep -q 'evals_enabled' "$CMD"
echo "OK [4]"

echo "[5] grading.json sintético valida contra schema (ajv 2020)"
ITER="$T/.forge/evals/skills/demo/workspace/iteration-1"
mkdir -p "$ITER/eval-1" "$ITER/eval-2"
cat > "$ITER/eval-1/grading.json" <<'EOF'
{
  "skill": "demo",
  "runner": "claude-code",
  "baseline": { "description": "sem skill" },
  "variant": { "description": "com skill" },
  "test_cases": [
    {
      "id": "TC-01",
      "prompt": "Identifique o módulo afetado",
      "baseline_result": { "output": "modulo generico", "duration_ms": 4200, "tokens": 350, "exit_code": 0 },
      "variant_result": { "output": "payment-processing module e ADR-014", "duration_ms": 3100, "tokens": 290, "exit_code": 0 },
      "expectations": [
        { "text": "Identificou o modulo correto", "passed": true, "evidence": "variant cita 'payment-processing module'" },
        { "text": "Citou a ADR relevante", "passed": true, "evidence": "variant cita 'ADR-014'" }
      ]
    }
  ],
  "aggregate": {
    "baseline_pass_rate": 0.5,
    "variant_pass_rate": 1.0,
    "delta_pass_rate": 0.5,
    "baseline_duration_mean_ms": 4200,
    "variant_duration_mean_ms": 3100,
    "delta_duration_ms": -1100
  }
}
EOF
# eval-2: variant pior em um caso, para variância > 0
cat > "$ITER/eval-2/grading.json" <<'EOF'
{
  "skill": "demo",
  "runner": "claude-code",
  "baseline": { "description": "sem skill" },
  "variant": { "description": "com skill" },
  "test_cases": [
    {
      "id": "TC-01",
      "prompt": "Identifique o módulo afetado",
      "baseline_result": { "output": "modulo generico", "duration_ms": 4000, "tokens": 360, "exit_code": 0 },
      "variant_result": { "output": "payment module", "duration_ms": 3300, "tokens": 300, "exit_code": 0 },
      "expectations": [
        { "text": "Identificou o modulo correto", "passed": true, "evidence": "variant cita 'payment module'" },
        { "text": "Citou a ADR relevante", "passed": false, "evidence": "variant nao menciona ADR" }
      ]
    }
  ],
  "aggregate": {
    "baseline_pass_rate": 0.5,
    "variant_pass_rate": 0.5,
    "delta_pass_rate": 0.0,
    "baseline_duration_mean_ms": 4000,
    "variant_duration_mean_ms": 3300,
    "delta_duration_ms": -700
  }
}
EOF
node - "$T/.forge/schemas/grading.schema.json" "$ITER/eval-1/grading.json" "$ITER/eval-2/grading.json" <<'NODEEOF'
const Ajv = require(process.env.AJV_PATH || 'ajv/dist/2020').default;
const { readFileSync } = require('fs');
const ajv = new Ajv({ allErrors: true, strict: false });
const schema = JSON.parse(readFileSync(process.argv[2], 'utf8'));
const validate = ajv.compile(schema);
for (const f of process.argv.slice(3)) {
  const data = JSON.parse(readFileSync(f, 'utf8'));
  if (!validate(data)) {
    console.error('FAIL schema:', f, JSON.stringify(validate.errors, null, 2));
    process.exit(1);
  }
}
console.log('grading.json valido contra schema');
NODEEOF
echo "OK [5]"

echo "[6] eval-aggregate.sh: mean±stddev + deltas"
out6="$(AJV_PATH="$WS/node_modules/ajv/dist/2020" bash "$T/.forge/scripts/eval-aggregate.sh" "$ITER")"
echo "$out6" | grep -q '^OK aggregate'
[ -f "$ITER/aggregate.json" ]
node -e "
  const a = JSON.parse(require('fs').readFileSync('$ITER/aggregate.json','utf8'));
  if (a.n_evals !== 2) throw new Error('n_evals != 2');
  // pass-rate variant mean = (1.0 + 0.5)/2 = 0.75
  if (a.variant.pass_rate_mean !== 0.75) throw new Error('variant mean != 0.75: ' + a.variant.pass_rate_mean);
  // stddev > 0 (casos divergem)
  if (!(a.variant.pass_rate_stddev > 0)) throw new Error('stddev deveria ser > 0');
  // delta pass-rate = 0.75 - 0.5 = 0.25
  if (a.delta.pass_rate !== 0.25) throw new Error('delta pass_rate != 0.25: ' + a.delta.pass_rate);
  if (typeof a.delta.duration_ms !== 'number') throw new Error('delta duration ausente');
"
echo "OK [6]"

echo "[7] eval-holdout.sh: seleção por TEST score (anti-overfitting)"
# Construímos candidatas onde a melhor no TREINO NÃO é a melhor no TESTE.
# Split determinista 60/40 sobre ids ordenados: 5 casos -> train [TC-01..TC-03], test [TC-04,TC-05].
CAND="$ITER/candidates.json"
cat > "$CAND" <<'EOF'
{
  "skill": "demo",
  "cases": ["TC-01","TC-02","TC-03","TC-04","TC-05"],
  "candidates": [
    { "id": "overfit", "description": "decora o treino", "scores": { "TC-01": 1, "TC-02": 1, "TC-03": 1, "TC-04": 0, "TC-05": 0 } },
    { "id": "general", "description": "generaliza melhor", "scores": { "TC-01": 0, "TC-02": 1, "TC-03": 0, "TC-04": 1, "TC-05": 1 } }
  ]
}
EOF
out7="$(bash "$T/.forge/scripts/eval-holdout.sh" "$CAND")"
echo "$out7" | grep -q 'winner general'
[ -f "$ITER/holdout.json" ]
node -e "
  const h = JSON.parse(require('fs').readFileSync('$ITER/holdout.json','utf8'));
  if (h.selection_metric !== 'test_score') throw new Error('metric != test_score');
  if (h.winner.id !== 'general') throw new Error('winner deveria ser general (melhor no teste), veio ' + h.winner.id);
  const overfit = h.candidates.find(c => c.id === 'overfit');
  // overfit vence no treino mas perde no teste — train e test reportados separados
  if (!(overfit.train_score > h.winner.train_score)) throw new Error('overfit deveria ganhar no treino');
  if (!(h.winner.test_score > overfit.test_score)) throw new Error('winner deveria ganhar no teste');
  if (h.split.train.length !== 3 || h.split.test.length !== 2) throw new Error('split 60/40 incorreto');
"
echo "OK [7]"

echo "[8] holdout recusa description > 1024 chars"
BIG="$ITER/candidates-big.json"
node -e "
  const big = 'x'.repeat(1025);
  const o = { skill:'demo', cases:['TC-01','TC-02'], candidates:[{ id:'c0', description: big, scores:{'TC-01':1,'TC-02':1} }] };
  require('fs').writeFileSync('$BIG', JSON.stringify(o));
"
set +e
out8="$(bash "$T/.forge/scripts/eval-holdout.sh" "$BIG" 2>&1)"; rc8=$?
set -e
[ "$rc8" -ne 0 ]
echo "$out8" | grep -qi '1024'
echo "OK [8]"

echo "[9] camada Quality é opt-in (evals_enabled: false default)"
F="$T/.forge/FORGE.md"
grep -q 'evals_enabled: false' "$F"
echo "OK [9]"

echo "OK"
