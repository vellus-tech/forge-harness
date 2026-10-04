#!/usr/bin/env node
// audit.mjs — audita o registro REAL de ferramentas de cada subagente (não o transcript que ele escreveu).
//
// Uso: node audit.mjs <dir-subagents-da-sessão> [<skills|agents> <nome> --iteration 2]
// Ambiente: REEXEC_SCRATCH.
// Associa cada jsonl de subagente a uma execução pelo id opaco citado na primeira mensagem
// (runs/<id>/prompt.md para executor, runs/<id>/grader_prompt.md para grader) e marca toda chamada
// de ferramenta cujo argumento cite: o repositório do harness, um diretório de evals, o relatório,
// a árvore template/.forge do harness, outra execução (runs/<outro id>) ou /tmp fora do tmp da execução.
// Conta também commits git reais e chamadas Agent, que provam a política de sandbox aplicada.
// Com <tipo> <nome>, grava contamination.json na iteração do artefato (com caminhos de máquina trocados).
import { existsSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRATCH = process.env.REEXEC_SCRATCH;
const [subDir, kind, name, , iteration = '2'] = process.argv.slice(2);
const REPO = resolve(fileURLToPath(import.meta.url), '../../../..');
const map = new Map(readFileSync(join(SCRATCH, 'map.tsv'), 'utf8').trim().split('\n').map((l) => l.split('\t')).map((r) => [r[0], r]));
const HOME = process.env.HOME;
const repoMain = join(HOME, 'Documents/projects/forge-harness');
const files = readdirSync(subDir).filter((f) => f.endsWith('.jsonl'));
const report = [];
for (const f of files) {
  const lines = readFileSync(join(subDir, f), 'utf8').split('\n').filter(Boolean);
  let first;
  try { first = JSON.parse(lines[0]); } catch { continue; }
  const c = first?.message?.content;
  const text = typeof c === 'string' ? c : Array.isArray(c) ? c.map((x) => x.text || '').join('\n') : '';
  const m = text.match(/runs\/([0-9a-f]{10})\/(prompt|grader_prompt)\.md/);
  const m2 = !m && text.match(/runs\/([0-9a-f]{10})\//); // subagente de segundo nível (repasse do Ambiente)
  const hit = m || m2;
  if (!hit || !map.has(hit[1])) continue;
  const id = hit[1];
  const role = m ? (m[2] === 'prompt' ? 'executor' : 'grader') : 'subagente';
  const runDir = join(SCRATCH, 'runs', id);
  const flags = []; let calls = 0, commits = 0, agentCalls = 0;
  for (const l of lines) {
    let o; try { o = JSON.parse(l); } catch { continue; }
    const content = o?.message?.content;
    if (o.type !== 'assistant' || !Array.isArray(content)) continue;
    for (const part of content) {
      if (part.type !== 'tool_use') continue;
      calls++;
      const s = JSON.stringify(part.input);
      if (part.name === 'Agent' || part.name === 'Task') agentCalls++;
      if (part.name === 'Bash' && /\bgit\b[^"]*\bcommit\b/.test(s)) commits++;
      const checks = [
        [s.includes(repoMain), 'repositório do harness'],
        [/\.forge\/evals\b/.test(s.split(runDir).join('')), 'diretório .forge/evals'],
        [/RELATORIO|plano-melhorias/.test(s), 'relatório ou plano'],
        [/template\/\.forge/.test(s.split(runDir).join('')), 'template/.forge do harness'],
        [[...s.matchAll(/runs\/([0-9a-f]{10})/g)].some((x) => x[1] !== id), 'outra execução'],
        [/(^|[^A-Za-z0-9_.-])\/tmp\//.test(s.split(runDir).join('').replace(/\/private\/tmp\/claude-[^"\s]*/g, '')), '/tmp fora do tmp da execução']
      ];
      for (const [cond, why] of checks) if (cond) flags.push({ tool: part.name, why, input: s.slice(0, 300) });
    }
  }
  const r = map.get(id);
  report.push({ id, role, kind: r[1], name: r[2], eval_id: Number(r[3]), eval_name: r[4], config: r[5], run: Number(r[6]), file: f, tool_calls: calls, git_commits: commits, agent_calls: agentCalls, flags });
}
writeFileSync(join(SCRATCH, 'audit.json'), JSON.stringify(report, null, 2) + '\n');
const sel = kind ? report.filter((x) => x.kind === kind && x.name === name) : report;
const flagged = sel.filter((x) => x.flags.length);
console.log(`OK audit: ${sel.length} subagentes associados, ${flagged.length} com marca`);
for (const x of flagged) console.log(`  ${x.role} ${x.name} eval ${x.eval_id} ${x.config} run-${x.run}: ${[...new Set(x.flags.map((y) => y.why))].join('; ')}`);
if (kind) {
  const san = (t) => t.split(SCRATCH).join('<SCRATCH>').split(SCRATCH.replace(/^\/private/, '')).join('<SCRATCH>').split(HOME).join('<HOME>');
  const dst = join(REPO, '.forge/evals', kind, name, 'workspace', `iteration-${iteration}`, 'contamination.json');
  writeFileSync(dst, san(JSON.stringify(sel.map(({ file, ...x }) => x), null, 2)) + '\n');
}
