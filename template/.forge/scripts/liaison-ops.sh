#!/usr/bin/env bash
# liaison-ops.sh — operações deterministas do subsistema liaison: canal de mensagens ORDENADAS
# entre agentes de repositórios distintos (ex.: dono do .proto/gRPC e app cliente), sem drift de
# handoff manual. Onda 1 (núcleo local, SEM transporte — export/import são a primitiva MANUAL de
# sincronização; o transporte automático é a Onda 2).
#
# Modelo (ver rationale completo em lib/liaison-merge.mjs):
#   - Store: um JSONL append-only POR REMETENTE — .forge/liaison/<channel>/log/<sender>.jsonl,
#     um único escritor por arquivo. É esse invariante que torna o merge livre de conflito.
#   - Thread é campo da mensagem (thread_id), não arquivo — várias threads convivem no mesmo log.
#   - Lamport é POR THREAD (não por canal): participação parcial não exige ver threads alheias.
#   - Abertura de thread (kind: thread-open) e entrada de participante (kind: join) são
#     MENSAGENS, não configuração editada por fora.
#   - Visibilidade: a lista de participantes de uma thread ROTEIA (quem é cobrado por ack) — NÃO
#     confina leitura. Com hub compartilhado, quem alcança o transporte lê tudo.
#
# Uso:
#   liaison-ops.sh open     <channel> [--self <id>] --participants <a,b,c>
#   liaison-ops.sh thread   open  <channel> <thread-id> --subject "<txt>" --participants <a,b,c> [--body "<txt>"] [--requires-ack]
#   liaison-ops.sh thread   join  <channel> <thread-id> [--subject "<txt>"] [--body "<txt>"] [--requires-ack]
#   liaison-ops.sh thread   list  <channel>
#   liaison-ops.sh send     <channel> --thread <id> --kind note|question|answer|contract-change \
#                            --subject "<txt>" [--body "<txt>" | --body-file <path>] [--requires-ack] \
#                            [--in-reply-to <msg_id>] [--change <id>] [--contract-files <a,b>] [--commit <sha>]
#   liaison-ops.sh ack      <channel> <msg_id> [--subject "<txt>"]
#   liaison-ops.sh inbox    <channel> [--thread <id>]
#   liaison-ops.sh read     <channel> --upto <msg_id>
#   liaison-ops.sh status   [<channel>]
#   liaison-ops.sh export   <channel> --out <dir>
#   liaison-ops.sh import   <channel> --from <dir>
#   liaison-ops.sh render   <channel>
#
# Determinístico: created_at = data do commit HEAD (nunca wall clock; exceção: state.json —
# cursores locais de leitura, único lugar onde wall clock é aceitável). content_sha cobre o
# envelope canônico menos content_sha/trust. trust é carimbado no IMPORT, nunca pelo remetente.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${FORGE_ROOT:-$(git -C "$(pwd)" rev-parse --show-toplevel 2>/dev/null || pwd)}"
export FORGE_ROOT="$ROOT"
LIBDIR="$SCRIPT_DIR/lib"
LIAISON_DIR="$ROOT/.forge/liaison"
CONFIG="$LIAISON_DIR/liaison.yaml"
TPL="$(cd "$SCRIPT_DIR/.." && pwd)/templates/liaison/CHANNEL.md"

cmd="${1:-}"; shift || true
[ -n "$cmd" ] || { echo "Usage: liaison-ops.sh open|thread|send|inbox|read|ack|status|export|import|render [args...]" >&2; exit 1; }

_git_date() { git -C "$ROOT" log -1 --format=%cI 2>/dev/null || echo ""; }
_id_ok() { printf '%s' "$1" | grep -Eq '^[a-z0-9][a-z0-9._-]*$'; }
_chan_ok() { printf '%s' "$1" | grep -Eq '^[a-z0-9][a-z0-9-]*$'; }

_read_self() {
  [ -f "$CONFIG" ] || { printf ''; return 0; }
  node - "$LIBDIR" "$CONFIG" <<'NODEEOF'
const { readFileSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, cfg] = process.argv;
  const { parseYamlSubset } = await import(pathToFileURL(join(lib, 'yaml-lite.mjs')).href);
  const doc = parseYamlSubset(readFileSync(cfg, 'utf8'));
  process.stdout.write((doc.self && doc.self.id) || '');
})();
NODEEOF
}

_render() {
  local ch="$1"
  local ch_dir="$LIAISON_DIR/$ch"
  [ -f "$TPL" ] || { echo "WARN: template ausente ($TPL) — CHANNEL.md não regenerado" >&2; return 0; }
  local self; self="$(_read_self)"
  LIAISON_ROOT="$ROOT" LIAISON_CHANNEL="$ch" LIAISON_CHANNEL_DIR="$ch_dir" LIAISON_TPL="$TPL" \
    LIAISON_OUT="$ch_dir/CHANNEL.md" LIAISON_SELF="$self" \
    node "$LIBDIR/liaison-render.mjs"
}

case "$cmd" in

