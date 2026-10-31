#!/usr/bin/env node
// tests/native-readers-gate.driver.mjs — driver do gate `native-readers-gate.sh` (TASK-06/
// TASK-07, STORY-04): exercita os três leitores compartilhados
// `template/.forge/scripts/lib/native-{transcript,registry,workspace}.mjs` pela API, sem passar
// pelo CLI (que ainda não existe nesta wave). Cada seção checa a existência do módulo antes de
// importar — módulo ausente reporta FAIL nomeando o que falta, nunca um stack trace de import
// (preâmbulo de tasks.md).
//
// Fixtures de socket real (node:net) e de pid vivo/morto rodam DENTRO deste driver (tests/), não
// no template — o template nunca abre conexão nem spawna processo de sessão.
import { execFileSync, spawnSync } from 'node:child_process';
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  realpathSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { createServer } from 'node:net';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const WS = dirname(dirname(fileURLToPath(import.meta.url)));
const LIB = join(WS, 'template', '.forge', 'scripts', 'lib');

let n = 0;
let failures = 0;
const cleanups = [];

function onCleanup(fn) {
  cleanups.push(fn);
}

function check(label, fn) {
  n += 1;
  try {
    const result = fn();
    if (result === false) throw new Error('condição falsa');
    console.log(`OK [${n}] ${label}`);
  } catch (err) {
    failures += 1;
    console.log(`FAIL [${n}] ${label}: ${err && err.message ? err.message : err}`);
  }
}

async function checkAsync(label, fn) {
  n += 1;
  try {
    const result = await fn();
    if (result === false) throw new Error('condição falsa');
    console.log(`OK [${n}] ${label}`);
  } catch (err) {
    failures += 1;
    console.log(`FAIL [${n}] ${label}: ${err && err.message ? err.message : err}`);
  }
}

function assertEqual(actual, expected, msg) {
  if (actual !== expected) {
    throw new Error(`${msg} — esperado ${JSON.stringify(expected)}, obtido ${JSON.stringify(actual)}`);
  }
}

function assertTrue(cond, msg) {
  if (!cond) throw new Error(msg);
}

function assertFalse(cond, msg) {
  if (cond) throw new Error(msg);
}

async function importModuleOrFail(label, relPath) {
  const full = join(LIB, relPath);
  if (!existsSync(full)) {
    n += 1;
    failures += 1;
    console.log(`FAIL [${n}] ${label}: módulo '${relPath}' ausente em ${LIB}`);
    return null;
  }
  try {
    return await import(pathToFileURL(full).href);
  } catch (err) {
    n += 1;
    failures += 1;
    console.log(`FAIL [${n}] ${label}: módulo '${relPath}' falhou ao importar (${err.message})`);
    return null;
  }
}

function git(cwd, args) {
  return execFileSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
}

function initRepo(dir) {
  mkdirSync(dir, { recursive: true });
  git(dir, ['init', '-q']);
  git(dir, ['config', 'user.email', 'fixture@test']);
  git(dir, ['config', 'user.name', 'fixture']);
  git(dir, ['config', 'commit.gpgsign', 'false']);
  git(dir, ['commit', '--allow-empty', '-qm', 'init']);
}

function listenUnixSocket(path) {
  return new Promise((resolvePromise, rejectPromise) => {
    const srv = createServer();
    srv.on('error', rejectPromise);
    srv.listen(path, () => resolvePromise(srv));
  });
}

