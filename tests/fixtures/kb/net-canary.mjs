// Canário de rede dos gates do /forge:kb: tenta sair da máquina por vários caminhos, na thread
// principal e dentro de um Worker, contra um servidor local que roda em OUTRO processo (sob
// --permission, o próprio listen seria negado). Imprime uma linha por tentativa:
// `<onde>:<caminho>:ok|bloqueado`. Sob bloqueio, toda linha tem de ser `bloqueado`; sem bloqueio
// (recontrole), toda linha tem de ser `ok` — senão o canário não prova nada.
// Caminhos: fetch, net.connect (import ESM nomeado), socket cru (new net.Socket().connect) e
// processo filho (child_process.execFileSync do próprio node).
import { Worker } from 'node:worker_threads';
import { connect, Socket } from 'node:net';
import { execFileSync } from 'node:child_process';
const url = process.argv[2];
const u = new URL(url);
const tcp = (mk) => new Promise((res) => { try { const s = mk(() => { s.destroy(); res('ok'); }); s.on('error', () => res('bloqueado')); } catch { res('bloqueado'); } });
async function probes(net, cp) {
  let f; try { await fetch(url); f = 'ok'; } catch { f = 'bloqueado'; }
  const n = await tcp((cb) => net.connect(Number(u.port), u.hostname, cb));
  const r = await tcp((cb) => { const s = new net.Socket(); s.connect(Number(u.port), u.hostname, cb); return s; });
  let c; try { cp.execFileSync(process.execPath, ['-e', '0'], { stdio: 'ignore' }); c = 'ok'; } catch { c = 'bloqueado'; }
  return { fetch: f, 'net.connect': n, socket: r, child_process: c };
}
const main = await probes({ connect, Socket }, { execFileSync });
const workerCode = `
  const { parentPort } = require('node:worker_threads');
  const net = require('node:net'); const cp = require('node:child_process');
  const url = ${JSON.stringify(url)}; const u = new URL(url);
  ${tcp.toString().replace(/^/, 'const tcp = ')};
  (${probes.toString()})(net, cp).then((r) => parentPort.postMessage(r));
`;
const worker = await new Promise((res) => {
  let w; try { w = new Worker(workerCode.replace('async function probes', 'async function'), { eval: true }); } catch { res(null); return; }
  w.on('message', (r) => { res(r); w.terminate(); });
  w.on('error', () => res(null));
});
const all = { main, worker: worker ?? { fetch: 'bloqueado', 'net.connect': 'bloqueado', socket: 'bloqueado', child_process: 'bloqueado' } };
for (const [where, r] of Object.entries(all)) for (const [k, v] of Object.entries(r)) console.log(`${where}:${k}:${v}`);
