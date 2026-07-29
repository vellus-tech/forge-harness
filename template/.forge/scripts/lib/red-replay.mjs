// lib/red-replay.mjs — o motor do replay (Onda C, rule testing/regression-red-first.md,
// seção "Verificação"): converte a evidência DECLARADA (Onda B, honor-system) em evidência
// OBSERVADA de fato. Roda o teste declarado (nunca a suíte inteira) em worktrees git efêmeros,
// primeiro sobre HEAD (saúde do ambiente + Green real) e depois sobre a árvore PRÉ-correção
// (derivada, nunca perguntada ao autor).
//
// Ordem de execução (Furo 5, Onda C — decisão de design do orquestrador): o comando roda em
// HEAD PRIMEIRO. Se falhar ali por erro de build/ambiente (classify() != 'behavioral'), o
// problema é o worktree efêmero não ter as dependências materializadas (node_modules/.venv/...
// não são versionadas) — not-possible, rebaixável por waiver, NUNCA um FAIL inegociável. Só
// uma falha COMPORTAMENTAL em HEAD (a correção declarada não funciona) vira FAIL de verdade
// (ruleItem 'green'). Só depois de HEAD estar saudável é que a árvore base é derivada e testada
// — não adianta gastar esforço reconstruindo/revertendo se o ambiente nem roda o comando.
//
// Três estratégias para derivar a base pré-correção, nesta ordem — nunca trava mudo: quando
// nenhuma das duas primeiras funciona, cai em NOT-POSSIBLE, um veredito válido que a rule
// resolve com waiver (não com a máquina inventando um teste ou um commit):
//
//   (a) ANCESTRY — localiza o commit que introduziu o CASO declarado (test_id) no arquivo de
//       teste — não o commit que criou o ARQUIVO (Furo 2: arquivo de teste preexistente é o
//       fluxo comuníssimo "acrescentar caso de regressão a um arquivo antigo"; ancorar na
//       criação do arquivo levava a base para uma era anterior ao caso existir). Base = pai do
//       primeiro commit que toca fix_files DEPOIS desse commit de introdução do caso.
//   (b) REVERT-SYNTHESIS — quando (a) não resolve (o caso mais comum é teste e correção no
//       mesmo commit — squash): cria um worktree em HEAD e reverte, só nos fix_files, o diff
//       introduzido pelo commit que os tocou por último — mantendo o teste (que já está em
//       HEAD) intacto. A base deixa de ser um commit literal e passa a ser uma árvore sintética.
//   (c) NOT-POSSIBLE — nem test_id resolve a um commit de introdução, nem os fix_files têm
//       histórico git suficiente para sintetizar o revert, nem o test_id declarado existe na
//       árvore base derivada. Retorna { strategy:'not-possible', reason }. O caller
//       (lib/red-evidence-ops.mjs) grava status:'not-possible' e devolve exit≠0 pedindo waiver
//       — nunca lança exceção, nunca deixa o processo pendurado.
//
// Veredito 'observed' exige, na ordem: (0) comando passa em HEAD (Green real, não presumido);
// (1) o test_id declarado (quando presente) existe no arquivo de teste na árvore base — senão a
// base está errada por construção (Furo 2); (2) o teste FALHA na base (exit≠0); (3) a falha
// classifica como 'behavioral' via red-classify.mjs (nunca 'build-error'/'unknown'); (4) a saída
// casa com failure_pattern quando declarado; (5) a saída MENCIONA o test_id declarado — o caso
// que falhou precisa ser o caso declarado, não uma falha histórica adjacente que por acaso casa
// com o padrão (Furo 2). Qualquer ausência aborta com motivo nomeado — ver replay() abaixo.
import { existsSync, readFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { execFileSync, spawn } from 'node:child_process';
import { classify } from './red-classify.mjs';

const DEFAULT_TIMEOUT_S = 120;
const EXCERPT_MAX_CHARS = 6000;
const MAX_BUFFER_BYTES = 64 * 1024 * 1024; // Furo 4 — teto generoso, nunca ENOBUFS silencioso

function git(root, args, opts = {}) {
  return execFileSync('git', ['-C', root, ...args], { encoding: 'utf8', ...opts });
}

function currentHeadSha(root) {
  try { return git(root, ['rev-parse', 'HEAD']).trim(); } catch { return null; }
}

function isAncestorOrEqual(root, a, b) {
  if (a === b) return true;
  try { git(root, ['merge-base', '--is-ancestor', a, b], { stdio: 'ignore' }); return true; }
  catch { return false; }
}

function parentOf(root, sha) {
  try { return git(root, ['rev-parse', `${sha}^`]).trim(); } catch { return null; }
}

function fileExistsAt(root, ref, relPath) {
  try { execFileSync('git', ['-C', root, 'cat-file', '-e', `${ref}:${relPath}`], { stdio: 'ignore' }); return true; }
  catch { return false; }
}

function readFileAt(root, ref, relPath) {
  try { return execFileSync('git', ['-C', root, 'show', `${ref}:${relPath}`], { encoding: 'utf8' }); }
  catch { return null; }
}

// caseExistsInContent: testId ausente ⇒ true (nada declarado, nada a exigir — não é falso
// positivo, é "não avaliável"). testId presente ⇒ precisa aparecer literalmente no conteúdo.
function caseExistsInContent(content, testId) {
  if (!testId) return true;
  if (typeof content !== 'string') return false;
  return content.includes(testId);
}

// commits (mais antigo primeiro) que ADICIONARAM ou MODIFICARAM test_path — cobre tanto "arquivo
// novo" quanto "caso novo num arquivo antigo" (Furo 2).
function testTouchCommits(root, testPath) {
  let out;
  try { out = git(root, ['log', '--diff-filter=AM', '--format=%H', '--reverse', '--', testPath]); } catch { return []; }
  return out.trim().split('\n').filter(Boolean);
}

// findCaseIntroCommit: primeiro commit (cronologicamente) cujo conteúdo do arquivo JÁ contém
// o test_id declarado. Sem test_id declarado, melhor esforço = primeiro commit que tocou o
// arquivo (mantém compat com evidências antigas que nunca declararam test_id).
function findCaseIntroCommit(root, testPath, testId) {
  const commits = testTouchCommits(root, testPath);
  if (!commits.length) return null;
  if (!testId) return commits[0];
  for (const c of commits) {
    if (caseExistsInContent(readFileAt(root, c, testPath), testId)) return c;
  }
  return null; // test_id nunca apareceu no histórico do arquivo — sinal honesto de not-possible
}

// primeiro commit (cronologicamente) que toca algum fix_file E que vem DEPOIS de afterCommit
// (o commit que introduziu o caso). Exclui explicitamente afterCommit === candidato — esse é o
// caso "teste e correção no mesmo commit", tratado pela estratégia (b), não por esta.
function findFixCommitAfter(root, fixFiles, afterCommit) {
  let out;
  try { out = git(root, ['log', '--format=%H', '--reverse', '--', ...fixFiles]); } catch { return null; }
  const commits = out.trim().split('\n').filter(Boolean);
  for (const c of commits) {
    if (c === afterCommit) continue;
    if (isAncestorOrEqual(root, afterCommit, c)) return c;
  }
  return null;
}

// commit mais recente (até HEAD) que tocou um fix_file específico — usado pela estratégia (b)
// para saber qual diff reverter.
function findFixLastCommit(root, file) {
  let out;
  try { out = git(root, ['log', '-1', '--format=%H', '--', file]); } catch { return null; }
  out = out.trim();
  return out || null;
}

// deriveBase: decide a estratégia SEM tocar em disco (nenhum worktree criado aqui) — só
// inspeção de histórico. Puro o suficiente para ser testado isoladamente.
export function deriveBase({ root, testPath, fixFiles, testId }) {
  if (!testPath || !Array.isArray(fixFiles) || !fixFiles.length) {
    return { strategy: 'not-possible', reason: 'test_path/fix_files ausentes — grave com /forge:red record antes de replay' };
  }

  const caseCommit = findCaseIntroCommit(root, testPath, testId);
  if (caseCommit) {
    const fixCommit = findFixCommitAfter(root, fixFiles, caseCommit);
    if (fixCommit) {
      const base = parentOf(root, fixCommit);
      if (base && fileExistsAt(root, base, testPath) && caseExistsInContent(readFileAt(root, base, testPath), testId)) {
        return { strategy: 'ancestry', ref: base, caseCommit, fixCommit };
      }
    }
  }

  // (b) revert-synthesis a partir de HEAD — exige o teste (com o caso declarado) presente em
  // HEAD e histórico git para cada fix_file (sem histórico, não há o que reverter).
  const headContent = readFileAt(root, 'HEAD', testPath);
  if (headContent === null) {
    return {
      strategy: 'not-possible',
      reason: `test_path (${testPath}) não resolve por ancestry nem existe em HEAD — declare corretamente com /forge:red record ou dispense com /forge:red waive`,
    };
  }
  if (!caseExistsInContent(headContent, testId)) {
    return {
      strategy: 'not-possible',
      reason: `test_id ('${testId}') declarado não aparece em ${testPath} nem em HEAD — a base não pode conter um caso que não existe (item 3, Verificação)`,
    };
  }
  const reverts = [];
  for (const f of fixFiles) {
    const c = findFixLastCommit(root, f);
    if (!c) return { strategy: 'not-possible', reason: `fix_files '${f}' sem histórico git — revert-synthesis inviável` };
    reverts.push({ file: f, commit: c });
  }
  let head;
  try { head = git(root, ['rev-parse', 'HEAD']).trim(); } catch { return { strategy: 'not-possible', reason: 'HEAD não resolve (repo sem commits?)' }; }
  return { strategy: 'revert-synthesis', ref: head, reverts };
}

// ── worktrees efêmeros ──────────────────────────────────────────────────────────────────
// _liveWorktrees rastreia todo worktree criado por ESTE processo (root, dir) para dois fins:
// (a) handler de SIGINT/SIGTERM (Furo 6) — sem isso, Ctrl-C ou timeout externo mata o processo
//     sem passar pelo finally do replay(), vazando diretório em TMPDIR e entrada administrativa
//     em `git worktree list` do repo real. (b) nunca precisamos de `git worktree prune` — cada
//     entrada é removida explicitamente pelo próprio código que a criou.
const _liveWorktrees = new Map(); // dir -> root
let _signalHandlersInstalled = false;
// Furo 12 — o processo TESTE em si (não só os worktrees) também precisa morrer num sinal
// externo: sem isto, `bash -c 'sleep 300; node --test'` e o `sleep` sobrevivem ao Ctrl-C/timeout
// externo do orquestrador, órfãos, presos ao grupo de processo que o replay criou (detached:true
// em runTest) mas nunca matou fora do próprio timeout interno.
let _liveChildPid = null;

function removeWorktreeSync(root, dir) {
  if (!dir) return;
  // Furo 7 — remove APENAS a entrada deste worktree (`worktree remove`, não `prune`). Um
  // `prune` global apagaria da lista do git entradas legítimas de OUTROS worktrees (ex.: os
  // que /forge:coding-loop cria) que estejam temporariamente ausentes do disco por qualquer
  // outro motivo — o replay não tem autoridade para arrumar a casa alheia.
  try { execFileSync('git', ['-C', root, 'worktree', 'remove', '--force', dir], { stdio: 'ignore' }); } catch { /* best-effort */ }
  try { if (existsSync(dir)) rmSync(dir, { recursive: true, force: true }); } catch { /* best-effort */ }
  _liveWorktrees.delete(dir);
}

function installSignalHandlers() {
  if (_signalHandlersInstalled) return;
  _signalHandlersInstalled = true;
  const cleanupAndExit = (code) => {
    if (_liveChildPid) {
      try { process.kill(-_liveChildPid, 'SIGKILL'); }
      catch { try { process.kill(_liveChildPid, 'SIGKILL'); } catch { /* best-effort */ } }
      _liveChildPid = null;
    }
    for (const [dir, r] of [..._liveWorktrees]) removeWorktreeSync(r, dir);
    process.exit(code);
  };
  process.on('SIGINT', () => cleanupAndExit(130));
  process.on('SIGTERM', () => cleanupAndExit(143));
}

function makeWorktreePath() {
  // NÃO usa mkdtempSync (que já CRIA o diretório) — `git worktree add` exige que o destino
  // não exista ainda.
  const rand = Math.random().toString(16).slice(2) + process.pid.toString(16);
  return join(tmpdir(), `forge-red-replay-${rand}`);
}

function addWorktree(root, ref) {
  installSignalHandlers();
  const dir = makeWorktreePath();
  execFileSync('git', ['-C', root, 'worktree', 'add', '--detach', dir, ref], { stdio: ['ignore', 'pipe', 'pipe'] });
  _liveWorktrees.set(dir, root);
  return dir;
}

function removeWorktree(root, dir) {
  removeWorktreeSync(root, dir);
}

// applyRevert: para cada fix_file, calcula o diff commit->pai (a reversão exata da correção
// introduzida por `commit`) e aplica no worktree. Ordem do `git diff` é DELIBERADA — diff(commit,
// pai) descreve "o que muda ao ir de commit para pai", ou seja, já é o patch reverso; aplicá-lo
// (sem -R) transforma o estado 'commit' (o que o worktree tem, checkado em HEAD) em 'pai'.
// Retorna o texto combinado dos patches aplicados (Furo 8 — para reprodução por um auditor).
function applyRevert(root, worktreeDir, reverts) {
  const applied = [];
  for (const { file, commit } of reverts) {
    const parent = parentOf(root, commit);
    if (!parent) throw new Error(`revert-synthesis: ${commit} é commit raiz (sem pai) — não há o que reverter em ${file}`);
    let diff;
    try { diff = git(root, ['diff', commit, parent, '--', file]); }
    catch (e) { throw new Error(`revert-synthesis: git diff falhou para ${file} (${e.message})`); }
    if (!diff.trim()) continue; // arquivo sem mudança nesse commit — nada a reverter
    try {
      execFileSync('git', ['-C', worktreeDir, 'apply', '--whitespace=nowarn', '-'], { input: diff, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] });
      applied.push(diff);
    } catch (e) {
      const detail = (e.stderr || e.message || '').toString().trim();
      throw new Error(`revert-synthesis: não foi possível aplicar o patch reverso em ${file} (${detail})`);
    }
  }
  return applied.join('\n');
}

