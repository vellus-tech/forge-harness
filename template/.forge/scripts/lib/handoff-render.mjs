// handoff-render — deterministic renderer for .forge/HANDOFF.md (sections 1-3, 5).
// Reads the active change state (manifest/progress/deferrals) and fills the handoff template.
// The narrative delta (section 4) is preserved across regenerations when already filled, so a
// rule-based hook run never destroys a delta written by /forge:handoff.
//
// REGRA DE BYTES AUTORAIS (#120, 5ª rodada — digest em vez de forma/regex):
//
//   1. O render é uma função pura dos dados do change (manifest/progress/deferrals + git + FORGE.md).
//   2. "Bytes autorais" de um HANDOFF.md anterior são os bytes que esse render não explica.
//   3. A região do slot NARRATIVE-DELTA é sempre autoral por definição: seu conteúdo BRUTO, sem
//      trim e sem atalho de placeholder, é sempre copiado para a frente quando os dois arquivos —
//      o anterior e o novo render — têm o par de marcadores.
//   4. Para a região FORA do slot ("outside"), a 4ª rodada comparava contra uma "forma" (regex)
//      derivada do template, com cada `{{CAMPO}}` virando um coringa `[^\n]*`. Isso tem um furo: o
//      coringa também casa com texto autoral escrito na MESMA LINHA de um campo (ex.: uma nota
//      colada depois do valor de `{{CHANGE_ID}}` ou de `{{OPEN_DEFERRALS}}`), que então desaparece
//      com rc 0 e sem WARN — exatamente a classe de bug que a issue #120 denuncia. Nenhuma forma
//      derivada de regex fecha esse furo por completo (o campo não tem gramática fixa o bastante).
//   5. A regra atual não usa forma nenhuma: o próprio HANDOFF.md carrega, fora do slot, um
//      comentário `<!-- FORGE:HANDOFF-DIGEST sha256=<hash> -->` com o sha256 de tudo o que está fora
//      do slot NAQUELE arquivo (o comentário exclui a si mesmo do hash — ele descreve o resto do
//      documento, não a si próprio). Na próxima geração, o "outside" do arquivo anterior é
//      re-hasheado (com o comentário removido) e comparado ao hash que o próprio comentário
//      registra: se bater, nada foi tocado por fora desde que ESSE arquivo foi escrito — mesmo que
//      HEAD/data/progresso tenham mudado desde então, porque o hash foi calculado sobre os bytes já
//      atualizados na última geração, não sobre um estado anterior a ela. Se não bater (edição
//      manual, texto colado, truncamento) ou se o comentário não existir (arquivo legado, anterior a
//      esta regra, ou template sem o marcador de digest), backup + WARN.
//   6. Comparação de digest é feita em Buffer bruto, nunca via string utf8 decodificada: o marcador
//      do digest é ASCII puro, que em UTF-8 (válido ou não) nunca aparece como byte de continuação,
//      então localizá-lo por Buffer.indexOf funciona mesmo que o resto do arquivo tenha bytes
//      inválidos — sem isso, decodificar para achar o marcador substituiria bytes ruins por U+FFFD e
//      quebraria o hash de qualquer arquivo que não seja UTF-8 limpo.
//   7. Se o template não tiver o marcador de digest (`<!-- FORGE:HANDOFF-DIGEST -->`) — um template
//      customizado de um adotante, por exemplo — a regra não é desligada: cai para comparação
//      literal de bytes entre o "outside" do arquivo anterior e o que seria escrito agora. Isso
//      ainda é seguro (nunca perde bytes em silêncio) e cobre o caso trivial de duas gerações sem
//      mudança nenhuma de estado; só reintroduz o falso positivo de deriva de estado (HEAD/data)
//      que o digest evita, e só nesse template sem suporte ao marcador.
//
// Driven by env (set by handoff-gen.sh): HANDOFF_DIR, HANDOFF_TPL, FORGE_ROOT, HANDOFF_ID,
// HANDOFF_BRANCH, HANDOFF_SHA, HANDOFF_DATE, HANDOFF_TEST, HANDOFF_TYPECHECK, HANDOFF_LINT.
// Deterministic: no wall clock (uses HEAD commit date passed in), stable field order. The backup
// filename is prefixed by the deterministic HEAD commit date (HANDOFF_DATE, slugified — never wall
// clock) followed by a hash of the previous file's bytes: the date makes backups sortable by name
// in the chronological order they were made for, and the hash keeps the dedupe property — a rerun
// over the exact same previous bytes under the exact same HANDOFF_DATE overwrites the same path
// instead of growing forge-backups/ without bound, while previous content that genuinely differs
// (new state, new lost text) still gets its own file.
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { join, dirname, resolve as resolvePath } from 'node:path';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { parseYamlSubset } from './yaml-lite.mjs';

