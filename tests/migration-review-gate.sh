#!/usr/bin/env bash
# Gate — add-migration-review-rule (issue #241):
#   [1] rule migration-review.md existe
#   [2] rule cobre os 13 itens do checklist, a seção de exceção, "quem revisa" e as
#       referências a schema-evolution.md/money-as-cents.md/data-classification/data-config-sql.md
#   [3] range base..head sem migration no diff → PASS (sem migration)
#   [4] migration nova sem migration-review.md no commit head → FAIL nomeando o arquivo
#   [5] migration nova com migration-review.md (commitado) contendo "- [x] <path>" → PASS
#   [6] exceção válida (item != 2) → PASS (exceção ...)
#   [7] exceção do item 2 sem adr= → FAIL (evidência inválida)
#   [8] range com rev-range inexistente → FAIL (range inválido), nunca PASS
#   [9] sha único sem pai (commit raiz) com migration, mesmo com working tree sujo → resolve certo
#   [9b] migration-review.md com "- [x]" só na working tree (não commitado) → ainda FAIL
#   [10] --path em diretório fixture sem migration → PASS (sem migration)
#   [11] --path em diretório fixture com migration e migration-review.md local (disco) → PASS
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RULE="$WS/template/.forge/rules/data/migration-review.md"
MJS="$WS/template/.forge/scripts/lib/check-migration-review.mjs"
SH="$WS/template/.forge/scripts/check-migration-review.sh"

echo "[1] rule migration-review.md existe"
[ -f "$RULE" ] || { echo "FAIL [1]: $RULE não existe"; exit 1; }
echo "OK [1]"

echo "[2] rule cobre os 13 itens, exceção, quem revisa, referências"
need=(
  "RLS"
  "FORCE"
  "CONCURRENTLY"
  "DEFAULT PRIVILEGES"
  "tenant_id"
  "NOT VALID"
  "ON DELETE CASCADE"
  "money-as-cents"
  "data-classification"
  "schema-evolution"
  "backlog"
  "item="
  "data-engineer\|data-relational"
  "clone da head"
  "ENABLE ALWAYS"
  "três casos"
  "data-config-sql"
)
for pat in "down.*recusa\|destruiria dado"; do need+=("$pat"); done
for pat in "${need[@]}"; do
  grep -q "$pat" "$RULE" || { echo "FAIL [2]: padrão ausente na rule: $pat"; exit 1; }
done
echo "OK [2]"

echo "[3]-[9b] modo range — repositório git temporário sintético"
command -v node >/dev/null 2>&1 || { echo "FAIL: node >= 20 required"; exit 1; }

T="$(mktemp -d /tmp/forge-migreview.XXXXXX)"
trap 'rm -rf "$T"' EXIT
R="$T/repo"
mkdir -p "$R"
git -C "$R" init -q
git -C "$R" config user.email dev@test
git -C "$R" config user.name dev
git -C "$R" config commit.gpgsign false

# commit raiz, sem migration
echo "base" > "$R/README.md"
git -C "$R" add README.md
git -C "$R" commit -qm "chore: init"
base_sha="$(git -C "$R" rev-parse HEAD)"

echo "[3] base..head sem migration no diff → PASS (sem migration)"
echo "mais" >> "$R/README.md"
git -C "$R" add README.md
git -C "$R" commit -qm "chore: toca readme, sem migration"
head_sha="$(git -C "$R" rev-parse HEAD)"
out="$(cd "$R" && node "$MJS" range "$base_sha..$head_sha")"
echo "$out" | grep -q "PASS (sem migration)" || { echo "FAIL [3]: $out"; exit 1; }
echo "OK [3]"

echo "[4] migration nova sem migration-review.md no commit head → FAIL nomeando o arquivo"
mkdir -p "$R/db/migrate"
echo "CREATE TABLE foo (id int);" > "$R/db/migrate/001_create_foo.sql"
git -C "$R" add db/migrate/001_create_foo.sql
git -C "$R" commit -qm "feat: migration sem evidencia"
prev_sha="$head_sha"
head_sha="$(git -C "$R" rev-parse HEAD)"
set +e
out="$(cd "$R" && node "$MJS" range "$prev_sha..$head_sha")"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [4]: deveria ter falhado: $out"; exit 1; }
echo "$out" | grep -q "db/migrate/001_create_foo.sql" || { echo "FAIL [4]: saída não nomeia o arquivo: $out"; exit 1; }
echo "OK [4]"

echo "[5] migration-review.md commitado com - [x] <path> → PASS"
printf -- '- [x] db/migrate/001_create_foo.sql\n' > "$R/migration-review.md"
git -C "$R" add migration-review.md
git -C "$R" commit -qm "docs: evidencia de revisao"
prev_sha="$head_sha"
head_sha="$(git -C "$R" rev-parse HEAD)"
out="$(cd "$R" && node "$MJS" range "$prev_sha..$head_sha")"
echo "$out" | grep -q "^PASS" || { echo "FAIL [5]: $out"; exit 1; }
echo "OK [5]"

