#!/usr/bin/env bash
# Gate W289 — busca unificada (/forge:kb), avaliador `kb.sh eval` e conjunto de avaliação versionado
# (change add-unified-knowledge-search, REQ-11; design §2.11).
#
#   [1] métricas calculadas batem com valores escritos à mão numa fixture hermética; consulta sem
#       relevante no corpus é erro; fragmento largo demais gera aviso
#   [2] calibração e holdout versionados são cópias literais da evidência do change, com ao menos 4
#       consultas em inglês por partição
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w289.XXXXXX)"
trap 'rm -rf "$T"' EXIT
KB="$WS/template/.forge/scripts/kb.sh"
firstline() { local o; o="$("$@")" || return $?; printf '%s\n' "${o%%$'\n'*}"; }
ok() { echo "OK [$1]"; }
fail() { echo "FAIL [$1] $2"; exit 1; }

# [1]
E="$T/eval"; mkdir -p "$E/docs/plans"
printf '# alfa\n\nbeta gama\n' > "$E/docs/plans/alfa.md"
printf '# delta\n\nepsilon zeta\n' > "$E/docs/plans/delta.md"
printf '# eta\n\ntheta iota\n' > "$E/docs/plans/eta.md"
printf '[{"q":"beta gama","gold":["alfa.md"]},{"q":"epsilon","gold":["eta.md"]}]\n' > "$E/q.json"
FORGE_ROOT="$E" bash "$KB" eval "$E/q.json" --json > "$T/ev.json" || fail 1 "kb.sh eval falhou ou não existe"
node -e '
const o=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
const m=o.modes.bm25;
// consulta 1: alfa em 1º (hit). consulta 2: só delta casa "epsilon"; eta nunca aparece -> miss.
if (m.hit1!==0.5||m.hit5!==0.5||m.hit10!==0.5||m.mrr!==0.5) { console.log(JSON.stringify(o)); process.exit(1); }
if (!("lexical" in o.modes)) process.exit(1);
' "$T/ev.json" || fail 1 "métricas do eval divergem do esperado à mão"
printf '[{"q":"x","gold":["inexistente.md"]}]\n' > "$E/q2.json"
set +e; FORGE_ROOT="$E" bash "$KB" eval "$E/q2.json" > /dev/null 2> "$T/ev2.err"; rc=$?; set -e
[ "$rc" -ne 0 ] && grep -q 'sem documento relevante' "$T/ev2.err" || fail 1 "consulta sem relevante não virou erro"
printf '[{"q":"beta","gold":["docs/plans"]}]\n' > "$E/q3.json"
for i in $(seq 1 11); do printf '# n\n\nfiller\n' > "$E/docs/plans/f$i.md"; done
FORGE_ROOT="$E" bash "$KB" eval "$E/q3.json" > /dev/null 2> "$T/ev3.err" || fail 1 "eval com fragmento largo falhou"
grep -q 'casa mais de 10 documentos' "$T/ev3.err" || fail 1 "fragmento largo sem aviso"
ok 1

# [2]
# a evidência do change vive em specs/active durante o change e em specs/archived/<data>-<id> depois do archive
EV="$(ls -d "$WS"/.forge/specs/active/add-unified-knowledge-search/evidence/prototype "$WS"/.forge/specs/archived/*-add-unified-knowledge-search/evidence/prototype 2>/dev/null | head -1 || true)"
if [ -n "$EV" ] && [ -d "$EV" ]; then
  cmp -s "$EV/queries.json" "$WS/tests/fixtures/kb/eval/calibration.json" || fail 2 "calibration.json difere da evidência"
  cmp -s "$EV/holdout.json" "$WS/tests/fixtures/kb/eval/holdout.json" || fail 2 "holdout.json difere da evidência"
fi
node -e '
for (const f of process.argv.slice(1)) { const q=JSON.parse(require("fs").readFileSync(f,"utf8")); const en=q.filter(x=>/\b(the|what|why|how|we|got|for|of|to|and|is|did|inside|with|by|from|has|have|our|an|but|without)\b/i.test(x.q)).length; if(en<4) { console.log(f,en); process.exit(1); } }
' "$WS/tests/fixtures/kb/eval/calibration.json" "$WS/tests/fixtures/kb/eval/holdout.json" || fail 2 "menos de 4 consultas em inglês numa partição"
ok 2

echo "PASS w289-kb-eval (2 casos)"
