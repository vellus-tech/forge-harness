#!/usr/bin/env bash
# Gate — handoff-gen (REQ-02/NFR-02): o gerador determinístico monta .forge/HANDOFF.md a partir
# do estado do change (manifest/progress/deferrals), degrada sem FORGE.md, é idempotente e preserva
# um delta narrativo já escrito. Quando o arquivo existente não tem marcadores NARRATIVE-DELTA e o
# conteúdo mudaria (#120), os bytes anteriores são salvos em backup antes da escrita, com WARN.
#   [1] gera o artefato com as 5 seções + dados do change
#   [2] determinismo: duas execuções sem mudança de estado → diff vazio
#   [3] degradação sem FORGE.md → runtime = n/d
#   [4] preserva o delta narrativo escrito entre os marcadores (controle: nenhum backup)
#   [5] sem marcadores + conteúdo mudaria → backup byte-idêntico ao anterior + WARN nomeia o caminho
#   [6] arquivo idêntico ao que seria renderizado (sem marcadores) → nenhum backup
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GEN="$WS/template/.forge/scripts/handoff-gen.sh"
RENDER="$WS/template/.forge/scripts/lib/handoff-render.mjs"
[ -f "$GEN" ]
[ -f "$RENDER" ]
T="$(mktemp -d /tmp/forge-handoff.XXXXXX)"
trap 'rm -rf "$T"' EXIT

git -C "$T" init -q
git -C "$T" config user.email "fixture@test"
git -C "$T" config user.name "fixture"

DIR="$T/.forge/specs/active/demo-change"
mkdir -p "$DIR"
cat > "$DIR/manifest.yaml" <<'YAML'
id: demo-change
type: feature
scale: 2
status: implementing
YAML
cat > "$DIR/progress.json" <<'JSON'
{ "current_wave": 2, "done_stories": 1, "total_stories": 3, "done_tasks": 4, "total_tasks": 10 }
JSON
cat > "$DIR/deferrals.json" <<'JSON'
[ { "id": "DEFER-1", "status": "open" }, { "id": "DEFER-2", "status": "resolved" } ]
JSON

backup_count() { find "$T/.git/forge-backups" -maxdepth 1 -name 'handoff-*.md' 2>/dev/null | wc -l | tr -d ' '; }

echo "[1] gera artefato com seções + dados"
FORGE_ROOT="$T" bash "$GEN" demo-change >/dev/null
H="$T/.forge/HANDOFF.md"
[ -f "$H" ]
grep -q '## 1. Header' "$H"
grep -q '## 2. Estado' "$H"
grep -q '## 3. Regras fixas da sessão' "$H"
grep -q '## 4. Delta narrativo' "$H"
grep -q '## 5. Como retomar' "$H"
grep -q 'demo-change' "$H"
grep -q 'DEFER-1' "$H"
grep -q '4/10' "$H"
[ "$(backup_count)" = "0" ] || { echo "FAIL [1] (backup inesperado na primeira geração)"; exit 1; }
echo "OK [1]"

echo "[2] determinismo: duas execuções → diff vazio"
cp "$H" "$T/first.md"
FORGE_ROOT="$T" bash "$GEN" demo-change >/dev/null
diff "$T/first.md" "$H"
echo "OK [2]"

echo "[3] degradação sem FORGE.md → runtime n/d"
grep -q 'test=`n/d`' "$H"
echo "OK [3]"

echo "[4] preserva delta narrativo escrito (controle: nenhum backup)"
python3 - "$H" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
a = '<!-- FORGE:NARRATIVE-DELTA:START -->'
b = '<!-- FORGE:NARRATIVE-DELTA:END -->'
i = s.index(a) + len(a); j = s.index(b)
s = s[:i] + '\nFoco: terminar a wave 2. Decisão aberta: X.\n' + s[j:]
open(p, 'w').write(s)
PY
FORGE_ROOT="$T" bash "$GEN" demo-change >/dev/null
grep -q 'Foco: terminar a wave 2' "$H"
[ "$(backup_count)" = "0" ] || { echo "FAIL [4] (backup criado com marcadores presentes)"; exit 1; }
echo "OK [4]"

echo "[5] sem marcadores + conteúdo mudaria → backup byte-idêntico + WARN nomeia o caminho"
LEGACY="$T/legacy.md"
python3 -c "
body = ('## Secao antiga %d\n\nConteudo relevante que nao deveria sumir.\n\n' * 500)
open('$LEGACY', 'w').write(body % tuple(range(500)))
"
cp "$LEGACY" "$H"
EXPECT_BYTES="$(wc -c < "$LEGACY" | tr -d ' ')"
FORGE_ROOT="$T" bash "$GEN" demo-change >"$T/stdout-5.log" 2>"$T/stderr-5.log"
grep -q '^WARN: HANDOFF.md sem marcadores NARRATIVE-DELTA' "$T/stderr-5.log" \
  || { echo "FAIL [5] (WARN ausente em stderr)"; cat "$T/stderr-5.log"; exit 1; }
grep -q "conteúdo anterior ($EXPECT_BYTES bytes)" "$T/stderr-5.log" \
  || { echo "FAIL [5] (contagem de bytes no WARN não bate com o arquivo anterior)"; cat "$T/stderr-5.log"; exit 1; }
WARN_PATH="$(sed -n 's/.*salvo em \(.*\)$/\1/p' "$T/stderr-5.log" | head -1)"
[ -n "$WARN_PATH" ] || { echo "FAIL [5] (WARN sem caminho)"; exit 1; }
[ -f "$WARN_PATH" ] || { echo "FAIL [5] (caminho do WARN não existe: $WARN_PATH)"; exit 1; }
cmp -s "$LEGACY" "$WARN_PATH" || { echo "FAIL [5] (backup não é byte-idêntico ao conteúdo anterior)"; exit 1; }
[ "$(backup_count)" = "1" ] || { echo "FAIL [5] (esperado 1 backup em .git/forge-backups, achei $(backup_count))"; exit 1; }
grep -q 'demo-change' "$H"
echo "OK [5]"

echo "[6] arquivo idêntico ao que seria renderizado (sem marcadores) → nenhum backup"
T2="$T/idem"
DIR2="$T2/.forge/specs/active/demo-change"
mkdir -p "$DIR2"
cp "$DIR/manifest.yaml" "$DIR/progress.json" "$DIR/deferrals.json" "$DIR2/"
TPL2="$T/tpl-sem-marcadores.md"
printf '# Simples\n\nid={{CHANGE_ID}}\n' > "$TPL2"
BC_BEFORE="$(backup_count)"
run_render() {
  FORGE_ROOT="$T2" HANDOFF_DIR="$DIR2" HANDOFF_TPL="$TPL2" HANDOFF_ID="demo-change" \
  HANDOFF_BRANCH="" HANDOFF_SHA="" HANDOFF_DATE="" \
  HANDOFF_TEST="" HANDOFF_TYPECHECK="" HANDOFF_LINT="" \
  node "$RENDER"
}
run_render   # 1ª: arquivo não existe ainda — sem backup possível
run_render   # 2ª: arquivo existe, sem marcadores, mas idêntico ao que seria escrito agora
[ "$(backup_count)" = "$BC_BEFORE" ] || { echo "FAIL [6] (backup criado para conteúdo idêntico ao anterior)"; exit 1; }
grep -q 'id=demo-change' "$T2/.forge/HANDOFF.md"
echo "OK [6]"

echo "PASS w60-handoff-gen-gate"
