#!/usr/bin/env bash
# Gate W173 — contrato entre archive-state-machine.yaml (definição CANÔNICA) e a cadeia
# EXECUTÁVEL de spec-transition.sh (LDG-0035).
#
# Achado pelo harness-integrity-reviewer no PR #42: a rota lateral requirements-ready ->
# tasks-ready (pulo de design-ready, só para type:bugfix scale>=2 — LDG-0030) existe de verdade
# em spec-transition.sh, mas nenhuma transição no YAML declara essa aresta; a cadeia declarada só
# prevê requirements-ready -> design-ready -> tasks-ready linear. Nenhum gate confrontava as duas
# fontes. Este é um teste de CONTRATO: deriva o veredito esperado a partir do YAML (a definição
# canônica) e confere contra o comportamento REAL do script (execução de verdade, não uma
# reimplementação paralela da mesma lógica que só provaria concordar consigo mesma).
#
#   [0] CONTROLE: archive-state-machine.yaml continua válido contra o próprio schema.
#   [1] DRIFT: o YAML declara uma transição requirements-ready -> tasks-ready (a aresta que
#       faltava) — sem isto, nenhum vermelho abaixo prova nada, porque não haveria fonte
#       canônica nenhuma para derivar a expectativa.
#   [2] CONTRATO (positivo): type:bugfix, scale>=2 — o YAML autoriza o pulo lateral; o script
#       REAL, executado, permite requirements-ready -> tasks-ready direto.
#   [3] CONTRATO (negativo): type:feature, mesma scale — o YAML NÃO autoriza o pulo para este
#       tipo; o script REAL recusa o mesmo salto, e design-ready continua exigido.
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SM="$WS/template/.forge/schemas/archive-state-machine.yaml"
SCHEMA="$WS/template/.forge/schemas/archive-state-machine.schema.json"
T="$(mktemp -d /tmp/forge-w173.XXXXXX)"
trap 'rm -rf "$T"' EXIT
cp -R "$WS/template/.forge" "$T/.forge"
S="$T/.forge/scripts"

echo "[0] CONTROLE: archive-state-machine.yaml válido contra o próprio schema"
node "$WS/tools/validate-yaml.mjs" "$SCHEMA" "$SM" >/dev/null \
  || { echo "FAIL [0]: archive-state-machine.yaml não valida contra o schema"; node "$WS/tools/validate-yaml.mjs" "$SCHEMA" "$SM"; exit 1; }
echo "OK [0]"