# ---------------------------------------------------------------------------------------------
open)
  channel="${1:-}"; shift || true
  [ -n "$channel" ] || { echo "FAIL: <channel> obrigatório" >&2; exit 1; }
  _chan_ok "$channel" || { echo "FAIL: nome de canal inválido '$channel' (use [a-z0-9][a-z0-9-]*)" >&2; exit 1; }
  self_arg=""; participants=""
  while [ $# -gt 0 ]; do case "$1" in
    --self) self_arg="$2"; shift 2 ;;
    --participants) participants="$2"; shift 2 ;;
    *) shift ;;
  esac; done
  [ -n "$participants" ] || { echo "FAIL: --participants obrigatório (lista separada por vírgula)" >&2; exit 1; }
  [ -z "$self_arg" ] || _id_ok "$self_arg" || { echo "FAIL: --self inválido '$self_arg'" >&2; exit 1; }

  mkdir -p "$LIAISON_DIR" "$LIAISON_DIR/$channel/log" "$LIAISON_DIR/$channel/blobs" "$LIAISON_DIR/$channel/conflicts"
  [ -f "$LIAISON_DIR/$channel/state.json" ] || printf '{"cursors":{}}\n' > "$LIAISON_DIR/$channel/state.json"

  IFS=',' read -ra parts <<< "$participants"
  result="$(node - "$LIBDIR" "$CONFIG" "$self_arg" "$channel" "${parts[*]}" <<'NODEEOF'
const { readFileSync, existsSync, writeFileSync, renameSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, cfg, selfArg, channel, partsRaw] = process.argv;
  const { parseYamlSubset } = await import(pathToFileURL(join(lib, 'yaml-lite.mjs')).href);
  const idRe = /^[a-z0-9][a-z0-9._-]*$/;
  const newParts = partsRaw.split(' ').filter(Boolean);
  for (const p of newParts) if (!idRe.test(p)) { console.error(`participante inválido: ${p}`); process.exit(1); }

  let doc = { self: {}, channels: {} };
  if (existsSync(cfg)) doc = parseYamlSubset(readFileSync(cfg, 'utf8'));
  if (!doc.self) doc.self = {};
  if (!doc.channels) doc.channels = {};

  if (selfArg) {
    if (doc.self.id && doc.self.id !== selfArg) {
      console.error(`identidade local já fixada como '${doc.self.id}' — não pode virar '${selfArg}'`);
      process.exit(1);
    }
    doc.self.id = selfArg;
  }
  if (!doc.self.id) { console.error('self.id não configurado — passe --self na primeira chamada de open'); process.exit(1); }
  if (!newParts.includes(doc.self.id)) newParts.push(doc.self.id);

  const existing = (doc.channels[channel] && Array.isArray(doc.channels[channel].participants)) ? doc.channels[channel].participants : [];
  const merged = [...new Set([...existing, ...newParts])].sort();
  doc.channels[channel] = { participants: merged };

  // Serialização determinística — forma controlada (self.id + channels ordenados por nome).
  const lines = ['self:', `  id: ${doc.self.id}`, 'channels:'];
  for (const name of Object.keys(doc.channels).sort()) {
    lines.push(`  ${name}:`, '    participants:');
    for (const p of doc.channels[name].participants.slice().sort()) lines.push(`      - ${p}`);
  }
  const text = lines.join('\n') + '\n';
  writeFileSync(cfg + '.tmp', text);
  renameSync(cfg + '.tmp', cfg);
  console.log(doc.self.id);
  console.log(merged.join(','));
})();
NODEEOF
)"
  self_id="$(printf '%s\n' "$result" | sed -n '1p')"
  final_parts="$(printf '%s\n' "$result" | sed -n '2p')"
  _render "$channel"
  echo "OK open — canal $channel (self=$self_id, participantes: $final_parts)"
  ;;

# ---------------------------------------------------------------------------------------------
thread)
  sub="${1:-}"; shift || true
  channel="${1:-}"; shift || true
  [ -n "$sub" ] && [ -n "$channel" ] || { echo "FAIL: uso: thread open|join|list <channel> [...]" >&2; exit 1; }
  ch_dir="$LIAISON_DIR/$channel"
  [ -d "$ch_dir/log" ] || { echo "FAIL: canal '$channel' não inicializado (rode 'open' primeiro)" >&2; exit 1; }
  self="$(_read_self)"
  [ -n "$self" ] || { echo "FAIL: self não configurado (rode 'open' primeiro)" >&2; exit 1; }

  case "$sub" in
  open)
    thread_id="${1:-}"; shift || true
    [ -n "$thread_id" ] || { echo "FAIL: <thread-id> obrigatório" >&2; exit 1; }
    _chan_ok "$thread_id" || { echo "FAIL: thread-id inválido '$thread_id'" >&2; exit 1; }
    subject=""; body=""; participants=""; requires_ack="false"
    while [ $# -gt 0 ]; do case "$1" in
      --subject) subject="$2"; shift 2 ;;
      --body) body="$2"; shift 2 ;;
      --participants) participants="$2"; shift 2 ;;
      --requires-ack) requires_ack="true"; shift ;;
      *) shift ;;
    esac; done
    [ -n "$subject" ] || { echo "FAIL: --subject obrigatório" >&2; exit 1; }
    [ -n "$participants" ] || { echo "FAIL: --participants obrigatório" >&2; exit 1; }
    IFS=',' read -ra parts <<< "$participants"
    out="$(node - "$LIBDIR" "$ch_dir" "$self" "$channel" "$thread_id" "$subject" "$body" "${parts[*]}" "$requires_ack" "$(_git_date)" <<'NODEEOF'