// runTest: roda exatamente o comando declarado — nunca a suíte — via child_process.spawn com
// grupo de processo próprio (Furo 3/9). `detached:true` faz do processo filho o líder de um
// novo grupo; ao estourar o timeout, `process.kill(-child.pid, 'SIGKILL')` mata o GRUPO inteiro
// — inclusive filhos em background (`cmd & outro-cmd`) que herdam o mesmo grupo e, de outra
// forma, manteriam o pipe de stdout aberto para sempre (o bug medido: 91s com timeout de 3s).
// Sem dependência de `perl`/`timeout(1)` — zero-dep, portável (Furo 9).
function runTest({ cwd, command, timeoutS }) {
  return new Promise((resolve) => {
    let child;
    try {
      child = spawn('bash', ['-c', command], { cwd, detached: true, stdio: ['ignore', 'pipe', 'pipe'] });
    } catch (e) {
      resolve({ exitCode: null, output: `spawn falhou: ${e.message}`, timedOut: false, indeterminate: true });
      return;
    }
    _liveChildPid = child.pid;
    let out = '';
    let bytes = 0;
    let overflowed = false;
    let timedOut = false;
    let settled = false;

    const append = (chunk) => {
      if (overflowed) return;
      bytes += chunk.length;
      if (bytes > MAX_BUFFER_BYTES) {
        overflowed = true;
        out += `\n…(saída truncada — excedeu o teto de ${MAX_BUFFER_BYTES} bytes)…`;
        return;
      }
      out += chunk;
    };

    const timer = setTimeout(() => {
      timedOut = true;
      try { process.kill(-child.pid, 'SIGKILL'); } catch { try { child.kill('SIGKILL'); } catch { /* best-effort */ } }
    }, Math.max(1, timeoutS) * 1000);
    // failsafe: garante que o timer não segure o processo Node vivo além do necessário
    if (typeof timer.unref === 'function') timer.unref();

    child.stdout.on('data', (d) => append(d.toString('utf8')));
    child.stderr.on('data', (d) => append(d.toString('utf8')));

    const finish = (result) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      if (_liveChildPid === child.pid) _liveChildPid = null;
      resolve(result);
    };

    child.on('error', (e) => {
      finish({ exitCode: null, output: `${out}\nerro ao executar: ${e.message}`, timedOut, indeterminate: true });
    });
    child.on('close', (code, signal) => {
      if (timedOut) {
        finish({ exitCode: 124, output: `${out}\n…(timeout de ${timeoutS}s excedido — processo e filhos do grupo encerrados)…`, timedOut: true, indeterminate: false });
        return;
      }
      if (code === null && signal) {
        // encerrado por sinal externo (não nosso timeout) — estado ambíguo, não é nem
        // "passou" nem uma falha comportamental confiável (Furo 4).
        finish({ exitCode: null, output: `${out}\n…(processo encerrado por sinal ${signal})…`, timedOut: false, indeterminate: true });
        return;
      }
      finish({ exitCode: typeof code === 'number' ? code : 1, output: out, timedOut: false, indeterminate: false });
    });
  });
}

