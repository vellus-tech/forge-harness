#!/usr/bin/env node
// record.mjs — grava o custo medido de cada subagente a partir da notificação de término dele.
//
// Uso: node record.mjs <exec|grade|analyze> <id> <total_tokens> <tool_uses> <duration_ms> [<papel> <id> ...]
// Ambiente: REEXEC_SCRATCH.
// exec  → runs/<id>/timing.json (total_tokens, duration_ms, total_duration_seconds), lido pelo agregador;
// grade → runs/<id>/grader_timing.json;
// todos → linha em cost.tsv (papel, id, tokens, tool_uses, duration_ms, instante).
import { appendFileSync, existsSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const SCRATCH = process.env.REEXEC_SCRATCH;
if (!SCRATCH) { console.error('FAIL REEXEC_SCRATCH ausente'); process.exit(2); }
const a = process.argv.slice(2);
if (!a.length || a.length % 5) { console.error('uso: record.mjs <papel> <id> <tokens> <tool_uses> <duration_ms> [...]'); process.exit(2); }
for (let i = 0; i < a.length; i += 5) {
  const [role, id, tok, tools, ms] = a.slice(i, i + 5);
  const tokens = Number(tok), duration = Number(ms), toolUses = Number(tools);
  if (!(tokens > 0) || !(duration > 0)) { console.error(`FAIL ${id}: tokens/duração inválidos`); process.exit(1); }
  const run = join(SCRATCH, 'runs', id);
  const timing = { total_tokens: tokens, tool_uses: toolUses, duration_ms: duration, total_duration_seconds: Math.round(duration / 100) / 10 };
  if (role === 'exec') {
    if (!existsSync(run)) { console.error(`FAIL ${id}: execução inexistente`); process.exit(1); }
    writeFileSync(join(run, 'timing.json'), JSON.stringify(timing, null, 2) + '\n');
  } else if (role === 'grade') {
    writeFileSync(join(run, 'grader_timing.json'), JSON.stringify(timing, null, 2) + '\n');
  }
  appendFileSync(join(SCRATCH, 'cost.tsv'), [role, id, tokens, toolUses, duration, new Date().toISOString()].join('\t') + '\n');
  console.log(`OK ${role} ${id} tokens=${tokens} s=${timing.total_duration_seconds}`);
}
