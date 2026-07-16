#!/usr/bin/env bash
# Gate W100 — spec-delta como fase do pipeline (não improviso do archive) + archive
# auto-recuperável para impact stale.
#   [1] spec-new instala o esqueleto de spec-delta.yaml e o change novo valida
#   [2] scaffold determinista: REQ-NN + affected_capabilities → ops com payload;
#       NUNCA sobrescreve delta já autorado (SKIP)
#   [3] spec-verify integra o scaffold e avisa sobre placeholders remanescentes
#   [4] validate-archive recusa delta com marcadores de scaffold/template; aceita preenchido
#   [5] archive-spec auto-recupera impact.json stale (graph update → impact --change) e
#       arquiva fim a fim; impact fresh não dispara refresh
#   [6] doctor sinaliza change verified sem delta autorado como drift informativo (`·`)
#       sem alterar o exit (non-load-bearing)
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w100.XXXXXX)"
trap 'rm -rf "$T"' EXIT

cp -R "$WS/template/.forge" "$T/.forge"
SN="$T/.forge/scripts/spec-new.sh"; ST="$T/.forge/scripts/spec-transition.sh"
SV="$T/.forge/scripts/spec-verify.sh"; AS="$T/.forge/scripts/archive-spec.sh"
VS="$T/.forge/scripts/validate-spec.sh"; VA="$T/.forge/scripts/lib/validate-archive.mjs"
SC="$T/.forge/scripts/lib/spec-delta-scaffold.mjs"
# FORGE.md mínimo sem runtime: (spec-verify pula a fase de checks deterministicamente)
printf -- '---\nproject: w100\n---\n# FORGE\n' > "$T/.forge/FORGE.md"
git -C "$T" init -q
git -C "$T" -c user.email=t@t -c user.name=t add -A >/dev/null
git -C "$T" -c user.email=t@t -c user.name=t commit -qm init >/dev/null

write_reqs() { # write_reqs <change-id>
  cat > "$T/.forge/specs/active/$1/requirements.md" <<'EOF'
# Requirements — chg

## REQ-01 — Tokenizar PAN no checkout

- **Quando** o portador submete o PAN no checkout, **o sistema deve** retornar um token de uso único.
- **Critérios de aceite:**
  - [ ] token emitido em menos de 200ms
- **Rastreia:** proposal §2

## REQ-02 — Rejeitar PAN inválido

- **Quando** o PAN falha na validação de Luhn, **o sistema deve** recusar a requisição com erro 422.
- **Critérios de aceite:**
  - [ ] erro 422 com código estável
- **Rastreia:** proposal §2
EOF
}
set_caps() { # set_caps <change-id> <capability>
  CAP="$2" perl -pi -e 's/^affected_capabilities: \[\]$/affected_capabilities:\n  - $ENV{CAP}/' \
    "$T/.forge/specs/active/$1/manifest.yaml"
}
done_tasks() { # done_tasks <change-id>
  cat > "$T/.forge/specs/active/$1/tasks.md" <<'EOF'
# Tasks
> legenda: `[ ]` todo · `[X]` done
- [X] TASK-01 — implementar (rastreia: REQ-01; paths: src)
- [X] TASK-02 — testar (rastreia: REQ-02; paths: src)
EOF
}

echo "[1] spec-new instala esqueleto de spec-delta.yaml e o change valida"
FORGE_ROOT="$T" bash "$SN" chg-tok --type feature --scale 1 >/dev/null
[ -f "$T/.forge/specs/active/chg-tok/spec-delta.yaml" ] || { echo "FAIL: spec-new não instalou spec-delta.yaml"; exit 1; }
grep -q 'REQ-XXX-001' "$T/.forge/specs/active/chg-tok/spec-delta.yaml" || { echo "FAIL: esqueleto sem placeholder de template"; exit 1; }
FORGE_ROOT="$T" bash "$VS" --path "$T/.forge/specs/active/chg-tok" >/dev/null || { echo "FAIL: change novo com esqueleto não valida"; exit 1; }
# scale 0 não tem artefato de requirements → sem esqueleto (fluxo manual permanece)
FORGE_ROOT="$T" bash "$SN" chg-s0 --type feature --scale 0 >/dev/null
[ ! -f "$T/.forge/specs/active/chg-s0/spec-delta.yaml" ] || { echo "FAIL: scale 0 não deveria receber esqueleto"; exit 1; }
echo "OK [1]"