function truncateExcerpt(s) {
  const text = String(s || '');
  if (text.length <= EXCERPT_MAX_CHARS) return text;
  return `…(truncado — ${text.length} chars)…\n${text.slice(-EXCERPT_MAX_CHARS)}`;
}

// normalizeExcerpt: torna o excerto REPRODUZÍVEL antes de hashear (Furo 11) — sem isso,
// excerpt_sha256 é decorativo (o texto embute o path aleatório do worktree, então o hash muda
// a cada execução e ninguém pode conferi-lo). Substitui os paths de worktree por um placeholder
// fixo, normaliza separadores e some com durações/timestamps variáveis.
function normalizeExcerpt(text, worktreeDirs = []) {
  let out = String(text || '');
  for (const dir of worktreeDirs) {
    if (!dir) continue;
    const escaped = dir.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    out = out.replace(new RegExp(escaped, 'g'), '<WORKTREE>');
  }
  out = out.replace(/\\/g, '/');
  out = out.replace(/\b\d+(?:\.\d+)?\s?(?:ms|s)\b/gi, '<DUR>');
  // Furo 11 (correção) — `node --test` (reporter TAP) emite `# duration_ms 258.955917` por caso:
  // o número NÃO fica colado a "ms"/"s" (fica colado ao NOME do campo, "duration_ms"), então a
  // regex acima nunca casava e o excerpt trazia um float de duração diferente a cada replay do
  // MESMO change — excerpt_sha256 instável (três replays, três hashes). Cobre qualquer chave que
  // termine literalmente em "_ms"/"_seconds" seguida de número (duration_ms, elapsed_ms,
  // wall_time_seconds, ...) — ancorado no SUFIXO exato da chave (não em substring solta tipo
  // "time"/"duration" no meio de uma palavra qualquer), para não corromper prosa legítima do
  // excerpt (uma AssertionError podendo conter as palavras "sometimes"/"lifetime" etc.).
  out = out.replace(/\b(\w*_(?:ms|seconds?))\b[:=]?\s*\d+(?:\.\d+)?/gi, '$1 <DUR>');
  out = out.replace(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z?/g, '<TS>');
  return out;
}

