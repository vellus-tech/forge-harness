// liaison-merge — funções PURAS do subsistema liaison (canal de mensagens ordenadas entre
// agentes de repositórios distintos). Nenhuma função aqui toca disco, relógio de parede ou
// aleatoriedade — todo I/O (ler *.jsonl, escrever state.json/conflicts/) vive em liaison-ops.sh.
//
// Modelo:
//   - Store: um JSONL append-only POR REMETENTE (log/<sender>.jsonl). Single-writer por arquivo
//     é o invariante que torna o merge livre de conflito.
//   - Thread é campo da mensagem, não arquivo — várias threads convivem no mesmo conjunto de logs.
//   - Lamport é POR THREAD (não por canal): um remetente com participação parcial só conhece as
//     mensagens das threads em que está — um relógio por canal exigiria ver threads alheias.
//   - Ordem dentro da thread: (lamport, sender, seq). Entre threads não há ordem definida.
//   - seq é monotônico e sem buracos por remetente — é o detector de mensagem perdida.
//   - Abertura de thread (kind: thread-open) e entrada de participante (kind: join) são
//     mensagens, não configuração — a composição da thread converge pelo mesmo mecanismo do
//     resto e é auditável. Visibilidade: a lista de participantes da thread ROTEIA e organiza
//     (quem é cobrado por ack, para quem o roteamento se dirige) — NÃO confina leitura. Com hub
//     compartilhado, quem alcança o transporte lê tudo; confidencialidade real exige canal
//     separado, não a lista de participantes da thread.
import { createHash } from 'node:crypto';

// --- Envelope / integridade -------------------------------------------------

// Serialização canônica (chaves ordenadas recursivamente) — usada para content_sha e para
// qualquer comparação byte-a-byte. Arrays preservam ordem (são dado, não chave).
export function canonicalStringify(value) {
  return JSON.stringify(sortKeysDeep(value));
}

function sortKeysDeep(v) {
  if (Array.isArray(v)) return v.map(sortKeysDeep);
  if (v && typeof v === 'object') {
    return Object.keys(v).sort().reduce((acc, k) => { acc[k] = sortKeysDeep(v[k]); return acc; }, {});
  }
  return v;
}

export function sha256Hex(text) {
  return createHash('sha256').update(text, 'utf8').digest('hex');
}

// content_sha cobre o envelope MENOS content_sha (auto-referente) e MENOS trust — trust é
// carimbado no IMPORT (nunca pelo remetente), então não pode fazer parte da integridade
// calculada na origem, ou toda cópia importada divergiria da cópia local por definição.
export function computeContentSha(msg) {
  const { content_sha, trust, ...rest } = msg;
  return sha256Hex(canonicalStringify(rest));
}

// --- Contadores monotônicos --------------------------------------------------

// Próximo seq (POR REMETENTE): maior seq conhecido + 1, começando em 1. `messages` deve conter
// só mensagens do mesmo remetente (o caller filtra).
export function nextSeq(messagesForSender) {
  const max = messagesForSender.reduce((m, e) => Math.max(m, Number(e.seq) || 0), 0);
  return max + 1;
}

// Próximo lamport (POR THREAD): maior lamport conhecido entre TODOS os remetentes da thread + 1,
// começando em 1 (abertura da thread). `messages` deve conter só mensagens da mesma thread.
export function nextLamport(messagesForThread) {
  const max = messagesForThread.reduce((m, e) => Math.max(m, Number(e.lamport) || 0), 0);
  return max + 1;
}

// --- Ordenação ---------------------------------------------------------------

// Ordem total dentro de uma thread: (lamport, sender, seq). Como (sender, seq) é único por
// mensagem, o tie-break é total — a ordem resultante independe da ordem de entrada do array
// (propriedade central: embaralhar a entrada não muda a saída).
export function threadOrder(messages) {
  return messages.slice().sort((a, b) => {
    const l = (Number(a.lamport) || 0) - (Number(b.lamport) || 0);
    if (l !== 0) return l;
    const s = String(a.sender).localeCompare(String(b.sender));
    if (s !== 0) return s;
    return (Number(a.seq) || 0) - (Number(b.seq) || 0);
  });
}

// --- Diagnósticos (não bloqueantes) -----------------------------------------

// Buracos de seq por remetente: para cada remetente com pelo menos uma mensagem, espera-se
// 1..max contíguo. Relata só remetentes com buraco real (não relata "ainda não enviou o N+1").
export function detectGaps(messages) {
  const bySender = new Map();
  for (const m of messages) {
    if (!bySender.has(m.sender)) bySender.set(m.sender, []);
    bySender.get(m.sender).push(Number(m.seq) || 0);
  }
  const gaps = [];
  for (const [sender, seqs] of bySender) {
    const seen = new Set(seqs);
    const max = Math.max(0, ...seqs);
    const missing = [];
    for (let i = 1; i < max; i++) if (!seen.has(i)) missing.push(i);
    if (missing.length) gaps.push({ sender, missing });
  }
  return gaps.sort((a, b) => a.sender.localeCompare(b.sender));
}

// Forks: mesma (sender, seq) com content_sha divergente — duas versões da "mesma" posição no
// log de um remetente. Nunca deveria acontecer com single-writer honesto; sinaliza corrupção ou
// spoofing que escapou da validação de import.
export function detectForks(messages) {
  const byKey = new Map();
  for (const m of messages) {
    const key = `${m.sender}:${m.seq}`;
    if (!byKey.has(key)) byKey.set(key, []);
    byKey.get(key).push(m);
  }
  const forks = [];
  for (const [key, group] of byKey) {
    const shas = new Set(group.map((m) => m.content_sha));
    if (shas.size > 1) {
      const [sender, seq] = key.split(':');
      forks.push({
        sender,
        seq: Number(seq),
        msg_ids: group.map((m) => m.msg_id).sort(),
        content_shas: [...shas].sort(),
      });
    }
  }
  return forks.sort((a, b) => a.sender.localeCompare(b.sender) || a.seq - b.seq);
}