const env = process.env;
const dir = env.HANDOFF_DIR;
const root = env.FORGE_ROOT;
const out = join(root, '.forge', 'HANDOFF.md');

const readJson = (p) => { try { return JSON.parse(readFileSync(p, 'utf8')); } catch { return null; } };
const dash = (v) => (v === undefined || v === null || v === '' ? 'n/d' : String(v));

const manifest = parseYamlSubset(readFileSync(join(dir, 'manifest.yaml'), 'utf8'));
const progress = readJson(join(dir, 'progress.json')) || {};
const deferrals = readJson(join(dir, 'deferrals.json'));

const open = Array.isArray(deferrals)
  ? deferrals.filter((d) => d && d.status === 'open').map((d) => d.id)
  : (deferrals && Array.isArray(deferrals.deferrals)
      ? deferrals.deferrals.filter((d) => d && d.status === 'open').map((d) => d.id)
      : []);

const map = {
  CHANGE_ID: dash(env.HANDOFF_ID),
  TYPE: dash(manifest.type),
  SCALE: dash(manifest.scale),
  PHASE: dash(manifest.status),
  BRANCH: dash(env.HANDOFF_BRANCH),
  SHA: dash(env.HANDOFF_SHA),
  DATE: dash(env.HANDOFF_DATE),
  WAVE: dash(progress.current_wave),
  STORIES_DONE: dash(progress.done_stories ?? 0),
  STORIES_TOTAL: dash(progress.total_stories ?? 0),
  TASKS_DONE: dash(progress.done_tasks ?? 0),
  TASKS_TOTAL: dash(progress.total_tasks ?? 0),
  OPEN_DEFERRALS: open.length ? open.join(', ') : 'nenhum',
  RUNTIME_TEST: dash(env.HANDOFF_TEST),
  RUNTIME_TYPECHECK: dash(env.HANDOFF_TYPECHECK),
  RUNTIME_LINT: dash(env.HANDOFF_LINT),
};

const rawTpl = readFileSync(env.HANDOFF_TPL, 'utf8');
let content = rawTpl;
for (const [k, v] of Object.entries(map)) content = content.replaceAll(`{{${k}}}`, v);

function slugDate(v) {
  const s = (v || '').replace(/[^0-9A-Za-z]+/g, '-').replace(/^-+|-+$/g, '');
  return s || 'sem-data';
}