const { readFileSync, writeFileSync, readdirSync, existsSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, chDir, self, channel, threadId, subject, body, partsRaw, requiresAck, now] = process.argv;
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const logDir = join(chDir, 'log');
  const files = existsSync(logDir) ? readdirSync(logDir).filter((f) => f.endsWith('.jsonl')) : [];
  const all = [];
  for (const f of files) {
    const text = readFileSync(join(logDir, f), 'utf8');
    for (const line of text.split('\n')) { const t = line.trim(); if (t) all.push(JSON.parse(t)); }
  }
  if (all.some((m) => m.thread_id === threadId && m.kind === 'thread-open')) {
    console.error(`thread '${threadId}' já está aberta`); process.exit(1);
  }
  const own = all.filter((m) => m.sender === self);
  const seq = M.nextSeq(own);
  const lamport = 1; // abertura — primeira mensagem lógica da thread
  const participants = [...new Set(partsRaw.split(' ').filter(Boolean))];
  if (!participants.includes(self)) participants.push(self);
  const msgId = `${self}-${String(seq).padStart(4, '0')}`;
  const msg = {
    msg_id: msgId, channel, thread_id: threadId, sender: self, seq, lamport,
    kind: 'thread-open', in_reply_to: null, requires_ack: requiresAck === 'true',
    subject, ...(body ? { body } : {}),
    refs: { change_id: null, contract_files: [], commit: null },
    participants: participants.sort(),
    created_at: now, trust: 'self',
  };
  msg.content_sha = M.computeContentSha(msg);
  const errs = M.validateEnvelope(msg);
  if (errs.length) { console.error('envelope inválido: ' + errs.join('; ')); process.exit(1); }
  own.push(msg);
  const target = join(logDir, `${self}.jsonl`);
  const senderMsgs = all.filter((m) => m.sender === self).concat([msg]).sort((a, b) => a.seq - b.seq);
  writeFileSync(target + '.tmp', senderMsgs.map((m) => JSON.stringify(m)).join('\n') + '\n');
  require('fs').renameSync(target + '.tmp', target);
  process.stdout.write(msgId);
})();
NODEEOF
)"
    _render "$channel"
    echo "OK thread open — $thread_id aberta em $channel por $self ($out)"
    ;;

  join)
    thread_id="${1:-}"; shift || true
    [ -n "$thread_id" ] || { echo "FAIL: <thread-id> obrigatório" >&2; exit 1; }
    subject=""; body=""; requires_ack="false"
    while [ $# -gt 0 ]; do case "$1" in
      --subject) subject="$2"; shift 2 ;;
      --body) body="$2"; shift 2 ;;
      --requires-ack) requires_ack="true"; shift ;;
      *) shift ;;
    esac; done
    [ -n "$subject" ] || subject="$self entrou na thread"
    out="$(node - "$LIBDIR" "$ch_dir" "$self" "$channel" "$thread_id" "$subject" "$body" "$requires_ack" "$(_git_date)" <<'NODEEOF'
const { readFileSync, writeFileSync, readdirSync, existsSync, renameSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, chDir, self, channel, threadId, subject, body, requiresAck, now] = process.argv;
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const logDir = join(chDir, 'log');
  const files = existsSync(logDir) ? readdirSync(logDir).filter((f) => f.endsWith('.jsonl')) : [];
  const all = [];
  for (const f of files) {
    const text = readFileSync(join(logDir, f), 'utf8');
    for (const line of text.split('\n')) { const t = line.trim(); if (t) all.push(JSON.parse(t)); }
  }
  const threadMsgs = all.filter((m) => m.thread_id === threadId);
  if (!threadMsgs.some((m) => m.kind === 'thread-open')) {
    console.error(`thread '${threadId}' desconhecida localmente (aguarde o thread-open chegar)`); process.exit(1);
  }
  const own = all.filter((m) => m.sender === self);
  const seq = M.nextSeq(own);
  const lamport = M.nextLamport(threadMsgs);
  const msgId = `${self}-${String(seq).padStart(4, '0')}`;
  const msg = {
    msg_id: msgId, channel, thread_id: threadId, sender: self, seq, lamport,
    kind: 'join', in_reply_to: null, requires_ack: requiresAck === 'true',
    subject, ...(body ? { body } : {}),
    refs: { change_id: null, contract_files: [], commit: null },
    created_at: now, trust: 'self',
  };
  msg.content_sha = M.computeContentSha(msg);
  const errs = M.validateEnvelope(msg);
  if (errs.length) { console.error('envelope inválido: ' + errs.join('; ')); process.exit(1); }
  const target = join(logDir, `${self}.jsonl`);
  const senderMsgs = own.concat([msg]).sort((a, b) => a.seq - b.seq);
  writeFileSync(target + '.tmp', senderMsgs.map((m) => JSON.stringify(m)).join('\n') + '\n');
  renameSync(target + '.tmp', target);
  process.stdout.write(msgId);
})();
NODEEOF
)"
    _render "$channel"
    echo "OK thread join — $self entrou em $thread_id ($out)"
    ;;

  list)
    node - "$LIBDIR" "$ch_dir" <<'NODEEOF'
const { readFileSync, readdirSync, existsSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, chDir] = process.argv;
  const { mergeLogs } = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const logDir = join(chDir, 'log');
  const files = existsSync(logDir) ? readdirSync(logDir).filter((f) => f.endsWith('.jsonl')) : [];
  const all = [];
  for (const f of files) {
    const text = readFileSync(join(logDir, f), 'utf8');
    for (const line of text.split('\n')) { const t = line.trim(); if (t) all.push(JSON.parse(t)); }
  }
  const { threads } = mergeLogs(all);
  const ids = Object.keys(threads).sort();
  if (!ids.length) { console.log('(nenhuma thread aberta)'); return; }
  for (const id of ids) {
    const t = threads[id];
    console.log(`${id} — ${t.subject || '(sem assunto)'} · participantes: ${t.participants.join(', ')} · ${t.order.length} mensagem(ns)`);
  }
})();
NODEEOF
    ;;

  *) echo "FAIL: subcomando desconhecido 'thread $sub'" >&2; exit 1 ;;
  esac
  ;;

