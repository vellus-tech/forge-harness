#!/usr/bin/env bash
# Gate W5.3 — meta-avaliação do harness (§18):
#   [1] .forge/evals/meta é diretório de 1ª classe (README + presente no template)
#   [2] comando /forge:eval harness existe, marca opt-in e usa o caso requirements
#   [3] schema meta-eval é JSON válido
#   [4] meta-count.sh conta [MISS]/[CONFLICT]/[CLARIFY] e deriva Status determinista
#   [5] meta-count.sh deriva FAIL quando Status ausente mas há achados
#   [6] caso real with vs without template: meta-aggregate produz delta quantitativo
#   [7] meta-aggregate.json valida contra schema (ajv 2020) e tem mean±stddev
#   [8] verdict determinista: template_helps quando reduz MISS/CONFLICT e sobe pass-rate
#   [9] meta-aggregate recusa caso com um braço vazio
#  [10] camada Quality é opt-in (evals_enabled: false default)
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w53.XXXXXX)"
trap 'rm -rf "$T"' EXIT

cp -R "$WS/template/.forge" "$T/.forge"
export FORGE_ROOT="$T"

echo "[1] .forge/evals/meta de 1ª classe"
[ -d "$T/.forge/evals/meta" ]
[ -f "$T/.forge/evals/meta/README.md" ]
grep -qi 'meta-avalia' "$T/.forge/evals/meta/README.md"
echo "OK [1]"

echo "[2] /forge:eval harness (opt-in + caso requirements)"
CMD="$T/.forge/commands/quality/eval.md"
[ -f "$CMD" ]
head -1 "$CMD" | grep -q '^---'
grep -q 'description:' "$CMD"
grep -qi 'harness' "$CMD"
grep -q 'evals_enabled' "$CMD"
grep -qi 'requirements-validator\|requirements' "$CMD"
grep -q 'MISS\|CONFLICT' "$CMD"
echo "OK [2]"

echo "[3] schema meta-eval é JSON válido"
SCH="$T/.forge/schemas/meta-eval.schema.json"
[ -f "$SCH" ]
node -e "JSON.parse(require('fs').readFileSync('$SCH','utf8'))"
echo "OK [3]"

echo "[4] meta-count.sh conta marcadores + Status"
R="$T/report.txt"
cat > "$R" <<'EOF'
## Status: FAIL
[MISS]     req de login sem requisito
[MISS]     req de logout sem requisito
[CONFLICT] escopo contradiz proposal
[CLARIFY]  qual o TTL da sessao?
EOF
bash "$T/.forge/scripts/meta-count.sh" "$R" --out "$T/counts.json" >/dev/null
node -e "
  const c = JSON.parse(require('fs').readFileSync('$T/counts.json','utf8'));
  if (c.miss !== 2) throw new Error('miss != 2: ' + c.miss);
  if (c.conflict !== 1) throw new Error('conflict != 1: ' + c.conflict);
  if (c.clarify !== 1) throw new Error('clarify != 1: ' + c.clarify);
  if (c.status !== 'FAIL' || c.passed !== false) throw new Error('status incorreto');
  if (c.findings !== 3) throw new Error('findings != 3: ' + c.findings);
"
echo "OK [4]"

echo "[5] meta-count deriva FAIL sem linha Status quando há achados"
R2="$T/report2.txt"
printf '[MISS]     algo ausente\n' > "$R2"
bash "$T/.forge/scripts/meta-count.sh" "$R2" --out "$T/counts2.json" >/dev/null
node -e "
  const c = JSON.parse(require('fs').readFileSync('$T/counts2.json','utf8'));
  if (c.status !== 'FAIL') throw new Error('deveria derivar FAIL');
"
# E PASS quando não há nenhum achado nem Status
R3="$T/report3.txt"
printf 'Tudo certo, sem achados.\n' > "$R3"
bash "$T/.forge/scripts/meta-count.sh" "$R3" --out "$T/counts3.json" >/dev/null
node -e "
  const c = JSON.parse(require('fs').readFileSync('$T/counts3.json','utf8'));
  if (c.status !== 'PASS' || c.passed !== true) throw new Error('deveria derivar PASS');
"
echo "OK [5]"

