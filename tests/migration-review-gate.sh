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
#   [12] wiring no pre-push — push com migration nova sem migration-review.md commitado → recusado
#   [13] wiring no pre-push — push com migration e migration-review.md completo → aceito
#   [14] wiring no pre-push — .forge/scripts/ inteiro ausente → push não é afetado por este bloco
#   [15] wiring no pre-push — ref nova sem remotes, migration num commit anterior ao tip → recusado
#   [16] wiring no pre-push — ref nova sem commit novo (já no remoto) → aceito, nada a varrer
#   [17] evidência antiga (de push anterior) não cobre edição nova da migration
#   [18] migration com nome acentuado (core.quotePath) é detectada e casa com a evidência
#   [19] migration movida para fora do diretório de migrations exige evidência (--no-renames)
#   [20] exceção inválida não fica mascarada por outra linha do mesmo path
#   [21] range começando com '-' → FAIL, nunca vira opção do git
#   [22] color.ui=always / diff.external do usuário não esvaziam a evidência adicionada
set -euo pipefail

# Isolamento git (LDG-0201), antes de qualquer uso de git neste arquivo: GIT_DIR herdado do
# ambiente faria os comandos git abaixo obedecerem ao repositório de quem invocou o gate, e não
# ao repositório sintético criado aqui.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RULE="$WS/template/.forge/rules/data/migration-review.md"
MJS="$WS/template/.forge/scripts/lib/check-migration-review.mjs"
SH="$WS/template/.forge/scripts/check-migration-review.sh"
PRE_PUSH="$WS/template/.forge/hooks/git/pre-push"

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
# mantém a linha que já cobria 002 (continua ok) e adiciona 003 com exceção de item 2 sem adr
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

echo "[12]-[14] wiring no pre-push — bloco MIGRATION_REVIEW_CHECK"

T2="$(mktemp -d "${TMPDIR:-/tmp}/forge-migreview-hook.XXXXXX")"
trap 'rm -rf "$T" "$T2"' EXIT
T2="$(cd "$T2" && pwd -P)"
ZERO2=0000000000000000000000000000000000000000

# mkminrepo <dir> — repositório git com .forge/hooks/git/pre-push (o hook REAL, único arquivo
# copiado de .forge/hooks/) e .forge/scripts/ só com check-migration-review.sh +
# lib/check-migration-review.mjs reais — nunca .forge/scripts/ inteiro (isso incluiria
# scripts/tests/ e ativaria HARNESS_SUITE, além dos demais blocos delegados). Os blocos irmãos
# (DOCS_LIB, RED_LIB, AI_CHECK, ACKS, SUPPRESSION_CHECK) recebem stub de uma linha, mesmo padrão
# de tests/w223-delegacao-arvore-do-hook-gate.sh, para que [12]/[13] fiquem determinísticos.
mkminrepo() {
  local d="$1"
  mkdir -p "$d/.forge/hooks/git/lib" "$d/.forge/scripts/lib"
  cp "$PRE_PUSH" "$d/.forge/hooks/git/pre-push"
  chmod +x "$d/.forge/hooks/git/pre-push"
  printf '#!/usr/bin/env bash\ncheck_docs_reviewed() { return 0; }\n' > "$d/.forge/hooks/git/lib/check-docs-reviewed.sh"
  printf '#!/usr/bin/env bash\ncheck_red_first() { return 0; }\n_redfirst_resolve_base() { printf "%%s\\n" "$1"; }\n' > "$d/.forge/hooks/git/lib/check-red-first.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$d/.forge/scripts/check-ai-attribution.sh"
  chmod +x "$d/.forge/scripts/check-ai-attribution.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$d/.forge/scripts/check-liaison-acks.sh"
  chmod +x "$d/.forge/scripts/check-liaison-acks.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$d/.forge/scripts/check-suppression-reference.sh"
  chmod +x "$d/.forge/scripts/check-suppression-reference.sh"
  cp "$SH" "$d/.forge/scripts/check-migration-review.sh"
  chmod +x "$d/.forge/scripts/check-migration-review.sh"
  cp "$MJS" "$d/.forge/scripts/lib/check-migration-review.mjs"
  git -C "$d" init -q -b main
  git -C "$d" config user.email dev@test
  git -C "$d" config user.name dev
  git -C "$d" config commit.gpgsign false
}

