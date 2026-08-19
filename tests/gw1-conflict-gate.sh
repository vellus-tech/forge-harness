#!/usr/bin/env bash
# Gate GW.1 — conflito de fontes bloqueante (G1) + precedência (G2):
#   [1] change scale-3 com analysis.md contendo BLOCKER → spec-transition recusa 'implementing'
#   [2] analysis.md com Status: FAIL (sem linha BLOCKER explícita) → também recusa
#   [3] analysis.md limpo (Status: PASS, sem BLOCKER) → 'implementing' permitido
#   [4] precedência declarada no FORGE.md (§2.1) e na constitution (princípio 11)
#   [5] rule conflict-handling.md instalada, com frontmatter válido e based_on
#   [6] regra transversal de bloqueio propagada (agents/README + analyze + pipeline)
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-gw1.XXXXXX)"
trap 'rm -rf "$T"' EXIT
cp -R "$WS/template/.forge" "$T/.forge"
S="$T/.forge/scripts"

# change scale 3 driven to tasks-ready
(cd "$T" && bash "$S/spec-new.sh" feat-conf --type feature --scale 3 >/dev/null
            bash "$S/spec-transition.sh" feat-conf requirements-ready >/dev/null
            bash "$S/spec-transition.sh" feat-conf design-ready >/dev/null
            bash "$S/spec-transition.sh" feat-conf tasks-ready >/dev/null)
D="$T/.forge/specs/active/feat-conf"

# Este gate mede a precedência do BLOCKER de analysis.md, não o story sharding. Desde a issue #35,
# porém, um change scale >= 3 também precisa estar shardado para alcançar `implementing` — sem
# declarar a dispensa, os cenários [1] a [3] passariam a medir a mensagem errada (reprovariam por
# falta de stories, não por BLOCKER, e o [3] nunca liberaria). A dispensa é a rota oficial e em
# BLOCK STYLE, que é a única que o yaml-lite parseia (LDG-0033); usá-la aqui exercita de quebra
# que ela de fato funciona ponta a ponta no spec-transition.
cat >> "$D/manifest.yaml" <<'EOF'
quick_plan:
  enabled: true
  skipped_phases:
    - story-sharding
  justification: "fixture do gw1 mede precedência de BLOCKER em analysis.md, não story sharding"
EOF

echo "[1] analysis.md com BLOCKER trava implementing"
cat > "$D/analysis.md" <<'EOF'
# Analysis — feat-conf
## Status: FAIL
## Achados
| ID | Severidade | Tipo | Onde | Recomendação |
|---|---|---|---|---|
| A-01 | BLOCKER | conflict | account-management vs organization | Aplicar ADR-0001 (RLS); rule database-naming em drift |
## Síntese
Conflito de isolamento multi-tenant entre módulos.
EOF
set +e
out="$(cd "$T" && bash "$S/spec-transition.sh" feat-conf implementing 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] && grep -q 'BLOCKER' <<<"$out" \
  || { echo "FAIL [1]: spec-transition não recusou implementing com BLOCKER em analysis.md (rc=$rc, out=$out)"; exit 1; }
grep -q '^status: tasks-ready$' "$D/manifest.yaml"   # não transicionou
echo "OK [1]"

echo "[2] Status: FAIL sem linha BLOCKER explícita também trava"
cat > "$D/analysis.md" <<'EOF'
# Analysis — feat-conf
## Status: FAIL
## Achados
| ID | Severidade | Tipo | Onde | Recomendação |
|---|---|---|---|---|
| A-01 | HIGH | drift | rule X | revisar |
## Síntese
Pendência aberta.
EOF
set +e
(cd "$T" && bash "$S/spec-transition.sh" feat-conf implementing) >/dev/null 2>&1; rc=$?
set -e
[ "$rc" -ne 0 ]
echo "OK [2]"

echo "[3] analysis.md limpo libera implementing"
cat > "$D/analysis.md" <<'EOF'
# Analysis — feat-conf
## Status: PASS
## Achados
| ID | Severidade | Tipo | Onde | Recomendação |
|---|---|---|---|---|
## Síntese
Sem conflitos; cobertura completa.
EOF
(cd "$T" && bash "$S/spec-transition.sh" feat-conf implementing >/dev/null)
grep -q '^status: implementing$' "$D/manifest.yaml"
echo "OK [3]"

echo "[4] precedência declarada (FORGE.md §2.1 + constitution princípio 11)"
grep -q 'Source-of-truth precedence' "$T/.forge/FORGE.md"
grep -q 'higher-authority' "$T/.forge/FORGE.md"
grep -q 'constitution > .*baseline.*rules' "$T/.forge/constitution.md"
echo "OK [4]"

echo "[5] rule conflict-handling instalada e válida"
[ -f "$T/.forge/rules/conventions/conflict-handling.md" ]
bash "$T/.forge/scripts/validate-frontmatter.sh" "$T/.forge/rules/conventions/conflict-handling.md" >/dev/null
grep -q '^based_on:' "$T/.forge/rules/conventions/conflict-handling.md"
echo "OK [5]"

echo "[6] regra de bloqueio propagada"
grep -q 'conflito de fontes é bloqueante\|conflito.*bloqueante' "$T/.forge/agents/README.md"
grep -q 'Conflito é bloqueante' "$T/.forge/commands/specs/analyze.md"
grep -q 'bloqueante' "$T/.forge/commands/specs/run-spec-pipeline.md"
echo "OK [6]"

echo "OK"
