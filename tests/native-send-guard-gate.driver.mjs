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