echo "[12] push com migration nova sem migration-review.md commitado → recusado"
R12="$T2/r12"
mkminrepo "$R12"
echo "base" > "$R12/README.md"
git -C "$R12" add -A >/dev/null 2>&1
git -C "$R12" commit -qm "chore: init"
mkdir -p "$R12/db/migrate"
echo "CREATE TABLE foo (id int);" > "$R12/db/migrate/001_foo.sql"
git -C "$R12" add -A >/dev/null 2>&1
git -C "$R12" commit -qm "feat: migration sem evidencia"
SHA12="$(git -C "$R12" rev-parse HEAD)"
set +e
out="$(cd "$R12" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA12" "$ZERO2" | bash "$R12/.forge/hooks/git/pre-push" origin "file://$R12" 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [12]: push deveria ter sido recusado (saída: '$out')"; exit 1; }
case "$out" in
  *"migration sem parecer de revisão"*) : ;;
  *) echo "FAIL [12]: saída não cita 'migration sem parecer de revisão' (saída: '$out')"; exit 1 ;;
esac
echo "OK [12]"

echo "[13] push com migration e migration-review.md completo → aceito"
R13="$T2/r13"
mkminrepo "$R13"
echo "base" > "$R13/README.md"
git -C "$R13" add -A >/dev/null 2>&1
git -C "$R13" commit -qm "chore: init"
mkdir -p "$R13/db/migrate"
echo "CREATE TABLE foo (id int);" > "$R13/db/migrate/001_foo.sql"
printf -- '- [x] db/migrate/001_foo.sql\n' > "$R13/migration-review.md"
git -C "$R13" add -A >/dev/null 2>&1
git -C "$R13" commit -qm "feat: migration com evidencia"
SHA13="$(git -C "$R13" rev-parse HEAD)"
out="$(cd "$R13" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA13" "$ZERO2" | bash "$R13/.forge/hooks/git/pre-push" origin "file://$R13" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [13]: push deveria ter sido aceito (saída: '$out')"; exit 1; }
case "$out" in
  *"migration sem parecer"*) echo "FAIL [13]: saída cita bloqueio indevido (saída: '$out')"; exit 1 ;;
  *) : ;;
esac
echo "OK [13]"

echo "[14] .forge/scripts/ inteiro ausente (harness não instalado) → push não é afetado por este bloco"
R14="$T2/r14"
mkdir -p "$R14/.forge/hooks/git"
cp "$PRE_PUSH" "$R14/.forge/hooks/git/pre-push"
chmod +x "$R14/.forge/hooks/git/pre-push"
git -C "$R14" init -q -b main
git -C "$R14" config user.email dev@test
git -C "$R14" config user.name dev
git -C "$R14" config commit.gpgsign false
mkdir -p "$R14/db/migrate"
echo "CREATE TABLE foo (id int);" > "$R14/db/migrate/001_foo.sql"
git -C "$R14" add -A >/dev/null 2>&1
git -C "$R14" commit -qm "feat: migration sem harness instalado"
SHA14="$(git -C "$R14" rev-parse HEAD)"
set +e
out="$(cd "$R14" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA14" "$ZERO2" | bash "$R14/.forge/hooks/git/pre-push" origin "file://$R14" 2>&1)"; rc=$?
set -e
case "$out" in
  *"migration sem parecer"*) echo "FAIL [14]: bloco migration-review afetou push sem .forge/scripts/ (saída: '$out')"; exit 1 ;;
  *) : ;;
esac
echo "OK [14] (rc=$rc)"