# ---------------------------------------------------------------------------------------------
send)
  channel="${1:-}"; shift || true
  [ -n "$channel" ] || { echo "FAIL: <channel> obrigatório" >&2; exit 1; }
  ch_dir="$LIAISON_DIR/$channel"
  [ -d "$ch_dir/log" ] || { echo "FAIL: canal '$channel' não inicializado (rode 'open' primeiro)" >&2; exit 1; }
  self="$(_read_self)"
  [ -n "$self" ] || { echo "FAIL: self não configurado (rode 'open' primeiro)" >&2; exit 1; }

  thread_id=""; kind=""; subject=""; body=""; body_file=""; requires_ack="false"
  in_reply_to=""; change=""; contract_files=""; commit=""
  while [ $# -gt 0 ]; do case "$1" in
    --thread) thread_id="$2"; shift 2 ;;
    --kind) kind="$2"; shift 2 ;;
    --subject) subject="$2"; shift 2 ;;
    --body) body="$2"; shift 2 ;;
    --body-file) body_file="$2"; shift 2 ;;
    --requires-ack) requires_ack="true"; shift ;;
    --in-reply-to) in_reply_to="$2"; shift 2 ;;
    --change) change="$2"; shift 2 ;;
    --contract-files) contract_files="$2"; shift 2 ;;
    --commit) commit="$2"; shift 2 ;;
    *) shift ;;
  esac; done
  [ -n "$thread_id" ] || { echo "FAIL: --thread obrigatório" >&2; exit 1; }
  [ -n "$kind" ] || { echo "FAIL: --kind obrigatório (note|question|answer|contract-change)" >&2; exit 1; }
  case "$kind" in
    note|question|answer|contract-change) ;;
    ack|thread-open|join) echo "FAIL: kind '$kind' tem subcomando dedicado (ack / thread open / thread join)" >&2; exit 1 ;;
    *) echo "FAIL: kind inválido '$kind'" >&2; exit 1 ;;
  esac
  [ -n "$subject" ] || { echo "FAIL: --subject obrigatório" >&2; exit 1; }
  if [ -n "$body" ] && [ -n "$body_file" ]; then echo "FAIL: use --body OU --body-file, não os dois" >&2; exit 1; fi
  if [ "$kind" = "answer" ] && [ "$requires_ack" = "true" ]; then
    echo "FAIL: requires_ack proibido em kind=answer" >&2; exit 1
  fi

  body_ref=""
  if [ -n "$body_file" ]; then
    [ -f "$body_file" ] || { echo "FAIL: --body-file '$body_file' não encontrado" >&2; exit 1; }
    mkdir -p "$ch_dir/blobs"
    blob_out="$(node - "$LIBDIR" "$body_file" "$ch_dir/blobs" <<'NODEEOF'
const { readFileSync, writeFileSync, existsSync } = require('fs');
const { join, basename } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, file, blobsDir] = process.argv;
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const buf = readFileSync(file);
  if (buf.length > M.BLOB_MAX_BYTES) { console.error(`blob excede ${M.BLOB_MAX_BYTES} bytes (${buf.length})`); process.exit(1); }
  const sha = M.sha256Hex(buf.toString('binary'));
  const safeBase = basename(file).replace(/[^A-Za-z0-9._-]/g, '_');
  const name = `${sha}-${safeBase}`;
  const dest = join(blobsDir, name);
  if (!existsSync(dest)) writeFileSync(dest, buf);
  process.stdout.write(`blobs/${name}`);
})();
NODEEOF
)"
    body_ref="$blob_out"
    body=""
  fi

  IFS=',' read -ra cfiles <<< "${contract_files:-}"
  out="$(node - "$LIBDIR" "$ch_dir" "$self" "$channel" "$thread_id" "$kind" "$subject" "$body" "$body_ref" \
    "$requires_ack" "${in_reply_to:-}" "${change:-}" "${cfiles[*]:-}" "${commit:-}" "$(_git_date)" <<'NODEEOF'
const { readFileSync, writeFileSync, readdirSync, existsSync, renameSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, chDir, self, channel, threadId, kind, subject, body, bodyRef,
    requiresAck, inReplyTo, change, cfilesRaw, commit, now] = process.argv;
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const logDir = join(chDir, 'log');
  const files = existsSync(logDir) ? readdirSync(logDir).filter((f) => f.endsWith('.jsonl')) : [];
  const all = [];
  for (const f of files) {
    const text = readFileSync(join(logDir, f), 'utf8');
    for (const line of text.split('\n')) { const t = line.trim(); if (t) all.push(JSON.parse(t)); }
  }
  const threadMsgs = all.filter((m) => m.thread_id === threadId);
  if (!threadMsgs.some((m) => m.kind === 'thread-open')) {
    console.error(`thread '${threadId}' desconhecida localmente (abra ou aguarde o thread-open chegar)`); process.exit(1);
  }
  const own = all.filter((m) => m.sender === self);
  const seq = M.nextSeq(own);
  const lamport = M.nextLamport(threadMsgs);
  const msgId = `${self}-${String(seq).padStart(4, '0')}`;
  const cfiles = cfilesRaw ? cfilesRaw.split(' ').filter(Boolean) : [];
  const msg = {
    msg_id: msgId, channel, thread_id: threadId, sender: self, seq, lamport,
    kind, in_reply_to: inReplyTo || null, requires_ack: requiresAck === 'true',
    subject, ...(body ? { body } : {}), ...(bodyRef ? { body_ref: bodyRef } : {}),
    refs: { change_id: change || null, contract_files: cfiles, commit: commit || null },
    created_at: now, trust: 'self',
  };
  msg.content_sha = M.computeContentSha(msg);
  const errs = M.validateEnvelope(msg);
  if (errs.length) { console.error('envelope inválido: ' + errs.join('; ')); process.exit(1); }
  const target = join(logDir, `${self}.jsonl`);
  const senderMsgs = own.concat([msg]).sort((a, b) => a.seq - b.seq);
  writeFileSync(target + '.tmp', senderMsgs.map((m) => JSON.stringify(m)).join('\n') + '\n');
  renameSync(target + '.tmp', target);
  process.stdout.write(msgId);
})();
NODEEOF
)"
  _render "$channel"
  echo "OK send — $out em $thread_id ($kind)"
  ;;

