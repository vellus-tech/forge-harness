#!/usr/bin/env bash
# Gate — handoff-gen (REQ-02/NFR-02): o gerador determinístico monta .forge/HANDOFF.md a partir
# do estado do change (manifest/progress/deferrals), degrada sem FORGE.md, é idempotente e preserva
# um delta narrativo já escrito.
#
# Regra de bytes autorais (#120, 4ª rodada — causa raiz, não mais sintoma por sintoma): o render é
# função pura dos dados do change (manifest/progress/deferrals/git/FORGE.md). "Bytes autorais" de um
# HANDOFF.md anterior são os bytes que esse render não explica — nas regiões que o template não
# gera: o slot NARRATIVE-DELTA inteiro, bruto, sem trim nem atalho de placeholder (qualquer texto
# ali, mesmo começando com o prefixo do placeholder "_(A preencher", é autoral e sobrevive por
# cópia literal para a frente sempre que os dois arquivos — o anterior e o novo render — têm o par
# de marcadores); e todo byte fora da estrutura literal do template, verificado contra uma "forma"
# derivada do próprio template em que cada `{{CAMPO}}` vira um coringa e o resto é casado ao pé da
# letra — então uma mudança só nos campos gerados (HEAD, data, progresso) sempre casa com a forma e
# nunca dispara backup nem WARN, e um arquivo sem os marcadores nunca casa (a forma exige o texto
# literal dos marcadores) e sempre dispara. Backup byte-idêntico + WARN acontecem se e somente se
# algum byte autoral não sobrevive no arquivo novo; o WARN nomeia a região da perda — "sem
# marcadores" ou "fora do bloco" — e nunca aponta "fora do bloco" quando a perda é no slot, o que é
# garantido por construção (o slot bruto é sempre copiado para a frente antes de qualquer decisão
# de backup, nunca depois).
#   [1] gera o artefato com as 5 seções + dados do change
#   [2] determinismo: duas execuções sem mudança de estado → diff vazio
#   [3] degradação sem FORGE.md → runtime = n/d
#   [4] preserva o delta narrativo escrito entre os marcadores, com o resto do documento inalterado
#       (controle: nenhum backup — nada fora do slot mudou)
#   [5] sem marcadores + conteúdo mudaria → backup byte-idêntico ao anterior + WARN nomeia o caminho
#   [6] arquivo idêntico ao que seria renderizado (sem marcadores) → nenhum backup
#   [7] PBT: para conteúdo anterior gerado, cobrindo os quatro quadrantes com/sem marcadores ×
#       perda/sem-perda (bytes aleatórios dentro E fora dos marcadores, inclusive UTF-8 inválido,
#       para os quadrantes de perda; corpo de slot reaproveitando o render atual — inclusive com um
#       commit real de deriva de estado entre as duas gerações — para o quadrante sem perda com
#       marcadores; arquivo anterior vazio para o quadrante sem perda sem marcadores), os bytes
#       anteriores são sempre recuperáveis depois da geração — no próprio arquivo (delta preservado,
#       comparado por Buffer) ou num backup byte-idêntico nomeado pelo WARN
#   [8] backup é byte-idêntico ao arquivo anterior mesmo com bytes inválidos em UTF-8, e a
#       contagem de bytes no WARN bate com o tamanho bruto do arquivo, não com a string decodificada
#   [9] arquivo anterior de 0 bytes → nenhum backup, nenhum WARN (nada a recuperar)
#   [10] com marcadores JÁ presentes, texto escrito fora do par START/END (mesma prática que a
#        issue #120 descreve, /forge:handoff acumulando rodadas fora do slot) é recuperável por
#        backup byte-idêntico + WARN nomeando o caminho, exatamente como o caso sem marcadores —
#        nada além do slot é perdido em silêncio
#   [11] achado HIGH (4ª rodada): texto real escrito DENTRO do slot logo após o prefixo do
#        placeholder ("_(A preencher...") sobrevive no próprio arquivo, sem backup nem WARN — o
#        atalho `startsWith('_(A preencher')` que descartava esse texto foi removido
#   [12] achado HIGH (4ª rodada): corpo de slot com indentação e linhas em branco nas bordas
#        sobrevive byte a byte (sem trim) dentro do próprio arquivo
#   [13] achado MEDIUM (4ª rodada): fluxo canônico com um commit real entre duas gerações — só
#        HEAD sha/data avançam, nada mais muda — não dispara backup nem WARN (a forma do template
#        aceita qualquer valor nos campos gerados)
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