function matchesPattern(output, pattern) {
  if (!pattern) return true;
  try { return new RegExp(pattern).test(output); }
  catch { return output.includes(pattern); }
}

// FAILURE_LINE_PATTERNS: assinaturas de "este caso especificamente FALHOU", uma por formato de
// runner (Onda E, item 3b — auditoria: a versão anterior de outputMentionsCase casava testId em
// QUALQUER LUGAR da saída, e um reporter TAP como `node --test` imprime também os casos que
// PASSARAM — um excerto em que o caso declarado aparece com ✔ e quem falhou foi outro caso
// diferente passava como se fosse o defeito relatado). Cada padrão captura o NOME/identificador
// do caso na linha de falha; outputMentionsCase confere testId só contra essas capturas, nunca
// contra a saída inteira.
const FAILURE_LINE_PATTERNS = [
  // node --test / TAP genérico: "not ok 2 - <nome>"
  /^not ok\s+\d+\s*-\s*(.+)$/gm,
  // reporters "spec"-like com marcador de falha explícito: "✖ <nome>" / "✗ <nome>"
  /^\s*[✖✗]\s+(.+)$/gm,
  // pytest — resumo curto: "FAILED path/to/test.py::test_nome[params] - Motivo"
  /^FAILED\s+(\S+)/gm,
  // pytest — cabeçalho de falha detalhada: "____ test_nome ____"
  /^_{3,}\s*(.+?)\s*_{3,}\s*$/gm,
  // xUnit (.NET, `dotnet test`): "Failed TestNamespace.TestClass.TestMethod [12 ms]"
  /^\s*Failed\s+(\S+)/gm,
  // JUnit — maven surefire: "[ERROR] testFoo(com.example.FooTest)  Time elapsed: ..."
  /^\[ERROR\]\s+(\S+)/gm,
  // JUnit — gradle: "com.example.FooTest > testFoo FAILED"
  /^(\S+)\s*>\s*(\S+)\s+FAILED\s*$/gm,
  // Go: "--- FAIL: TestFoo (0.00s)"
  /^--- FAIL:\s*(\S+)/gm,
];

