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
#   [7] PBT: sem marcadores, os bytes anteriores são sempre recuperáveis — no próprio arquivo
#       (já idêntico) ou num backup byte-idêntico nomeado pelo WARN; com marcadores, o corpo
#       entre eles é sempre preservado no arquivo (não cobre bytes fora do slot — ver [10])
#   [8] backup é byte-idêntico ao arquivo anterior mesmo com bytes inválidos em UTF-8, e a
#       contagem de bytes no WARN bate com o tamanho bruto do arquivo, não com a string decodificada
#   [9] arquivo anterior de 0 bytes → nenhum backup, nenhum WARN (nada a recuperar)
#   [10] controle/limitação conhecida (DA-09, roadmap Onda 8): com marcadores JÁ presentes, texto
#        escrito fora do par START/END continua sendo descartado sem backup e sem WARN — este
#        cenário não é regressão a corrigir aqui; documenta o limite do que o #120 cobre
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GEN="$WS/template/.forge/scripts/handoff-gen.sh"
RENDER="$WS/template/.forge/scripts/lib/handoff-render.mjs"
LIB="$WS/template/.forge/scripts/lib"
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

echo "[7] PBT: bytes anteriores sempre recuperáveis (delta preservado ou backup byte-idêntico)"
node - "$LIB" "$GEN" "$T" <<'EOF' || { echo "FAIL [7] (propriedade de recuperabilidade falhou)"; exit 1; }
const [lib, gen, root] = process.argv.slice(2);
const fs = await import('node:fs');
const path = await import('node:path');
const { spawnSync } = await import('node:child_process');
const { forAll, gen: G } = await import(`${lib}/pbt.mjs`);

const H = path.join(root, '.forge', 'HANDOFF.md');
const WORDS = ['alfa', 'bravo', 'charlie', 'delta', 'echo', 'foxtrot', 'golf', 'hotel', 'india', 'julia', 'kilo', 'lima'];
const wordsGen = G.array(G.oneOf(WORDS), 5, 40);
const padGen = G.array(G.oneOf(WORDS), 0, 15);

function runCase(hasMarkers, bodyWords, prefixWords, suffixWords) {
  const body = bodyWords.join(' ');
  const prefix = prefixWords.join(' ');
  const suffix = suffixWords.join(' ');
  const prev = hasMarkers
    ? `${prefix}\n\n<!-- FORGE:NARRATIVE-DELTA:START -->\n${body}\n<!-- FORGE:NARRATIVE-DELTA:END -->\n\n${suffix}\n`
    : `${prefix}\n${body}\n${suffix}\n`;
  fs.writeFileSync(H, prev, 'utf8');
  const res = spawnSync('bash', [gen, 'demo-change'], { cwd: root, env: { ...process.env, FORGE_ROOT: root }, encoding: 'utf8' });
  if (res.status !== 0) return false; // #120 é sobre nunca perder bytes com rc 0 — rc≠0 já é outro defeito
  const after = fs.readFileSync(H, 'utf8');
  // Com marcadores, a propriedade provada é só a preservação do corpo entre START/END — prefix e
  // suffix (fora do slot) NÃO entram nesta checagem de propósito: são descartados por desenho
  // sempre que os marcadores já existem (limitação conhecida, ver [10] e o comentário no topo de
  // handoff-render.mjs). Não fortaleça esta linha para exigir prefix/suffix sem antes mudar o
  // desenho e o DA-09 do plano — o [10] existiria para falhar primeiro.
  if (hasMarkers) return after.includes(body);
  if (after === prev) return true; // nada a recuperar — já idêntico ao que seria escrito
  const m = /salvo em (.*)$/m.exec(res.stderr || '');
  if (!m) return false; // conteúdo mudou sem marcadores e sem aviso — bytes perdidos sem rastro
  const backupPath = m[1].trim();
  return fs.existsSync(backupPath) && fs.readFileSync(backupPath, 'utf8') === prev;
}

const SEED = 20260925;
const RUNS = 80;
const r = forAll([G.bool(), wordsGen, padGen, padGen], runCase, { runs: RUNS, seed: SEED });
if (!r.ok) {
  console.error(`propriedade falhou após ${r.runs} caso(s) (seed ${r.seed}): ${JSON.stringify(r.counterexample)}${r.error ? ` — ${r.error}` : ''}`);
  process.exit(1);
}
console.log(`PBT OK — seed ${SEED}, ${r.runs} casos`);
EOF
echo "OK [7]"

