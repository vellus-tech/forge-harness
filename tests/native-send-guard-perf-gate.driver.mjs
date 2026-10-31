#!/usr/bin/env node
// tests/native-send-guard-perf-gate.driver.mjs — driver do gate de desempenho do gancho de
// saída (NFR-01, TASK-16/TASK-17, STORY-09): p95 ≤ 300 ms em 50 execuções POR CASO do REQ-05
// (`main`, `agentId`, nome de sessão, `uds:`, só aviso de ociosidade), medidas com
// `node:perf_hooks` sobre o PROCESSO REAL do gancho (`guard-cross-session-send.sh` via stdin),
// porque é o caminho de produção (inclusive o custo de iniciar o `node` a cada chamada) que o
// NFR mede — não a função importada em processo. Fixture: registro de 20 sessões vivas e
// workspace com repositório aninhado e worktree (o pior caminho de resolução de identidade).
//
// Módulo/gancho ausente -> FAIL nomeando o que falta, nunca stack trace.
import { execFileSync, spawn, spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { performance } from 'node:perf_hooks';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const WS = dirname(dirname(fileURLToPath(import.meta.url)));
const HOOK_SH = join(WS, 'template', '.forge', 'hooks', 'pre-tool-use', 'guard-cross-session-send.sh');
const P95_BUDGET_MS = 300;
const RUNS_PER_CASE = 50;

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

function percentile(sortedMs, p) {
  if (sortedMs.length === 0) return NaN;
  const idx = Math.ceil((p / 100) * sortedMs.length) - 1;
  return sortedMs[Math.max(0, Math.min(sortedMs.length - 1, idx))];
}

function runHookOnce(payloadText, env) {
  const t0 = performance.now();
  const res = spawnSync('bash', [HOOK_SH], { input: payloadText, encoding: 'utf8', env });
  const t1 = performance.now();
  return { ms: t1 - t0, status: res.status, stderr: res.stderr };
}

async function main() {
  if (!existsSync(HOOK_SH)) {
    console.log(`FAIL [1] gancho ausente: ${HOOK_SH}`);
    console.log('\n1 de 1 checagem(ns) reprovada(s).');
    process.exit(1);
  }

  const T = mkdtempSync(join(tmpdir(), 'forge-send-guard-perf-'));
  onCleanup(() => rmSync(T, { recursive: true, force: true }));

  const SESS_DIR = join(T, 'sessions');
  mkdirSync(SESS_DIR, { recursive: true });
  const PROJECTS_DIR = join(T, 'projects');
  mkdirSync(PROJECTS_DIR, { recursive: true });

  // Workspace de fixture com repositório aninhado e worktree (NFR-01: o pior caminho de
  // resolução de identidade — git-common-dir seguido de subida de diretório).
  const mainRepo = join(T, 'perf-main-repo');
  initRepo(mainRepo);
  git(mainRepo, ['remote', 'add', 'origin', 'https://github.com/acme/perf-fixture.git']);
  const nestedRepo = join(mainRepo, 'vendor', 'nested');
  initRepo(nestedRepo);
  const wtOutside = join(T, 'perf-wt-outside');
  git(mainRepo, ['worktree', 'add', '--detach', wtOutside]);
  onCleanup(() => {
    try {
      git(mainRepo, ['worktree', 'remove', '--force', wtOutside]);
    } catch {
      /* best-effort */
    }
  });

  // Registro de 20 sessões vivas (REQ do NFR-01). A primeira (índice 0) é o alvo de todos os
  // casos de destino de sessão; as demais 19 só preenchem o registro para medir o custo real de
  // varredura do diretório.
  const MYPID = process.pid;
  const helperProc = spawn(process.execPath, ['-e', 'setInterval(() => {}, 1000)'], { stdio: 'ignore' });
  onCleanup(() => {
    try {
      helperProc.kill();
    } catch {
      /* best-effort */
    }
  });

  const targetSockPath = join(T, 'target.sock');
  const targetSrv = await listenUnixSocket(targetSockPath);
  onCleanup(() => targetSrv.close());
  writeFileSync(
    join(SESS_DIR, 'target.json'),
    JSON.stringify({ pid: MYPID, name: 'PERF-TARGET', cwd: nestedRepo, sessionId: 'perf-own-session', messagingSocketPath: targetSockPath }),
  );

  for (let i = 0; i < 18; i += 1) {
    // Metade das entradas extras usa o pid real do `helperProc` (vivo), metade um pid já
    // encerrado — o custo de varredura é o mesmo (registro de 20 arquivos), e a mistura evita
    // que a resolução pare no primeiro item por acidente de ordenação do diretório.
    const pid = i % 2 === 0 ? helperProc.pid : 900000 + i;
    writeFileSync(
      join(SESS_DIR, `extra-${i}.json`),
      JSON.stringify({ pid, name: `EXTRA-${i}`, cwd: wtOutside, sessionId: `extra-session-${i}`, messagingSocketPath: join(T, `extra-${i}.sock`) }),
    );
  }

  const env = { ...process.env, FORGE_CLAUDE_SESSIONS_DIR: SESS_DIR, FORGE_CLAUDE_PROJECTS_DIR: PROJECTS_DIR };

  const cases = [
    ['main', JSON.stringify({ session_id: 'perf-s', cwd: mainRepo, tool_name: 'SendMessage', tool_input: { to: 'main', recipient_kind: 'main', message: 'x', content: 'x' } })],
    [
      'agentId',
      JSON.stringify({ session_id: 'perf-s', cwd: mainRepo, tool_name: 'SendMessage', tool_input: { to: 'a1234567890abcdef', recipient_kind: 'agent', message: 'x', content: 'x' } }),
    ],
    [
      'nome de sessão',
      JSON.stringify({
        session_id: 'perf-s',
        cwd: mainRepo,
        tool_name: 'SendMessage',
        tool_input: { to: 'PERF-TARGET', recipient_kind: 'name', message: 'ephemeral: presence', content: 'ephemeral: presence' },
      }),
    ],
    [
      'uds:',
      JSON.stringify({
        session_id: 'perf-s',
        cwd: mainRepo,
        tool_name: 'SendMessage',
        tool_input: { to: `uds:${targetSockPath}`, recipient_kind: 'session', message: 'ephemeral: presence', content: 'ephemeral: presence' },
      }),
    ],
    [
      'só aviso de ociosidade',
      JSON.stringify({
        session_id: 'perf-s',
        cwd: mainRepo,
        tool_name: 'SendMessage',
        tool_input: { to: 'PERF-TARGET', recipient_kind: 'name', message: '', content: '', notify_when_idle: true },
      }),
    ],
  ];

  const results = [];
  for (const [label, payload] of cases) {
    const durations = [];
    for (let i = 0; i < RUNS_PER_CASE; i += 1) {
      const { ms } = runHookOnce(payload, env);
      durations.push(ms);
    }
    durations.sort((a, b) => a - b);
    const p95 = percentile(durations, 95);
    results.push({ label, p95 });
    check(`NFR-01 — caso '${label}': p95 ≤ ${P95_BUDGET_MS} ms em ${RUNS_PER_CASE} execuções`, () => {
      if (p95 > P95_BUDGET_MS) {
        throw new Error(`p95 medido = ${p95.toFixed(1)} ms (acima do teto)`);
      }
      return true;
    });
  }

  console.log('\nResumo de p95 por caso:');
  for (const { label, p95 } of results) {
    console.log(`  ${label}: p95 = ${p95.toFixed(1)} ms`);
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
  console.log(`\nPASS native-send-guard-perf-gate.driver — ${n} checagens.`);
}

main().catch((err) => {
  console.log(`FAIL [${n + 1}] driver: exceção não tratada: ${err && err.stack ? err.stack : err}`);
  process.exit(1);
});