echo "[7] PBT: bytes anteriores sempre recuperáveis, nos quatro quadrantes com/sem marcadores × perda/sem-perda"
node - "$LIB" "$GEN" "$T" <<'EOF' || { echo "FAIL [7] (propriedade de recuperabilidade falhou)"; exit 1; }
const [lib, gen, root] = process.argv.slice(2);
const fs = await import('node:fs');
const path = await import('node:path');
const { execFileSync, spawnSync } = await import('node:child_process');
const { forAll, gen: G } = await import(`${lib}/pbt.mjs`);

const H = path.join(root, '.forge', 'HANDOFF.md');
const START = '<!-- FORGE:NARRATIVE-DELTA:START -->';
const END = '<!-- FORGE:NARRATIVE-DELTA:END -->';
const WORDS = ['alfa', 'bravo', 'charlie', 'delta', 'echo', 'foxtrot', 'golf', 'hotel', 'india', 'julia', 'kilo', 'lima'];
// O corpo do delta fica em palavras ASCII de propósito: ele é lido de volta como string utf8 pelo
// próprio handoff-render.mjs (o merge do delta decodifica o arquivo anterior para localizar os
// marcadores), então bytes inválidos ali testariam a decodificação de texto, não o backup. Prefix
// e suffix (fora do slot) são o que a correção do #120 passa a proteger por Buffer bruto — o
// gerador cobre todo o intervalo de bytes 0-255, então inclui UTF-8 inválido (bytes de continuação
// soltos, 0xFF, etc.) sem que o teste precise construí-los à mão.
const wordsGen = G.array(G.oneOf(WORDS), 5, 40);
const byteGen = G.array(G.int(0, 255), 0, 30);
// Os quatro quadrantes da regra de bytes autorais (com/sem marcadores × perda/sem-perda). Os dois
// quadrantes "com-marcadores" ganham um sabor de corpo de slot (edgeChoice) que exercita as bordas
// que o achado HIGH nomeou: prefixo do placeholder seguido de texto real, indentação/linhas em
// branco, e — só no quadrante sem-perda — uma deriva de estado por commit real (achado MEDIUM).
const kindGen = G.oneOf(['wm-loss', 'wm-noloss', 'nm-loss', 'nm-noloss']);
const edgeGen = G.oneOf(['random', 'placeholder-prefix', 'indented', 'bordered-spaces', 'commit-drift']);