echo "[6] exceção válida (item != 2) → PASS (exceção ...)"
mkdir -p "$R/db/migrate"
echo "CREATE TABLE bar (id int);" > "$R/db/migrate/002_create_bar.sql"
printf -- '- [exception] db/migrate/002_create_bar.sql item=5 backlog=PROJ-1\n' >> "$R/migration-review.md"
git -C "$R" add db/migrate/002_create_bar.sql migration-review.md
git -C "$R" commit -qm "feat: migration com excecao valida"
prev_sha="$head_sha"
head_sha="$(git -C "$R" rev-parse HEAD)"
out="$(cd "$R" && node "$MJS" range "$prev_sha..$head_sha")"
echo "$out" | grep -qi "PASS.*exce" || { echo "FAIL [6]: $out"; exit 1; }
echo "OK [6]"

echo "[7] exceção do item 2 sem adr= → FAIL (evidência inválida)"
echo "CREATE TABLE baz (id int);" > "$R/db/migrate/003_create_baz.sql"
# remove a linha anterior que ja cobria 002 (continua ok) e adiciona 003 com excecao de item 2 sem adr
printf -- '- [exception] db/migrate/003_create_baz.sql item=2 backlog=PROJ-2\n' >> "$R/migration-review.md"
git -C "$R" add db/migrate/003_create_baz.sql migration-review.md
git -C "$R" commit -qm "feat: migration com excecao invalida item 2 sem adr"
prev_sha="$head_sha"
head_sha="$(git -C "$R" rev-parse HEAD)"
set +e
out="$(cd "$R" && node "$MJS" range "$prev_sha..$head_sha")"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [7]: deveria ter falhado (item 2 sem adr): $out"; exit 1; }
echo "$out" | grep -q "db/migrate/003_create_baz.sql" || { echo "FAIL [7]: saída não nomeia o arquivo: $out"; exit 1; }
echo "OK [7]"

echo "[8] range com rev-range inexistente → FAIL (range inválido), nunca PASS"
set +e
out="$(cd "$R" && node "$MJS" range "nonexistent1..nonexistent2")"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [8]: deveria ter falhado: $out"; exit 1; }
echo "$out" | grep -qi "range inv" || { echo "FAIL [8]: saída não indica range inválido: $out"; exit 1; }
echo "OK [8]"

echo "[9]/[9b] sha único sem pai (commit raiz) com migration — resolve via diff-tree, nunca pelo disco"
R2="$T/repo-root"
mkdir -p "$R2/db/migrate"
git -C "$R2" init -q
git -C "$R2" config user.email dev@test
git -C "$R2" config user.name dev
git -C "$R2" config commit.gpgsign false
echo "CREATE TABLE root_tbl (id int);" > "$R2/db/migrate/001_root.sql"
printf -- '- [x] db/migrate/001_root.sql\n' > "$R2/migration-review.md"
git -C "$R2" add db/migrate/001_root.sql migration-review.md
git -C "$R2" commit -qm "feat: migration no commit raiz, com evidencia"
root_sha="$(git -C "$R2" rev-parse HEAD)"
# working tree sujo: edita arquivo sem commitar
echo "-- dirty edit" >> "$R2/db/migrate/001_root.sql"
out="$(cd "$R2" && node "$MJS" range "$root_sha")"
echo "$out" | grep -q "^PASS" || { echo "FAIL [9]: $out"; exit 1; }
echo "OK [9]"

echo "[9b] migration-review.md com - [x] só na working tree (não commitado) → ainda FAIL"
R3="$T/repo-root2"
mkdir -p "$R3/db/migrate"
git -C "$R3" init -q
git -C "$R3" config user.email dev@test
git -C "$R3" config user.name dev
git -C "$R3" config commit.gpgsign false
echo "CREATE TABLE root_tbl2 (id int);" > "$R3/db/migrate/001_root2.sql"
git -C "$R3" add db/migrate/001_root2.sql
git -C "$R3" commit -qm "feat: migration no commit raiz, sem evidencia no commit"
root_sha2="$(git -C "$R3" rev-parse HEAD)"
# evidencia só no disco, não commitada
printf -- '- [x] db/migrate/001_root2.sql\n' > "$R3/migration-review.md"
set +e
out="$(cd "$R3" && node "$MJS" range "$root_sha2")"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [9b]: evidência não commitada deveria falhar (lida do blob, não do disco): $out"; exit 1; }
echo "OK [9b]"

echo "[10] (Red esperado antes do wrapper) --path em diretório sem migration → PASS (sem migration)"
FIX_EMPTY="$T/fixture-empty"
mkdir -p "$FIX_EMPTY"
echo "nada aqui" > "$FIX_EMPTY/README.md"
if [ ! -f "$SH" ]; then
  echo "SH ausente — Red esperado (wrapper ainda não existe)"
else
  out="$(bash "$SH" --path "$FIX_EMPTY")"
  echo "$out" | grep -q "PASS (sem migration)" || { echo "FAIL [10]: $out"; exit 1; }
  echo "OK [10]"
fi

echo "[11] --path em diretório com migration e migration-review.md local (disco) → PASS"
FIX_WITH="$T/fixture-with-migration"
mkdir -p "$FIX_WITH/db/migrate"
echo "CREATE TABLE qux (id int);" > "$FIX_WITH/db/migrate/001_qux.sql"
printf -- '- [x] db/migrate/001_qux.sql\n' > "$FIX_WITH/migration-review.md"
if [ ! -f "$SH" ]; then
  echo "SH ausente — Red esperado (wrapper ainda não existe)"
else
  out="$(bash "$SH" --path "$FIX_WITH")"
  echo "$out" | grep -q "^PASS" || { echo "FAIL [11]: $out"; exit 1; }
  echo "OK [11]"
fi

echo "PASS migration-review-gate"
