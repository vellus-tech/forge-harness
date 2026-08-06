// liaison-render — gera .forge/liaison/<channel>/CHANNEL.md deterministicamente a partir dos
// logs (log/<sender>.jsonl) do canal, via merge puro (liaison-merge.mjs). Mesmo padrão do
// ledger-render.mjs: só o bloco <!-- FORGE:NARRATIVE:START/END --> sobrevive entre gerações.
//
// Ordenação: threads pela ordem de abertura (opened_at do thread-open, com desempate por
// thread_id) SÓ para o índice — dentro de cada thread a ordem é sempre (lamport, sender, seq),
// nunca timestamp. Determinístico: a mesma união de mensagens sempre produz o mesmo CHANNEL.md
// byte-a-byte, não importa a ordem em que os arquivos log/*.jsonl foram lidos ou importados.
//
// Driven by env (set by liaison-ops.sh): LIAISON_ROOT, LIAISON_CHANNEL, LIAISON_CHANNEL_DIR,
// LIAISON_TPL, LIAISON_OUT, LIAISON_SELF.
import { readFileSync, writeFileSync, existsSync, readdirSync } from 'node:fs';
import { renderUntrusted } from './untrusted-render.mjs';
import { join } from 'node:path';
import { mergeLogs } from './liaison-merge.mjs';

const env = process.env;
const channel = env.LIAISON_CHANNEL;
const channelDir = env.LIAISON_CHANNEL_DIR;
const tplPath = env.LIAISON_TPL;
const out = env.LIAISON_OUT;
const self = env.LIAISON_SELF || '(desconhecido)';

function readJsonl(p) {
  let text;
  try { text = readFileSync(p, 'utf8'); } catch { return []; }
  const out = [];
  for (const line of text.split('\n')) {
    const t = line.trim();
    if (!t) continue;
    try { out.push(JSON.parse(t)); } catch { /* linha corrompida: ignorada pelo render, sinalizada pelo doctor */ }
  }
  return out;
}

function readAllMessages(dir) {
  const logDir = join(dir, 'log');
  if (!existsSync(logDir)) return [];
  const files = readdirSync(logDir).filter((f) => f.endsWith('.jsonl')).sort();
  const all = [];
  for (const f of files) all.push(...readJsonl(join(logDir, f)));
  return all;
}

const messages = readAllMessages(channelDir);
const { threads, quarantined, gaps, forks } = mergeLogs(messages);

const threadIds = Object.keys(threads).sort((a, b) => {
  const ta = threads[a].opened_at || '';
  const tb = threads[b].opened_at || '';
  if (ta !== tb) return ta.localeCompare(tb);
  return a.localeCompare(b);
});

function fmtTag(m) {
  const bits = [m.kind];
  if (m.requires_ack) bits.push('ack?');
  return bits.join(' · ');
}

function renderMessage(m) {
  const lines = [`- **${m.msg_id}** [${fmtTag(m)}] \`${m.sender}\` (lamport ${m.lamport}) — ${m.subject || '(sem assunto)'}`];
  if (m.in_reply_to) lines.push(`  ↳ em resposta a \`${m.in_reply_to}\``);
  // Corpo de mensagem é texto arbitrário escrito por OUTRO repositório. Vai sempre embrulhado
  // (banner + fence + neutralização), inclusive o que nós mesmos escrevemos: um render que trata
  // conteúdo próprio e alheio de formas diferentes convida ao erro no dia em que a origem do
  // registro deixar de ser óbvia — e o custo de embrulhar o próprio é uma linha a mais.
  if (m.body) lines.push(...renderUntrusted(m.body, m.sender).split('\n').map((l) => `  ${l}`));
  else if (m.body_ref) lines.push(`  corpo em \`${m.body_ref}\``);
  const refs = m.refs || {};
  const refBits = [];
  if (refs.change_id) refBits.push(`change \`${refs.change_id}\``);
  if (Array.isArray(refs.contract_files) && refs.contract_files.length) refBits.push(`contratos: ${refs.contract_files.join(', ')}`);
  if (refs.commit) refBits.push(`commit \`${refs.commit}\``);
  if (refBits.length) lines.push(`  ${refBits.join(' · ')}`);
  return lines.join('\n');
}

function renderThreadIndex() {
  if (!threadIds.length) return '_(nenhuma thread aberta)_';
  return threadIds.map((id) => {
    const t = threads[id];
    return `- **${id}** — ${t.subject || '(sem assunto)'} · participantes: ${t.participants.join(', ')} · ${t.order.length} mensagem(ns)`;
  }).join('\n');
}

function renderThreadViews() {
  if (!threadIds.length) return '_(nenhuma thread aberta)_';
  return threadIds.map((id) => {
    const t = threads[id];
    const body = t.messages.map(renderMessage).join('\n');
    return `### ${id} — ${t.subject || '(sem assunto)'}\n\nParticipantes: ${t.participants.join(', ')} · aberta por \`${t.opened_by}\`\n\n${body}`;
  }).join('\n\n');
}

function renderQuarantine() {
  if (!quarantined.length) return '_(nenhuma)_';
  return quarantined.map((m) => `- \`${m.msg_id}\` (thread \`${m.thread_id}\`, remetente \`${m.sender}\`) — ${m.quarantine_reason}`).join('\n');
}

function renderDiagnostics() {
  const parts = [];
  if (gaps.length) parts.push(gaps.map((g) => `- **buraco de seq** em \`${g.sender}\`: faltando ${g.missing.join(', ')}`).join('\n'));
  if (forks.length) parts.push(forks.map((f) => `- **fork** em \`${f.sender}\` seq ${f.seq}: ${f.msg_ids.join(' vs ')}`).join('\n'));
  return parts.length ? parts.join('\n') : '_(nenhum)_';
}

const totalMessages = threadIds.reduce((s, id) => s + threads[id].order.length, 0);
const summary = threadIds.length || quarantined.length
  ? `**${threadIds.length} thread(s)** · ${totalMessages} mensagem(ns) · ${quarantined.length} em quarentena`
  : '_(canal vazio — nenhuma mensagem ainda)_';

let content = readFileSync(tplPath, 'utf8');
content = content
  .replaceAll('{{CHANNEL}}', channel)
  .replaceAll('{{SELF}}', self)
  .replaceAll('{{SUMMARY}}', summary)
  .replaceAll('{{THREAD_INDEX}}', renderThreadIndex())
  .replaceAll('{{THREAD_VIEWS}}', renderThreadViews())
  .replaceAll('{{QUARANTINE}}', renderQuarantine())
  .replaceAll('{{DIAGNOSTICS}}', renderDiagnostics());

// Preserva o bloco narrativo já escrito ("Notas") entre regenerações.
const START = '<!-- FORGE:NARRATIVE:START -->';
const END = '<!-- FORGE:NARRATIVE:END -->';
if (existsSync(out)) {
  const prev = readFileSync(out, 'utf8');
  const ps = prev.indexOf(START), pe = prev.indexOf(END);
  const cs = content.indexOf(START), ce = content.indexOf(END);
  if (ps >= 0 && pe > ps && cs >= 0 && ce > cs) {
    const prevBody = prev.slice(ps + START.length, pe).trim();
    const placeholder = content.slice(cs + START.length, ce).trim();
    if (prevBody && !prevBody.startsWith('_(Espaço livre') && prevBody !== placeholder) {
      content = content.slice(0, cs + START.length) + '\n' + prevBody + '\n' + content.slice(ce);
    }
  }
}

writeFileSync(out, content);
