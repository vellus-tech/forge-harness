#!/usr/bin/env bash
# Gate W4.2 — impact / baseline extract / archive integration (§16.4, §13.2):
#   [1] impact de uma semente lista EXATAMENTE os dependentes transitivos esperados
#   [2] impact --files de folha (money) → todos que dependem dela; de raiz (handler) → só ela
#   [3] baseline extract gera capability stubs por boundary (dry-run + real); não sobrescreve
#   [4] archive de change que toca código SEM impact.json → FAIL pedindo /forge:impact
#   [5] impact --change grava impact.json fresco → archive passa o pré-flight de impacto
#   [6] impact.json stale (grafo mudou) → archive FAIL pedindo re-scan
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w42.XXXXXX)"
trap 'rm -rf "$T"' EXIT
cp -R "$WS/template/.forge" "$T/.forge"
# quality.require_tests_before_archive passou a ser ENFORCEMENT REAL no pré-flight §13.1
# (LDG-0008): sem um check `test` com status `passed` no verification.yaml, o archive
# reprova. A fixture declara um comando de teste que passa — é o que um projeto real tem,
# e desligar a chave aqui faria o gate medir a dispensa em vez do mecanismo.
perl -pi -e 's/^  test:$/  test: true/' "$T/.forge/FORGE.md"
S="$T/.forge/scripts"

# fixture: domain/money <- application/pay <- api/handler (chain p/ impact)
# + services/billing (boundary nomeado p/ baseline extract — caso real services/<nome>)
mkdir -p "$T/src/domain" "$T/src/application" "$T/src/api" "$T/services/billing"
printf 'export class Money { constructor(public c:number){} }\n' > "$T/src/domain/money.ts"
printf "import { Money } from '../domain/money';\nexport const pay=(c:number)=>new Money(c);\n" > "$T/src/application/pay.ts"
printf "import { pay } from '../application/pay';\nexport const h=()=>pay(1);\n" > "$T/src/api/handler.ts"
printf 'export class Invoice {}\n' > "$T/services/billing/invoice.ts"
FORGE_ROOT="$T" bash "$S/graph.sh" build >/dev/null

echo "[1] impact transitivo exato (semente = money)"
out="$(FORGE_ROOT="$T" bash "$S/impact.sh" --files src/domain/money.ts)"
grep -q 'src/domain/money.ts' <<<"$out" || { echo "FAIL [1]: money.ts ausente do impacto — saída: $out"; exit 1; }
grep -q 'src/application/pay.ts' <<<"$out" || { echo "FAIL [1]: pay.ts ausente do impacto — saída: $out"; exit 1; }
grep -q 'src/api/handler.ts' <<<"$out" || { echo "FAIL [1]: handler.ts ausente do impacto — saída: $out"; exit 1; }
# exatamente 3 impactados, nem mais nem menos
n="$(echo "$out" | grep -c '^  src/')"
[ "$n" -eq 3 ]
echo "OK [1] (3 impactados: money + pay + handler)"

echo "[2] folha vs raiz"
# raiz (handler) não é dependência de ninguém → só ela impactada
out="$(FORGE_ROOT="$T" bash "$S/impact.sh" --files src/api/handler.ts)"
n="$(echo "$out" | grep -c '^  src/')"
[ "$n" -eq 1 ] || { echo "FAIL [2]: esperado 1 impactado, veio $n — saída: $out"; exit 1; }
grep -q 'src/api/handler.ts' <<<"$out" || { echo "FAIL [2]: o único impactado não é handler.ts — saída: $out"; exit 1; }
echo "OK [2]"

echo "[3] baseline extract por boundary (services/<nome> -> capability)"
out="$(FORGE_ROOT="$T" bash "$S/baseline-extract.sh" --dry-run)"
grep -q 'billing' <<<"$out" || { echo "FAIL [3]: services/billing não virou capability candidata — saída: $out"; exit 1; }
FORGE_ROOT="$T" bash "$S/baseline-extract.sh" >/dev/null
[ -f "$T/.forge/product/current/capabilities/billing/spec.yaml" ]
node "$WS/tools/validate-yaml.mjs" "$WS/template/.forge/schemas/baseline-capability.schema.json" "$T/.forge/product/current/capabilities/billing/spec.yaml" >/dev/null
# segunda rodada não sobrescreve / não duplica
out2="$(FORGE_ROOT="$T" bash "$S/baseline-extract.sh")"
grep -q 'no new capability stubs' <<<"$out2"
echo "OK [3]"