echo "[8] backup byte-idêntico com bytes inválidos em UTF-8; WARN conta bytes brutos, não a string decodificada"
BC_BEFORE8="$(backup_count)"
printf 'Se\xe7\xe3o antiga em latin-1\n\xff\xfe lixo binario\n' > "$H"
cp "$H" "$T/prev-8.bin"
EXPECT_BYTES8="$(wc -c < "$T/prev-8.bin" | tr -d ' ')"
FORGE_ROOT="$T" bash "$GEN" demo-change >"$T/stdout-8.log" 2>"$T/stderr-8.log"
grep -q '^WARN: HANDOFF.md sem marcadores NARRATIVE-DELTA' "$T/stderr-8.log" \
  || { echo "FAIL [8] (WARN ausente em stderr)"; cat "$T/stderr-8.log"; exit 1; }
grep -q "conteúdo anterior ($EXPECT_BYTES8 bytes)" "$T/stderr-8.log" \
  || { echo "FAIL [8] (contagem de bytes no WARN não bate com o tamanho bruto do arquivo anterior)"; cat "$T/stderr-8.log"; exit 1; }
WARN_PATH8="$(sed -n 's/.*salvo em \(.*\)$/\1/p' "$T/stderr-8.log" | head -1)"
[ -n "$WARN_PATH8" ] || { echo "FAIL [8] (WARN sem caminho)"; exit 1; }
[ -f "$WARN_PATH8" ] || { echo "FAIL [8] (caminho do WARN não existe: $WARN_PATH8)"; exit 1; }
cmp -s "$T/prev-8.bin" "$WARN_PATH8" \
  || { echo "FAIL [8] (backup não é byte-idêntico ao conteúdo anterior — bytes inválidos em UTF-8 corrompem a cópia)"; exit 1; }
[ "$(backup_count)" = "$((BC_BEFORE8 + 1))" ] || { echo "FAIL [8] (contagem de backups não incrementou em 1)"; exit 1; }
echo "OK [8]"

echo "[9] arquivo anterior vazio (0 bytes) → nenhum backup, nenhum WARN (nada a recuperar)"
BC_BEFORE9="$(backup_count)"
: > "$H"
FORGE_ROOT="$T" bash "$GEN" demo-change >"$T/stdout-9.log" 2>"$T/stderr-9.log"
[ -s "$T/stderr-9.log" ] && { echo "FAIL [9] (WARN/ruído em stderr para arquivo anterior vazio)"; cat "$T/stderr-9.log"; exit 1; }
[ "$(backup_count)" = "$BC_BEFORE9" ] || { echo "FAIL [9] (backup criado para arquivo anterior vazio, sem nada a recuperar)"; exit 1; }
grep -q 'demo-change' "$H"
echo "OK [9]"

echo "[10] controle/limitação conhecida: com marcadores presentes, conteúdo fora do slot NARRATIVE-DELTA some sem backup e sem WARN (DA-09, roadmap Onda 8)"
FORGE_ROOT="$T" bash "$GEN" demo-change >/dev/null 2>&1   # regenera do zero — marcadores presentes
python3 - "$H" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
extra = "\n## Rodada extra\n\nTexto acrescentado FORA do par de marcadores (mesma prática que a issue #120 descreve).\n"
open(p, 'w').write(s + extra)
PY
BC_BEFORE10="$(backup_count)"
FORGE_ROOT="$T" bash "$GEN" demo-change >"$T/stdout-10.log" 2>"$T/stderr-10.log"
grep -q 'Rodada extra' "$H" \
  && { echo "FAIL [10] (o texto fora do slot deveria ter sido perdido nesta rodada — se a limitação foi corrigida, atualize este cenário, o comentário de handoff-render.mjs e o CHANGELOG em vez de deixá-lo falhar)"; exit 1; }
[ -s "$T/stderr-10.log" ] && { echo "FAIL [10] (WARN inesperado — a limitação documentada é a ausência de aviso neste caso)"; cat "$T/stderr-10.log"; exit 1; }
[ "$(backup_count)" = "$BC_BEFORE10" ] || { echo "FAIL [10] (backup inesperado — a limitação documentada é a ausência de backup neste caso)"; exit 1; }
echo "OK [10] (limitação conhecida confirmada, não é regressão desta mudança)"

echo "PASS w60-handoff-gen-gate"