// --- Merge central ------------------------------------------------------------

// Recebe o conjunto (união) de mensagens de TODOS os arquivos log/<sender>.jsonl atualmente
// conhecidos localmente — em QUALQUER ordem — e produz uma view determinística:
//   threads[thread_id] = { subject, opened_by, participants[], order: [msg_id...], messages[] }
//   quarantined: mensagens cuja thread não tem thread-open correspondente (ainda) — retidas até
//     a abertura chegar; sincronização parcial não pode inventar thread.
//   gaps / forks: diagnósticos não bloqueantes (ver acima).
// Pura: nenhuma leitura de disco, nenhum relógio de parede. Determinística sob permutação da
// entrada — é a propriedade que garante que N réplicas convirjam para o mesmo CHANNEL.md.
export function mergeLogs(messages) {
  const byThread = new Map();
  for (const m of messages) {
    if (!byThread.has(m.thread_id)) byThread.set(m.thread_id, []);
    byThread.get(m.thread_id).push(m);
  }

  const threads = {};
  const quarantined = [];

  for (const [threadId, msgs] of byThread) {
    const opens = msgs.filter((m) => m.kind === 'thread-open').sort((a, b) => {
      const l = (Number(a.lamport) || 0) - (Number(b.lamport) || 0);
      if (l !== 0) return l;
      const s = String(a.sender).localeCompare(String(b.sender));
      if (s !== 0) return s;
      return (Number(a.seq) || 0) - (Number(b.seq) || 0);
    });
    if (!opens.length) {
      for (const m of msgs) quarantined.push({ ...m, quarantine_reason: 'thread-open ausente' });
      continue;
    }
    const opener = opens[0];
    const order = threadOrder(msgs);
    const participants = new Set(Array.isArray(opener.participants) ? opener.participants : []);
    participants.add(opener.sender);
    for (const m of order) if (m.kind === 'join') participants.add(m.sender);
    threads[threadId] = {
      subject: opener.subject || '',
      opened_by: opener.sender,
      opened_at: opener.created_at || null,
      participants: [...participants].sort(),
      order: order.map((m) => m.msg_id),
      messages: order,
    };
  }

  return {
    threads,
    quarantined: quarantined.sort((a, b) => a.thread_id.localeCompare(b.thread_id) || a.sender.localeCompare(b.sender) || (Number(a.seq) || 0) - (Number(b.seq) || 0)),
    gaps: detectGaps(messages),
    forks: detectForks(messages),
  };
}

// --- Validação de envelope (reimplementação à mão do schema — sem ajv em runtime) -------------

export const KINDS = ['note', 'question', 'answer', 'contract-change', 'ack', 'thread-open', 'join'];
export const ACK_FORBIDDEN_KINDS = new Set(['ack', 'answer']);
export const BODY_MAX_BYTES = 2048;
export const BLOB_MAX_BYTES = 65536;
export const IMPORT_MAX_MESSAGES = 200;
export const BODY_REF_RE = /^blobs\/[A-Za-z0-9._-]+$/;
export const ID_RE = /^[a-z0-9][a-z0-9._-]*$/;

// Valida a forma do envelope (campos obrigatórios, enums, tetos). Não decide política de
// import (spoofing, duplicata, quarentena) — isso mora em liaison-ops.sh, que tem o contexto de
// "em qual arquivo esta mensagem chegou". Retorna array de strings de erro (vazio = válido).
export function validateEnvelope(msg) {
  const errors = [];
  if (!msg || typeof msg !== 'object') return ['mensagem não é um objeto'];
  const req = ['msg_id', 'channel', 'thread_id', 'sender', 'seq', 'lamport', 'kind', 'subject', 'created_at', 'content_sha', 'trust'];
  for (const f of req) if (msg[f] === undefined || msg[f] === null || msg[f] === '') errors.push(`campo obrigatório ausente: ${f}`);
  if (msg.kind && !KINDS.includes(msg.kind)) errors.push(`kind inválido: ${msg.kind}`);
  if (msg.requires_ack === undefined) errors.push('campo obrigatório ausente: requires_ack');
  if (msg.requires_ack === true && ACK_FORBIDDEN_KINDS.has(msg.kind)) errors.push(`requires_ack proibido em kind=${msg.kind}`);
  if (msg.kind === 'thread-open' && (!Array.isArray(msg.participants) || msg.participants.length < 1)) {
    errors.push('thread-open requer participants não vazio');
  }
  const hasBody = typeof msg.body === 'string' && msg.body.length > 0;
  const hasBodyRef = typeof msg.body_ref === 'string' && msg.body_ref.length > 0;
  // body e body_ref são ambos opcionais (thread-open/join costumam não ter corpo substantivo,
  // o subject já basta) — mas mutuamente exclusivos quando presentes.
  if (hasBody && hasBodyRef) errors.push('mensagem com body E body_ref (no máximo um é permitido)');
  if (hasBody && Buffer.byteLength(msg.body, 'utf8') > BODY_MAX_BYTES) errors.push(`body excede ${BODY_MAX_BYTES} bytes`);
  if (hasBodyRef && !BODY_REF_RE.test(msg.body_ref)) errors.push(`body_ref fora do padrão permitido: ${msg.body_ref}`);
  if (msg.trust && !['self', 'untrusted-peer'].includes(msg.trust)) errors.push(`trust inválido: ${msg.trust}`);
  return errors;
}