echo "[4] archive sem impact.json (change toca codigo) → FAIL"
# change verified scale-0 que declara affected_paths de código
(cd "$T" && bash "$S/spec-new.sh" feat-impact --type feature --scale 0 >/dev/null)
perl -0pi -e 's/^affected_paths: \[\]$/affected_paths:\n  - services\/billing/m' "$T/.forge/specs/active/feat-impact/manifest.yaml"
(cd "$T" && bash "$S/spec-transition.sh" feat-impact tasks-ready >/dev/null)
# G5 (LDG-0036/#82, spec-transition.sh) já exige impact.json fresco ANTES de implementing — o
# mesmo julgamento que este caso testa no archive, só que mais cedo. Roda /forge:impact aqui só
# para destravar a transição, e REMOVE o impact.json de novo logo abaixo — o que este caso [4]
# prova é o pré-flight do ARCHIVE, que precisa continuar reprovando quando o arquivo não existe
# nesse momento (ex.: alguém apagou, ou o grafo mudou depois de implementing sem novo /forge:impact).
(cd "$T" && bash "$S/impact.sh" --change feat-impact >/dev/null)
(cd "$T" && bash "$S/spec-transition.sh" feat-impact implementing >/dev/null)
rm -f "$T/.forge/specs/active/feat-impact/impact.json"
perl -pi -e 's/^(\s*)- \[ \] /$1- [X] /' "$T/.forge/specs/active/feat-impact/tasks.md"
(cd "$T" && bash "$S/spec-transition.sh" feat-impact implemented >/dev/null
            bash "$S/spec-verify.sh" feat-impact >/dev/null
            bash "$S/approval-log.sh" feat-impact --gate implementation_verified --decision approve >/dev/null
            bash "$S/spec-transition.sh" feat-impact verified >/dev/null
            bash "$S/approval-log.sh" feat-impact --gate human_archive_approval --decision approve >/dev/null)
cat > "$T/.forge/specs/active/feat-impact/spec-delta.yaml" <<'EOF'
operations:
  - op: add_requirement
    capability: billing
    requirement_id: REQ-BIL-001
    requirement:
      id: REQ-BIL-001
      title: Sample requirement touching code
      normative: SHALL
EOF
set +e
out="$(FORGE_ROOT="$T" bash "$S/validate-archive.sh" feat-impact 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [4]: validate-archive deveria reprovar sem impact.json, mas passou (rc=$rc) — saída: $out"; exit 1; }
grep -q 'impact.json missing' <<<"$out" || { echo "FAIL [4]: reprovou por outro motivo que não impact.json missing — saída: $out"; exit 1; }
echo "OK [4]"

echo "[5] impact --change grava impact.json → archive passa o pre-flight de impacto"
FORGE_ROOT="$T" bash "$S/impact.sh" --change feat-impact >/dev/null
[ -f "$T/.forge/specs/active/feat-impact/impact.json" ]
node "$WS/tools/validate-yaml.mjs" "$WS/template/.forge/schemas/graph.schema.json" "$T/.forge/graph/graph.json" >/dev/null
# validate-archive não deve mais falhar por impact (pode falhar por outra coisa? não — tudo pronto)
FORGE_ROOT="$T" bash "$S/validate-archive.sh" feat-impact >/dev/null
echo "OK [5]"

echo "[6] impact.json stale (grafo mudou) → archive FAIL"
printf "\nexport const extra = 99;\n" >> "$T/src/domain/money.ts"
FORGE_ROOT="$T" bash "$S/graph.sh" update >/dev/null   # fingerprint muda
set +e
out="$(FORGE_ROOT="$T" bash "$S/validate-archive.sh" feat-impact 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [6]: validate-archive deveria reprovar com impact.json stale, mas passou (rc=$rc) — saída: $out"; exit 1; }
grep -q 'stale' <<<"$out" || { echo "FAIL [6]: reprovou por outro motivo que não staleness — saída: $out"; exit 1; }
echo "OK [6]"

echo "OK"