echo "[15] wiring no pre-push — ref nova sem remotes, migration num commit ANTERIOR ao tip → recusado"
# Regressão do code-evaluator (PR #246): o fallback `range="$lsha"` copiado do AI_CHECK fazia o
# `diff-tree` olhar só o commit tip; a migration do commit do meio passava sem evidência.
R15="$T2/r15"
mkminrepo "$R15"
echo "base" > "$R15/README.md"
git -C "$R15" add -A >/dev/null 2>&1
git -C "$R15" commit -qm "chore: init"
mkdir -p "$R15/db/migrate"
echo "CREATE TABLE foo (id int);" > "$R15/db/migrate/001_foo.sql"
git -C "$R15" add -A >/dev/null 2>&1
git -C "$R15" commit -qm "feat: migration sem evidência"
echo "mais" >> "$R15/README.md"
git -C "$R15" add -A >/dev/null 2>&1
git -C "$R15" commit -qm "chore: tip só toca readme"
SHA15="$(git -C "$R15" rev-parse HEAD)"
set +e
out="$(cd "$R15" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA15" "$ZERO2" | bash "$R15/.forge/hooks/git/pre-push" origin "file://$R15" 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [15]: migration fora do tip passou sem evidência (saída: '$out')"; exit 1; }
case "$out" in
  *"db/migrate/001_foo.sql"*) : ;;
  *) echo "FAIL [15]: saída não nomeia a migration do commit do meio (saída: '$out')"; exit 1 ;;
esac
echo "OK [15]"

echo "[16] wiring no pre-push — ref nova SEM commit novo (tudo já no remoto), tip tocou migration antiga → aceito"
# Regressão do code-evaluator (PR #246): sem commit novo, o fallback cobrava o diff do tip — push
# de um nome de branch novo sobre commit já publicado era bloqueado sem tocar migration alguma.
R16="$T2/r16"
mkminrepo "$R16"
echo "base" > "$R16/README.md"
git -C "$R16" add -A >/dev/null 2>&1
git -C "$R16" commit -qm "chore: init"
mkdir -p "$R16/db/migrate"
echo "CREATE TABLE foo (id int);" > "$R16/db/migrate/001_foo.sql"
git -C "$R16" add -A >/dev/null 2>&1
git -C "$R16" commit -qm "feat: migration antiga, anterior ao harness"
git -C "$R16" update-ref refs/remotes/origin/main HEAD   # já publicado
SHA16="$(git -C "$R16" rev-parse HEAD)"
set +e
out="$(cd "$R16" && printf 'refs/heads/release %s refs/heads/release %s\n' "$SHA16" "$ZERO2" | bash "$R16/.forge/hooks/git/pre-push" origin "file://$R16" 2>&1)"; rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "FAIL [16]: ref nova sem commit novo foi recusada (saída: '$out')"; exit 1; }
case "$out" in
  *"migration sem parecer"*) echo "FAIL [16]: bloqueio indevido (saída: '$out')"; exit 1 ;;
  *) : ;;
esac
echo "OK [16]"

# [17]-[21] — modo range, repositório sintético próprio (regressões do code-evaluator, PR #246).
R17="$T/repo17"
mkdir -p "$R17/db/migrate"
git -C "$R17" init -q
git -C "$R17" config user.email dev@test
git -C "$R17" config user.name dev
git -C "$R17" config commit.gpgsign false
echo "CREATE TABLE t (id int);" > "$R17/db/migrate/001_t.sql"
printf -- '- [x] db/migrate/001_t.sql sha=a\n' > "$R17/migration-review.md"
git -C "$R17" add -A
git -C "$R17" commit -qm "feat: migration revisada"

echo "[17] migration já revisada e editada depois, sem atualizar a linha de evidência → FAIL; com a linha atualizada → PASS"
b17="$(git -C "$R17" rev-parse HEAD)"
echo "DROP TABLE t;" >> "$R17/db/migrate/001_t.sql"
git -C "$R17" add -A
git -C "$R17" commit -qm "feat: edita migration já revisada"
set +e
out="$(cd "$R17" && node "$MJS" range "$b17..HEAD")"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [17]: evidência antiga cobriu edição nova da migration: $out"; exit 1; }
echo "$out" | grep -q "não foi adicionada nem atualizada" || { echo "FAIL [17]: diagnóstico não diz que a evidência é antiga: $out"; exit 1; }
printf -- '- [x] db/migrate/001_t.sql sha=b\n' > "$R17/migration-review.md"
git -C "$R17" add -A
git -C "$R17" commit -qm "docs: parecer novo da migration editada"
out="$(cd "$R17" && node "$MJS" range "$b17..HEAD")"
echo "$out" | grep -q "^PASS" || { echo "FAIL [17]: linha atualizada deveria passar: $out"; exit 1; }
echo "OK [17]"