function runCase(kind, bodyWords, prefixBytes, suffixBytes, edgeChoice) {
  const hasMarkers = kind.startsWith('wm');
  const words = bodyWords.join(' ');
  let bodyBuf = Buffer.from(words, 'utf8');
  if (hasMarkers) {
    // Corpo BRUTO, nunca aparado — é exatamente o que a regra exige preservar por igual,
    // comece ele como começar.
    if (edgeChoice === 'placeholder-prefix') bodyBuf = Buffer.from(`_(A preencher: texto)_\nNOTA-REAL: ${words}`, 'utf8');
    else if (edgeChoice === 'indented') bodyBuf = Buffer.from(`\n\n    ${words}\n    linha2\n\n\n`, 'utf8');
    else if (edgeChoice === 'bordered-spaces') bodyBuf = Buffer.from(`   ${words}   `, 'utf8');
  }

  let prevBuf;
  if (kind === 'nm-noloss') {
    prevBuf = Buffer.alloc(0); // nada a recuperar — o único "sem marcadores, sem perda" possível
  } else if (kind === 'wm-noloss') {
    // Reaproveita o render ATUAL (não bytes aleatórios) como "fora do slot", para cair de fato no
    // caminho sem-perda: a forma do template casa com ele por construção. `commit-drift` avança o
    // HEAD real entre a captura da referência e a geração medida — só campos gerados mudam.
    if (fs.existsSync(H)) fs.rmSync(H);
    const res0 = spawnSync('bash', [gen, 'demo-change'], { cwd: root, env: { ...process.env, FORGE_ROOT: root }, encoding: 'utf8' });
    if (res0.status !== 0) return false;
    const refStr = fs.readFileSync(H, 'utf8');
    const rcs = refStr.indexOf(START), rce = refStr.indexOf(END);
    if (rcs < 0 || rce < 0) return false;
    if (edgeChoice === 'commit-drift') {
      try { execFileSync('git', ['-C', root, 'commit', '--allow-empty', '-q', '-m', 'drift'], { stdio: 'ignore' }); } catch { /* segue sem deriva */ }
    }
    prevBuf = Buffer.concat([
      Buffer.from(refStr.slice(0, rcs + START.length), 'utf8'),
      bodyBuf,
      Buffer.from(refStr.slice(rce), 'utf8'),
    ]);
  } else {
    const prefixBuf = Buffer.from(prefixBytes);
    const suffixBuf = Buffer.from(suffixBytes);
    prevBuf = hasMarkers
      ? Buffer.concat([prefixBuf, Buffer.from(`\n\n${START}\n`, 'utf8'), bodyBuf, Buffer.from(`\n${END}\n\n`, 'utf8'), suffixBuf, Buffer.from('\n')])
      : Buffer.concat([prefixBuf, Buffer.from('\n'), bodyBuf, Buffer.from('\n'), suffixBuf, Buffer.from('\n')]);
  }

  fs.writeFileSync(H, prevBuf);
  const res = spawnSync('bash', [gen, 'demo-change'], { cwd: root, env: { ...process.env, FORGE_ROOT: root }, encoding: 'utf8' });
  if (res.status !== 0) return false; // #120 é sobre nunca perder bytes com rc 0 — rc≠0 já é outro defeito
  const afterBuf = fs.readFileSync(H);
  // Com marcadores, o corpo do slot tem de sobreviver dentro do próprio arquivo sempre, bruto,
  // qualquer que seja seu formato — é a única parte que o merge de fato reescreve para preservar.
  if (hasMarkers && !afterBuf.includes(bodyBuf)) return false;
  if (afterBuf.equals(prevBuf)) return true; // nada mudou — nada a recuperar

  const m = /salvo em (.*)$/m.exec(res.stderr || '');
  const backedUp = !!m;

  if (kind === 'nm-noloss') return !backedUp; // arquivo vazio: nada a recuperar, backup seria ruído
  if (kind === 'wm-noloss') return !backedUp; // forma do template casa (com ou sem deriva de estado): sem backup, sem WARN

  // Quadrantes de perda: se o arquivo final não é byte-idêntico ao anterior, o que mudou fora do
  // que foi preservado só pode estar recuperável por backup — nunca perdido em silêncio com rc 0.
  if (!backedUp) return false; // conteúdo anterior mudaria e sumiu sem aviso nem backup — bytes perdidos sem rastro
  const backupPath = m[1].trim();
  return fs.existsSync(backupPath) && fs.readFileSync(backupPath).equals(prevBuf);
}

const SEED = 20260925;
const RUNS = 80;
const r = forAll([kindGen, wordsGen, byteGen, byteGen, edgeGen], runCase, { runs: RUNS, seed: SEED });
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