// outputMentionsCase: o CASO que falhou tem que ser o declarado (Furo 2, item C) — sem isso,
// uma falha histórica adjacente que por acaso casa com failure_pattern (ex.: "AssertionError"
// genérico) passaria como se fosse o defeito relatado. Casa testId contra as LINHAS DE FALHA
// reconhecidas (ver FAILURE_LINE_PATTERNS), não contra a saída inteira — sem isso, um caso que
// PASSOU (✔/ok) mas cujo nome contém testId como substring bastava para aprovar, mesmo quando o
// caso que de fato falhou é outro completamente diferente. Formato não reconhecido (nenhuma
// linha de falha identificada por assinatura conhecida) cai no fallback de substring na saída
// inteira — degradação deliberada para não cegar runners fora da lista coberta.
function outputMentionsCase(output, testId) {
  if (!testId) return true;
  const text = String(output || '');
  const failingNames = [];
  for (const re of FAILURE_LINE_PATTERNS) {
    re.lastIndex = 0;
    let m;
    while ((m = re.exec(text))) {
      for (let i = 1; i < m.length; i++) if (m[i]) failingNames.push(m[i]);
      if (!re.global) break;
    }
  }
  if (failingNames.length) return failingNames.some((n) => n.includes(testId));
  return text.includes(testId);
}