echo "[2] scaffold gera ops dos REQ-NN e não sobrescreve delta autorado"
write_reqs chg-tok
set_caps chg-tok card-tokenization
out="$(node "$SC" "$T/.forge/specs/active/chg-tok" "$T")"
echo "$out" | grep -q '^OK' || { echo "FAIL: scaffold não gerou ($out)"; exit 1; }
D="$T/.forge/specs/active/chg-tok/spec-delta.yaml"
grep -q 'capability: card-tokenization' "$D" || { echo "FAIL: capability não derivada do manifest"; exit 1; }
grep -q 'requirement_id: REQ-CT-001' "$D" || { echo "FAIL: requirement_id não derivado com padding de 3 dígitos (REQ-CT-001)"; exit 1; }
grep -q 'when: "o portador submete o PAN no checkout"' "$D" || { echo "FAIL: when não extraído do requirements.md"; exit 1; }
grep -q '<scaffold:' "$D" || { echo "FAIL: given deveria ficar marcado <scaffold:>"; exit 1; }
FORGE_ROOT="$T" bash "$VS" --path "$T/.forge/specs/active/chg-tok" >/dev/null || { echo "FAIL: delta scaffolded não passa validate-spec"; exit 1; }
# autoria manual → scaffold vira SKIP e preserva o conteúdo
perl -pi -e 's/<scaffold: precondição — preencher na fase verify>/portador autenticado na sessão de checkout/g' "$D"
before="$(shasum "$D")"
node "$SC" "$T/.forge/specs/active/chg-tok" "$T" | grep -q '^SKIP' || { echo "FAIL: scaffold sobrescreveu delta autorado"; exit 1; }
[ "$before" = "$(shasum "$D")" ] || { echo "FAIL: conteúdo autorado foi alterado"; exit 1; }
# REQ novo adicionado DEPOIS da geração → SKIP com aviso de cobertura (nunca reescreve)
cat >> "$T/.forge/specs/active/chg-tok/requirements.md" <<'EOF'

## REQ-03 — Expirar token após uso

- **Quando** o token é usado numa autorização, **o sistema deve** invalidá-lo imediatamente.
- **Critérios de aceite:**
  - [ ] segunda tentativa com o mesmo token falha
EOF
out="$(node "$SC" "$T/.forge/specs/active/chg-tok" "$T")"
echo "$out" | grep -q '^SKIP' || { echo "FAIL: scaffold reescreveu delta com REQ novo"; exit 1; }
echo "$out" | grep -q 'WARN: REQ sem op correspondente.*REQ-03' || { echo "FAIL: cobertura de REQ-03 não avisada ($out)"; exit 1; }
echo "OK [2]"

echo "[3] spec-verify integra o scaffold e avisa placeholder remanescente"
FORGE_ROOT="$T" bash "$SN" chg-ver --type feature --scale 1 >/dev/null
write_reqs chg-ver
set_caps chg-ver card-tokenization
for s in requirements-ready tasks-ready implementing; do FORGE_ROOT="$T" bash "$ST" chg-ver "$s" >/dev/null; done
done_tasks chg-ver
out="$(FORGE_ROOT="$T" bash "$SV" chg-ver)"
echo "$out" | grep -q 'spec-delta: OK' || { echo "FAIL: spec-verify não rodou o scaffold"; echo "$out"; exit 1; }
echo "$out" | grep -q 'WARN: spec-delta.yaml ainda tem placeholders' || { echo "FAIL: spec-verify não avisou placeholder"; echo "$out"; exit 1; }
[ -f "$T/.forge/specs/active/chg-ver/verification.yaml" ] || { echo "FAIL: verification.yaml não escrito"; exit 1; }
echo "OK [3]"

echo "[4] scaffold bloqueia verified (validate-spec) e o archive (validate-archive)"
FORGE_ROOT="$T" bash "$ST" chg-ver implemented >/dev/null
# transição a verified com delta ainda em scaffold → FAIL (validate-spec estrito de verified em diante)
set +e
out="$(FORGE_ROOT="$T" bash "$ST" chg-ver verified 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] && echo "$out" | grep -q 'scaffold/template placeholders' || { echo "FAIL: transição a verified aceitou delta em scaffold ($out)"; exit 1; }
perl -pi -e 's/<scaffold: precondição — preencher na fase verify>/portador autenticado na sessão de checkout/g' "$T/.forge/specs/active/chg-ver/spec-delta.yaml"
FORGE_ROOT="$T" bash "$ST" chg-ver verified >/dev/null || { echo "FAIL: verified recusado com delta preenchido"; exit 1; }
perl -pi -e 's/^  human_archive_approval: false/  human_archive_approval: true/' "$T/.forge/specs/active/chg-ver/manifest.yaml"
# pré-flight do archive recusa marcador reintroduzido; aceita ao removê-lo
printf '# <scaffold: reintroduzido para o teste>\n' >> "$T/.forge/specs/active/chg-ver/spec-delta.yaml"
set +e
out="$(node "$VA" "$T/.forge/specs/active/chg-ver" "$T" 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] && echo "$out" | grep -q 'scaffold/template placeholders' || { echo "FAIL: pré-flight aceitou delta com scaffold ($out)"; exit 1; }
perl -ni -e 'print unless /<scaffold: reintroduzido/' "$T/.forge/specs/active/chg-ver/spec-delta.yaml"
node "$VA" "$T/.forge/specs/active/chg-ver" "$T" >/dev/null || { echo "FAIL: pré-flight recusou delta preenchido"; node "$VA" "$T/.forge/specs/active/chg-ver" "$T"; exit 1; }
echo "OK [4]"