# ---------------------------------------------------------------------------------------------
ack)
  channel="${1:-}"; shift || true
  msg_id="${1:-}"; shift || true
  [ -n "$channel" ] && [ -n "$msg_id" ] || { echo "FAIL: uso: ack <channel> <msg_id> [--subject <txt>]" >&2; exit 1; }
  ch_dir="$LIAISON_DIR/$channel"
  [ -d "$ch_dir/log" ] || { echo "FAIL: canal '$channel' não inicializado" >&2; exit 1; }
  self="$(_read_self)"
  [ -n "$self" ] || { echo "FAIL: self não configurado" >&2; exit 1; }
  subject=""
  while [ $# -gt 0 ]; do case "$1" in --subject) subject="$2"; shift 2 ;; *) shift ;; esac; done

  out="$(node - "$LIBDIR" "$ch_dir" "$self" "$channel" "$msg_id" "$subject" "$(_git_date)" <<'NODEEOF'
const { readFileSync, writeFileSync, readdirSync, existsSync, renameSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, chDir, self, channel, targetId, subjectArg, now] = process.argv;
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const logDir = join(chDir, 'log');
  const files = existsSync(logDir) ? readdirSync(logDir).filter((f) => f.endsWith('.jsonl')) : [];
  const all = [];
  for (const f of files) {
    const text = readFileSync(join(logDir, f), 'utf8');
    for (const line of text.split('\n')) { const t = line.trim(); if (t) all.push(JSON.parse(t)); }
  }
  const target = all.find((m) => m.msg_id === targetId);
  if (!target) { console.error(`mensagem '${targetId}' desconhecida localmente`); process.exit(1); }
  const threadId = target.thread_id;
  const threadMsgs = all.filter((m) => m.thread_id === threadId);
  const own = all.filter((m) => m.sender === self);
  const seq = M.nextSeq(own);
  const lamport = M.nextLamport(threadMsgs);
  const msgId = `${self}-${String(seq).padStart(4, '0')}`;
  const subject = subjectArg || `ack: ${target.subject || target.msg_id}`;
  const msg = {
    msg_id: msgId, channel, thread_id: threadId, sender: self, seq, lamport,
    kind: 'ack', in_reply_to: targetId, requires_ack: false,
    subject,
    refs: { change_id: null, contract_files: [], commit: null },
    created_at: now, trust: 'self',
  };
  msg.content_sha = M.computeContentSha(msg);
  const errs = M.validateEnvelope(msg);
  if (errs.length) { console.error('envelope inválido: ' + errs.join('; ')); process.exit(1); }
  const targetFile = join(logDir, `${self}.jsonl`);
  const senderMsgs = own.concat([msg]).sort((a, b) => a.seq - b.seq);
  writeFileSync(targetFile + '.tmp', senderMsgs.map((m) => JSON.stringify(m)).join('\n') + '\n');
  renameSync(targetFile + '.tmp', targetFile);
  process.stdout.write(msgId);
})();
NODEEOF
)"
  _render "$channel"
  echo "OK ack — $out confirma $msg_id"
  ;;

# ---------------------------------------------------------------------------------------------
inbox)
  channel="${1:-}"; shift || true
  [ -n "$channel" ] || { echo "FAIL: <channel> obrigatório" >&2; exit 1; }
  ch_dir="$LIAISON_DIR/$channel"
  [ -d "$ch_dir/log" ] || { echo "FAIL: canal '$channel' não inicializado" >&2; exit 1; }
  filter_thread=""
  while [ $# -gt 0 ]; do case "$1" in --thread) filter_thread="$2"; shift 2 ;; *) shift ;; esac; done

  node - "$LIBDIR" "$ch_dir" "$filter_thread" <<'NODEEOF'
const { readFileSync, readdirSync, existsSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, chDir, filterThread] = process.argv;
  const { mergeLogs } = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const logDir = join(chDir, 'log');
  const files = existsSync(logDir) ? readdirSync(logDir).filter((f) => f.endsWith('.jsonl')) : [];
  const all = [];
  for (const f of files) {
    const text = readFileSync(join(logDir, f), 'utf8');
    for (const line of text.split('\n')) { const t = line.trim(); if (t) all.push(JSON.parse(t)); }
  }
  const { threads } = mergeLogs(all);
  const state = existsSync(join(chDir, 'state.json')) ? JSON.parse(readFileSync(join(chDir, 'state.json'), 'utf8')) : { cursors: {} };
  const cursors = state.cursors || {};
  let ids = Object.keys(threads).sort();
  if (filterThread) ids = ids.filter((id) => id === filterThread);
  if (!ids.length) { console.log('(nenhuma thread)'); return; }
  for (const id of ids) {
    const t = threads[id];
    const cursorMsgId = cursors[id] && cursors[id].msg_id;
    const cursorIdx = cursorMsgId ? t.order.indexOf(cursorMsgId) : -1;
    const unread = t.messages.slice(cursorIdx + 1);
    console.log(`${id} — ${t.subject || '(sem assunto)'}: ${unread.length} não lida(s)`);
    for (const m of unread) console.log(`  ${m.msg_id} [${m.kind}] \`${m.sender}\` — ${m.subject || '(sem assunto)'}`);
  }
})();
NODEEOF
  ;;

