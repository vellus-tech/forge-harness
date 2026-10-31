#!/usr/bin/env node
// tests/native-send-guard-gate.driver.mjs — driver do gate `native-send-guard-gate.sh`.
//
// Parte 1 (TASK-14/TASK-15, STORY-08, design §2.5 etapas 1 a 4, REQ-04, REQ-05): classificação
// de destino (`classifyRecipient`) e varredura de segredo do gancho de saída
// `guard-cross-session-send.sh`, exercitados pela API de `native-send-guard.mjs` e, para os
// casos que precisam do processo real (stdin, script .sh, cópia da árvore), via `spawnSync`.
//
// Parte 2 (TASK-16/TASK-17, STORY-09, etapas 5 e 6, REQ-06, REQ-07) é anexada a este mesmo
// arquivo quando a TASK-16 entra — os casos da parte 1 continuam verdes.
//
// Para destino de sessão com corpo limpo, as asserções desta parte 1 observam a CLASSIFICAÇÃO
// (`classifyRecipient`) em vez do exit code final de `evaluateSendGuard`/`runGuard`: o exit final
// desses casos depende das etapas 5 e 6, que só existem a partir da TASK-17 (preâmbulo de
// tasks.md, nota da TASK-14).
//
// Módulo ausente -> FAIL nomeando o que falta, nunca stack trace (preâmbulo de tasks.md).
import { execFileSync, spawn, spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { writeConfig } from '../template/.forge/scripts/lib/liaison-config.mjs';

const WS = dirname(dirname(fileURLToPath(import.meta.url)));
const LIB = join(WS, 'template', '.forge', 'scripts', 'lib');
const HOOK_SH = join(WS, 'template', '.forge', 'hooks', 'pre-tool-use', 'guard-cross-session-send.sh');

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

function listenUnixSocket(path) {
  return new Promise((resolvePromise, rejectPromise) => {
    const srv = createServer();
    srv.on('error', rejectPromise);
    srv.listen(path, () => resolvePromise(srv));
  });
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

// mkConsumerRepo(dir) — réplica mínima de um consumidor do harness (mesmo padrão de outros
// gates: copia scripts/templates/hooks/schemas/rules/commands/ledger + forge.yaml de
// `template/.forge/` para `<dir>/.forge/`). Usada pelo teste de leitor único (TASK-14, item 4):
// a cópia precisa ter a MESMA estrutura relativa (`hooks/pre-tool-use/../../scripts/lib`) para
// que o gancho copiado localize a `lib/` copiada, não a original.
function mkConsumerRepo(dir) {
  mkdirSync(join(dir, '.forge'), { recursive: true });
  for (const d of ['scripts', 'templates', 'hooks', 'schemas', 'rules', 'commands', 'ledger']) {
    const src = join(WS, 'template', '.forge', d);
    if (existsSync(src)) cpSync(src, join(dir, '.forge', d), { recursive: true });
  }
  cpSync(join(WS, 'template', '.forge', 'forge.yaml'), join(dir, '.forge', 'forge.yaml'));
  initRepo(dir);
}

async function main() {
  const T = mkdtempSync(join(tmpdir(), 'forge-send-guard-'));
  onCleanup(() => rmSync(T, { recursive: true, force: true }));

  const SESS_DIR = join(T, 'sessions');
  mkdirSync(SESS_DIR, { recursive: true });
  const PROJECTS_DIR = join(T, 'projects');
  mkdirSync(PROJECTS_DIR, { recursive: true });

  // --- socket real vivo durante todo o driver (node:net) --------------------------------------
  const sockPath = join(T, 'unique.sock');
  const srv = await listenUnixSocket(sockPath);
  onCleanup(() => srv.close());

  const MYPID = process.pid; // vivo durante toda a execução do driver
  // Segundo pid vivo real, para o caso de nome AMBÍGUO (duas sessões vivas com o mesmo nome) —
  // precisa ser um processo que este driver realmente possui, não um pid arbitrário (process.kill
  // com um pid de terceiro lançaria EPERM, que isAlive() trata como morto).
  const helperProc = spawn(process.execPath, ['-e', 'setInterval(() => {}, 1000)'], { stdio: 'ignore' });
  onCleanup(() => {
    try {
      helperProc.kill();
    } catch {
      /* best-effort */
    }
  });
  const helperPid = helperProc.pid;

  function writeRegistryEntry(filename, { name, pid, cwd = T, sessionId, sock = sockPath }) {
    writeFileSync(join(SESS_DIR, filename), JSON.stringify({ pid, name, cwd, sessionId, messagingSocketPath: sock }));
  }

  writeRegistryEntry('session-unique.json', { name: 'SESSION-UNIQUE', pid: MYPID, cwd: join(T, 'ws-origin'), sessionId: 'own-session-1' });
  writeRegistryEntry('session-ambig-a.json', { name: 'SESSION-AMBIG', pid: MYPID, sessionId: 'amb-a' });
  writeRegistryEntry('session-ambig-b.json', { name: 'SESSION-AMBIG', pid: helperPid, sessionId: 'amb-b' });

  function agentToolUseLine(name) {
    return JSON.stringify({
      type: 'assistant',
      message: { role: 'assistant', content: [{ type: 'tool_use', id: 'toolu_01', name: 'Agent', input: { name, description: 'x', prompt: 'y' } }] },
    });
  }
  function writeTranscript(sessionId, lines) {
    const dir = join(PROJECTS_DIR, 'proj');
    mkdirSync(dir, { recursive: true });
    const path = join(dir, `${sessionId}.jsonl`);
    writeFileSync(path, `${lines.join('\n')}\n`);
    return path;
  }
  const transcriptNoAgent = writeTranscript('sess-noagent', ['not-json-garbage', JSON.stringify({ type: 'user', message: { role: 'user', content: 'hi' } })]);
  const transcriptWithGhost = writeTranscript('sess-ghost', [agentToolUseLine('GHOST-AGENT')]);
  const transcriptWithSameNameAgent = writeTranscript('sess-samename', [agentToolUseLine('SESSION-UNIQUE')]);

  function basePayload(overrides) {
    return {
      session_id: 'sess-x',
      transcript_path: null,
      cwd: join(T, 'ws-origin'),
      tool_name: 'SendMessage',
      tool_input: {},
      ...overrides,
    };
  }

  const opts = { sessionsDir: SESS_DIR, projectsDir: PROJECTS_DIR };

  // ---------------------------------------------------------------------------------------
  // REQ-05 — classificação de destino (evidência a, emenda de 2026-10-30)
  // ---------------------------------------------------------------------------------------
  const G = await importModuleOrFail('native-send-guard', 'native-send-guard.mjs');
  if (G) {
    check('REQ-05 caso 1 — nome sem registro e sem Agent nomeado no transcript -> bloqueado (emenda)', () => {
      const payload = basePayload({
        transcript_path: transcriptNoAgent,
        tool_input: { to: 'probe-helper', recipient_kind: 'name', message: 'measurement case 1', content: 'measurement case 1', type: 'message', recipient: 'probe-helper' },
      });
      const c = G.classifyRecipient(payload, opts);
      assertEqual(c.kind, 'blocked', `classificação deveria ser 'blocked' (obtido '${c.kind}': ${c.reason})`);
      assertEqual(G.evaluateSendGuard(payload, opts).exitCode, 2, 'exit code deveria ser 2');
    });

    check('REQ-05 caso 1b — recipient_kind agent com agentId -> interno, exit 0', () => {
      const payload = basePayload({ tool_input: { to: 'a1234567890abcdef', recipient_kind: 'agent', message: 'measurement case 1b', content: 'measurement case 1b' } });
      const c = G.classifyRecipient(payload, opts);
      assertEqual(c.kind, 'internal', `obtido '${c.kind}'`);
      assertEqual(G.evaluateSendGuard(payload, opts).exitCode, 0, 'exit code deveria ser 0');
    });

    check('REQ-05 caso 2 — recipient_kind main com to=main -> interno, exit 0', () => {
      const payload = basePayload({
        agent_id: 'a1234567890abcdef',
        agent_type: 'general-purpose',
        tool_input: { to: 'main', recipient_kind: 'main', message: 'measurement case 2', content: 'measurement case 2' },
      });
      const c = G.classifyRecipient(payload, opts);
      assertEqual(c.kind, 'internal', `obtido '${c.kind}'`);
      assertEqual(G.evaluateSendGuard(payload, opts).exitCode, 0, 'exit code deveria ser 0');
    });

    check('REQ-05 caso 3 — sessão local por nome único -> sessão (classificação independente das etapas 5/6)', () => {
      const payload = basePayload({
        tool_input: { to: 'SESSION-UNIQUE', recipient_kind: 'name', message: 'ephemeral: presence\nmeasurement case 3', content: 'ephemeral: presence\nmeasurement case 3' },
      });
      const c = G.classifyRecipient(payload, opts);
      assertEqual(c.kind, 'session', `obtido '${c.kind}': ${c.reason || ''}`);
    });

    check('REQ-05 caso 3b — nome com sufixo [ref] -> bloqueado (ref não mapeável ao registro local)', () => {
      const payload = basePayload({ tool_input: { to: 'SESSION-UNIQUE [a1b2c3]', recipient_kind: 'name', message: 'measurement case 3b', content: 'measurement case 3b' } });
      const r = G.evaluateSendGuard(payload, opts);
      assertEqual(r.exitCode, 2, `exit code deveria ser 2 (obtido ${r.exitCode}: ${r.message})`);
      assertTrue(/uds:|nome puro/.test(r.message || ''), 'mensagem deveria orientar o nome puro ou o endereço uds:');
    });

    check('REQ-05 caso 4 — recipient_kind session (uds:<socket>) -> sessão (classificação)', () => {
      const payload = basePayload({ tool_input: { to: `uds:${sockPath}`, recipient_kind: 'session', message: 'measurement case 4', content: 'measurement case 4' } });
      const c = G.classifyRecipient(payload, opts);
      assertEqual(c.kind, 'session', `obtido '${c.kind}'`);
    });

    check('REQ-05 caso 5 — só aviso de ociosidade (notify_when_idle, sem corpo) para destino de sessão -> classificação sessão', () => {
      const payload = basePayload({ tool_input: { to: 'SESSION-UNIQUE', recipient_kind: 'name', message: '', notify_when_idle: true, content: '' } });
      const c = G.classifyRecipient(payload, opts);
      assertEqual(c.kind, 'session', `obtido '${c.kind}'`);
    });

    check('REQ-05 — nome com mais de um registro vivo -> bloqueado pedindo uds:', () => {
      const payload = basePayload({ tool_input: { to: 'SESSION-AMBIG', recipient_kind: 'name', message: 'x', content: 'x' } });
      const r = G.evaluateSendGuard(payload, opts);
      assertEqual(r.exitCode, 2, `exit code deveria ser 2 (obtido ${r.exitCode})`);
      assertTrue(/uds:/.test(r.message || ''), 'mensagem deveria orientar o endereço uds:');
    });

    check('REQ-05 — nome sem registro e sem Agent nomeado no transcript -> bloqueado orientando agentId', () => {
      const payload = basePayload({ transcript_path: transcriptNoAgent, tool_input: { to: 'GHOST-AGENT', recipient_kind: 'name', message: 'x', content: 'x' } });
      const r = G.evaluateSendGuard(payload, opts);
      assertEqual(r.exitCode, 2, `obtido ${r.exitCode}`);
      assertTrue(/agentId/.test(r.message || ''), 'mensagem deveria orientar o agentId');
    });

    check('REQ-05 — nome sem registro, com Agent nomeado no transcript -> interno, exit 0', () => {
      const payload = basePayload({ transcript_path: transcriptWithGhost, tool_input: { to: 'GHOST-AGENT', recipient_kind: 'name', message: 'x', content: 'x' } });
      const c = G.classifyRecipient(payload, opts);
      assertEqual(c.kind, 'internal', `obtido '${c.kind}'`);
      assertEqual(G.evaluateSendGuard(payload, opts).exitCode, 0, 'exit code deveria ser 0');
    });

    check('REQ-05 — nome igual entre sessão viva e Agent nomeado no transcript -> tratado como sessão (registro vence)', () => {
      const payload = basePayload({ transcript_path: transcriptWithSameNameAgent, tool_input: { to: 'SESSION-UNIQUE', recipient_kind: 'name', message: 'x', content: 'x' } });
      const c = G.classifyRecipient(payload, opts);
      assertEqual(c.kind, 'session', `obtido '${c.kind}'`);
    });

    for (const bad of ['*', 'a,b', 'a\nb']) {
      check(`REQ-05 — 'to' com caractere não suportado (${JSON.stringify(bad)}) e recipient_kind ausente -> bloqueado`, () => {
        const payload = basePayload({ tool_input: { to: bad, message: 'x', content: 'x' } });
        assertEqual(G.evaluateSendGuard(payload, opts).exitCode, 2, 'exit code deveria ser 2');
      });
    }

    check('REQ-05 — recipient_kind desconhecido -> bloqueado (fail-closed)', () => {
      const payload = basePayload({ tool_input: { to: 'whatever', recipient_kind: 'carrier-pigeon', message: 'x', content: 'x' } });
      assertEqual(G.evaluateSendGuard(payload, opts).exitCode, 2, 'exit code deveria ser 2');
    });

    check('REQ-05 — recipient_kind ausente -> bloqueado (fail-closed)', () => {
      const payload = basePayload({ tool_input: { to: 'whatever', message: 'x', content: 'x' } });
      assertEqual(G.evaluateSendGuard(payload, opts).exitCode, 2, 'exit code deveria ser 2');
    });

    check('defesa — tool_name diferente de SendMessage -> exit 0 (matcher já filtra)', () => {
      const payload = basePayload({ tool_name: 'Read', tool_input: { to: 'SESSION-UNIQUE', recipient_kind: 'name', message: 'qualquer coisa' } });
      assertEqual(G.evaluateSendGuard(payload, opts).exitCode, 0, 'exit code deveria ser 0');
    });

    // -------------------------------------------------------------------------------------
    // REQ-04 — varredura de segredo (step 4, independente das etapas 5/6: roda antes delas)
    // -------------------------------------------------------------------------------------
    const SECRET_SAMPLES = [
      ['AWS Access Key ID', 'AKIAABCDEFGHIJKLMNOP'],
      ['AWS Secret Access Key', `aws_key = "${'A'.repeat(40)}"`],
      ['JWT', 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dGVzdHNpZ25hdHVyZQ'],
      ['chave privada PEM', '-----BEGIN PRIVATE KEY-----'],
      ['API key de LLM', `sk-${'A'.repeat(25)}`],
      ['token do GitHub', `ghp_${'A'.repeat(36)}`],
      ['token do npm', `npm_${'A'.repeat(36)}`],
      ['senha em atribuição', 'password: "abcdef12"'],
      ['credencial em connection string', 'postgres://user:secretpw@host/db'],
    ];
    for (const [patternName, sample] of SECRET_SAMPLES) {
      check(`REQ-04 — família '${patternName}' de SECRET_PATTERNS no corpo -> exit 2 sem eco do trecho`, () => {
        const payload = basePayload({ tool_input: { to: 'SESSION-UNIQUE', recipient_kind: 'name', message: sample, content: sample } });
        const r = G.evaluateSendGuard(payload, opts);
        assertEqual(r.exitCode, 2, `exit code deveria ser 2 (obtido ${r.exitCode})`);
        assertFalse((r.message || '').includes(sample), 'mensagem de bloqueio nunca ecoa o trecho que casou');
      });
    }

    check('REQ-04 — segredo em campo string aninhado (objeto) -> exit 2', () => {
      const payload = basePayload({
        tool_input: {
          to: 'SESSION-UNIQUE',
          recipient_kind: 'name',
          message: 'corpo limpo',
          content: 'corpo limpo',
          extra: { note: 'AKIAABCDEFGHIJKLMNOP' },
        },
      });
      assertEqual(G.evaluateSendGuard(payload, opts).exitCode, 2, 'exit code deveria ser 2');
    });

    check('REQ-04 — segredo em array de strings -> exit 2', () => {
      const payload = basePayload({
        tool_input: {
          to: 'SESSION-UNIQUE',
          recipient_kind: 'name',
          message: 'corpo limpo',
          content: 'corpo limpo',
          tags: ['ok', `ghp_${'B'.repeat(36)}`],
        },
      });
      assertEqual(G.evaluateSendGuard(payload, opts).exitCode, 2, 'exit code deveria ser 2');
    });

    check('REQ-04 — payload vazio (stdin vazio) -> exit 2 via runGuard', () => {
      const r = G.runGuard('', opts);
      assertEqual(r.exitCode, 2, `obtido ${r.exitCode}`);
    });

    check('REQ-04 — payload malformado (JSON inválido) -> exit 2 via runGuard', () => {
      const r = G.runGuard('{not json', opts);
      assertEqual(r.exitCode, 2, `obtido ${r.exitCode}`);
    });

    check('REQ-04 — destino de sessão sem campo de corpo (message ausente, sem notify_when_idle) -> exit 2', () => {
      const payload = basePayload({ tool_input: { to: 'SESSION-UNIQUE', recipient_kind: 'name' } });
      assertEqual(G.evaluateSendGuard(payload, opts).exitCode, 2, 'exit code deveria ser 2');
    });

    check('REQ-04 — destino de sessão com message vazio sem notify_when_idle -> exit 2 (sem corpo)', () => {
      const payload = basePayload({ tool_input: { to: 'SESSION-UNIQUE', recipient_kind: 'name', message: '', content: '' } });
      assertEqual(G.evaluateSendGuard(payload, opts).exitCode, 2, 'exit code deveria ser 2');
    });

    // -------------------------------------------------------------------------------------
    // Gancho .sh real (contrato stdin-json, auto-localização de scripts/lib/, exec node)
    // -------------------------------------------------------------------------------------
    function runHookProcess(stdinText, env = {}) {
      return spawnSync('bash', [HOOK_SH], { input: stdinText, encoding: 'utf8', env: { ...process.env, ...env } });
    }

    check('gancho .sh — destino interno (main) via processo real -> exit 0', () => {
      if (!existsSync(HOOK_SH)) throw new Error(`gancho ausente: ${HOOK_SH}`);
      const payload = JSON.stringify(basePayload({ tool_input: { to: 'main', recipient_kind: 'main', message: 'x', content: 'x' } }));
      const res = runHookProcess(payload, { FORGE_CLAUDE_SESSIONS_DIR: SESS_DIR, FORGE_CLAUDE_PROJECTS_DIR: PROJECTS_DIR });
      assertEqual(res.status, 0, `exit code deveria ser 0 (obtido ${res.status}, stderr=${res.stderr})`);
    });

    check('gancho .sh — stdin malformado via processo real -> exit 2, nunca 1', () => {
      const res = runHookProcess('{not json', { FORGE_CLAUDE_SESSIONS_DIR: SESS_DIR, FORGE_CLAUDE_PROJECTS_DIR: PROJECTS_DIR });
      assertEqual(res.status, 2, `exit code deveria ser 2 (obtido ${res.status})`);
    });

    check('gancho .sh — node ausente no PATH -> exit 2 (fail-closed), nunca 1', () => {
      const res = runHookProcess('{}', { PATH: '/usr/bin:/bin' });
      assertTrue(res.status === 2, `exit code deveria ser 2 (obtido ${res.status})`);
    });

    // -------------------------------------------------------------------------------------
    // Leitor único: mutar um padrão de secret-scan.mjs numa CÓPIA da árvore e ver `send` e o
    // gancho mudarem juntos (REQ-04, "a varredura é a mesma função usada pelo send").
    // -------------------------------------------------------------------------------------
    const copyDir = join(T, 'leitor-unico-repo');
    mkConsumerRepo(copyDir);
    const copiedSecretScan = join(copyDir, '.forge', 'scripts', 'lib', 'secret-scan.mjs');
    const copiedHook = join(copyDir, '.forge', 'hooks', 'pre-tool-use', 'guard-cross-session-send.sh');
    const copiedOps = join(copyDir, '.forge', 'scripts', 'liaison-ops.sh');
    const MARKER = 'FIXTURE-MARKER-9f3a7c';

    check('leitor único — insere padrão novo em secret-scan.mjs na cópia da árvore', () => {
      if (!existsSync(copiedSecretScan)) throw new Error(`secret-scan.mjs ausente na cópia: ${copiedSecretScan}`);
      const text = readFileSync(copiedSecretScan, 'utf8');
      const mutated = text.replace(
        'export const SECRET_PATTERNS = [',
        `export const SECRET_PATTERNS = [\n  { name: 'Marca de fixture (leitor único)', re: /${MARKER}/ },`,
      );
      if (mutated === text) throw new Error('não encontrou o ponto de inserção em SECRET_PATTERNS');
      writeFileSync(copiedSecretScan, mutated);
      return true;
    });

    check('leitor único — gancho copiado detecta o padrão novo', () => {
      if (!existsSync(copiedHook)) throw new Error(`gancho copiado ausente: ${copiedHook}`);
      const payload = JSON.stringify(
        basePayload({
          cwd: copyDir,
          tool_input: { to: 'SESSION-UNIQUE', recipient_kind: 'name', message: `ephemeral: presence\n${MARKER}`, content: `ephemeral: presence\n${MARKER}` },
        }),
      );
      const res = spawnSync('bash', [copiedHook], {
        input: payload,
        encoding: 'utf8',
        env: { ...process.env, FORGE_CLAUDE_SESSIONS_DIR: SESS_DIR, FORGE_CLAUDE_PROJECTS_DIR: PROJECTS_DIR },
      });
      assertEqual(res.status, 2, `gancho copiado deveria bloquear (exit 2); obtido ${res.status}, stderr=${res.stderr}`);
      assertFalse((res.stderr || '').includes(MARKER), 'stderr não deveria ecoar o trecho que casou');
    });

    check('leitor único — send copiado recusa o mesmo padrão novo (mesma função findSecrets)', () => {
      if (!existsSync(copiedOps)) throw new Error(`liaison-ops.sh ausente na cópia: ${copiedOps}`);
      // FORGE_ROOT precisa ser fixado explicitamente na cópia (nunca herdado do ambiente): quem
      // invocar este gate via `red-evidence.sh task` já roda com FORGE_ROOT setado para ESTA
      // worktree, e sem a sobrescrita aqui o `liaison-ops.sh` da cópia resolveria a raiz errada
      // (esta worktree, não `copyDir`) — mesmo defeito que `LG()` evita nos outros gates do
      // liaison, que sempre fixam FORGE_ROOT por fixture em vez de confiar no cwd/ambiente.
      const copyEnv = { ...process.env, FORGE_ROOT: copyDir };
      try {
        execFileSync('bash', [copiedOps, 'open', 'fx', '--self', 'me', '--participants', 'me,peer'], { cwd: copyDir, env: copyEnv, encoding: 'utf8' });
        execFileSync('bash', [copiedOps, 'thread', 'open', 'fx', 'th1', '--subject', 'leitor unico', '--participants', 'me'], { cwd: copyDir, env: copyEnv, encoding: 'utf8' });
      } catch (err) {
        throw new Error(`setup do canal falhou: ${err.stderr || err.stdout || err.message}`);
      }
      const res = spawnSync('bash', [copiedOps, 'send', 'fx', '--thread', 'th1', '--kind', 'note', '--subject', 's', '--body', MARKER], {
        cwd: copyDir,
        env: copyEnv,
        encoding: 'utf8',
      });
      assertTrue(res.status !== 0, `send copiado deveria recusar; obtido status ${res.status}`);
      assertTrue(/segredo/i.test(res.stderr || res.stdout || ''), 'send deveria mencionar o achado de segredo');
    });

    // =======================================================================================
    // Parte 2 (TASK-16/TASK-17, STORY-09, design §2.5 etapas 5 e 6, REQ-06, REQ-07): contenção
    // por workspace, origem cruzada e destino declarado. Reaproveita T/SESS_DIR/MYPID/opts já
    // criados na parte 1.
    // =======================================================================================
    const P2 = join(T, 'p2');
    mkdirSync(P2, { recursive: true });

    const mainRepo = join(P2, 'forge-harness'); // origem — "caso de 2026-10-30" do REQ-07
    initRepo(mainRepo);
    git(mainRepo, ['remote', 'add', 'origin', 'https://github.com/acme/forge-harness.git']);

    const nestedRepo = join(mainRepo, 'vendor', 'nested'); // repositório aninhado
    initRepo(nestedRepo);

    const wtOutside = join(P2, 'wt-outside'); // worktree FORA da árvore principal
    git(mainRepo, ['worktree', 'add', '--detach', wtOutside]);
    onCleanup(() => {
      try {
        git(mainRepo, ['worktree', 'remove', '--force', wtOutside]);
      } catch {
        /* best-effort */
      }
    });

    const paymentsRepo = join(P2, 'payments'); // outro workspace — "caso de 2026-10-30"
    initRepo(paymentsRepo);
    git(paymentsRepo, ['remote', 'add', 'origin', 'https://github.com/acme/payments.git']);

    const cloneA = join(P2, 'clone-a'); // identidade via insteadOf
    initRepo(cloneA);
    git(cloneA, ['remote', 'add', 'origin', 'git@work-alias:acme/shared.git']);
    git(cloneA, ['config', 'url.git@github.com:.insteadOf', 'git@work-alias:']);
    const cloneB = join(P2, 'clone-b');
    initRepo(cloneB);
    git(cloneB, ['remote', 'add', 'origin', 'git@github.com:acme/shared.git']);

    // home como repositório (dotfiles): duas raízes de "home" DIFERENTES, cada também
    // repositório git — não podem colapsar na mesma identidade só por serem "home".
    const fakeHomeA = join(P2, 'fakehome-a');
    initRepo(fakeHomeA);
    const fakeHomeB = join(P2, 'fakehome-b');
    initRepo(fakeHomeB);

    const channelPeerRepo = join(P2, 'channel-peer'); // participante com peer-path
    initRepo(channelPeerRepo);
    git(channelPeerRepo, ['remote', 'add', 'origin', 'https://github.com/acme/channel-peer.git']);
    const nonParticipantRepo = join(P2, 'non-participant'); // nenhum peer aponta aqui
    initRepo(nonParticipantRepo);
    git(nonParticipantRepo, ['remote', 'add', 'origin', 'https://github.com/acme/non-participant.git']);
    const homonymOtherRepo = join(P2, 'homonym-other'); // destino homônimo, NUNCA cadastrado
    initRepo(homonymOtherRepo);
    git(homonymOtherRepo, ['remote', 'add', 'origin', 'https://github.com/acme/homonym-other.git']);
    const mismatchOriginRepo = join(P2, 'mismatch-origin'); // self_identity divergente
    initRepo(mismatchOriginRepo);
    git(mismatchOriginRepo, ['remote', 'add', 'origin', 'https://github.com/acme/mismatch-origin.git']);
    const mismatchDestRepo = join(P2, 'mismatch-dest');
    initRepo(mismatchDestRepo);
    git(mismatchDestRepo, ['remote', 'add', 'origin', 'https://github.com/acme/mismatch-dest.git']);
    const uncommittedOriginRepo = join(P2, 'uncommitted-origin');
    initRepo(uncommittedOriginRepo);
    git(uncommittedOriginRepo, ['remote', 'add', 'origin', 'https://github.com/acme/uncommitted-origin.git']);
    const uncommittedDestRepo = join(P2, 'uncommitted-dest');
    initRepo(uncommittedDestRepo);
    git(uncommittedDestRepo, ['remote', 'add', 'origin', 'https://github.com/acme/uncommitted-dest.git']);

    function writeAllowlistFile(root, doc) {
      mkdirSync(join(root, '.forge', 'liaison'), { recursive: true });
      writeFileSync(join(root, '.forge', 'liaison', 'allowed-workspaces.json'), `${JSON.stringify(doc, null, 2)}\n`);
    }
    function commitAllowlist(root, msg = 'chore: cadastro de workspace') {
      git(root, ['add', '.forge/liaison/allowed-workspaces.json']);
      git(root, ['commit', '-qm', msg]);
    }
    function allowEntry(id) {
      return { id, reason: 'teste', granted_by: 'fixture@test', granted_at: '2026-01-01T00:00:00Z' };
    }

    // Cadastro inicial de mainRepo: libera os repositórios usados pelos testes de ETAPA 6 (que
    // não são o foco da contenção) — channel-peer e non-participant precisam passar a etapa 5
    // para isolar a etapa 6.
    writeAllowlistFile(mainRepo, {
      version: 1,
      allowed_workspaces: [allowEntry('github.com/acme/channel-peer'), allowEntry('github.com/acme/non-participant')],
    });
    commitAllowlist(mainRepo, 'chore: cadastro inicial (fixtures da etapa 6)');

    const destEntries = [];
    async function makeDestSocket(label, { cwd, pid = MYPID, name } = {}) {
      const sockP = join(T, `p2-${label}.sock`);
      const srv2 = await listenUnixSocket(sockP);
      onCleanup(() => srv2.close());
      writeRegistryEntry(`p2-${label}.json`, { name: name || `DEST-${label.toUpperCase()}`, pid, cwd, sessionId: `p2-${label}-session`, sock: sockP });
      destEntries.push(sockP);
      return `uds:${sockP}`;
    }

    const udsSameRepo = await makeDestSocket('same-repo', { cwd: mainRepo });
    const udsNested = await makeDestSocket('nested', { cwd: nestedRepo });
    const udsWtOutside = await makeDestSocket('wt-outside', { cwd: wtOutside });
    const udsPaymentsNoAllow = await makeDestSocket('payments-noallow', { cwd: paymentsRepo });
    const udsPaymentsAllowed = await makeDestSocket('payments-allowed', { cwd: paymentsRepo });
    const udsCloneB = await makeDestSocket('clone-b', { cwd: cloneB });
    const udsHomeB = await makeDestSocket('home-b', { cwd: fakeHomeB });
    const udsHomonymA = await makeDestSocket('homonym-a', { cwd: mainRepo, name: 'HOMONYM' });
    const udsHomonymB = await makeDestSocket('homonym-b', { cwd: homonymOtherRepo, name: 'HOMONYM' });
    const udsChannelPeer = await makeDestSocket('channel-peer', { cwd: channelPeerRepo });
    const udsNonParticipant = await makeDestSocket('non-participant', { cwd: nonParticipantRepo });
    const udsMismatchDest = await makeDestSocket('mismatch-dest', { cwd: mismatchDestRepo });
    const udsUncommittedDest = await makeDestSocket('uncommitted-dest', { cwd: uncommittedDestRepo });

    // destino sem registro (socket nunca aberto)
    const udsNoRegistry = `uds:${join(T, 'p2-no-registry.sock')}`;

    // destino com pid morto (socket real, fechado — a aliveness depende do pid, não só do socket)
    const deadSockPath = join(T, 'p2-dead.sock');
    const deadSrvTmp = await listenUnixSocket(deadSockPath);
    deadSrvTmp.close();
    const deadProc2 = spawnSync(process.execPath, ['-e', 'process.exit(0)']);
    writeRegistryEntry('p2-dead.json', { name: 'DEST-DEAD', pid: deadProc2.pid, cwd: paymentsRepo, sessionId: 'p2-dead-session', sock: deadSockPath });
    const udsDead = `uds:${deadSockPath}`;

    // registro ilegível (JSON inválido) ao lado de destinos válidos — resolução por SOCKET não
    // é fail-closed quando já achou o destino certo (native-registry.mjs só é fail-closed por
    // socket quando NENHUM registro válido deu match); por NOME, é sempre fail-closed (parte 1).
    writeFileSync(join(SESS_DIR, 'p2-illegible.json'), '{ nao é json');

    // /tmp vs /private/tmp — socket real criado sob /tmp literal (symlink para /private/tmp no
    // macOS); o payload referencia o endereço pelo caminho /private/tmp e precisa casar.
    const realTmpDest = join(P2, 'realtmp-dest');
    initRepo(realTmpDest);
    const tmpSlashSock = `/tmp/forge-send-guard-tmp-${process.pid}-${Date.now()}.sock`;
    const tmpSrv = await listenUnixSocket(tmpSlashSock);
    onCleanup(() => {
      try {
        tmpSrv.close();
      } catch {
        /* best-effort */
      }
      try {
        rmSync(tmpSlashSock, { force: true });
      } catch {
        /* best-effort */
      }
    });
    writeRegistryEntry('p2-tmp.json', { name: 'DEST-TMP', pid: MYPID, cwd: realTmpDest, sessionId: 'p2-tmp-session', sock: tmpSlashSock });
    const udsTmpPrivate = `uds:${tmpSlashSock.replace(/^\/tmp\//, '/private/tmp/')}`;

    function p2Payload({ to, message, sessionId, cwd = mainRepo, extra = {} }) {
      return basePayload({
        session_id: sessionId || 'p2-sem-registro-proprio',
        cwd,
        tool_input: { to, recipient_kind: 'session', message, content: message, ...extra },
      });
    }

    const EPH = 'ephemeral: presence';

    // ---------------------------------------------------------------------------------------
    // REQ-07 — contenção por workspace
    // ---------------------------------------------------------------------------------------
    check('REQ-07 — destino no mesmo repositório -> passa', () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsSameRepo, message: EPH }), opts);
      assertEqual(r.exitCode, 0, `exit code deveria ser 0 (obtido ${r.exitCode}: ${r.message})`);
    });

    check('REQ-07 — destino em repositório aninhado -> mesmo workspace, passa', () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsNested, message: EPH }), opts);
      assertEqual(r.exitCode, 0, `exit code deveria ser 0 (obtido ${r.exitCode}: ${r.message})`);
    });

    check('REQ-07 — destino em worktree fora da árvore principal -> mesmo workspace, passa', () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsWtOutside, message: EPH }), opts);
      assertEqual(r.exitCode, 0, `exit code deveria ser 0 (obtido ${r.exitCode}: ${r.message})`);
    });

    check("REQ-07 — caso 'forge-harness' -> 'payments' SEM cadastro -> exit 2, sem comando pronto e sem citar manifest/settings", () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsPaymentsNoAllow, message: EPH }), opts);
      assertEqual(r.exitCode, 2, `exit code deveria ser 2 (obtido ${r.exitCode})`);
      const msg = r.message || '';
      assertTrue(/forge-harness/.test(msg) && /payments/.test(msg), 'mensagem deveria nomear as duas identidades');
      assertFalse(/native allow /.test(msg), 'mensagem não deveria imprimir comando pronto');
      assertFalse(/hooks\.manifest|settings\.json/.test(msg), 'mensagem não deveria sugerir mexer em manifest/settings');
    });

    check("REQ-07 — caso 'forge-harness' -> 'payments' com cadastro COMMITADO -> exit 0", () => {
      const doc = JSON.parse(readFileSync(join(mainRepo, '.forge', 'liaison', 'allowed-workspaces.json'), 'utf8'));
      doc.allowed_workspaces.push(allowEntry('github.com/acme/payments'));
      writeAllowlistFile(mainRepo, doc);
      commitAllowlist(mainRepo, 'chore: libera payments');
      const r = G.evaluateSendGuard(p2Payload({ to: udsPaymentsAllowed, message: EPH }), opts);
      assertEqual(r.exitCode, 0, `exit code deveria ser 0 (obtido ${r.exitCode}: ${r.message})`);
    });

    check('REQ-07 — cadastro só na árvore de trabalho (não commitado) não libera', () => {
      writeAllowlistFile(uncommittedOriginRepo, {
        version: 1,
        allowed_workspaces: [allowEntry('github.com/acme/uncommitted-dest')],
      }); // NÃO commita — propositalmente
      const r = G.evaluateSendGuard(p2Payload({ to: udsUncommittedDest, message: EPH, cwd: uncommittedOriginRepo }), opts);
      assertEqual(r.exitCode, 2, `exit code deveria ser 2 (cadastro não commitado não deveria liberar; obtido ${r.exitCode})`);
    });

    check("REQ-07 — self_identity divergente -> exit 2 ('contenção suspensa até decisão humana')", () => {
      writeAllowlistFile(mismatchOriginRepo, {
        version: 1,
        self_identity: 'github.com/acme/outro-remote-fixado',
        allowed_workspaces: [allowEntry('github.com/acme/mismatch-dest')],
      });
      commitAllowlist(mismatchOriginRepo);
      const r = G.evaluateSendGuard(p2Payload({ to: udsMismatchDest, message: EPH, cwd: mismatchOriginRepo }), opts);
      assertEqual(r.exitCode, 2, `exit code deveria ser 2 mesmo com o destino cadastrado (obtido ${r.exitCode}: ${r.message})`);
      assertTrue(/diverge|identidade fixada/i.test(r.message || ''), 'mensagem deveria citar a divergência de identidade fixada');
    });

    check('REQ-07 — nome homônimo em workspaces diferentes resolvido pelo socket, sem ambiguidade', () => {
      const rA = G.evaluateSendGuard(p2Payload({ to: udsHomonymA, message: EPH }), opts);
      assertEqual(rA.exitCode, 0, `destino homônimo no mesmo repositório deveria passar (obtido ${rA.exitCode}: ${rA.message})`);
      const rB = G.evaluateSendGuard(p2Payload({ to: udsHomonymB, message: EPH }), opts);
      assertEqual(rB.exitCode, 2, `destino homônimo em outro workspace sem cadastro deveria bloquear (obtido ${rB.exitCode})`);
    });

    check('REQ-07 — destino sem registro local (socket nunca aberto) -> exit 2', () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsNoRegistry, message: EPH }), opts);
      assertEqual(r.exitCode, 2, `exit code deveria ser 2 (obtido ${r.exitCode})`);
    });

    check('REQ-07 — destino com pid morto -> exit 2 (não resolve como vivo)', () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsDead, message: EPH }), opts);
      assertEqual(r.exitCode, 2, `exit code deveria ser 2 (obtido ${r.exitCode})`);
    });

    check('REQ-07 — registro ilegível ao lado de destino válido não impede a resolução por socket', () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsSameRepo, message: EPH }), opts);
      assertEqual(r.exitCode, 0, `exit code deveria ser 0 (obtido ${r.exitCode}: ${r.message})`);
    });

    check('REQ-07 — /tmp e /private/tmp convergem na comparação de socket', () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsTmpPrivate, message: EPH }), opts);
      assertEqual(r.exitCode, 2, `destino em outro workspace sem cadastro ainda deveria bloquear (${r.exitCode}) — mas a resolução do socket precisa ter encontrado o registro (ver mensagem)`);
      assertFalse(/sem registro local/.test(r.message || ''), 'o socket deveria ter sido resolvido (/tmp e /private/tmp convergem) — o bloqueio é de contenção, não de resolução');
    });

    check('REQ-07 — HOME como repositório (dotfiles): duas sessões não colapsam no mesmo workspace', () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsHomeB, message: EPH, cwd: fakeHomeA, extra: {} }), { ...opts, home: undefined });
      // Sem override de home, o cálculo usa os.homedir() real — o teste confere que fakeHomeA e
      // fakeHomeB (repositórios DIFERENTES, cada um candidato a objeto) não convergem para a
      // mesma identidade só por serem simulações de home: cada um some sua própria identidade de
      // repositório normal (não há colapso, resultado é bloqueio por serem workspaces diferentes
      // sem cadastro, nunca 'exit 0' por engano).
      assertEqual(r.exitCode, 2, `exit code deveria ser 2 (workspaces diferentes sem cadastro; obtido ${r.exitCode})`);
    });

    check('REQ-07 — dois clones do mesmo repositório (um com insteadOf) convergem na identidade -> passa', () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsCloneB, message: EPH, cwd: cloneA }), opts);
      assertEqual(r.exitCode, 0, `exit code deveria ser 0 (obtido ${r.exitCode}: ${r.message})`);
    });

    // ---------------------------------------------------------------------------------------
    // REQ-07 — origem cruzada (registro da própria sessão via session_id)
    // ---------------------------------------------------------------------------------------
    check("REQ-07 — session_id do payload com registro próprio cujo workspace difere do cwd -> exit 2 'origem ambígua'", () => {
      writeRegistryEntry('p2-own-session.json', { name: 'OWN-SESSION', pid: MYPID, cwd: paymentsRepo, sessionId: 'p2-own-diverge', sock: sockPath });
      const r = G.evaluateSendGuard(p2Payload({ to: udsSameRepo, message: EPH, sessionId: 'p2-own-diverge', cwd: mainRepo }), opts);
      assertEqual(r.exitCode, 2, `exit code deveria ser 2 (obtido ${r.exitCode}: ${r.message})`);
      assertTrue(/ambígua|ambigua/i.test(r.message || ''), 'mensagem deveria dizer que a origem é ambígua');
    });

    check('REQ-07 — session_id sem registro próprio -> vale o cwd do payload', () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsSameRepo, message: EPH, sessionId: 'p2-sem-registro-proprio-2', cwd: mainRepo }), opts);
      assertEqual(r.exitCode, 0, `exit code deveria ser 0 (obtido ${r.exitCode}: ${r.message})`);
    });

    check('REQ-07 — session_id do payload com registro próprio CONSISTENTE com o cwd -> passa normalmente', () => {
      writeRegistryEntry('p2-own-session-ok.json', { name: 'OWN-SESSION-OK', pid: MYPID, cwd: mainRepo, sessionId: 'p2-own-ok', sock: sockPath });
      const r = G.evaluateSendGuard(p2Payload({ to: udsSameRepo, message: EPH, sessionId: 'p2-own-ok', cwd: mainRepo }), opts);
      assertEqual(r.exitCode, 0, `exit code deveria ser 0 (obtido ${r.exitCode}: ${r.message})`);
    });

    // ---------------------------------------------------------------------------------------
    // REQ-06 — destino declarado (etapa 6, depois de a etapa 5 já ter passado)
    // ---------------------------------------------------------------------------------------
    function publishOwnMessage(root, channel, { msgId, sender = 'me', threadId = 't1', contentSha = 'sha-fixture', subject = 'assunto fixture' }) {
      const chDir = join(root, '.forge', 'liaison', channel);
      mkdirSync(join(chDir, 'log'), { recursive: true });
      const rec = { sender, msg_id: msgId, thread_id: threadId, content_sha: contentSha, subject };
      writeFileSync(join(chDir, 'log', `${sender}.jsonl`), `${JSON.stringify(rec)}\n`, { flag: 'a' });
      const stateFile = join(chDir, 'state.json');
      const state = existsSync(stateFile) ? JSON.parse(readFileSync(stateFile, 'utf8')) : { cursors: {} };
      if (!state.published) state.published = {};
      state.published[sender] = msgId;
      writeFileSync(stateFile, `${JSON.stringify(state, null, 2)}\n`);
      return `liaison:${channel}/${msgId}`;
    }
    function writeUnpublishedMessage(root, channel, { msgId, sender = 'me' }) {
      const chDir = join(root, '.forge', 'liaison', channel);
      mkdirSync(join(chDir, 'log'), { recursive: true });
      const rec = { sender, msg_id: msgId, thread_id: 't1', content_sha: 'sha-np', subject: 'não publicada' };
      writeFileSync(join(chDir, 'log', `${sender}.jsonl`), `${JSON.stringify(rec)}\n`, { flag: 'a' });
      return `liaison:${channel}/${msgId}`;
    }

    const SELF_ID = 'me';
    const CH_V = 'ch-verificavel';
    const CH_I = 'ch-inconclusivo';
    writeConfig(join(mainRepo, '.forge', 'liaison', 'liaison.yaml'), {
      self: { id: SELF_ID },
      channels: {
        [CH_V]: { participants: [SELF_ID, 'peer-a'], peers: { 'peer-a': channelPeerRepo } },
        [CH_I]: { participants: [SELF_ID, 'peer-b'], peers: {} },
      },
    });

    const ptrOk = publishOwnMessage(mainRepo, CH_V, { msgId: 'm-ok' });
    const ptrPeer = publishOwnMessage(mainRepo, CH_V, { msgId: 'm-peer', sender: 'outro-remetente' });
    const ptrInconclusive = publishOwnMessage(mainRepo, CH_I, { msgId: 'm-inconclusive', sender: SELF_ID });
    const ptrCap = publishOwnMessage(mainRepo, CH_V, { msgId: 'm-cap', sender: SELF_ID });
    // ESCRITA DEPOIS da marca de publicação (ptrCap): isPublished é posicional no log
    // append-only — uma mensagem escrita ANTES da marca de publicação conta como publicada
    // mesmo sem ter sido marcada individualmente (mesma regra de unpublishedCount). Por isso
    // "não publicada" só é "não publicada" de verdade se vier DEPOIS do último publish.
    const ptrUnpub = writeUnpublishedMessage(mainRepo, CH_V, { msgId: 'm-unpub', sender: SELF_ID });

    check('REQ-06 — ponteiro válido (próprio, publicado) -> passa', () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsSameRepo, message: ptrOk }), opts);
      assertEqual(r.exitCode, 0, `exit code deveria ser 0 (obtido ${r.exitCode}: ${r.message})`);
    });

    check('REQ-06 — ponteiro para mensagem inexistente -> exit 2', () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsSameRepo, message: `liaison:${CH_V}/m-nao-existe` }), opts);
      assertEqual(r.exitCode, 2, `exit code deveria ser 2 (obtido ${r.exitCode})`);
    });

    check('REQ-06 — ponteiro de mensagem de peer (não é própria) -> exit 2', () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsSameRepo, message: ptrPeer }), opts);
      assertEqual(r.exitCode, 2, `exit code deveria ser 2 (obtido ${r.exitCode})`);
    });

    check('REQ-06 — ponteiro não publicado -> exit 2', () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsSameRepo, message: ptrUnpub }), opts);
      assertEqual(r.exitCode, 2, `exit code deveria ser 2 (obtido ${r.exitCode})`);
    });

    check('REQ-06 — ponteiro validado a partir de uma worktree resolve o mesmo canal do tronco', () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsSameRepo, message: ptrOk, cwd: wtOutside }), opts);
      assertEqual(r.exitCode, 0, `exit code deveria ser 0 (obtido ${r.exitCode}: ${r.message})`);
    });

    check('REQ-06 — destino participa do canal (peer-path verificável, outro repositório) -> passa', () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsChannelPeer, message: ptrOk }), opts);
      assertEqual(r.exitCode, 0, `exit code deveria ser 0 (obtido ${r.exitCode}: ${r.message})`);
    });

    check('REQ-06 — destino NÃO participa do canal (peer-path todos verificáveis, nenhum coincide) -> exit 2', () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsNonParticipant, message: ptrOk }), opts);
      assertEqual(r.exitCode, 2, `exit code deveria ser 2 (obtido ${r.exitCode})`);
      assertTrue(/participa/i.test(r.message || ''), 'mensagem deveria dizer que o destino não participa do canal');
    });

    check('REQ-06 — participante sem peer-path torna a checagem inconclusiva -> passa', () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsNonParticipant, message: ptrInconclusive }), opts);
      assertEqual(r.exitCode, 0, `exit code deveria ser 0 (inconclusivo deveria passar; obtido ${r.exitCode}: ${r.message})`);
    });

    check('REQ-06 — declaração efêmera com classe válida -> passa', () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsSameRepo, message: 'ephemeral: schedule' }), opts);
      assertEqual(r.exitCode, 0, `exit code deveria ser 0 (obtido ${r.exitCode}: ${r.message})`);
    });

    check('REQ-06 — declaração efêmera com classe inválida -> exit 2 listando as classes', () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsSameRepo, message: 'ephemeral: nao-existe' }), opts);
      assertEqual(r.exitCode, 2, `exit code deveria ser 2 (obtido ${r.exitCode})`);
      assertTrue(/presence/.test(r.message || ''), 'mensagem deveria listar as classes aceitas');
    });

    check('REQ-06 — declaração fora da primeira linha não vazia -> exit 2', () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsSameRepo, message: `algum texto\n${ptrOk}` }), opts);
      assertEqual(r.exitCode, 2, `exit code deveria ser 2 (obtido ${r.exitCode})`);
      assertTrue(/primeira linha/.test(r.message || ''), 'mensagem deveria citar a primeira linha');
    });

    check('REQ-06 — ephemeral: internal-coordination no MESMO repositório -> passa', () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsSameRepo, message: 'ephemeral: internal-coordination\ncoordenação interna curta' }), opts);
      assertEqual(r.exitCode, 0, `exit code deveria ser 0 (obtido ${r.exitCode}: ${r.message})`);
    });

    check('REQ-06 — ephemeral: internal-coordination ENTRE repositórios -> exit 2', () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsPaymentsAllowed, message: 'ephemeral: internal-coordination\ncoordenação interna curta' }), opts);
      assertEqual(r.exitCode, 2, `exit code deveria ser 2 (obtido ${r.exitCode})`);
      assertTrue(/liaison/i.test(r.message || ''), 'mensagem deveria explicar que material entre repositórios é de liaison');
    });

    check('REQ-06 — teto de 1024 bytes do texto livre do ponteiro: dentro do teto passa', () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsSameRepo, message: `${ptrCap}\n${'x'.repeat(1000)}` }), opts);
      assertEqual(r.exitCode, 0, `exit code deveria ser 0 (obtido ${r.exitCode}: ${r.message})`);
    });

    check('REQ-06 — teto de 1024 bytes do texto livre do ponteiro: acima do teto bloqueia', () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsSameRepo, message: `${ptrCap}\n${'x'.repeat(1100)}` }), opts);
      assertEqual(r.exitCode, 2, `exit code deveria ser 2 (obtido ${r.exitCode})`);
    });

    check('REQ-06 — teto de 1024 bytes do corpo de declaração efêmera (não internal-coordination)', () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsSameRepo, message: `ephemeral: presence\n${'x'.repeat(1100)}` }), opts);
      assertEqual(r.exitCode, 2, `exit code deveria ser 2 (obtido ${r.exitCode})`);
    });

    check('REQ-06 — mensagem sem ponteiro nem declaração -> exit 2 explicando as duas formas', () => {
      const r = G.evaluateSendGuard(p2Payload({ to: udsSameRepo, message: 'só um texto qualquer, sem nada' }), opts);
      assertEqual(r.exitCode, 2, `exit code deveria ser 2 (obtido ${r.exitCode})`);
      assertTrue(/liaison:|ephemeral/i.test(r.message || ''), 'mensagem deveria explicar as duas formas de declarar');
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
  console.log(`\nPASS native-send-guard-gate.driver — ${n} checagens.`);
}

main().catch((err) => {
  console.log(`FAIL [${n + 1}] driver: exceção não tratada: ${err && err.stack ? err.stack : err}`);
  process.exit(1);
});
