#!/usr/bin/env bash
# Gate GW.3 — fonte da verdade de dados (G4 + §4 do plano):
#   [1] as 4 rules de governança de dados instaladas e válidas (matriz + 3 stores)
#   [2] matriz transversal declara os 3 mecanismos de isolamento por store
#   [3] database-naming.md saneada: NÃO afirma mais "sem RLS conforme ADR"
#   [4] checker: design conforme → OK; "RLS opcional" → CONFLICT nomeando o arquivo
#   [5] checker: "RLS dispensável só por exceção formal" é PERMITIDO (não conflita)
#   [6] checker: cache sem namespace de tenant → CONFLICT
#   [7] o anti-padrão LITERAL do incidente é pego (DD "RLS opcional" entre módulos)
#   [8] ADR template de governança de dados disponível
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-gw3.XXXXXX)"
trap 'rm -rf "$T"' EXIT
cp -R "$WS/template/.forge" "$T/.forge"
CHK="$T/.forge/scripts/lib/check-data-governance.mjs"

echo "[1] 4 rules de dados instaladas e válidas"
for r in data-governance data-config-sql data-transactional-nosql data-cache; do
  [ -f "$T/.forge/rules/data/$r.md" ]
done
bash "$T/.forge/scripts/validate-frontmatter.sh" "$T/.forge/rules/data" >/dev/null
echo "OK [1]"

echo "[2] matriz transversal: 3 mecanismos por store"
M="$T/.forge/rules/data/data-governance.md"
grep -q 'PostgreSQL' "$M" && grep -q 'MongoDB' "$M" && grep -qi 'redis' "$M"
grep -qi 'RLS' "$M" && grep -qi 'filtro de repositório\|interceptor' "$M" && grep -qi 'namespacing de chave\|namespace' "$M"
echo "OK [2]"

echo "[3] database-naming saneada (não afirma mais 'sem RLS conforme ADR')"
! grep -q 'não via schema separado nem RLS (conforme ADR' "$T/.forge/rules/conventions/database-naming.md"
grep -q 'data-config-sql\|data-governance' "$T/.forge/rules/conventions/database-naming.md"
echo "OK [3]"

echo "[4] checker: conforme OK; RLS opcional CONFLICT"
mkdir -p "$T/ok" "$T/bad"
printf '# Design\ntenant_id + EF Global Query Filter + RLS obrigatorio.\n' > "$T/ok/design.md"
node "$CHK" "$T/ok" >/dev/null
printf '# Design\nDD-002: coluna tenant_id + filtro EF, RLS opcional.\n' > "$T/bad/design.md"
set +e
out="$(node "$CHK" "$T/bad")"; rc=$?
set -e
[ "$rc" -ne 0 ] && echo "$out" | grep -q 'CONFLICT' && echo "$out" | grep -q 'design.md'
echo "OK [4]"

echo "[5] exceção formal é permitida"
printf '# Design\nRLS dispensavel so por excecao formal documentada nesta tabela.\n' > "$T/exc.md"
node "$CHK" "$T/exc.md" >/dev/null
echo "OK [5]"

echo "[6] cache sem namespace de tenant → CONFLICT"
printf '# Design\nO cache usa chave global sem namespace de tenant.\n' > "$T/cache.md"
set +e
out="$(node "$CHK" "$T/cache.md")"; rc=$?
set -e
[ "$rc" -ne 0 ] && echo "$out" | grep -qi 'cross-tenant\|namespace'
echo "OK [6]"

echo "[7] anti-padrão literal do incidente (change real)"
(cd "$T" && bash "$T/.forge/scripts/spec-new.sh" feat-tenant --type feature --scale 2 >/dev/null)
cat >> "$T/.forge/specs/active/feat-tenant/design.md" <<'EOF'

## Decisao de isolamento
account-management (DD-002): coluna tenant_id + filtro EF, RLS opcional.
EOF
set +e
out="$(FORGE_ROOT="$T" bash "$T/.forge/scripts/check-data-governance.sh" feat-tenant)"; rc=$?
set -e
[ "$rc" -ne 0 ] && echo "$out" | grep -q 'CONFLICT'
echo "OK [7]"

echo "[8] ADR template de governança de dados"
[ -f "$T/.forge/templates/product/adr-data-governance.md" ]
grep -q 'isolamento multi-tenant' "$T/.forge/templates/product/adr-data-governance.md"
echo "OK [8]"

echo "OK"