echo "[10] com marcadores presentes, conteúdo fora do slot NARRATIVE-DELTA é recuperável por backup + WARN (mesma prática que a issue #120 descreve)"
FORGE_ROOT="$T" bash "$GEN" demo-change >/dev/null 2>&1   # regenera do zero — marcadores presentes, estado inalterado (idempotente, sem backup aqui)
python3 - "$H" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
extra = "\n## Rodada extra\n\nTexto acrescentado FORA do par de marcadores (mesma prática que a issue #120 descreve).\n"
open(p, 'w').write(s + extra)
PY
cp "$H" "$T/prev-10.bin"
EXPECT_BYTES10="$(wc -c < "$T/prev-10.bin" | tr -d ' ')"
BC_BEFORE10="$(backup_count)"
FORGE_ROOT="$T" bash "$GEN" demo-change >"$T/stdout-10.log" 2>"$T/stderr-10.log"
grep -q 'Rodada extra' "$H" \
  && { echo "FAIL [10] (o texto fora do slot não deveria sobreviver no próprio arquivo — só a seção 4 é preservada; ele precisa estar no backup)"; exit 1; }
grep -q '^WARN: HANDOFF.md com conteúdo fora do bloco NARRATIVE-DELTA' "$T/stderr-10.log" \
  || { echo "FAIL [10] (WARN ausente em stderr — a rodada extra fora do slot foi perdida sem aviso)"; cat "$T/stderr-10.log"; exit 1; }
grep -q "conteúdo anterior ($EXPECT_BYTES10 bytes)" "$T/stderr-10.log" \
  || { echo "FAIL [10] (contagem de bytes no WARN não bate com o arquivo anterior, rodada extra incluída)"; cat "$T/stderr-10.log"; exit 1; }
WARN_PATH10="$(sed -n 's/.*salvo em \(.*\)$/\1/p' "$T/stderr-10.log" | head -1)"
[ -n "$WARN_PATH10" ] || { echo "FAIL [10] (WARN sem caminho)"; exit 1; }
cmp -s "$T/prev-10.bin" "$WARN_PATH10" \
  || { echo "FAIL [10] (backup não é byte-idêntico ao arquivo anterior — a rodada extra não sobreviveu nem no arquivo nem no backup)"; exit 1; }
[ "$(backup_count)" = "$((BC_BEFORE10 + 1))" ] || { echo "FAIL [10] (esperado 1 backup novo — achei $(($(backup_count) - BC_BEFORE10)))"; exit 1; }
echo "OK [10]"

echo "[11] com marcadores, texto real dentro do slot logo após o prefixo do placeholder sobrevive no próprio arquivo — sem backup, sem WARN (achado HIGH, 4ª rodada)"
FORGE_ROOT="$T" bash "$GEN" demo-change >/dev/null 2>&1   # regenera do zero — marcadores presentes, placeholder puro
python3 - "$H" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
a = '<!-- FORGE:NARRATIVE-DELTA:START -->'
b = '<!-- FORGE:NARRATIVE-DELTA:END -->'
i = s.index(a) + len(a)
j = s.index(b)
placeholder = s[i:j]
# nota real logo após o prefixo do placeholder, dentro do slot — o padrão que a issue #120
# (achado HIGH) descreve; o `startsWith('_(A preencher')` antigo descartava isto em silêncio.
note = placeholder + '\nNOTA-REAL: decisao X tomada; gotcha Y no deploy.\n'
s = s[:i] + note + s[j:]
open(p, 'w').write(s)
PY
BC_BEFORE11="$(backup_count)"
FORGE_ROOT="$T" bash "$GEN" demo-change >"$T/stdout-11.log" 2>"$T/stderr-11.log"
grep -q 'NOTA-REAL: decisao X tomada' "$H" \
  || { echo "FAIL [11] (nota real após o prefixo do placeholder sumiu do próprio arquivo — perda dentro do slot)"; exit 1; }