# ---------------------------------------------------------------------------------------------
read)
  channel="${1:-}"; shift || true
  [ -n "$channel" ] || { echo "FAIL: <channel> obrigatório" >&2; exit 1; }
  ch_dir="$LIAISON_DIR/$channel"
  [ -d "$ch_dir/log" ] || { echo "FAIL: canal '$channel' não inicializado" >&2; exit 1; }
  upto=""
  while [ $# -gt 0 ]; do case "$1" in --upto) upto="$2"; shift 2 ;; *) shift ;; esac; done
  [ -n "$upto" ] || { echo "FAIL: --upto <msg_id> obrigatório" >&2; exit 1; }

  now_wall="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  out="$(node - "$LIBDIR" "$ch_dir" "$upto" "$now_wall" <<'NODEEOF'
const { readFileSync, writeFileSync, readdirSync, existsSync, renameSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, chDir, upto, nowWall] = process.argv;
  const { mergeLogs } = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const logDir = join(chDir, 'log');
  const files = existsSync(logDir) ? readdirSync(logDir).filter((f) => f.endsWith('.jsonl')) : [];
  const all = [];
  for (const f of files) {
    const text = readFileSync(join(logDir, f), 'utf8');
    for (const line of text.split('\n')) { const t = line.trim(); if (t) all.push(JSON.parse(t)); }
  }
  const { threads } = mergeLogs(all);
  const threadId = Object.keys(threads).find((id) => threads[id].order.includes(upto));
  if (!threadId) { console.error(`mensagem '${upto}' desconhecida localmente (fora de qualquer thread resolvida)`); process.exit(1); }
  const idx = threads[threadId].order.indexOf(upto);
  const stateFile = join(chDir, 'state.json');
  const state = existsSync(stateFile) ? JSON.parse(readFileSync(stateFile, 'utf8')) : { cursors: {} };
  if (!state.cursors) state.cursors = {};
  const prev = state.cursors[threadId];
  if (prev && threads[threadId].order.includes(prev.msg_id)) {
    const prevIdx = threads[threadId].order.indexOf(prev.msg_id);
    if (idx < prevIdx) { console.error(`cursor não pode regredir (atual: ${prev.msg_id}, pedido: ${upto})`); process.exit(1); }
  }
  state.cursors[threadId] = { msg_id: upto, read_at: nowWall };
  writeFileSync(stateFile + '.tmp', JSON.stringify(state, null, 2) + '\n');
  renameSync(stateFile + '.tmp', stateFile);
  process.stdout.write(threadId);
})();
NODEEOF
)"
  echo "OK read — cursor de $out avançado até $upto"
  ;;

# ---------------------------------------------------------------------------------------------
status)
  channel="${1:-}"
  if [ -n "$channel" ]; then
    ch_dir="$LIAISON_DIR/$channel"
    [ -d "$ch_dir/log" ] || { echo "FAIL: canal '$channel' não inicializado" >&2; exit 1; }
    node - "$LIBDIR" "$ch_dir" "$channel" <<'NODEEOF'
const { readFileSync, readdirSync, existsSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, chDir, channel] = process.argv;
  const { mergeLogs } = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const logDir = join(chDir, 'log');
  const files = existsSync(logDir) ? readdirSync(logDir).filter((f) => f.endsWith('.jsonl')) : [];
  const all = [];
  for (const f of files) {
    const text = readFileSync(join(logDir, f), 'utf8');
    for (const line of text.split('\n')) { const t = line.trim(); if (t) all.push(JSON.parse(t)); }
  }
  const { threads, quarantined, gaps, forks } = mergeLogs(all);
  const state = existsSync(join(chDir, 'state.json')) ? JSON.parse(readFileSync(join(chDir, 'state.json'), 'utf8')) : { cursors: {} };
  const cursors = state.cursors || {};
  let unread = 0;
  for (const id of Object.keys(threads)) {
    const cur = cursors[id] && cursors[id].msg_id;
    const idx = cur ? threads[id].order.indexOf(cur) : -1;
    unread += threads[id].order.length - (idx + 1);
  }
  const diag = gaps.length || forks.length ? ` · ${gaps.length} buraco(s) · ${forks.length} fork(s)` : '';
  console.log(`LIAISON/${channel}: ${Object.keys(threads).length} thread(s) · ${unread} não lida(s) · ${quarantined.length} em quarentena${diag}`);
})();
NODEEOF
  else
    self="$(_read_self)"
    if [ ! -d "$LIAISON_DIR" ]; then echo "LIAISON: não inicializado"; exit 0; fi
    channels=()
    while IFS= read -r d; do [ -n "$d" ] && channels+=("$(basename "$d")"); done \
      < <(find "$LIAISON_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | LC_ALL=C sort)
    if [ "${#channels[@]}" -eq 0 ]; then echo "LIAISON: self=${self:-?} · 0 canal(is)"; exit 0; fi
    node - "$LIBDIR" "$LIAISON_DIR" "${channels[*]}" "$self" <<'NODEEOF'
const { readFileSync, readdirSync, existsSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, liaisonDir, channelsRaw, self] = process.argv;
  const { mergeLogs } = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const channels = channelsRaw.split(' ').filter(Boolean);
  let threadsTotal = 0, unreadTotal = 0, quarantinedTotal = 0;
  for (const channel of channels) {
    const chDir = join(liaisonDir, channel);
    const logDir = join(chDir, 'log');
    const files = existsSync(logDir) ? readdirSync(logDir).filter((f) => f.endsWith('.jsonl')) : [];
    const all = [];
    for (const f of files) {
      const text = readFileSync(join(logDir, f), 'utf8');
      for (const line of text.split('\n')) { const t = line.trim(); if (t) all.push(JSON.parse(t)); }
    }
    const { threads, quarantined } = mergeLogs(all);
    const state = existsSync(join(chDir, 'state.json')) ? JSON.parse(readFileSync(join(chDir, 'state.json'), 'utf8')) : { cursors: {} };
    const cursors = state.cursors || {};
    threadsTotal += Object.keys(threads).length;
    quarantinedTotal += quarantined.length;
    for (const id of Object.keys(threads)) {
      const cur = cursors[id] && cursors[id].msg_id;
      const idx = cur ? threads[id].order.indexOf(cur) : -1;
      unreadTotal += threads[id].order.length - (idx + 1);
    }
  }
  console.log(`LIAISON: self=${self || '?'} · ${channels.length} canal(is) · ${threadsTotal} thread(s) · ${unreadTotal} não lida(s) · ${quarantinedTotal} em quarentena`);
})();
NODEEOF
  fi
  ;;