echo "[18] migration com nome acentuado em db/migrate/ (core.quotePath) → FAIL nomeando o path real; com evidência acentuada → PASS"
b18="$(git -C "$R17" rev-parse HEAD)"
echo "CREATE TABLE s (id int);" > "$R17/db/migrate/002_situação.sql"
git -C "$R17" add -A
git -C "$R17" commit -qm "feat: migration com nome acentuado"
set +e
out="$(cd "$R17" && node "$MJS" range "$b18..HEAD")"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [18]: migration acentuada escapou do gate: $out"; exit 1; }
echo "$out" | grep -q "db/migrate/002_situação.sql" || { echo "FAIL [18]: saída não nomeia o path sem escape: $out"; exit 1; }
printf -- '- [x] db/migrate/002_situação.sql\n' >> "$R17/migration-review.md"
git -C "$R17" add -A
git -C "$R17" commit -qm "docs: parecer da migration acentuada"
out="$(cd "$R17" && node "$MJS" range "$b18..HEAD")"
echo "$out" | grep -q "^PASS" || { echo "FAIL [18]: evidência acentuada deveria casar: $out"; exit 1; }
echo "OK [18]"

echo "[19] migration movida para fora do diretório de migrations, sem evidência → FAIL nomeando a origem"
b19="$(git -C "$R17" rev-parse HEAD)"
mkdir -p "$R17/old"
git -C "$R17" mv db/migrate/001_t.sql old/001_t.sql
git -C "$R17" commit -qm "chore: move migration"
set +e
out="$(cd "$R17" && node "$MJS" range "$b19..HEAD")"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [19]: rename para fora do padrão passou sem evidência: $out"; exit 1; }
echo "$out" | grep -q "db/migrate/001_t.sql" || { echo "FAIL [19]: saída não nomeia a origem do rename: $out"; exit 1; }
echo "OK [19]"

echo "[20] exceção item=2 sem adr= seguida de outra linha válida do mesmo path → FAIL (a inválida não fica mascarada)"
b20="$(git -C "$R17" rev-parse HEAD)"
echo "CREATE TABLE u (id int);" > "$R17/db/migrate/003_u.sql"
printf -- '- [exception] db/migrate/003_u.sql item=2 backlog=P-1\n- [exception] db/migrate/003_u.sql item=5 backlog=P-2\n' >> "$R17/migration-review.md"
git -C "$R17" add -A
git -C "$R17" commit -qm "feat: migration com exceção inválida mascarada"
set +e
out="$(cd "$R17" && node "$MJS" range "$b20..HEAD")"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [20]: exceção inválida mascarada por outra linha: $out"; exit 1; }
echo "$out" | grep -q "item 2 sem adr" || { echo "FAIL [20]: saída não cita item 2 sem adr: $out"; exit 1; }
echo "OK [20]"

echo "[21] range começando com '-' (viraria opção do git) → FAIL, nunca PASS"
set +e
out="$(cd "$R17" && node "$MJS" range "--stdin" </dev/null)"; rc=$?
set -e
[ "$rc" -ne 0 ] || { echo "FAIL [21]: range '--stdin' passou: $out"; exit 1; }
echo "OK [21]"

echo "[22] color.ui=always / diff.external na config do usuário não esvaziam a evidência adicionada → PASS"
# Regressão do round 2 do code-evaluator (PR #246): `git diff` porcelain com cor punha escape ANSI
# antes do '+' e a linha de evidência recém-adicionada era lida como vazia.
b22="$(git -C "$R17" rev-parse HEAD)"
echo "CREATE TABLE v (id int);" > "$R17/db/migrate/004_v.sql"
printf -- '- [x] db/migrate/004_v.sql\n' >> "$R17/migration-review.md"
git -C "$R17" add -A
git -C "$R17" commit -qm "feat: migration revisada, config de cor agressiva"
printf '#!/bin/sh\necho externo\n' > "$T/ext-diff.sh"; chmod +x "$T/ext-diff.sh"
out="$(cd "$R17" && GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=color.ui GIT_CONFIG_VALUE_0=always GIT_CONFIG_KEY_1=diff.external GIT_CONFIG_VALUE_1="$T/ext-diff.sh" node "$MJS" range "$b22..HEAD")" || true
echo "$out" | grep -q "^PASS" || { echo "FAIL [22]: config de cor/diff externo do usuário bloqueou evidência válida: $out"; exit 1; }
echo "OK [22]"

echo "PASS migration-review-gate"