async function runSetup({ cwd, setupCommand, timeoutS }) {
  if (!setupCommand) return { ok: true };
  const res = await runTest({ cwd, command: setupCommand, timeoutS });
  if (res.indeterminate) return { ok: false, reason: 'setup_command com resultado indeterminado', run: res };
  if (res.exitCode !== 0) return { ok: false, reason: 'setup_command falhou', run: res };
  return { ok: true };
}

// replay: orquestra HEAD(saúde) → derive → worktree(s) → run(s) → veredito. SEMPRE limpa os
// worktrees que criou, mesmo em erro (try/finally) — nunca deixa lixo em `git worktree list`.
export async function replay({ root, evidence, timeoutS = DEFAULT_TIMEOUT_S }) {
  const testPath = evidence && evidence.test_path;
  const testId = (evidence && evidence.test_id) || null;
  const command = evidence && evidence.command;
  const fixFiles = (evidence && evidence.fix_files) || [];
  const failurePattern = evidence && evidence.failure_pattern;
  const setupCommand = (evidence && evidence.setup_command) || null;

  const replayHead = currentHeadSha(root);
  const finish = (obj) => ({ replay_head: replayHead, ...obj });

  if (!testPath || !command) {
    return finish({ verdict: 'not-possible', reason: 'test_path/command ausentes — grave com /forge:red record antes de replay' });
  }

  const descriptor = deriveBase({ root, testPath, fixFiles, testId });
  if (descriptor.strategy === 'not-possible') {
    return finish({ verdict: 'not-possible', reason: descriptor.reason, strategy: 'not-possible' });
  }

  let headDir = null;
  let baseDir = null;
  try {
    // ── passo 0 (Furo 5): HEAD primeiro. Distingue "ambiente do worktree incompleto" (não
    // culpa do Red-first, rebaixável) de "a correção declarada realmente não funciona"
    // (FAIL de verdade, ruleItem 'green').
    try {
      headDir = addWorktree(root, 'HEAD');
    } catch (e) {
      return finish({ verdict: 'not-possible', reason: `worktree HEAD falhou: ${(e.stderr || e.message || '').toString().trim()}` });
    }
    const headSetup = await runSetup({ cwd: headDir, setupCommand, timeoutS });
    if (!headSetup.ok) {
      return finish({ verdict: 'not-possible', reason: `ambiente do worktree incompleto — ${headSetup.reason} em HEAD (declare setup_command correto ou dispense com /forge:red waive)`, strategy: descriptor.strategy });
    }
    const headRun = await runTest({ cwd: headDir, command, timeoutS });
    if (headRun.indeterminate) {
      return finish({ verdict: 'not-possible', reason: 'ambiente do worktree incompleto — execução indeterminada em HEAD (sinal externo/erro de spawn)', strategy: descriptor.strategy });
    }
    if (headRun.exitCode !== 0) {
      const headClassification = classify(headRun.output);
      if (headClassification !== 'behavioral') {
        return finish({
          verdict: 'not-possible',
          reason: `ambiente do worktree incompleto — comando falha em HEAD com sinal de erro de build/ambiente ('${headClassification}'), não comportamental (dependências não versionadas? declare setup_command)`,
          strategy: descriptor.strategy,
          diagnostic: { classification: headClassification, excerpt: truncateExcerpt(normalizeExcerpt(headRun.output, [headDir])) },
        });
      }
      return finish({
        verdict: 'fail', ruleItem: 'green',
        reason: 'teste falha em HEAD — a correção declarada não torna o teste verde',
        strategy: descriptor.strategy,
        diagnostic: { classification: headClassification, excerpt: truncateExcerpt(normalizeExcerpt(headRun.output, [headDir])) },
      });
    }

    // ── árvore base derivada ────────────────────────────────────────────────────────────
    try {
      baseDir = addWorktree(root, descriptor.strategy === 'revert-synthesis' ? 'HEAD' : descriptor.ref);
    } catch (e) {
      return finish({ verdict: 'not-possible', reason: `worktree base falhou: ${(e.stderr || e.message || '').toString().trim()}`, strategy: descriptor.strategy });
    }
    let revertPatch = null;
    if (descriptor.strategy === 'revert-synthesis') {
      try { revertPatch = applyRevert(root, baseDir, descriptor.reverts); }
      catch (e) { return finish({ verdict: 'not-possible', reason: e.message, strategy: descriptor.strategy }); }
    }
    if (!existsSync(join(baseDir, testPath))) {
      return finish({ verdict: 'not-possible', reason: `test_path (${testPath}) ausente na árvore base derivada`, strategy: descriptor.strategy });
    }
    // Furo 2, defesa em profundidade: confere de novo no worktree materializado (não só no
    // blob via `git show`, cujo resultado deriveBase já validou) — protege contra fix_files
    // que colidam acidentalmente com test_path durante o revert.
    let baseTestContent = null;
    try { baseTestContent = readFileSync(join(baseDir, testPath), 'utf8'); } catch { baseTestContent = null; }
    if (!caseExistsInContent(baseTestContent, testId)) {
      return finish({ verdict: 'not-possible', reason: `test_id ('${testId}') declarado não aparece na árvore base derivada — a base está errada`, strategy: descriptor.strategy });
    }

    const baseSetup = await runSetup({ cwd: baseDir, setupCommand, timeoutS });
    if (!baseSetup.ok) {
      return finish({ verdict: 'not-possible', reason: `ambiente do worktree incompleto — ${baseSetup.reason} na base (declare setup_command correto ou dispense com /forge:red waive)`, strategy: descriptor.strategy });
    }

    const baseRun = await runTest({ cwd: baseDir, command, timeoutS });
    if (baseRun.indeterminate) {
      return finish({ verdict: 'not-possible', reason: 'ambiente do worktree incompleto — execução indeterminada na base (sinal externo/erro de spawn)', strategy: descriptor.strategy });
    }
    const classification = classify(baseRun.output);
    const excerpt = truncateExcerpt(normalizeExcerpt(baseRun.output, [baseDir, headDir]));
    const baseInfo = { strategy: descriptor.strategy, ref: descriptor.ref, exitCode: baseRun.exitCode, classification, excerpt };

    if (baseRun.exitCode === 0) {
      return finish({ verdict: 'fail', ruleItem: '2', reason: 'teste já passa na árvore base — não reproduz o defeito relatado (item 2)', strategy: descriptor.strategy, base: baseInfo, base_result: 'passed', diagnostic: { classification, excerpt } });
    }
    if (classification !== 'behavioral') {
      return finish({
        verdict: 'fail', ruleItem: '3',
        reason: `falha na base classificada como '${classification}' — erro de build/compilação, não comportamento (item 3)`,
        strategy: descriptor.strategy, base: baseInfo, base_result: 'failed', diagnostic: { classification, excerpt },
      });
    }
    if (!matchesPattern(baseRun.output, failurePattern)) {
      return finish({
        verdict: 'fail', ruleItem: '4',
        reason: `saída da falha diverge do failure_pattern declarado ('${failurePattern}') (item 4)`,
        strategy: descriptor.strategy, base: baseInfo, base_result: 'failed', diagnostic: { classification, excerpt },
      });
    }
    if (!outputMentionsCase(baseRun.output, testId)) {
      return finish({
        verdict: 'fail', ruleItem: 'test-id',
        reason: `saída da falha não menciona o caso declarado (test_id: '${testId}') — o caso que falhou pode não ser o declarado`,
        strategy: descriptor.strategy, base: baseInfo, base_result: 'failed', diagnostic: { classification, excerpt },
      });
    }

    return finish({
      verdict: 'observed',
      strategy: descriptor.strategy,
      base_strategy: descriptor.strategy,
      // 'ancestry': descriptor.ref é o commit pré-correção real. 'revert-synthesis': descriptor.ref
      // é o HEAD a partir do qual o revert foi sintetizado (não existe um commit literal
      // pré-correção — a árvore é sintética) — registrado assim mesmo por ser a referência mais
      // honesta disponível (rastreável, resolve no histórico real).
      base_commit: descriptor.ref,
      classification,
      excerpt,
      base_result: 'failed',
      revert_patch: revertPatch,
      head: { exitCode: 0 },
    });
  } finally {
    removeWorktree(root, baseDir);
    removeWorktree(root, headDir);
  }
}