# ---------------------------------------------------------------------------------------------
export)
  channel="${1:-}"; shift || true
  [ -n "$channel" ] || { echo "FAIL: <channel> obrigatório" >&2; exit 1; }
  ch_dir="$LIAISON_DIR/$channel"
  [ -d "$ch_dir/log" ] || { echo "FAIL: canal '$channel' não inicializado" >&2; exit 1; }
  out_dir=""
  while [ $# -gt 0 ]; do case "$1" in --out) out_dir="$2"; shift 2 ;; *) shift ;; esac; done
  [ -n "$out_dir" ] || { echo "FAIL: --out <dir> obrigatório" >&2; exit 1; }
  mkdir -p "$out_dir/log" "$out_dir/blobs"
  if [ -d "$ch_dir/log" ]; then find "$ch_dir/log" -type f -name '*.jsonl' -exec cp {} "$out_dir/log/" \; ; fi
  if [ -d "$ch_dir/blobs" ]; then find "$ch_dir/blobs" -type f -exec cp {} "$out_dir/blobs/" \; 2>/dev/null || true; fi
  n="$(find "$out_dir/log" -type f -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' ')"
  echo "OK export — canal $channel exportado para $out_dir ($n arquivo(s) de log)"
  ;;

# ---------------------------------------------------------------------------------------------
import)
  channel="${1:-}"; shift || true
  [ -n "$channel" ] || { echo "FAIL: <channel> obrigatório" >&2; exit 1; }
  ch_dir="$LIAISON_DIR/$channel"
  [ -d "$ch_dir/log" ] || { echo "FAIL: canal '$channel' não inicializado (rode 'open' primeiro)" >&2; exit 1; }
  from_dir=""
  while [ $# -gt 0 ]; do case "$1" in --from) from_dir="$2"; shift 2 ;; *) shift ;; esac; done
  [ -n "$from_dir" ] || { echo "FAIL: --from <dir> obrigatório" >&2; exit 1; }
  [ -d "$from_dir/log" ] || { echo "FAIL: '$from_dir/log' não encontrado" >&2; exit 1; }
  self="$(_read_self)"
  [ -n "$self" ] || { echo "FAIL: self não configurado" >&2; exit 1; }
  mkdir -p "$ch_dir/conflicts" "$ch_dir/blobs"

  out="$(node - "$LIBDIR" "$ch_dir" "$from_dir" "$self" "$channel" <<'NODEEOF'
const { readFileSync, writeFileSync, readdirSync, existsSync, renameSync, copyFileSync } = require('fs');
const { join, basename } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, chDir, fromDir, self, channel] = process.argv;
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const logDir = join(chDir, 'log');
  const conflictsDir = join(chDir, 'conflicts');
  const blobsDir = join(chDir, 'blobs');
  const fromLog = join(fromDir, 'log');
  const fromBlobs = join(fromDir, 'blobs');

  const readJsonl = (p) => {
    let text; try { text = readFileSync(p, 'utf8'); } catch { return []; }
    const out = [];
    for (const line of text.split('\n')) { const t = line.trim(); if (t) { try { out.push(JSON.parse(t)); } catch { /* linha corrompida ignorada */ } } }
    return out;
  };
  const writeConflict = (msgId, reason, incoming, existing) => {
    writeFileSync(join(conflictsDir, `${msgId}.json`), JSON.stringify({ msg_id: msgId, reason, incoming, existing: existing || null }, null, 2) + '\n');
  };

  const bundleFiles = readdirSync(fromLog).filter((f) => f.endsWith('.jsonl'));
  // Pré-varredura: junta candidatos válidos por arquivo, aplicando as regras de import ANTES de
  // escrever qualquer coisa (import é atômico à luz do teto de 200 msgs por chamada).
  const perSenderNew = new Map(); // sender -> [msg,...] a acrescentar
  let acceptedCount = 0, dupCount = 0, conflictCount = 0;
  const conflictsToWrite = [];

  for (const file of bundleFiles) {
    const fileSender = basename(file, '.jsonl');
    if (!M.ID_RE.test(fileSender)) { continue; }
    if (fileSender === self) continue; // nunca importamos nosso próprio arquivo de fora — somos a fonte da verdade dele
    const incoming = readJsonl(join(fromLog, file));
    const existing = existsSync(join(logDir, file)) ? readJsonl(join(logDir, file)) : [];
    const existingById = new Map(existing.map((m) => [m.msg_id, m]));

    for (const raw of incoming) {
      // spoofing: sender != nome do arquivo em que chegou
      if (raw.sender !== fileSender) {
        conflictsToWrite.push([raw.msg_id || `${file}:unknown`, `sender declarado ('${raw.sender}') diverge do arquivo ('${fileSender}')`, raw, existingById.get(raw.msg_id)]);
        conflictCount++; continue;
      }
      // spoofing: mensagem se declara com o self.id local vinda de fora
      if (raw.sender === self) {
        conflictsToWrite.push([raw.msg_id || `${file}:self-spoof`, `mensagem se declara sender='${self}' (identidade local) vinda de fora`, raw, null]);
        conflictCount++; continue;
      }
      const errs = M.validateEnvelope(raw);
      if (errs.length) {
        conflictsToWrite.push([raw.msg_id || `${file}:invalid`, `envelope inválido: ${errs.join('; ')}`, raw, existingById.get(raw.msg_id)]);
        conflictCount++; continue;
      }
      const recomputed = M.computeContentSha(raw);
      if (recomputed !== raw.content_sha) {
        conflictsToWrite.push([raw.msg_id, `content_sha não confere (declarado ${raw.content_sha}, recalculado ${recomputed})`, raw, existingById.get(raw.msg_id)]);
        conflictCount++; continue;
      }
      const already = existingById.get(raw.msg_id);
      if (already) {
        if (already.content_sha === raw.content_sha) { dupCount++; continue; } // duplicata: no-op silencioso
        conflictsToWrite.push([raw.msg_id, 'content_sha diverge para o mesmo msg_id', raw, already]);
        conflictCount++; continue;
      }
      // body_ref: valida path e existência do blob no bundle
      if (raw.body_ref) {
        if (!M.BODY_REF_RE.test(raw.body_ref)) {
          conflictsToWrite.push([raw.msg_id, `body_ref fora do padrão permitido: ${raw.body_ref}`, raw, null]);
          conflictCount++; continue;
        }
        const blobName = raw.body_ref.slice('blobs/'.length);
        const srcBlob = join(fromBlobs, blobName);
        if (!existsSync(srcBlob)) {
          conflictsToWrite.push([raw.msg_id, `blob referenciado ausente no bundle: ${raw.body_ref}`, raw, null]);
          conflictCount++; continue;
        }
        const stat = require('fs').statSync(srcBlob);
        if (stat.size > M.BLOB_MAX_BYTES) {
          conflictsToWrite.push([raw.msg_id, `blob excede ${M.BLOB_MAX_BYTES} bytes`, raw, null]);
          conflictCount++; continue;
        }
      }
      acceptedCount++;
      if (!perSenderNew.has(fileSender)) perSenderNew.set(fileSender, { toAdd: [], srcFile: file });
      perSenderNew.get(fileSender).toAdd.push(raw);
    }
  }

  if (acceptedCount > M.IMPORT_MAX_MESSAGES) {
    console.error(`import excede o teto de ${M.IMPORT_MAX_MESSAGES} mensagens por chamada (${acceptedCount}) — nada foi aplicado`);
    process.exit(1);
  }

  // Fase de escrita — atômica por arquivo de remetente.
  for (const [sender, { toAdd, srcFile }] of perSenderNew) {
    const target = join(logDir, `${sender}.jsonl`);
    const existing = existsSync(target) ? readJsonl(target) : [];
    const merged = existing.concat(toAdd.map((m) => ({ ...m, trust: 'untrusted-peer' })));
    const byId = new Map(merged.map((m) => [m.msg_id, m]));
    const finalMsgs = [...byId.values()].sort((a, b) => a.seq - b.seq);
    writeFileSync(target + '.tmp', finalMsgs.map((m) => JSON.stringify(m)).join('\n') + '\n');
    renameSync(target + '.tmp', target);
    for (const m of toAdd) {
      if (m.body_ref) {
        const blobName = m.body_ref.slice('blobs/'.length);
        const dest = join(blobsDir, blobName);
        if (!existsSync(dest)) copyFileSync(join(fromBlobs, blobName), dest);
      }
    }
  }
  for (const [msgId, reason, incoming, existing] of conflictsToWrite) writeConflict(msgId, reason, incoming, existing);

  // Quarentena recalculada, apenas informativa (não persistida).
  const files2 = existsSync(logDir) ? readdirSync(logDir).filter((f) => f.endsWith('.jsonl')) : [];
  const all2 = [];
  for (const f of files2) for (const m of readJsonl(join(logDir, f))) all2.push(m);
  const { quarantined } = M.mergeLogs(all2);

  process.stdout.write(`${acceptedCount} ${dupCount} ${conflictCount} ${quarantined.length}`);
})();
NODEEOF
)"
  IFS=' ' read -r n_new n_dup n_conf n_quar <<< "$out"
  _render "$channel"
  echo "OK import — $n_new nova(s), $n_dup duplicata(s) (no-op), $n_conf conflito(s), $n_quar em quarentena"
  ;;

# ---------------------------------------------------------------------------------------------
render)
  channel="${1:-}"
  [ -n "$channel" ] || { echo "FAIL: <channel> obrigatório" >&2; exit 1; }
  ch_dir="$LIAISON_DIR/$channel"
  [ -d "$ch_dir/log" ] || { echo "FAIL: canal '$channel' não inicializado" >&2; exit 1; }
  _render "$channel"
  echo "OK $ch_dir/CHANNEL.md"
  ;;

*)
  echo "FAIL: comando desconhecido '$cmd'" >&2; exit 1
  ;;
esac