echo "[1] DRIFT: YAML declara a aresta lateral requirements-ready -> tasks-ready"
(cd "$WS" && node -e "
const { parse } = require('yaml');
const fs = require('fs');
const doc = parse(fs.readFileSync(process.argv[1], 'utf8'));
const edge = (doc.transitions || []).find((t) => t.from === 'requirements-ready' && t.to === 'tasks-ready');
if (!edge) { console.error('FAIL [1]: nenhuma transição requirements-ready -> tasks-ready declarada no YAML canônico'); process.exit(1); }
if (edge.type_conditional !== 'bugfix') { console.error('FAIL [1]: aresta existe mas sem type_conditional: bugfix — ' + JSON.stringify(edge)); process.exit(1); }
if (typeof edge.scale_gte !== 'number') { console.error('FAIL [1]: aresta sem scale_gte — ' + JSON.stringify(edge)); process.exit(1); }
console.log('OK [1] aresta declarada: ' + JSON.stringify(edge));
" "$SM")

# derive_allows <yaml> <from> <to> <type> <scale> [qp] — deriva do YAML (fonte canônica), sem olhar
# spec-transition.sh, se a transição from->to é permitida para (type,scale,quick_plan). 'any' de
# origem conta; type_conditional/scale_gte/manifest_conditional filtram. O 6º argumento diz se o
# manifest declara quick_plan dispensando design ("yes"/"no", default "no") — sem ele, uma aresta
# com manifest_conditional nunca casa, que é o comportamento correto para manifest sem a dispensa.
derive_allows() {
  (cd "$WS" && node -e "
    const { parse } = require('yaml');
    const fs = require('fs');
    const [, smPath, from, to, type, scale, qp] = process.argv;
    const doc = parse(fs.readFileSync(smPath, 'utf8'));
    const sc = parseInt(scale, 10);
    const ok = (doc.transitions || []).some((t) => {
      if (t.to !== to) return false;
      if (t.from !== from && t.from !== 'any') return false;
      if (t.type_conditional && t.type_conditional !== type) return false;
      if (t.manifest_conditional === 'quick_plan.skips_design' && qp !== 'yes') return false;
      if (typeof t.scale_gte === 'number' && !(sc >= t.scale_gte)) return false;
      return true;
    });
    process.stdout.write(ok ? 'yes' : 'no');
  " "$@")
}

# ── [2] CONTRATO positivo: type:bugfix scale 2 — YAML autoriza; script REAL permite ─────────
echo "[2] CONTRATO positivo: type:bugfix scale>=2 — YAML autoriza o pulo, script real permite"
EXPECT2="$(derive_allows "$SM" requirements-ready tasks-ready bugfix 2)"
[ "$EXPECT2" = "yes" ] || { echo "FAIL [2]: pré-condição do teste quebrada — YAML não autoriza mais o pulo (verifique [1])"; exit 1; }
FORGE_ROOT="$T" bash "$S/spec-new.sh" bug-skip --type bugfix --scale 2 >/dev/null
FORGE_ROOT="$T" bash "$S/spec-transition.sh" bug-skip requirements-ready >/dev/null
OUT2="$(FORGE_ROOT="$T" bash "$S/spec-transition.sh" bug-skip tasks-ready)"
grep -q '^OK bug-skip: requirements-ready -> tasks-ready$' <<< "$OUT2" \
  || { echo "FAIL [2]: script REAL recusou o pulo que o YAML autoriza — saída: $OUT2"; exit 1; }
echo "OK [2]"

# ── [3] CONTRATO negativo: type:feature, mesma scale — YAML NÃO autoriza; script real recusa ─
echo "[3] CONTRATO negativo: type:feature scale>=2 — YAML NÃO autoriza o pulo, script real recusa"
EXPECT3="$(derive_allows "$SM" requirements-ready tasks-ready feature 2)"
[ "$EXPECT3" = "no" ] || { echo "FAIL [3]: pré-condição do teste quebrada — YAML autoriza o pulo também para feature (não deveria)"; exit 1; }
FORGE_ROOT="$T" bash "$S/spec-new.sh" feat-noskip --type feature --scale 2 >/dev/null
FORGE_ROOT="$T" bash "$S/spec-transition.sh" feat-noskip requirements-ready >/dev/null
set +e
OUT3="$(FORGE_ROOT="$T" bash "$S/spec-transition.sh" feat-noskip tasks-ready 2>&1)"
RC3=$?
set -e
[ "$RC3" -ne 0 ] || { echo "FAIL [3]: script REAL permitiu o pulo para type:feature (YAML não autoriza) — saída: $OUT3"; exit 1; }
grep -q 'FAIL' <<< "$OUT3" || { echo "FAIL [3]: saída sem FAIL: $OUT3"; exit 1; }
# e o caminho linear (via design-ready) continua funcionando para feature
FORGE_ROOT="$T" bash "$S/spec-transition.sh" feat-noskip design-ready >/dev/null
OUT3B="$(FORGE_ROOT="$T" bash "$S/spec-transition.sh" feat-noskip tasks-ready)"
grep -q '^OK feat-noskip: design-ready -> tasks-ready$' <<< "$OUT3B" \
  || { echo "FAIL [3]: caminho linear via design-ready quebrou para feature — saída: $OUT3B"; exit 1; }
echo "OK [3]"

# ── [4] CONTRATO positivo por manifest: type:feature com quick_plan dispensando design ───────
# Fecha a cegueira que o code-review adversarial achou: a aresta lateral foi generalizada em
# spec-transition.sh (LDG-0172) sem entrada correspondente aqui, e este gate — que existe para
# pegar exatamente esse drift — passava verde porque só conhecia a condição de bugfix.
echo "[4] CONTRATO positivo por manifest: feature + quick_plan.skips_design — YAML autoriza, script real permite"
EXPECT4="$(derive_allows "$SM" requirements-ready tasks-ready feature 2 yes)"
[ "$EXPECT4" = "yes" ] || { echo "FAIL [4]: o YAML canônico não autoriza o pulo para manifest com quick_plan dispensando design"; exit 1; }
# contador de controle: o MESMO manifest sem a dispensa continua recusado pelo contrato
EXPECT4N="$(derive_allows "$SM" requirements-ready tasks-ready feature 2 no)"
[ "$EXPECT4N" = "no" ] || { echo "FAIL [4] controle: o YAML autorizaria o pulo mesmo sem quick_plan — a condição não filtra nada"; exit 1; }
FORGE_ROOT="$T" bash "$S/spec-new.sh" feat-qp --type feature --scale 2 >/dev/null
MAN4="$T/.forge/specs/active/feat-qp/manifest.yaml"
python3 - "$MAN4" <<'PYQP'
import io,sys,re
p=sys.argv[1]
s=io.open(p,encoding='utf-8').read()
s=re.sub(r'(?ms)^quick_plan:.*?(?=^\S|\Z)', '', s)
s=s.rstrip('\n')+'\nquick_plan:\n  enabled: true\n  skipped_phases: [design]\n  justification: "correcao pontual sem decisao arquitetural, validada em w173"\n'
io.open(p,'w',encoding='utf-8').write(s)
PYQP
FORGE_ROOT="$T" bash "$S/spec-transition.sh" feat-qp requirements-ready >/dev/null
set +e
OUT4="$(FORGE_ROOT="$T" bash "$S/spec-transition.sh" feat-qp tasks-ready 2>&1)"
RC4=$?
set -e
[ "$RC4" -eq 0 ] || { echo "FAIL [4]: o YAML autoriza o pulo por quick_plan mas o script REAL recusou — saída: $OUT4"; exit 1; }
grep -q '^OK feat-qp: requirements-ready -> tasks-ready$' <<< "$OUT4" \
  || { echo "FAIL [4]: saída inesperada do pulo por quick_plan: $OUT4"; exit 1; }
echo "OK [4]"

echo "OK"