echo "[6] caso real with vs without: meta-aggregate produz delta"
CASE="$T/.forge/evals/meta/requirements-template"
for arm in with-template without-template; do for k in 1 2; do
  mkdir -p "$CASE/runs/$arm/run-$k"
done; done
# without-template: validador acha muitas lacunas (estrutura livre)
cat > "$CASE/runs/without-template/run-1/validator-report.txt" <<'EOF'
## Status: FAIL
[MISS]     requisito de autenticacao ausente
[MISS]     requisito de auditoria ausente
[MISS]     criterios de aceite ausentes
[CONFLICT] escopo do MVP contradiz a proposal
EOF
cat > "$CASE/runs/without-template/run-2/validator-report.txt" <<'EOF'
## Status: FAIL
[MISS]     requisito de autenticacao ausente
[MISS]     requisito de auditoria ausente
[CONFLICT] escopo do MVP contradiz a proposal
EOF
# with-template: estrutura completa reduz achados
cat > "$CASE/runs/with-template/run-1/validator-report.txt" <<'EOF'
## Status: PASS
[CLARIFY]  qual o TTL da sessao?
EOF
cat > "$CASE/runs/with-template/run-2/validator-report.txt" <<'EOF'
## Status: PASS
EOF
for arm in with-template without-template; do for k in 1 2; do
  bash "$T/.forge/scripts/meta-count.sh" "$CASE/runs/$arm/run-$k/validator-report.txt" \
    --out "$CASE/runs/$arm/run-$k/counts.json" >/dev/null
done; done
out6="$(bash "$T/.forge/scripts/meta-aggregate.sh" "$CASE")"
grep -q '^OK meta' <<<"$out6"
[ -f "$CASE/meta-aggregate.json" ]
echo "OK [6]"

echo "[7] meta-aggregate.json valida contra schema + mean±stddev"
node - "$SCH" "$CASE/meta-aggregate.json" <<'NODEEOF'
const Ajv = require(process.env.AJV_PATH || 'ajv/dist/2020').default;
const { readFileSync } = require('fs');
const ajv = new Ajv({ allErrors: true, strict: false });
const validate = ajv.compile(JSON.parse(readFileSync(process.argv[2], 'utf8')));
const data = JSON.parse(readFileSync(process.argv[3], 'utf8'));
if (!validate(data)) { console.error('FAIL schema:', JSON.stringify(validate.errors, null, 2)); process.exit(1); }
if (typeof data.without_template.miss_stddev !== 'number') throw new Error('miss_stddev ausente (without)');
if (data.with_template.n !== 2 || data.without_template.n !== 2) throw new Error('n incorreto');
console.log('meta-aggregate.json valido contra schema');
NODEEOF
echo "OK [7]"

echo "[8] verdict determinista template_helps"
AJV_PATH="$WS/node_modules/ajv/dist/2020" node -e "
  const d = JSON.parse(require('fs').readFileSync('$CASE/meta-aggregate.json','utf8'));
  // without MISS mean = (3+2)/2 = 2.5; with = 0 -> delta -2.5
  if (d.delta.miss !== -2.5) throw new Error('delta.miss != -2.5: ' + d.delta.miss);
  if (d.delta.conflict !== -1) throw new Error('delta.conflict != -1: ' + d.delta.conflict);
  if (d.delta.pass_rate !== 1) throw new Error('delta.pass_rate != 1: ' + d.delta.pass_rate);
  if (d.verdict !== 'template_helps') throw new Error('verdict != template_helps: ' + d.verdict);
"
echo "OK [8]"

echo "[9] meta-aggregate recusa braço vazio"
EMPTY="$T/.forge/evals/meta/empty-case"
mkdir -p "$EMPTY/runs/with-template/run-1"
cp "$CASE/runs/with-template/run-1/counts.json" "$EMPTY/runs/with-template/run-1/counts.json"
set +e
out9="$(bash "$T/.forge/scripts/meta-aggregate.sh" "$EMPTY" 2>&1)"; rc9=$?
set -e
[ "$rc9" -ne 0 ]
grep -qi 'braço\|brac\|>=1' <<<"$out9"
echo "OK [9]"

echo "[10] camada Quality é opt-in (evals_enabled: false default)"
grep -q 'evals_enabled: false' "$T/.forge/FORGE.md"
echo "OK [10]"

echo "OK"