async function main() {
  // ---------------------------------------------------------------------------------------
  // TRANSCRIPT (native-transcript.mjs) — design §2.6, REQ-02, REQ-08
  // ---------------------------------------------------------------------------------------
  const T = await importModuleOrFail('transcript', 'native-transcript.mjs');
  if (T) {
    const line = (overrides) => ({
      type: 'user',
      isMeta: true,
      promptSource: 'system',
      turnOrigin: 'peer',
      message: { role: 'user', content: '' },
      ...overrides,
    });
    const tag = (from, fromName, fromMode, body) =>
      `Another Claude session sent a message:\n<cross-session-message from="${from}" from-name="${fromName}" from-mode="${fromMode}">\n${body}\n</cross-session-message>\n\nThis came from another Claude session.`;

    check('transcript: recepção real (tag uds: + origin consistente) extraída', () => {
      const l = line({
        message: { role: 'user', content: tag('uds:/tmp/cc-socks/42.sock', 'PEER', 'default', 'ola') },
        origin: { kind: 'peer', from: 'uds:/tmp/cc-socks/42.sock', verifiedPeerPid: 42, name: 'PEER', fromMode: 'default', body: 'ola' },
      });
      const rec = T.extractReception(l);
      assertTrue(rec, 'extractReception deveria retornar a recepção');
      assertEqual(rec.from, 'uds:/tmp/cc-socks/42.sock', 'from');
      assertEqual(rec.fromName, 'PEER', 'fromName');
      assertEqual(rec.fromMode, 'default', 'fromMode');
      assertEqual(rec.body, 'ola', 'body');
      assertEqual(rec.verifiedPeerPid, 42, 'verifiedPeerPid');
      assertTrue(rec.consistent, 'deveria ser consistente (origin confere a tag)');
      assertTrue(T.isCandidateLine(l), 'deveria ser candidata');
    });

    check('transcript: controle embutido — runControlFixture() ok e fingerprints fixos da evidência b', () => {
      const res = T.runControlFixture();
      assertTrue(res.ok, `runControlFixture deveria passar: ${res.reason || ''}`);
      const expected = [
        'b843a088d77925ead49ceac0181d3108da745af004d6e8d123ed7bc4467b4654',
        '161d6df6c22d3f94b8c284be2ba6da60ed5cfbdac4d7636f2fef05d16eff4baf',
      ];
      assertEqual(JSON.stringify([...T.CONTROL_FIXTURE_FINGERPRINTS].sort()), JSON.stringify([...expected].sort()), 'fingerprints de controle');
    });

    check('transcript: candidata sem extração (origin peer/uds: sem a tag no texto) = instrumento quebrado', () => {
      const l = line({
        message: { role: 'user', content: 'nada de tag aqui, só prosa' },
        origin: { kind: 'peer', from: 'uds:/tmp/cc-socks/7.sock', verifiedPeerPid: 7 },
      });
      const parsed = T.parseTranscriptText(JSON.stringify(l));
      assertTrue(parsed.candidateCount >= 1, 'deveria contar como candidata');
      assertEqual(parsed.receptions.length, 0, 'não deveria extrair nenhuma recepção');
      assertTrue(parsed.brokenInstrument, 'deveria reportar instrumento quebrado');
    });

    check('transcript: linha api-request-shape sozinha com a string da tag = nada pendente', () => {
      const l = {
        type: 'api-request-shape',
        shape: { tools: [{ description: 'Use <cross-session-message from="uds:...") para enviar.' }] },
      };
      const parsed = T.parseTranscriptText(JSON.stringify(l));
      assertEqual(parsed.candidateCount, 0, 'não deveria contar candidata');
      assertEqual(parsed.receptions.length, 0, 'não deveria extrair recepção');
      assertFalse(parsed.brokenInstrument, 'não deveria ser instrumento quebrado (nada pendente)');
    });

    const negativeControls = {
      "origin.kind 'human'": line({ message: { role: 'user', content: 'turno humano comum' }, origin: { kind: 'human' } }),
      "origin.kind 'task-notification'": line({ message: { role: 'user', content: 'notificação de tarefa' }, origin: { kind: 'task-notification' } }),
      "origin.kind 'coordinator'": line({ message: { role: 'user', content: 'mensagem do coordinator' }, origin: { kind: 'coordinator' } }),
      "turnOrigin 'scheduled' (mesmo citando a tag e os marcadores)": line({
        turnOrigin: 'scheduled',
        message: { role: 'user', content: tag('uds:/tmp/cc-socks/9.sock', 'X', 'default', 'corpo') },
      }),
      "<agent-message> com origin.kind 'peer' e from de agentId": line({
        message: { role: 'user', content: '<agent-message from="a1111111111111111">oi main</agent-message>' },
        origin: { kind: 'peer', from: 'a1111111111111111' },
      }),
      'turno humano que só cita a tag (sem isMeta/promptSource/origin)': {
        type: 'user',
        message: { role: 'user', content: 'você viu que a tag é <cross-session-message from="uds:/tmp/x.sock" ...>? só comentando' },
      },
    };
    for (const [desc, obj] of Object.entries(negativeControls)) {
      check(`transcript: controle negativo — ${desc} = nada pendente`, () => {
        const parsed = T.parseTranscriptText(JSON.stringify(obj));
        assertEqual(parsed.candidateCount, 0, 'não deveria contar como candidata');
        assertFalse(parsed.brokenInstrument, 'não deveria ser instrumento quebrado');
      });
    }

    check('transcript: recepção sem origin.body é extraída com o fingerprint da tag', () => {
      const l = line({
        message: { role: 'user', content: tag('uds:/tmp/cc-socks/5.sock', 'SEMBODY', 'default', 'corpo da tag') },
        origin: { kind: 'peer', from: 'uds:/tmp/cc-socks/5.sock', name: 'SEMBODY', fromMode: 'default' },
      });
      const rec = T.extractReception(l);
      assertTrue(rec, 'deveria extrair mesmo sem origin.body');
      assertTrue(rec.consistent, 'ausência de origin.body não é divergência');
      assertEqual(rec.fingerprint, T.fingerprint('uds:/tmp/cc-socks/5.sock', 'SEMBODY', 'corpo da tag'), 'fingerprint pelos valores da tag');
    });

    check('transcript: formato derivado — tag em bloco de content array, sem origin, é extraída', () => {
      const l = {
        type: 'user',
        message: {
          role: 'user',
          content: [{ type: 'text', text: tag('uds:/tmp/cc-socks/6.sock', 'ARRAYFORM', 'default', 'corpo em array') }],
        },
      };
      const rec = T.extractReception(l);
      assertTrue(rec, 'deveria extrair do bloco de texto do array');
      assertEqual(rec.body, 'corpo em array', 'corpo extraído do bloco de array');
      const parsed = T.parseTranscriptText(JSON.stringify(l));
      assertFalse(parsed.brokenInstrument, 'transcript com extração bem-sucedida não é instrumento quebrado');
    });

    check('transcript: divergência entre tag e origin = instrumento quebrado', () => {
      const l = line({
        message: { role: 'user', content: tag('uds:/tmp/cc-socks/8.sock', 'REAL', 'default', 'corpo real') },
        origin: { kind: 'peer', from: 'uds:/tmp/cc-socks/8.sock', name: 'NOME-DIVERGENTE', fromMode: 'default', body: 'corpo real' },
      });
      const rec = T.extractReception(l);
      assertTrue(rec, 'deveria extrair (a extração não depende de consistência)');
      assertFalse(rec.consistent, 'deveria marcar como inconsistente (nome diverge)');
      const parsed = T.parseTranscriptText(JSON.stringify(l));
      assertTrue(parsed.brokenInstrument, 'divergência tag×origin deveria ser instrumento quebrado');
    });

    const projectsDir = mkdtempSync('/tmp/forge-native-readers-projects-');
    onCleanup(() => rmSync(projectsDir, { recursive: true, force: true }));
    check('transcript: locateTranscript — zero resultado reprova nomeando a sessão', () => {
      const res = T.locateTranscript({ sessionId: 'nao-existe', projectsDir });
      assertFalse(res.ok, 'deveria reprovar');
      assertTrue(/nao-existe/.test(res.reason), 'deveria nomear a sessão');
    });
    mkdirSync(join(projectsDir, 'slug-a'), { recursive: true });
    writeFileSync(join(projectsDir, 'slug-a', 'sess-1.jsonl'), tagLineText());
    check('transcript: locateTranscript — resultado único resolve o caminho', () => {
      const res = T.locateTranscript({ sessionId: 'sess-1', projectsDir });
      assertTrue(res.ok, `deveria resolver: ${res.reason || ''}`);
      assertEqual(res.path, join(projectsDir, 'slug-a', 'sess-1.jsonl'), 'caminho do transcript');
    });
    mkdirSync(join(projectsDir, 'slug-b'), { recursive: true });
    writeFileSync(join(projectsDir, 'slug-b', 'sess-1.jsonl'), '{}');
    check('transcript: locateTranscript — mais de um resultado reprova', () => {
      const res = T.locateTranscript({ sessionId: 'sess-1', projectsDir });
      assertFalse(res.ok, 'deveria reprovar com dois arquivos de sessão homônima em slugs diferentes');
    });

    check('transcript: readTranscript — fim a fim (controle + locate + parse) sobre transcript real', () => {
      const dir = mkdtempSync('/tmp/forge-native-readers-rt-');
      onCleanup(() => rmSync(dir, { recursive: true, force: true }));
      mkdirSync(join(dir, 'slug-c'), { recursive: true });
      writeFileSync(join(dir, 'slug-c', 'sess-2.jsonl'), tagLineText());
      const res = T.readTranscript({ sessionId: 'sess-2', projectsDir: dir });
      assertTrue(res.ok, `deveria ler com sucesso: ${res.reason || ''}`);
      assertEqual(res.receptions.length, 1, 'deveria extrair exatamente uma recepção do transcript real');
    });

    function tagLineText() {
      const l = line({
        message: { role: 'user', content: tag('uds:/tmp/cc-socks/99.sock', 'END2END', 'default', 'corpo fim a fim') },
        origin: { kind: 'peer', from: 'uds:/tmp/cc-socks/99.sock', verifiedPeerPid: 99, name: 'END2END', fromMode: 'default', body: 'corpo fim a fim' },
      });
      return JSON.stringify(l) + '\n';
    }
  }

  // ---------------------------------------------------------------------------------------
  // REGISTRY (native-registry.mjs) — design §2.5, evidência c, REQ-02, REQ-07
  // ---------------------------------------------------------------------------------------
  const R = await importModuleOrFail('registry', 'native-registry.mjs');
  if (R) {
    const sessionsDir = mkdtempSync('/tmp/forge-native-readers-sessions-');
    onCleanup(() => rmSync(sessionsDir, { recursive: true, force: true }));

    const alivePid = process.pid;
    const deadProc = spawnSync(process.execPath, ['-e', 'process.exit(0)']);
    const deadPid = deadProc.pid;

    const aliveSocketPath = join(sessionsDir, 'alive.sock');
    const srv = await listenUnixSocket(aliveSocketPath);
    onCleanup(() => srv.close());

    function writeEntry(file, obj) {
      writeFileSync(join(sessionsDir, file), JSON.stringify(obj));
    }

    writeEntry(`${alivePid}.json`, {
      pid: alivePid,
      sessionId: 'session-alive',
      name: 'ALIVE-ONE',
      cwd: '/fixture/alive',
      messagingSocketPath: aliveSocketPath,
    });

    check('registry: vivo — pid vivo + socket existe → isAlive true', () => {
      const { entries } = R.readRegistryFiles({ sessionsDir });
      const e = entries.find((x) => x.pid === alivePid);
      assertTrue(e, 'entrada deveria existir');
      assertTrue(R.isAlive(e), 'deveria estar viva');
    });

    writeEntry('nosocket.json', {
      pid: alivePid,
      sessionId: 'session-nosocket',
      name: 'NO-SOCKET',
      cwd: '/fixture/nosocket',
      messagingSocketPath: join(sessionsDir, 'nao-existe.sock'),
    });
    check('registry: morto — pid vivo mas socket não existe → isAlive false', () => {
      const { entries } = R.readRegistryFiles({ sessionsDir });
      const e = entries.find((x) => x.sessionId === 'session-nosocket');
      assertTrue(e, 'entrada deveria existir');
      assertFalse(R.isAlive(e), 'não deveria estar viva (socket ausente)');
    });

    const regularFileSocket = join(sessionsDir, 'regular-file.sock');
    writeFileSync(regularFileSocket, 'não é um socket');
    writeEntry('notasocket.json', {
      pid: alivePid,
      sessionId: 'session-notasocket',
      name: 'NOT-A-SOCKET',
      cwd: '/fixture/notasocket',
      messagingSocketPath: regularFileSocket,
    });
    check('registry: morto — arquivo regular no lugar do socket → isAlive false', () => {
      const { entries } = R.readRegistryFiles({ sessionsDir });
      const e = entries.find((x) => x.sessionId === 'session-notasocket');
      assertFalse(R.isAlive(e), 'não deveria estar viva (não é socket)');
    });

    writeEntry(`${deadPid}.json`, {
      pid: deadPid,
      sessionId: 'session-dead',
      name: 'DEAD-ONE',
      cwd: '/fixture/dead',
      messagingSocketPath: aliveSocketPath,
    });
    check('registry: morto — pid não vivo → isAlive false mesmo com socket existente', () => {
      const { entries } = R.readRegistryFiles({ sessionsDir });
      const e = entries.find((x) => x.sessionId === 'session-dead');
      assertFalse(R.isAlive(e), 'não deveria estar viva (processo encerrado)');
    });

    // "homônimo": segunda sessão viva com o MESMO nome de ALIVE-ONE, pid e socket próprios.
    const homonymSocketPath = join(sessionsDir, 'homonym.sock');
    const srv2 = await listenUnixSocket(homonymSocketPath);
    onCleanup(() => srv2.close());
    writeEntry('homonym.json', {
      pid: alivePid,
      sessionId: 'session-homonym',
      name: 'ALIVE-ONE',
      cwd: '/fixture/homonym',
      messagingSocketPath: homonymSocketPath,
    });
    check('registry: homônimo — duas sessões vivas com o mesmo nome → resolveByName ambíguo', () => {
      const res = R.resolveByName({ sessionsDir, name: 'ALIVE-ONE' });
      assertFalse(res.ok, 'deveria recusar');
      assertTrue(res.ambiguous, 'deveria marcar como ambíguo');
    });

    // Resolução por nome único — usa um dir isolado só com a entrada viva e nenhum erro.
    const uniqueDir = mkdtempSync('/tmp/forge-native-readers-unique-');
    onCleanup(() => rmSync(uniqueDir, { recursive: true, force: true }));
    const uniqueSocketPath = join(uniqueDir, 'unique.sock');
    const srv3 = await listenUnixSocket(uniqueSocketPath);
    onCleanup(() => srv3.close());
    writeFileSync(
      join(uniqueDir, `${alivePid}.json`),
      JSON.stringify({ pid: alivePid, sessionId: 'session-unique', name: 'UNIQUE-NAME', cwd: '/fixture/unique', messagingSocketPath: uniqueSocketPath }),
    );
    check('registry: resolução por nome — nome vivo único resolve a entrada', () => {
      const res = R.resolveByName({ sessionsDir: uniqueDir, name: 'UNIQUE-NAME' });
      assertTrue(res.ok, `deveria resolver: ${res.reason || ''}`);
      assertEqual(res.entry.cwd, '/fixture/unique', 'cwd da entrada resolvida');
    });
    check('registry: resolução por nome — nome inexistente entre registros válidos recusa (não fail-closed)', () => {
      const res = R.resolveByName({ sessionsDir: uniqueDir, name: 'NUNCA-EXISTIU' });
      assertFalse(res.ok, 'deveria recusar');
      assertFalse(res.ambiguous, 'não deveria ser ambíguo');
    });

    check('registry: resolução por socket — /tmp e /private/tmp convergem (realpath do diretório pai)', () => {
      const viaRealTmp = uniqueSocketPath.replace(/^\/tmp\//, '/private/tmp/');
      const res = R.resolveBySocket({ sessionsDir: uniqueDir, sockFile: viaRealTmp });
      assertTrue(res.ok, `deveria resolver via /private/tmp: ${res.reason || ''}`);
      assertEqual(res.entry.sessionId, 'session-unique', 'sessionId resolvido pelo socket normalizado');
    });

    check('registry: resolução por sessionId — acha o registro da própria sessão', () => {
      const res = R.resolveBySessionId({ sessionsDir: uniqueDir, sessionId: 'session-unique' });
      assertTrue(res.ok, `deveria resolver: ${res.reason || ''}`);
      assertEqual(res.entry.cwd, '/fixture/unique', 'cwd do registro da própria sessão');
    });

    const brokenDir = mkdtempSync('/tmp/forge-native-readers-broken-');
    onCleanup(() => rmSync(brokenDir, { recursive: true, force: true }));
    writeFileSync(join(brokenDir, 'broken.json'), '{ json malformado');
    check('registry: ilegível — JSON malformado faz resolveByName falhar nomeando o arquivo', () => {
      const res = R.resolveByName({ sessionsDir: brokenDir, name: 'QUALQUER' });
      assertFalse(res.ok, 'deveria recusar (fail-closed)');
      assertTrue(/broken\.json/.test(res.reason), 'deveria nomear o arquivo ilegível');
    });

    const missingFieldDir = mkdtempSync('/tmp/forge-native-readers-missing-');
    onCleanup(() => rmSync(missingFieldDir, { recursive: true, force: true }));
    writeFileSync(join(missingFieldDir, `${alivePid}.json`), JSON.stringify({ pid: alivePid, name: 'SEM-CAMPO', cwd: '/fixture/x' }));
    check('registry: sem campo (messagingSocketPath ausente) → resolução falha fail-closed nomeando o arquivo', () => {
      const res = R.resolveByName({ sessionsDir: missingFieldDir, name: 'SEM-CAMPO' });
      assertFalse(res.ok, 'deveria recusar (fail-closed)');
      assertTrue(res.reason.includes(`${alivePid}.json`), 'deveria nomear o arquivo incompleto');
    });
  }

  // ---------------------------------------------------------------------------------------
  // WORKSPACE (native-workspace.mjs) — design §2.5 "Raiz de workspace", REQ-02, REQ-07
  // ---------------------------------------------------------------------------------------
  const W = await importModuleOrFail('workspace', 'native-workspace.mjs');
  if (W) {
    const base = mkdtempSync('/tmp/forge-native-readers-ws-');
    onCleanup(() => rmSync(base, { recursive: true, force: true }));
    const fixtureHome = join(base, 'home');
    mkdirSync(fixtureHome, { recursive: true });

    // --- raiz: aninhado ---
    const outer = join(base, 'outer');
    initRepo(outer);
    const inner = join(outer, 'vendor', 'inner');
    initRepo(inner);
    check('workspace: raiz — repositório aninhado: repositório principal do caminho interno é o INNER', () => {
      const root = W.mainRepoRoot(inner);
      assertEqual(realpathSync(root), realpathSync(inner), 'mainRepoRoot deveria ser o repo inner');
    });
    check('workspace: raiz — repositório aninhado: workspace sobe até o OUTER (mais externo)', () => {
      const ws = W.workspaceRoot(inner, { home: fixtureHome });
      assertEqual(realpathSync(ws), realpathSync(outer), 'workspaceRoot deveria subir até o outer');
    });

    // --- raiz: worktree fora da árvore ---
    const wtMain = join(base, 'wt-main');
    initRepo(wtMain);
    const wtOutside = join(base, 'wt-outside');
    git(wtMain, ['worktree', 'add', '-q', '-b', 'wt-branch', wtOutside]);
    check('workspace: raiz — worktree fora da árvore resolve para o repositório principal', () => {
      const root = W.mainRepoRoot(wtOutside);
      assertEqual(realpathSync(root), realpathSync(wtMain), 'mainRepoRoot da worktree deveria ser o repo principal');
    });

    // --- raiz: home como repositório (dotfiles) ---
    initRepo(fixtureHome);
    const underHome = join(fixtureHome, 'projects', 'my-app');
    initRepo(underHome);
    check('workspace: raiz — home como repositório: projeto aninhado sob home NÃO colapsa para home', () => {
      const ws = W.workspaceRoot(underHome, { home: fixtureHome });
      assertEqual(realpathSync(ws), realpathSync(underHome), 'workspace deveria ficar no próprio projeto, nunca subir até HOME');
    });
    const homeOnlyBase = join(base, 'home-only-base');
    const homeOnly = join(homeOnlyBase, 'home2');
    mkdirSync(homeOnly, { recursive: true });
    initRepo(homeOnly);
    const cwdInsideHomeRepoNoNested = join(homeOnly, 'subdir-sem-git');
    mkdirSync(cwdInsideHomeRepoNoNested, { recursive: true });
    check('workspace: raiz — home sem projeto aninhado: workspace nunca é o próprio HOME', () => {
      const ws = W.workspaceRoot(cwdInsideHomeRepoNoNested, { home: homeOnly });
      assertFalse(realpathSync(ws) === realpathSync(homeOnly), 'workspace não deveria ser o HOME, mesmo sendo repositório git');
    });

    // --- raiz: fora de repositório ---
    const noRepo = join(base, 'no-repo-dir');
    mkdirSync(noRepo, { recursive: true });
    check('workspace: raiz — fora de repositório: workspace é o próprio cwd', () => {
      const ws = W.workspaceRoot(noRepo, { home: fixtureHome });
      assertEqual(realpathSync(ws), realpathSync(noRepo), 'workspace deveria ser o próprio cwd fora de repositório');
    });

    // --- identidade: insteadOf ---
    const cloneA = join(base, 'clone-a');
    initRepo(cloneA);
    git(cloneA, ['remote', 'add', 'origin', 'git@work-alias:owner/repo.git']);
    git(cloneA, ['config', 'url.git@github.com:.insteadOf', 'git@work-alias:']);
    const cloneB = join(base, 'clone-b');
    initRepo(cloneB);
    git(cloneB, ['remote', 'add', 'origin', 'git@github.com:owner/repo.git']);
    check('workspace: identidade — dois clones (um com insteadOf) dão a MESMA identidade', () => {
      W.clearWorkspaceCaches();
      const idA = W.workspaceIdentity(cloneA);
      const idB = W.workspaceIdentity(cloneB);
      assertEqual(idA, idB, 'identidades deveriam convergir');
      assertEqual(idA, 'github.com/owner/repo', 'identidade esperada');
    });

    // --- identidade: forma scp, credencial, porta ---
    check('workspace: identidade — forma scp com alias de ssh config vira host/owner/repo', () => {
      assertEqual(W.normalizeRemote('git@my-ssh-alias:owner/repo.git'), 'my-ssh-alias/owner/repo', 'scp com alias');
    });
    check('workspace: identidade — credencial, porta e host em minúsculas são removidos/normalizados', () => {
      assertEqual(
        W.normalizeRemote('https://user:pass@Example.COM:8443/Owner/Repo.git'),
        'example.com/Owner/Repo',
        'credencial/porta/host',
      );
    });

    // --- identidade: sem remote ---
    const noRemote = join(base, 'no-remote');
    initRepo(noRemote);
    check('workspace: identidade — sem remote → realpath absoluto da raiz', () => {
      W.clearWorkspaceCaches();
      const id = W.workspaceIdentity(noRemote);
      assertEqual(id, realpathSync(noRemote), 'identidade sem remote deveria ser o realpath da raiz');
    });
  }

  for (const fn of cleanups.reverse()) {
    try {
      fn();
    } catch {
      /* best-effort */
    }
  }

  if (failures > 0) {
    console.log(`\n${failures} de ${n} checagem(ns) reprovada(s).`);
    process.exit(1);
  }
  console.log(`\nPASS native-readers-gate.driver — ${n} checagens.`);
}

main().catch((err) => {
  console.log(`FAIL [${n + 1}] driver: exceção não tratada: ${err && err.stack ? err.stack : err}`);
  process.exit(1);
});