echo "[5] archive auto-recupera impact stale e arquiva fim a fim"
mkdir -p "$T/src"
printf 'const b = require("./b.js");\nmodule.exports = { b };\n' > "$T/src/a.js"
printf 'module.exports = 1;\n' > "$T/src/b.js"
FORGE_ROOT="$T" bash "$T/.forge/scripts/graph.sh" build >/dev/null
perl -pi -e 's/^affected_paths: \[\]$/affected_paths:\n  - src\/a.js/' "$T/.forge/specs/active/chg-ver/manifest.yaml"
FORGE_ROOT="$T" bash "$T/.forge/scripts/impact.sh" --change chg-ver >/dev/null
# muda a estrutura do código DEPOIS do impact → grafo novo → impact.json stale
printf 'const c = require("./c.js");\nmodule.exports = { c };\n' > "$T/src/a.js"
printf 'module.exports = 2;\n' > "$T/src/c.js"
FORGE_ROOT="$T" bash "$T/.forge/scripts/graph.sh" build >/dev/null
out="$(FORGE_ROOT="$T" bash "$AS" chg-ver)" || { echo "FAIL: archive não completou"; echo "$out"; exit 1; }
echo "$out" | grep -q '\[0/6\] impact refresh' || { echo "FAIL: refresh de impact não logado"; echo "$out"; exit 1; }
echo "$out" | grep -q '^OK chg-ver archived' || { echo "FAIL: archive sem OK final"; echo "$out"; exit 1; }
[ -f "$T/.forge/product/current/capabilities/card-tokenization/spec.yaml" ] || { echo "FAIL: capability não aplicada ao baseline"; exit 1; }
# impact fresh → nenhum refresh disparado (segundo change, outra capability)
FORGE_ROOT="$T" bash "$SN" chg-arc2 --type feature --scale 1 >/dev/null
write_reqs chg-arc2
set_caps chg-arc2 pan-validation
for s in requirements-ready tasks-ready implementing; do FORGE_ROOT="$T" bash "$ST" chg-arc2 "$s" >/dev/null; done
done_tasks chg-arc2
FORGE_ROOT="$T" bash "$SV" chg-arc2 >/dev/null
perl -pi -e 's/<scaffold: precondição — preencher na fase verify>/PAN recebido no gateway/g' "$T/.forge/specs/active/chg-arc2/spec-delta.yaml"
FORGE_ROOT="$T" bash "$ST" chg-arc2 implemented >/dev/null
FORGE_ROOT="$T" bash "$ST" chg-arc2 verified >/dev/null
perl -pi -e 's/^  human_archive_approval: false/  human_archive_approval: true/' "$T/.forge/specs/active/chg-arc2/manifest.yaml"
perl -pi -e 's/^affected_paths: \[\]$/affected_paths:\n  - src\/a.js/' "$T/.forge/specs/active/chg-arc2/manifest.yaml"
FORGE_ROOT="$T" bash "$T/.forge/scripts/impact.sh" --change chg-arc2 >/dev/null
out="$(FORGE_ROOT="$T" bash "$AS" chg-arc2)" || { echo "FAIL: archive fresh não completou"; echo "$out"; exit 1; }
echo "$out" | grep -q '\[0/6\] impact refresh' && { echo "FAIL: refresh disparado com impact fresh"; echo "$out"; exit 1; }
echo "OK [5]"

echo "[6] doctor: drift informativo (·) sem mudar exit"
DR="$T/.forge/scripts/doctor.sh"
set +e
out_base="$(bash "$DR" 2>&1)"; rc_base=$?
set -e
FORGE_ROOT="$T" bash "$SN" chg-drift --type feature --scale 0 >/dev/null
perl -pi -e 's/^status: .*/status: verified/' "$T/.forge/specs/active/chg-drift/manifest.yaml"
rm -f "$T/.forge/specs/active/chg-drift/spec-delta.yaml"
set +e
out_drift="$(bash "$DR" 2>&1)"; rc_drift=$?
set -e
printf '%s' "$out_drift" | grep -q "drift — change 'chg-drift' verified sem spec-delta.yaml" || { echo "FAIL: doctor não acusou verified sem delta"; printf '%s\n' "$out_drift" | grep -i drift; exit 1; }
[ "$rc_drift" = "$rc_base" ] || { echo "FAIL: check de drift mudou o exit do doctor ($rc_base -> $rc_drift)"; exit 1; }
# placeholder também é drift
printf 'operations:\n  - op: add_requirement\n    capability: x\n    requirement_id: REQ-XXX-001\n' > "$T/.forge/specs/active/chg-drift/spec-delta.yaml"
set +e
out_ph="$(bash "$DR" 2>&1)"
set -e
printf '%s' "$out_ph" | grep -q "ainda em placeholder" || { echo "FAIL: doctor não acusou delta em placeholder"; exit 1; }
echo "OK [6]"

echo "PASS w100-spec-delta-pipeline-gate"