[ ! -s "$T/stderr-11.log" ] || { echo "FAIL [11] (WARN/ruído inesperado — o slot foi preservado no próprio arquivo, nada deveria ir a backup)"; cat "$T/stderr-11.log"; exit 1; }
[ "$(backup_count)" = "$BC_BEFORE11" ] || { echo "FAIL [11] (backup criado para conteúdo que já foi preservado no próprio arquivo)"; exit 1; }
echo "OK [11]"

echo "[12] com marcadores, corpo do slot com indentação e linhas em branco nas bordas sobrevive byte a byte — sem trim (achado HIGH, 4ª rodada)"
FORGE_ROOT="$T" bash "$GEN" demo-change >/dev/null 2>&1   # regenera do zero — marcadores presentes, placeholder puro
python3 - "$H" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
a = '<!-- FORGE:NARRATIVE-DELTA:START -->'
b = '<!-- FORGE:NARRATIVE-DELTA:END -->'
i = s.index(a) + len(a); j = s.index(b)
body = '\n\n    codigo indentado\n    linha2\n\n\n'
s = s[:i] + body + s[j:]
open(p, 'w').write(s)
PY
FORGE_ROOT="$T" bash "$GEN" demo-change >"$T/stdout-12.log" 2>"$T/stderr-12.log"
python3 - "$H" <<'PY' || { echo "FAIL [12] (corpo do slot com indentação/bordas não sobreviveu byte a byte — trim silencioso)"; exit 1; }
import sys
p = sys.argv[1]
s = open(p).read()
a = '<!-- FORGE:NARRATIVE-DELTA:START -->'
b = '<!-- FORGE:NARRATIVE-DELTA:END -->'
i = s.index(a) + len(a); j = s.index(b)
body = s[i:j]
expect = '\n\n    codigo indentado\n    linha2\n\n\n'
sys.exit(0 if body == expect else 1)
PY
echo "OK [12]"

echo "[13] fluxo canônico com commit real entre gerações: só HEAD sha/data avançam → nenhum backup, nenhum WARN (achado MEDIUM, 4ª rodada)"
git -C "$T" commit -q -m "estado A" --allow-empty >/dev/null
FORGE_ROOT="$T" bash "$GEN" demo-change >/dev/null 2>&1   # renderiza sob o estado A (HEAD sha/data do commit acima)
cp "$H" "$T/prev-13.bin"
git -C "$T" commit -q -m "estado B" --allow-empty >/dev/null   # avança HEAD sha/data — nenhum outro dado do change muda
SHA_A="$(sed -n 's/.*HEAD `\([^`]*\)`.*/\1/p' "$T/prev-13.bin" | head -1)"
BC_BEFORE13="$(backup_count)"
FORGE_ROOT="$T" bash "$GEN" demo-change >"$T/stdout-13.log" 2>"$T/stderr-13.log"
SHA_B="$(sed -n 's/.*HEAD `\([^`]*\)`.*/\1/p' "$H" | head -1)"
[ -n "$SHA_A" ] && [ -n "$SHA_B" ] && [ "$SHA_A" != "$SHA_B" ] \
  || { echo "FAIL [13] (pré-condição: HEAD sha não avançou entre os dois commits — cenário não exercita deriva de estado)"; exit 1; }
[ ! -s "$T/stderr-13.log" ] || { echo "FAIL [13] (WARN falso-positivo depois de um commit real — só HEAD sha/data mudaram — achado MEDIUM da 4ª rodada)"; cat "$T/stderr-13.log"; exit 1; }
[ "$(backup_count)" = "$BC_BEFORE13" ] || { echo "FAIL [13] (backup criado só porque HEAD sha/data avançaram — achado MEDIUM da 4ª rodada)"; exit 1; }
grep -q 'demo-change' "$H"
echo "OK [13]"

echo "PASS w60-handoff-gen-gate"