// Backs up the previous HANDOFF.md before any of it is discarded (#120). Mirrors the backup
// resolution the `update` flow uses since #76 (bin/forge.mjs): git-dir-relative and outside the
// working tree whenever one is resolvable (so it works from a linked worktree too, and never shows
// up in `git status` or gets swept by a gate that scans the tree), with a same-directory fallback
// for a non-git target. Takes the previous file as a raw Buffer, never the utf8-decoded string:
// decoding invalid UTF-8 replaces bad bytes with U+FFFD, and re-encoding that string back to disk
// changes the byte count and breaks the "byte-idêntico" contract for any HANDOFF.md that isn't
// clean UTF-8 (e.g. saved once from Latin-1/CP1252, or carrying a stray byte). Returns the absolute
// backup path and the exact byte length of what was saved, read from the buffer, not a decoded
// string.
function backupPreviousHandoff(root, prevBuf) {
  const bytes = prevBuf.length;
  const hash = createHash('sha256').update(prevBuf).digest('hex').slice(0, 16);
  const stamp = `${slugDate(env.HANDOFF_DATE)}-${hash}`;
  let gitDir = null;
  try {
    gitDir = resolvePath(root, execFileSync('git', ['-C', root, 'rev-parse', '--git-dir'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim());
  } catch { gitDir = null; }
  const backupPath = gitDir
    ? join(gitDir, 'forge-backups', `handoff-${stamp}.md`)
    : join(root, '.forge', `HANDOFF.md.bak-${stamp}`);
  mkdirSync(dirname(backupPath), { recursive: true });
  writeFileSync(backupPath, prevBuf);
  return { path: backupPath, bytes };
}

const START = '<!-- FORGE:NARRATIVE-DELTA:START -->';
const END = '<!-- FORGE:NARRATIVE-DELTA:END -->';
const rawCs = rawTpl.indexOf(START), rawCe = rawTpl.indexOf(END);
const tplHasSlot = rawCs >= 0 && rawCe > rawCs;

const DIGEST_PLACEHOLDER = '<!-- FORGE:HANDOFF-DIGEST -->';
// Matches either the unfilled placeholder or an already-filled digest line (with its trailing
// newline, if any), so the same helper strips it in either form.
const DIGEST_LINE_STR_RE = /<!-- FORGE:HANDOFF-DIGEST(?: sha256=[0-9a-f]{64})? -->\r?\n?/;
const digestSupported = rawTpl.includes(DIGEST_PLACEHOLDER);

// Buffer-level digest line lookup: the marker is pure ASCII, and any byte below 0x80 is
// unambiguous in a UTF-8 stream regardless of what invalid sequences surround it elsewhere in the
// buffer, so this never needs to decode the buffer as text (see rule item 6 above).
const DIGEST_PREFIX = Buffer.from('<!-- FORGE:HANDOFF-DIGEST sha256=', 'ascii');
const DIGEST_SUFFIX = Buffer.from(' -->', 'ascii');
const DIGEST_HEX_LEN = 64;

function findDigestLine(buf) {
  const start = buf.indexOf(DIGEST_PREFIX);
  if (start < 0) return null;
  const hexStart = start + DIGEST_PREFIX.length;
  const hexBuf = buf.subarray(hexStart, hexStart + DIGEST_HEX_LEN);
  const hex = hexBuf.toString('ascii');
  if (hexBuf.length !== DIGEST_HEX_LEN || !/^[0-9a-f]{64}$/.test(hex)) return null;
  const suffixStart = hexStart + DIGEST_HEX_LEN;
  if (buf.subarray(suffixStart, suffixStart + DIGEST_SUFFIX.length).compare(DIGEST_SUFFIX) !== 0) return null;
  let end = suffixStart + DIGEST_SUFFIX.length;
  if (buf[end] === 0x0d) end += 1; // \r
  if (buf[end] === 0x0a) end += 1; // \n
  return { start, end, hex };
}

function stripDigestLine(buf, found) {
  if (!found) return buf;
  return Buffer.concat([buf.subarray(0, found.start), buf.subarray(found.end)]);
}

function sha256Hex(buf) {
  return createHash('sha256').update(buf).digest('hex');
}

// Preserve an already-written narrative delta (idempotent regen), and back up whatever the render
// would otherwise silently discard (#120; see the header comment above for the full rule).
let backupInfo = null;
if (existsSync(out)) {
  const prevBuf = readFileSync(out);
  const prev = prevBuf.toString('utf8');
  const ps = prev.indexOf(START), pe = prev.indexOf(END);
  const cs = content.indexOf(START), ce = content.indexOf(END);
  const bothHaveMarkers = ps >= 0 && pe > ps && cs >= 0 && ce > cs;

  if (bothHaveMarkers) {
    // RAW slot body, no trim, no placeholder shortcut: the only thing that means "nothing to
    // preserve here" is the previous slot being byte-for-byte the template's own raw placeholder —
    // anything else, however it starts or ends, is authorial and is copied forward as-is.
    const prevSlotRaw = prev.slice(ps + START.length, pe);
    const tplSlotRaw = rawTpl.slice(rawCs + START.length, rawCe);
    if (prevSlotRaw !== tplSlotRaw) {
      content = content.slice(0, cs + START.length) + prevSlotRaw + content.slice(ce);
    }
  }

  // The "outside" region of the PREVIOUS file, in raw bytes: everything except the slot's own
  // (raw, already-preserved) body. Byte-level marker lookup, not string indexOf on the decoded
  // text, because prefix/suffix bytes here can be arbitrary (including invalid UTF-8) and must
  // stay byte-exact for the digest to mean anything.
  const psB = prevBuf.indexOf(START), peB = prevBuf.indexOf(END);
  const bothHaveMarkersBuf = psB >= 0 && peB > psB && tplHasSlot;
  const prevOutsideBuf = bothHaveMarkersBuf
    ? Buffer.concat([prevBuf.subarray(0, psB + START.length), prevBuf.subarray(peB)])
    : prevBuf;

  let wouldLoseBytes;
  if (digestSupported) {
    const found = findDigestLine(prevOutsideBuf);
    const stripped = stripDigestLine(prevOutsideBuf, found);
    wouldLoseBytes = !found || found.hex !== sha256Hex(stripped);
  } else {
    // No digest marker in this template: fall back to literal byte comparison of the "outside"
    // region against what would be written now. Still never loses bytes silently, at the cost of
    // a false positive on pure state drift (HEAD sha, date, progress numbers) — acceptable only
    // because this path is for a template that opted out of the digest mechanism.
    const csF = content.indexOf(START), ceF = content.indexOf(END);
    const newOutside = tplHasSlot
      ? content.slice(0, csF + START.length) + content.slice(ceF)
      : content;
    wouldLoseBytes = !prevOutsideBuf.equals(Buffer.from(newOutside, 'utf8'));
  }

  // If the previous bytes already equal what will be written there is nothing to lose, so no
  // backup; likewise an empty previous file (0 bytes) has nothing to recover, so it is skipped too
  // — the backup and WARN exist to make real prior content recoverable, not to leave a trace on
  // every run.
  if (wouldLoseBytes && prevBuf.length > 0) {
    backupInfo = { ...backupPreviousHandoff(root, prevBuf), bothHaveMarkers };
  }
}

// Stamp the digest of everything outside the slot in THIS render, so the next regeneration can
// tell a state-only change (fields the renderer itself controls) apart from an authorial byte
// (anything a human wrote that this renderer would not have produced) without matching against a
// template "shape" — see rule item 4-5 above for why the shape approach undercounts loss.
if (digestSupported) {
  const csF = content.indexOf(START), ceF = content.indexOf(END);
  const outsideNow = tplHasSlot
    ? content.slice(0, csF + START.length) + content.slice(ceF)
    : content;
  const outsideForHash = outsideNow.replace(DIGEST_LINE_STR_RE, '');
  const digestHex = sha256Hex(Buffer.from(outsideForHash, 'utf8'));
  content = content.replace(DIGEST_PLACEHOLDER, `<!-- FORGE:HANDOFF-DIGEST sha256=${digestHex} -->`);
}

writeFileSync(out, content);
if (backupInfo) {
  const reason = backupInfo.bothHaveMarkers
    ? 'HANDOFF.md com conteúdo fora do bloco NARRATIVE-DELTA'
    : 'HANDOFF.md sem marcadores NARRATIVE-DELTA';
  process.stderr.write(
    `WARN: ${reason} — conteúdo anterior (${backupInfo.bytes} bytes) salvo em ${backupInfo.path}\n`,
  );
}
