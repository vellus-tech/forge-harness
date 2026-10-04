#!/usr/bin/env node
// queue.mjs — fila das execuções e gradings de uma reexecução, derivada do disco.
//
// Uso: node queue.mjs status
//      node queue.mjs next <n> [--running <k>] [--limit <m>]   (marca e imprime até n tarefas: "exec <id>" ou "grade <id>")
//      node queue.mjs mark <exec|grade> <id> [...]             (marca como lançadas, sem imprimir)
// Ambiente: REEXEC_SCRATCH.
// Estado de cada execução, lido do disco a cada chamada:
//   exec pendente  → sem linha em launched.tsv para exec e sem timing.json
//   exec em curso  → lançada, sem timing.json
//   grade pendente → com timing.json e grading de nenhuma tentativa lançada
//   grade em curso → grade lançada, sem grader_timing.json
//   concluída      → com grader_timing.json
// Prioridade: grade pendente primeiro (fecha casos), depois exec na ordem do map.tsv.
import { appendFileSync, existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const S = process.env.REEXEC_SCRATCH;
const map = readFileSync(join(S, 'map.tsv'), 'utf8').trim().split('\n').map((l) => l.split('\t'));
const L = join(S, 'launched.tsv');
const launched = new Set(existsSync(L) ? readFileSync(L, 'utf8').trim().split('\n').filter(Boolean) : []);
const has = (id, f) => existsSync(join(S, 'runs', id, f));
const st = (id) => {
  if (has(id, 'grader_timing.json')) return 'done';
  if (has(id, 'timing.json')) return launched.has(`grade\t${id}`) ? 'grade_running' : 'grade_pending';
  return launched.has(`exec\t${id}`) ? 'exec_running' : 'exec_pending';
};
const [cmd, ...a] = process.argv.slice(2);
if (cmd === 'status') {
  const c = {}; const byArt = {};
  for (const r of map) { const s = st(r[0]); c[s] = (c[s] || 0) + 1; (byArt[r[2]] ||= {})[s] = (byArt[r[2]][s] || 0) + 1; }
  console.log(JSON.stringify(c));
  for (const [k, v] of Object.entries(byArt)) console.log(`${k} ${JSON.stringify(v)}`);
} else if (cmd === 'mark') {
  for (let i = 1; i < a.length; i++) appendFileSync(L, `${a[0]}\t${a[i]}\n`);
} else if (cmd === 'next' || cmd === 'fill') {
  // fill <limite>: lança só o que cabe sob o limite de subagentes simultâneos, contando os em curso.
  const running = map.filter((r) => ['exec_running', 'grade_running'].includes(st(r[0]))).length;
  const n = cmd === 'fill' ? Math.max(0, Number(a[0]) - running) : Number(a[0]);
  if (cmd === 'fill') console.error(`em curso ${running}, lançar ${n}`);
  const out = [];
  for (const r of map) if (out.length < n && st(r[0]) === 'grade_pending') out.push(['grade', r[0]]);
  // --skip <nome,...>: artefatos cujo exec espera folga (o task-coder abre subagentes, que contam no
  // mesmo limite de simultâneos; sob carga, a recusa do Agent vira modo degradado e contamina o caso).
  const si = a.indexOf('--skip');
  const skip = new Set(si >= 0 ? a[si + 1].split(',') : []);
  for (const r of map) if (out.length < n && st(r[0]) === 'exec_pending' && !skip.has(r[2])) out.push(['exec', r[0]]);
  for (const [k, id] of out) { appendFileSync(L, `${k}\t${id}\n`); console.log(`${k} ${id}`); }
}
