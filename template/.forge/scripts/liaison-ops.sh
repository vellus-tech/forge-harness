#!/usr/bin/env bash
# liaison-ops.sh — operações deterministas do subsistema liaison: canal de mensagens ORDENADAS
# entre agentes de repositórios distintos (ex.: dono do .proto/gRPC e app cliente), sem drift de
# handoff manual. Onda 2: transporte plugável (`transport` + `sync`) sobre o núcleo da Onda 1 —
# export/import continuam sendo a primitiva manual, e o transporte `manual` é literalmente ela.
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
#   liaison-ops.sh ack      <channel> <msg_id> [--subject "<txt>"] [--body "<txt>" | --body-file <path>] \
#                            [--reason wont-adopt|acknowledged]
#   liaison-ops.sh inbox    <channel> [--thread <id>]
#   liaison-ops.sh read     <channel> --upto <msg_id>
#   liaison-ops.sh status   [<channel>]
#   liaison-ops.sh export   <channel> --out <dir>
#   liaison-ops.sh import   <channel> --from <dir>
#   liaison-ops.sh conflicts list <channel>
#   liaison-ops.sh conflicts resolve <channel> <sender> <seq>
#   liaison-ops.sh peer     set <channel> <participante> --path <dir>
#   liaison-ops.sh peer-path <channel> <participante>
#   liaison-ops.sh transport set   <channel> --kind manual|fs|git|gh [--path <dir>] [--remote <url>] [--branch <b>]
#   liaison-ops.sh transport show  <channel>
#   liaison-ops.sh transport probe <channel>
#   liaison-ops.sh sync     <channel> [--push-only | --pull-only]
#   liaison-ops.sh render   <channel>
#
# TRANSPORTE (Onda 2): plugável, em lib/transports/<kind>.sh, com o contrato t_probe/t_push/t_pull.
# Move ARQUIVOS OPACOS — nunca parseia mensagem, nunca sabe o que é thread, nunca decide merge. A
# política de merge é uma só, em lib/liaison-import.mjs, compartilhada por `import` e `sync`: se
# houvesse uma por porta de entrada, a mais frouxa viraria o caminho de menor resistência.
# Topologia de hub único por canal (cada participante publica o próprio log e puxa os N-1
# restantes) — configuração cresce como N, não como N².
#
# Determinístico: created_at = data do commit HEAD (nunca wall clock; exceção: state.json —
# cursores locais de leitura, único lugar onde wall clock é aceitável). content_sha cobre o
# envelope canônico menos content_sha/trust. trust é carimbado no IMPORT, nunca pelo remetente —
# e, por ser excluído do hash, é o único campo que verificação por integridade não alcança: a
# derivação dele a partir do arquivo que carrega a linha é conferida por lib/liaison-trust.mjs,
# chamada no pre-push por check-liaison-acks.sh.
#
# Nenhum subcomando aceita flag que não conheça: argumento desconhecido REPROVA nomeando a flag,
# o subcomando e as flags aceitas por ele (ver _reject_unknown). O `ack` aceita corpo (--body /
# --body-file, issue #83) pelo MESMO caminho do `send` — _scan_secret_or_fail/_write_body_blob são
# funções compartilhadas, não uma segunda implementação: duas portas para o mesmo efeito é
# exatamente o que este comentário avisava antes de existirem funções para reusar. Medido em
# campo: 1138 de 1138 mensagens kind=ack sem body_ref, porque a ferramenta não oferecia onde
# escrever — o ack é, por desenho do protocolo, a mensagem que carrega POSIÇÃO (concorda/discorda/
# não se aplica), e sem corpo um recibo não informa nada a quem esperava a decisão.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ROOT é o CHECKOUT PRINCIPAL, nunca o worktree de onde o script foi chamado. O canal do liaison é
# estado durável de PROJETO, não de branch — mesma classe do ledger, e a mesma rule
# (conventions/machinery-propagation.md). Resolvido por `--show-toplevel`, cada worktree linkado
# ganha a SUA cópia de `log/<self>.jsonl` com o SEU contador de seq: é literalmente a causa-raiz da
# issue #36 ("duas cópias do mesmo log de remetente escrevendo em paralelo, cada uma com seu
# contador local"), com a agravante de que a colisão só aparece do outro lado, no import de quem
# recebe as duas versões da mesma posição. O invariante do store é UM ESCRITOR por arquivo de
# remetente; um único ROOT por clone é o que o torna verdadeiro dentro do clone.
#
# `--git-common-dir` devolve o `.git` compartilhado por TODOS os worktrees; o diretório que o
# contém é o tronco. `--path-format=absolute` é necessário porque, no próprio checkout principal,
# `--git-common-dir` devolveria `.git` relativo — e `dirname .git` daria `.`, que é justamente o
# worktree corrente que se quer evitar. Mesmo idioma de ledger-ops.sh e de hooks/git/pre-commit.
# Resolução do checkout principal e o aviso de divergência vivem em lib/forge-root.sh — UM sítio,
# consumido pelos quatro scripts que antes carregavam este corpo copiado (LDG-0068). Delegação em
# alvo ausente é erro: sem a lib, o script não segue resolvendo ROOT por conta própria.
if [ -f "$SCRIPT_DIR/lib/forge-root.sh" ]; then
  # shellcheck source=lib/forge-root.sh
  . "$SCRIPT_DIR/lib/forge-root.sh"
else
  echo "FAIL: $SCRIPT_DIR/lib/forge-root.sh ausente — é a resolução única do checkout principal; sem ela o script gravaria estado durável num lugar que ninguém declarou." >&2
  exit 1
fi
ROOT="$(forge_resolve_root)"
export FORGE_ROOT="$ROOT"
LIBDIR="$SCRIPT_DIR/lib"
LIAISON_DIR="$ROOT/.forge/liaison"
CONFIG="$LIAISON_DIR/liaison.yaml"
TPL="$(cd "$SCRIPT_DIR/.." && pwd)/templates/liaison/CHANNEL.md"

cmd="${1:-}"; shift || true
[ -n "$cmd" ] || { echo "Usage: liaison-ops.sh open|thread|send|inbox|read|ack|status|export|import|conflicts|peer|peer-path|transport|sync|render [args...]" >&2; exit 1; }

_git_date() { git -C "$ROOT" log -1 --format=%cI 2>/dev/null || echo ""; }
_id_ok() { printf '%s' "$1" | grep -Eq '^[a-z0-9][a-z0-9._-]*$'; }
_chan_ok() { printf '%s' "$1" | grep -Eq '^[a-z0-9][a-z0-9-]*$'; }

# Argumento que o subcomando não conhece REPROVA — nunca é descartado. Todo parser de flags
# terminava num caso curinga que apenas descartava o argumento, e o descarte silencioso publicava
# mensagem incompleta com rc 0 e sem aviso: um `ack ... --body-file corpo.md` (o `--body-file`
# só existe no `send`) publicava o ack SEM corpo
# nenhum, e a sessão que o escreveu acreditou ter anexado o relatório; um `--subjet` publicava
# mensagem sem assunto. Três linhas acima o script já sabia reprovar o VALOR inválido de uma flag
# conhecida (`--reason`) — só não reprovava a flag que não conhece.
#
# O conjunto de flags varia POR SUBCOMANDO, então a mensagem nomeia qual subcomando recusa: sem
# isso, quem escreveu `--body-file` num `ack` conclui que a flag não existe em lugar nenhum.
_reject_unknown() {  # _reject_unknown <subcomando> <flags aceitas> <argumento> [dica]
  local sub="$1" accepted="$2" arg="$3" hint="${4:-}"
  case "$arg" in
    -*) echo "FAIL: flag desconhecida '$arg' para o subcomando '$sub'" >&2 ;;
    *)  echo "FAIL: argumento inesperado '$arg' para o subcomando '$sub'" >&2 ;;
  esac
  echo "  flags aceitas em '$sub': $accepted" >&2
  [ -z "$hint" ] || echo "  $hint" >&2
  exit 1
}

_read_self() {
  [ -f "$CONFIG" ] || { printf ''; return 0; }
  node - "$LIBDIR" "$CONFIG" <<'NODEEOF'
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, cfg] = process.argv;
  const { readConfig } = await import(pathToFileURL(join(lib, 'liaison-config.mjs')).href);
  const doc = readConfig(cfg);
  process.stdout.write((doc.self && doc.self.id) || '');
})();
NODEEOF
}

# Emite, uma variável por linha (KIND/PATH/REMOTE/BRANCH), o transporte configurado do canal.
# Vazio quando não há transporte — o caller decide se isso é erro (sync) ou informação (show).
_read_transport() {
  [ -f "$CONFIG" ] || { printf ''; return 0; }
  node - "$LIBDIR" "$CONFIG" "$1" <<'NODEEOF'
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, cfg, channel] = process.argv;
  const C = await import(pathToFileURL(join(lib, 'liaison-config.mjs')).href);
  const t = C.getTransport(C.readConfig(cfg), channel);
  if (!t) return;
  const errs = C.validateTransport(t);
  if (errs.length) { console.error(`transporte inválido em liaison.yaml: ${errs.join('; ')}`); process.exit(1); }
  const out = [`KIND=${t.kind}`];
  for (const [k, v] of [['PATH', t.path], ['REMOTE', t.remote], ['BRANCH', t.branch]]) {
    if (v) out.push(`${k}=${v}`);
  }
  process.stdout.write(out.join('\n') + '\n');
})();
NODEEOF
}

# Carrega o transporte do canal em LIAISON_T_* e faz source do backend. Reprova (rc 1) quando o
# canal não tem transporte configurado — pré-requisito faltando REPROVA, nunca desliga o sync em
# silêncio contra um default inventado.
_load_transport() {
  local channel="$1"
  local conf; conf="$(_read_transport "$channel")" || exit 1
  if [ -z "$conf" ]; then
    echo "FAIL: transporte não configurado para o canal '$channel' — rode: liaison-ops.sh transport set $channel --kind fs --path <dir>" >&2
    return 1
  fi
  LIAISON_T_KIND=""; LIAISON_T_PATH=""; LIAISON_T_REMOTE=""; LIAISON_T_BRANCH=""
  local line key val
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    key="${line%%=*}"; val="${line#*=}"
    case "$key" in
      KIND) LIAISON_T_KIND="$val" ;;
      PATH) LIAISON_T_PATH="$val" ;;
      REMOTE) LIAISON_T_REMOTE="$val" ;;
      BRANCH) LIAISON_T_BRANCH="$val" ;;
    esac
  done <<< "$conf"
  local backend="$LIBDIR/transports/$LIAISON_T_KIND.sh"
  [ -f "$backend" ] || { echo "FAIL: backend de transporte ausente: $backend" >&2; return 1; }
  LIAISON_SELF="$(_read_self)"
  [ -n "$LIAISON_SELF" ] || { echo "FAIL: self não configurado (rode 'open' primeiro)" >&2; return 1; }
  export LIAISON_ROOT="$ROOT" LIAISON_CHANNEL="$channel" LIAISON_CHANNEL_DIR="$LIAISON_DIR/$channel"
  export LIAISON_SELF LIAISON_T_KIND LIAISON_T_PATH LIAISON_T_REMOTE LIAISON_T_BRANCH
  # shellcheck disable=SC1090
  . "$backend"
}

# Aplica um bundle cru (dir com log/ + blobs/) sobre o canal, pela política única de merge.
# Ecoa a linha de resultado e devolve rc 1 quando algum remetente reescreveu história.
_apply_bundle() {
  local channel="$1" from_dir="$2" label="$3"
  local ch_dir="$LIAISON_DIR/$channel"
  local self; self="$(_read_self)"
  mkdir -p "$ch_dir/conflicts" "$ch_dir/blobs"
  local out rc=0
  out="$(node - "$LIBDIR" "$ch_dir" "$from_dir" "$self" <<'NODEEOF'
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, chDir, fromDir, self] = process.argv;
  const { applyBundle } = await import(pathToFileURL(join(lib, 'liaison-import.mjs')).href);
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const r = applyBundle({ chDir, fromDir, self });
  const div = r.divergences.map((d) => `${d.sender}@seq=${d.seq} (${d.incoming ? d.incoming.msg_id : '?'})`).join(', ');
  process.stdout.write([r.accepted, r.dup, r.conflicts, r.quarantined, r.remaining, M.IMPORT_MAX_MESSAGES, div].join('\t'));
})();
NODEEOF
)" || return 1
  local n_new n_dup n_conf n_quar n_rest n_max div
  IFS=$'\t' read -r n_new n_dup n_conf n_quar n_rest n_max div <<< "$out"
  _render "$channel"
  if [ -n "$div" ]; then
    # Fail-loud continua: reescrita de história exige ação humana na ORIGEM. O que mudou é o
    # escopo do dano — só as posições nomeadas ficam retidas, o resto do log é aplicado.
    echo "FAIL: divergência de log em $div — log append-only não reescreve história; essas POSIÇÕES ficaram em quarentena (ver conflicts/) e as demais mensagens foram aplicadas" >&2
    rc=1
  fi
  local tail=""
  # Backlog acima do teto não é erro: é o próximo lote. Sem esta linha, um sync que aplicou 200 de
  # 205 pareceria ter terminado o trabalho.
  if [ "${n_rest:-0}" -gt 0 ]; then
    tail=" — $n_rest restante(s) acima do teto de $n_max por lote; rode sync novamente para aplicar o próximo"
  fi
  echo "OK $label — $n_new nova(s), $n_dup duplicata(s) (no-op), $n_conf conflito(s), $n_quar em quarentena${tail}"
  return $rc
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

# Segredo no corpo é segredo vazado: a mensagem sai do repositório e, com transporte por hub
# compartilhado ou branch remota, não volta atrás. Barra antes de escrever no log, não depois.
# Compartilhada por `send` e `ack` (issue #83) — um único ponto de varredura, nunca dois: se cada
# porta de escrita de corpo reimplementasse a checagem, bastaria uma esquecer para virar a mais
# frouxa, exatamente o raciocínio já registrado acima sobre por que o `ack` não tinha porta própria.
_scan_secret_or_fail() {  # _scan_secret_or_fail <body> <body_file>
  local body="$1" body_file="$2"
  [ -n "$body" ] || [ -n "$body_file" ] || return 0
  local scan_target="$body"
  [ -n "$body_file" ] && scan_target="$(cat "$body_file" 2>/dev/null || true)"
  local hits
  hits="$(SCAN_TEXT="$scan_target" node - "$LIBDIR" <<'NODEEOF'
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib] = process.argv;
  const { findSecrets } = await import(pathToFileURL(join(lib, 'secret-scan.mjs')).href);
  process.stdout.write(findSecrets(process.env.SCAN_TEXT || '').join(', '));
})();
NODEEOF
)"
  if [ -n "$hits" ]; then
    echo "FAIL: possível segredo no corpo da mensagem ($hits) — o liaison publica fora deste repositório; use uma referência (--change, --commit) em vez do valor" >&2
    return 1
  fi
  return 0
}

# Grava --body-file como blob (teto de tamanho + dedup por sha) e imprime `blobs/<nome>` em
# stdout. Compartilhada por `send` e `ack` pelo mesmo motivo do scan acima.
_write_body_blob() {  # _write_body_blob <ch_dir> <body_file>
  local ch_dir="$1" body_file="$2"
  [ -f "$body_file" ] || { echo "FAIL: --body-file '$body_file' não encontrado" >&2; return 1; }
  mkdir -p "$ch_dir/blobs"
  node - "$LIBDIR" "$body_file" "$ch_dir/blobs" <<'NODEEOF'
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
    *) _reject_unknown "open" "--self, --participants" "$1" ;;
  esac; done
  [ -n "$participants" ] || { echo "FAIL: --participants obrigatório (lista separada por vírgula)" >&2; exit 1; }
  [ -z "$self_arg" ] || _id_ok "$self_arg" || { echo "FAIL: --self inválido '$self_arg'" >&2; exit 1; }

  mkdir -p "$LIAISON_DIR" "$LIAISON_DIR/$channel/log" "$LIAISON_DIR/$channel/blobs" "$LIAISON_DIR/$channel/conflicts"
  [ -f "$LIAISON_DIR/$channel/state.json" ] || printf '{"cursors":{}}\n' > "$LIAISON_DIR/$channel/state.json"

  IFS=',' read -ra parts <<< "$participants"
  result="$(node - "$LIBDIR" "$CONFIG" "$self_arg" "$channel" "${parts[*]}" <<'NODEEOF'
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, cfg, selfArg, channel, partsRaw] = process.argv;
  const C = await import(pathToFileURL(join(lib, 'liaison-config.mjs')).href);
  const newParts = partsRaw.split(' ').filter(Boolean);
  for (const p of newParts) if (!C.ID_RE.test(p)) { console.error(`participante inválido: ${p}`); process.exit(1); }

  const doc = C.readConfig(cfg);

  if (selfArg) {
    if (doc.self.id && doc.self.id !== selfArg) {
      console.error(`identidade local já fixada como '${doc.self.id}' — não pode virar '${selfArg}'`);
      process.exit(1);
    }
    doc.self.id = selfArg;
  }
  if (!doc.self.id) { console.error('self.id não configurado — passe --self na primeira chamada de open'); process.exit(1); }
  if (!newParts.includes(doc.self.id)) newParts.push(doc.self.id);

  const prev = doc.channels[channel] || {};
  const existing = Array.isArray(prev.participants) ? prev.participants : [];
  const merged = [...new Set([...existing, ...newParts])].sort();
  // Reabrir um canal acrescenta participantes; NUNCA descarta o transporte já configurado —
  // `open` é idempotente e é chamado de novo sempre que a lista de participantes cresce.
  doc.channels[channel] = { participants: merged, ...(prev.transport ? { transport: prev.transport } : {}) };

  C.writeConfig(cfg, doc);
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
      *) _reject_unknown "thread open" "--subject, --body, --participants, --requires-ack" "$1" ;;
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
      *) _reject_unknown "thread join" "--subject, --body, --requires-ack" "$1" ;;
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
    [ $# -eq 0 ] || _reject_unknown "thread list" "(nenhuma)" "$1"
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

  thread_id=""; kind=""; subject=""; body=""; body_file=""; requires_ack="false"; authored_by=""; via=""
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
    --authored-by) authored_by="$2"; shift 2 ;;
    --via) via="$2"; shift 2 ;;
    *) _reject_unknown "send" "--thread, --kind, --subject, --body, --body-file, --requires-ack, --in-reply-to, --change, --contract-files, --commit, --authored-by, --via" "$1" ;;
  esac; done
  # authored_by registra a autoria REAL quando o conteúdo veio de outro repositório (o caso do
  # /forge:liaison ask). O sender continua sendo este repositório — é o invariante de um escritor por
  # arquivo que torna o merge livre de conflito; gravar no log alheio faria o log dele divergir do
  # nosso e o import do outro lado reprovaria por reescrita de história.
  if [ -n "${authored_by:-}" ]; then
    self_local="$(_read_self)"
    [ "$authored_by" != "$self_local" ] || { echo "FAIL: --authored-by igual ao self ($self_local) — omita a flag" >&2; exit 1; }
  fi
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

  _scan_secret_or_fail "$body" "$body_file" || exit 1

  body_ref=""
  if [ -n "$body_file" ]; then
    body_ref="$(_write_body_blob "$ch_dir" "$body_file")" || exit 1
    body=""
  fi

  IFS=',' read -ra cfiles <<< "${contract_files:-}"
  out="$(node - "$LIBDIR" "$ch_dir" "$self" "$channel" "$thread_id" "$kind" "$subject" "$body" "$body_ref" \
    "$requires_ack" "${in_reply_to:-}" "${change:-}" "${cfiles[*]:-}" "${commit:-}" "$(_git_date)" \
    "${authored_by:-}" "${via:-}" <<'NODEEOF'
const { readFileSync, writeFileSync, readdirSync, existsSync, renameSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, chDir, self, channel, threadId, kind, subject, body, bodyRef,
    requiresAck, inReplyTo, change, cfilesRaw, commit, now, authoredBy, via] = process.argv;
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
    ...(authoredBy ? { authored_by: authoredBy } : {}),
    ...(via ? { via } : {}),
    created_at: now,
    // Conteúdo cuja autoria é de outro repositório NUNCA é 'self', mesmo tendo sido escrito no
    // nosso arquivo: quem lê precisa saber que a procedência é externa antes de agir sobre ele.
    trust: authoredBy ? 'untrusted-peer' : 'self',
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
  [ -n "$channel" ] && [ -n "$msg_id" ] || { echo "FAIL: uso: ack <channel> <msg_id> [--subject <txt>] [--body <txt> | --body-file <path>] [--reason wont-adopt|acknowledged]" >&2; exit 1; }
  ch_dir="$LIAISON_DIR/$channel"
  [ -d "$ch_dir/log" ] || { echo "FAIL: canal '$channel' não inicializado" >&2; exit 1; }
  self="$(_read_self)"
  [ -n "$self" ] || { echo "FAIL: self não configurado" >&2; exit 1; }
  subject=""; reason=""; body=""; body_file=""
  while [ $# -gt 0 ]; do case "$1" in
    --subject) subject="$2"; shift 2 ;;
    --reason) reason="$2"; shift 2 ;;
    --body) body="$2"; shift 2 ;;
    --body-file) body_file="$2"; shift 2 ;;
    *) _reject_unknown "ack" "--subject, --body, --body-file, --reason" "$1" ;;
  esac; done
  case "${reason:-}" in
    ''|wont-adopt|acknowledged) ;;
    *) echo "FAIL: --reason inválido '$reason' (use wont-adopt | acknowledged)" >&2; exit 1 ;;
  esac
  [ -n "$subject" ] || [ -z "$reason" ] || subject="ack ($reason)"
  if [ -n "$body" ] && [ -n "$body_file" ]; then echo "FAIL: use --body OU --body-file, não os dois" >&2; exit 1; fi
  # `wont-adopt` sem corpo é exatamente o caso em que a ausência de justificativa É o defeito
  # (issue #83): o --reason distingue "reconheço e recuso" de "recebido, sem posição a tomar", e só
  # o primeiro exige posição por escrito. `acknowledged` e ack sem --reason continuam aceitando
  # recibo puro — não existe obrigação geral de corpo, só condicionada à recusa.
  if [ "${reason:-}" = "wont-adopt" ] && [ -z "$body" ] && [ -z "$body_file" ]; then
    echo "FAIL: --reason wont-adopt exige --body ou --body-file — recusa sem justificativa é o drift que este canal existe para evitar" >&2
    exit 1
  fi

  _scan_secret_or_fail "$body" "$body_file" || exit 1
  body_ref=""
  if [ -n "$body_file" ]; then
    body_ref="$(_write_body_blob "$ch_dir" "$body_file")" || exit 1
    body=""
  fi

  out="$(node - "$LIBDIR" "$ch_dir" "$self" "$channel" "$msg_id" "$subject" "$body" "$body_ref" "$(_git_date)" <<'NODEEOF'
const { readFileSync, writeFileSync, readdirSync, existsSync, renameSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, chDir, self, channel, targetId, subjectArg, body, bodyRef, now] = process.argv;
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
    subject, ...(body ? { body } : {}), ...(bodyRef ? { body_ref: bodyRef } : {}),
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

  // O ack AVANÇA o cursor da thread até a mensagem ackada — issue #102. Antes desta linha, o ato
  // mais forte de leitura do protocolo não marcava nada como lido, e `read --upto` era o único
  // caminho por onde um cursor avançava — toda mensagem ackada permanecia não lida.
  //
  // Só para mensagem de TERCEIRO. Ackar a própria mensagem é PARTICIPAÇÃO, não leitura: mover o
  // cursor ali marcaria como lidas as mensagens alheias que ficaram entre o cursor e a própria,
  // que ninguém leu. É a invariante que separa os dois atos.
  //
  // Não-regressão em modo NÃO estrito: ackar algo já lido é legítimo, e transformar isso em erro
  // faria um ato de protocolo falhar por um cursor que já estava adiante.
  if (target.sender !== self) {
    try {
      const { mergeLogs } = M;
      const { threads } = mergeLogs(all.concat([msg]));
      if (threads[threadId] && threads[threadId].order.includes(targetId)) {
        const { advanceCursor } = await import(pathToFileURL(join(lib, 'liaison-cursor.mjs')).href);
        advanceCursor({
          chDir, threads, threadId, upto: targetId,
          nowWall: new Date().toISOString().replace(/\.\d{3}Z$/, 'Z'), strict: false,
        });
      }
    } catch { /* o ack já está publicado; o cursor é conveniência, nunca desfaz a publicação */ }
  }
  process.stdout.write(msgId);
})();
NODEEOF
)"
  _render "$channel"
  # `wont-adopt` acka E registra dívida: a recusa vira item durável no ledger em vez de silêncio.
  # Silêncio é exatamente o que produz drift de contrato — o outro lado não distingue "não vi" de
  # "vi e decidi não adotar", e a decisão some com a sessão. Com o item no ledger, a recusa fica
  # atribuível, consultável e reaparece no planejamento.
  if [ "${reason:-}" = "wont-adopt" ]; then
    ledger_ops="$SCRIPT_DIR/ledger-ops.sh"
    if [ -f "$ledger_ops" ]; then
      FORGE_ROOT="$ROOT" bash "$ledger_ops" add --type tech-debt --priority P2 \
        --title "Contract-change recusado no liaison: $msg_id" \
        --detail "Este repositório ackou $msg_id (canal $channel) com --reason wont-adopt: reconheceu a mudança de contrato e decidiu NÃO adotá-la. A divergência resultante é conhecida e assumida, não acidental. Reabra quando a adoção entrar em roadmap, ou feche registrando por que a divergência é permanente." >/dev/null \
        || echo "WARN: ack gravado, mas o registro no ledger falhou — registre a dívida à mão" >&2
    else
      echo "WARN: ledger-ops.sh ausente — a recusa não foi registrada como dívida" >&2
    fi
  fi
  echo "OK ack — $out confirma $msg_id${reason:+ (motivo: $reason)}"
  ;;

# ---------------------------------------------------------------------------------------------
inbox)
  channel="${1:-}"; shift || true
  [ -n "$channel" ] || { echo "FAIL: <channel> obrigatório" >&2; exit 1; }
  ch_dir="$LIAISON_DIR/$channel"
  [ -d "$ch_dir/log" ] || { echo "FAIL: canal '$channel' não inicializado" >&2; exit 1; }
  filter_thread=""; show_body="false"; titles_only="false"
  while [ $# -gt 0 ]; do case "$1" in
    --thread) filter_thread="$2"; shift 2 ;;
    --show) show_body="true"; shift ;;
    --titles-only) titles_only="true"; shift ;;
    *) _reject_unknown "inbox" "--thread, --show, --titles-only" "$1" ;;
  esac; done

  node - "$LIBDIR" "$ch_dir" "$filter_thread" "$show_body" "$titles_only" <<'NODEEOF'
const { readFileSync, readdirSync, existsSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib2, chDir, filterThread, showBody, titlesOnly] = process.argv;
  const M = await import(pathToFileURL(join(lib2, 'liaison-merge.mjs')).href);
  // untrusted-render, não liaison-render: aquele é um SCRIPT (roda o render inteiro ao ser
  // carregado), então importá-lo só pela função quebraria justamente este caminho.
  const R = await import(pathToFileURL(join(lib2, 'untrusted-render.mjs')).href);
  const logDir = join(chDir, 'log');
  const files = existsSync(logDir) ? readdirSync(logDir).filter((f) => f.endsWith('.jsonl')) : [];
  const all = [];
  for (const f of files) {
    const text = readFileSync(join(logDir, f), 'utf8');
    for (const line of text.split('\n')) { const t = line.trim(); if (t) all.push(JSON.parse(t)); }
  }
  const { threads } = M.mergeLogs(all);
  const state = existsSync(join(chDir, 'state.json')) ? JSON.parse(readFileSync(join(chDir, 'state.json'), 'utf8')) : { cursors: {} };
  const cursors = state.cursors || {};
  let ids = Object.keys(threads).sort();
  if (filterThread) ids = ids.filter((id) => id === filterThread);
  if (!ids.length) { if (titlesOnly !== 'true') console.log('(nenhuma thread)'); return; }
  for (const id of ids) {
    const t = threads[id];
    const cursorMsgId = cursors[id] && cursors[id].msg_id;
    const cursorIdx = cursorMsgId ? t.order.indexOf(cursorMsgId) : -1;
    const unread = t.messages.slice(cursorIdx + 1);
    if (titlesOnly === 'true' && !unread.length) continue;
    console.log(`${id} — ${t.subject || '(sem assunto)'}: ${unread.length} não lida(s)`);
    for (const m of unread) {
      console.log(`  ${m.msg_id} [${m.kind}] \`${m.sender}\` — ${m.subject || '(sem assunto)'}`);
      // O corpo só sai com --show, e nunca cru: vai dentro do banner UNTRUSTED, em fence, com
      // `/forge:` neutralizado. Assunto e metadados são gerados por nós a partir do envelope;
      // o corpo é texto arbitrário de outro repositório.
      if (showBody === 'true' && m.body) {
        for (const line of R.renderUntrusted(m.body, m.sender).split('\n')) console.log(`  ${line}`);
      } else if (showBody === 'true' && m.body_ref) {
        console.log(`    corpo em \`${m.body_ref}\` (blob — abra deliberadamente)`);
      }
    }
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
  while [ $# -gt 0 ]; do case "$1" in --upto) upto="$2"; shift 2 ;; *) _reject_unknown "read" "--upto" "$1" ;; esac; done
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
  // A regra de não-regressão vive em lib/liaison-cursor.mjs, e é a MESMA que `ack` usa. Aqui em
  // modo estrito: o operador PEDIU um alvo, e um pedido inválido tem de ser dito.
  const { advanceCursor } = await import(pathToFileURL(join(lib, 'liaison-cursor.mjs')).href);
  try {
    advanceCursor({ chDir, threads, threadId, upto, nowWall, strict: true });
  } catch (e) { console.error(e.message); process.exit(1); }
  process.stdout.write(threadId);
})();
NODEEOF
)"
  echo "OK read — cursor de $out avançado até $upto"
  ;;

# ---------------------------------------------------------------------------------------------
status)
  channel="${1:-}"; shift || true
  [ $# -eq 0 ] || _reject_unknown "status" "(nenhuma)" "$1"
  if [ -n "$channel" ]; then
    ch_dir="$LIAISON_DIR/$channel"
    [ -d "$ch_dir/log" ] || { echo "FAIL: canal '$channel' não inicializado" >&2; exit 1; }
    node - "$LIBDIR" "$ch_dir" "$channel" <<'NODEEOF'
const { readFileSync, readdirSync, existsSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, chDir, channel] = process.argv;
  const { mergeLogs, formatSkew } = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const { readQuarantinedPositions } = await import(pathToFileURL(join(lib, 'liaison-import.mjs')).href);
  const logDir = join(chDir, 'log');
  const files = existsSync(logDir) ? readdirSync(logDir).filter((f) => f.endsWith('.jsonl')) : [];
  const all = [];
  for (const f of files) {
    const text = readFileSync(join(logDir, f), 'utf8');
    for (const line of text.split('\n')) { const t = line.trim(); if (t) all.push(JSON.parse(t)); }
  }
  const { threads, quarantined, gaps, forks, clockSkews } = mergeLogs(all);
  const state = existsSync(join(chDir, 'state.json')) ? JSON.parse(readFileSync(join(chDir, 'state.json'), 'utf8')) : { cursors: {} };
  const cursors = state.cursors || {};
  let unread = 0;
  for (const id of Object.keys(threads)) {
    const cur = cursors[id] && cursors[id].msg_id;
    const idx = cur ? threads[id].order.indexOf(cur) : -1;
    unread += threads[id].order.length - (idx + 1);
  }
  // created_at incoerente entra na linha E é nomeado abaixo: um contador não diz qual mensagem
  // nem contra qual referência, que é o único dado sobre o qual dá para agir (issue #36).
  const skewBit = clockSkews.length ? ` · ${clockSkews.length} created_at incoerente(s)` : '';
  const diag = gaps.length || forks.length ? ` · ${gaps.length} buraco(s) · ${forks.length} fork(s)` : '';
  // Posições retidas por divergência entram na linha E são NOMEADAS abaixo. Só o contador
  // esconderia o defeito da issue #48: um remetente calado é indistinguível de um quieto, e
  // "N em quarentena" não diz de quem nem de onde, que é o que permite agir.
  const pos = readQuarantinedPositions(chDir);
  const posBit = pos.length ? ` · ${pos.length} posição(ões) retida(s) por divergência` : '';
  console.log(`LIAISON/${channel}: ${Object.keys(threads).length} thread(s) · ${unread} não lida(s) · ${quarantined.length} em quarentena${posBit}${skewBit}${diag}`);
  const sh = (v) => (v ? String(v).slice(0, 12) : '?');
  for (const p of pos) console.log(`  ! quarentena por divergência: ${p.sender}@seq=${p.seq} — recebida ${p.msg_id || '?'}/${sh(p.content_sha)}, conhecida ${p.known_msg_id || '?'}/${sh(p.known_content_sha)} (conflicts/${p.file})`);
  for (const c of clockSkews) console.log(`  ! created_at incoerente: ${c.msg_id} (${c.sender}, thread ${c.thread_id}) tem created_at ${c.created_at}, ${formatSkew(c.behind_ms)} ANTES de ${c.in_reply_to} (${c.ref_created_at}) que ela responde — relógio de parede da origem, ou duas cópias do mesmo log escrevendo em paralelo`);
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
  const { mergeLogs, formatSkew } = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const { readQuarantinedPositions } = await import(pathToFileURL(join(lib, 'liaison-import.mjs')).href);
  const channels = channelsRaw.split(' ').filter(Boolean);
  const positions = [];
  const skews = [];
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
    const { threads, quarantined, clockSkews } = mergeLogs(all);
    for (const c of clockSkews) skews.push({ channel, ...c });
    const state = existsSync(join(chDir, 'state.json')) ? JSON.parse(readFileSync(join(chDir, 'state.json'), 'utf8')) : { cursors: {} };
    const cursors = state.cursors || {};
    threadsTotal += Object.keys(threads).length;
    quarantinedTotal += quarantined.length;
    for (const p of readQuarantinedPositions(chDir)) positions.push({ channel, ...p });
    for (const id of Object.keys(threads)) {
      const cur = cursors[id] && cursors[id].msg_id;
      const idx = cur ? threads[id].order.indexOf(cur) : -1;
      unreadTotal += threads[id].order.length - (idx + 1);
    }
  }
  const posBit = positions.length ? ` · ${positions.length} posição(ões) retida(s) por divergência` : '';
  const skewBit = skews.length ? ` · ${skews.length} created_at incoerente(s)` : '';
  console.log(`LIAISON: self=${self || '?'} · ${channels.length} canal(is) · ${threadsTotal} thread(s) · ${unreadTotal} não lida(s) · ${quarantinedTotal} em quarentena${posBit}${skewBit}`);
  const sh = (v) => (v ? String(v).slice(0, 12) : '?');
  for (const p of positions) console.log(`  ! quarentena por divergência em ${p.channel}: ${p.sender}@seq=${p.seq} — recebida ${p.msg_id || '?'}/${sh(p.content_sha)}, conhecida ${p.known_msg_id || '?'}/${sh(p.known_content_sha)}`);
  for (const c of skews) console.log(`  ! created_at incoerente em ${c.channel}: ${c.msg_id} (${c.sender}) tem created_at ${c.created_at}, ${formatSkew(c.behind_ms)} ANTES de ${c.in_reply_to} (${c.ref_created_at}) que ela responde`);
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
  while [ $# -gt 0 ]; do case "$1" in --out) out_dir="$2"; shift 2 ;; *) _reject_unknown "export" "--out" "$1" ;; esac; done
  [ -n "$out_dir" ] || { echo "FAIL: --out <dir> obrigatório" >&2; exit 1; }
  mkdir -p "$out_dir/log" "$out_dir/blobs"
  if [ -d "$ch_dir/log" ]; then find "$ch_dir/log" -type f -name '*.jsonl' -exec cp {} "$out_dir/log/" \; ; fi
  if [ -d "$ch_dir/blobs" ]; then find "$ch_dir/blobs" -type f -exec cp {} "$out_dir/blobs/" \; 2>/dev/null || true; fi
  n="$(find "$out_dir/log" -type f -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' ')" || n=0
  echo "OK export — canal $channel exportado para $out_dir ($n arquivo(s) de log)"
  ;;

# ---------------------------------------------------------------------------------------------
import)
  channel="${1:-}"; shift || true
  [ -n "$channel" ] || { echo "FAIL: <channel> obrigatório" >&2; exit 1; }
  ch_dir="$LIAISON_DIR/$channel"
  [ -d "$ch_dir/log" ] || { echo "FAIL: canal '$channel' não inicializado (rode 'open' primeiro)" >&2; exit 1; }
  from_dir=""
  while [ $# -gt 0 ]; do case "$1" in --from) from_dir="$2"; shift 2 ;; *) _reject_unknown "import" "--from" "$1" ;; esac; done
  [ -n "$from_dir" ] || { echo "FAIL: --from <dir> obrigatório" >&2; exit 1; }
  [ -d "$from_dir/log" ] || { echo "FAIL: '$from_dir/log' não encontrado" >&2; exit 1; }
  [ -n "$(_read_self)" ] || { echo "FAIL: self não configurado" >&2; exit 1; }
  _apply_bundle "$channel" "$from_dir" "import"
  ;;

# ---------------------------------------------------------------------------------------------
# conflicts — posições retidas por divergência (reescrita de história na origem) e a recuperação
# assistida delas. A retenção por posição foi entregue na issue #48; o que faltava era o caminho de
# volta: o conteúdo retido NUNCA entra no log local, então para o destinatário ele simplesmente não
# existe — no caso reportado, um ack legítimo. Até aqui só dava para lê-lo abrindo
# conflicts/*.divergence.json à mão e comparando com o log.
#
# `resolve` republica esse conteúdo numa sequência NOVA, que é o único caminho legítimo num log
# append-only. A republicação sai do NOSSO log, com `authored_by` do autor real e `resolves`
# apontando a posição de origem: escrever no log alheio quebraria o invariante de um escritor por
# arquivo — exatamente a causa-raiz da colisão de seq que a issue relata — e o import do outro lado
# reprovaria a linha por reescrita de história.
#
# `kind` vira `note`, nunca o kind original. Reemitir um `ack` ou um `contract-change` como se
# fosse nosso falsificaria autoria de decisão: quem acka é quem decidiu ackar, e a cobrança de ack
# (check-liaison-acks.sh) conta exatamente isso. `resolves.kind` preserva o que a mensagem era.
conflicts)
  sub="${1:-}"; shift || true
  case "$sub" in
    list)
      channel="${1:-}"; shift || true
      [ $# -eq 0 ] || _reject_unknown "conflicts list" "(nenhuma)" "$1"
      [ -n "$channel" ] || { echo "FAIL: uso: conflicts list <channel>" >&2; exit 1; }
      ch_dir="$LIAISON_DIR/$channel"
      [ -d "$ch_dir/log" ] || { echo "FAIL: canal '$channel' não inicializado" >&2; exit 1; }
      node - "$LIBDIR" "$ch_dir" "$channel" <<'NODEEOF'
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, chDir, channel] = process.argv;
  const { readQuarantinedPositions } = await import(pathToFileURL(join(lib, 'liaison-import.mjs')).href);
  const pos = readQuarantinedPositions(chDir);
  // Conjunto vazio responde EXPLICITAMENTE. Silêncio seria indistinguível de comando quebrado, e
  // este é justamente o comando que alguém roda para saber se há algo preso.
  if (!pos.length) { console.log(`LIAISON/${channel}: nenhuma posição retida por divergência`); return; }
  console.log(`LIAISON/${channel}: ${pos.length} posição(ões) retida(s) por divergência`);
  const sh = (v) => (v ? String(v).slice(0, 12) : '?');
  for (const p of pos) {
    console.log(`  ! ${p.sender}@seq=${p.seq} — recebida ${p.msg_id || '?'}/${sh(p.content_sha)}, conhecida ${p.known_msg_id || '?'}/${sh(p.known_content_sha)}${p.thread_id ? ` · thread ${p.thread_id}` : ''}${p.subject ? ` · "${p.subject}"` : ''} (conflicts/${p.file})`);
    if (p.resolved_as) console.log(`      republicada como ${p.resolved_as.msg_id} — a divergência na origem CONTINUA; corrigi-la é com quem escreveu o log`);
    else console.log(`      recuperar: liaison-ops.sh conflicts resolve ${channel} ${p.sender} ${p.seq}`);
  }
})();
NODEEOF
      ;;
    resolve)
      channel="${1:-}"; shift || true
      div_sender="${1:-}"; shift || true
      div_seq="${1:-}"; shift || true
      [ $# -eq 0 ] || _reject_unknown "conflicts resolve" "(nenhuma)" "$1"
      [ -n "$channel" ] && [ -n "$div_sender" ] && [ -n "$div_seq" ] \
        || { echo "FAIL: uso: conflicts resolve <channel> <sender> <seq>" >&2; exit 1; }
      printf '%s' "$div_seq" | grep -Eq '^[0-9]+$' || { echo "FAIL: <seq> deve ser inteiro, recebido '$div_seq'" >&2; exit 1; }
      _id_ok "$div_sender" || { echo "FAIL: <sender> inválido '$div_sender'" >&2; exit 1; }
      ch_dir="$LIAISON_DIR/$channel"
      [ -d "$ch_dir/log" ] || { echo "FAIL: canal '$channel' não inicializado" >&2; exit 1; }
      self="$(_read_self)"
      [ -n "$self" ] || { echo "FAIL: self não configurado" >&2; exit 1; }
      out="$(node - "$LIBDIR" "$ch_dir" "$self" "$channel" "$div_sender" "$div_seq" "$(_git_date)" <<'NODEEOF'
const { readFileSync, writeFileSync, readdirSync, existsSync, renameSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, chDir, self, channel, divSender, divSeqRaw, now] = process.argv;
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const I = await import(pathToFileURL(join(lib, 'liaison-import.mjs')).href);
  const divSeq = Number(divSeqRaw);
  const pos = I.readQuarantinedPositions(chDir).find((p) => p.sender === divSender && p.seq === divSeq);
  if (!pos) { console.error(`nenhuma posição retida em ${divSender}@seq=${divSeq} (veja: conflicts list ${channel})`); process.exit(1); }
  if (pos.resolved_as) { console.error(`${divSender}@seq=${divSeq} já foi republicada como ${pos.resolved_as.msg_id} — republicar de novo duplicaria o conteúdo no canal`); process.exit(1); }
  const rec = JSON.parse(readFileSync(join(chDir, 'conflicts', pos.file), 'utf8'));
  const inc = rec.incoming;
  if (!inc || !inc.thread_id) { console.error(`o registro conflicts/${pos.file} não carrega a mensagem recebida — nada a republicar`); process.exit(1); }

  const logDir = join(chDir, 'log');
  const files = existsSync(logDir) ? readdirSync(logDir).filter((f) => f.endsWith('.jsonl')) : [];
  const all = [];
  for (const f of files) {
    const text = readFileSync(join(logDir, f), 'utf8');
    for (const line of text.split('\n')) { const t = line.trim(); if (t) all.push(JSON.parse(t)); }
  }
  const threadMsgs = all.filter((m) => m.thread_id === inc.thread_id);
  if (!threadMsgs.some((m) => m.kind === 'thread-open')) {
    console.error(`thread '${inc.thread_id}' desconhecida localmente — sincronize a abertura da thread antes de republicar`); process.exit(1);
  }
  // Corpo em blob: o blob de uma posição RETIDA não é copiado pelo import (só o das mensagens
  // aplicadas), então pode não existir aqui. Republicar sem o corpo seria entregar um envelope
  // vazio dizendo que recuperou o conteúdo.
  if (inc.body_ref && !existsSync(join(chDir, 'blobs', inc.body_ref.slice('blobs/'.length)))) {
    console.error(`o corpo da posição está em ${inc.body_ref}, ausente em blobs/ — peça à origem o blob (ou republique você mesmo o conteúdo com 'send')`); process.exit(1);
  }

  const own = all.filter((m) => m.sender === self);
  const seq = M.nextSeq(own);
  const lamport = M.nextLamport(threadMsgs);
  const msgId = `${self}-${String(seq).padStart(4, '0')}`;
  const msg = {
    msg_id: msgId, channel, thread_id: inc.thread_id, sender: self, seq, lamport,
    kind: 'note', in_reply_to: inc.in_reply_to || null, requires_ack: false,
    subject: inc.subject,
    ...(inc.body ? { body: inc.body } : {}),
    ...(inc.body_ref ? { body_ref: inc.body_ref } : {}),
    refs: inc.refs || { change_id: null, contract_files: [], commit: null },
    authored_by: inc.sender,
    via: 'divergence-resolve',
    resolves: { sender: inc.sender, seq: divSeq, msg_id: inc.msg_id || null, content_sha: inc.content_sha || null, kind: inc.kind || null },
    created_at: now,
    trust: 'untrusted-peer',
  };
  msg.content_sha = M.computeContentSha(msg);
  const errs = M.validateEnvelope(msg);
  if (errs.length) { console.error('envelope inválido: ' + errs.join('; ')); process.exit(1); }
  const target = join(logDir, `${self}.jsonl`);
  const senderMsgs = own.concat([msg]).sort((a, b) => a.seq - b.seq);
  writeFileSync(target + '.tmp', senderMsgs.map((m) => JSON.stringify(m)).join('\n') + '\n');
  renameSync(target + '.tmp', target);
  I.markResolved(chDir, divSender, divSeq, { msg_id: msgId, created_at: now });
  process.stdout.write(`${msgId}\t${inc.msg_id || '?'}`);
})();
NODEEOF
)" || exit 1
      IFS=$'\t' read -r new_id orig_id <<< "$out"
      _render "$channel"
      echo "OK conflicts resolve — $new_id republica o conteúdo de $orig_id ($div_sender@seq=$div_seq) em sequência nova; a divergência na origem continua e só ela pode corrigi-la"
      ;;
    *)
      echo "FAIL: uso: conflicts list <channel> | conflicts resolve <channel> <sender> <seq>" >&2; exit 1 ;;
  esac
  ;;

# ---------------------------------------------------------------------------------------------
# peer — caminho LOCAL do repositório de um participante, para o subcomando síncrono `liaison ask`.
# Fica no liaison.yaml e não numa mensagem porque é informação de máquina: o mesmo participante
# mora em diretórios diferentes em cada estação. Quem não tem o peer clonado não usa o atalho.
peer)
  sub="${1:-}"; shift || true
  channel="${1:-}"; shift || true
  participant="${1:-}"; shift || true
  [ "$sub" = "set" ] || { echo "FAIL: uso: peer set <channel> <participante> --path <dir>" >&2; exit 1; }
  [ -n "$channel" ] && [ -n "$participant" ] || { echo "FAIL: <channel> e <participante> obrigatórios" >&2; exit 1; }
  peer_path=""
  while [ $# -gt 0 ]; do case "$1" in --path) peer_path="$2"; shift 2 ;; *) _reject_unknown "peer set" "--path" "$1" ;; esac; done
  [ -n "$peer_path" ] || { echo "FAIL: --path obrigatório" >&2; exit 1; }
  node - "$LIBDIR" "$CONFIG" "$channel" "$participant" "$peer_path" <<'NODEEOF'
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, cfg, channel, participant, path] = process.argv;
  const C = await import(pathToFileURL(join(lib, 'liaison-config.mjs')).href);
  const doc = C.readConfig(cfg);
  if (!doc.channels[channel]) { console.error(`canal '${channel}' não registrado — rode 'open' primeiro`); process.exit(1); }
  if (!C.ID_RE.test(participant)) { console.error(`participante inválido: ${participant}`); process.exit(1); }
  if (!doc.channels[channel].peers) doc.channels[channel].peers = {};
  doc.channels[channel].peers[participant] = path;
  C.writeConfig(cfg, doc);
})();
NODEEOF
  echo "OK peer set — $participant → $peer_path (canal $channel)"
  ;;

peer-path)
  channel="${1:-}"; shift || true
  participant="${1:-}"; shift || true
  [ $# -eq 0 ] || _reject_unknown "peer-path" "(nenhuma)" "$1"
  [ -n "$channel" ] && [ -n "$participant" ] || { echo "FAIL: uso: peer-path <channel> <participante>" >&2; exit 1; }
  out="$(node - "$LIBDIR" "$CONFIG" "$channel" "$participant" <<'NODEEOF'
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, cfg, channel, participant] = process.argv;
  const C = await import(pathToFileURL(join(lib, 'liaison-config.mjs')).href);
  const p = C.getPeerPath(C.readConfig(cfg), channel, participant);
  if (!p) {
    console.error(`caminho local de '${participant}' não configurado no canal '${channel}' — rode: liaison-ops.sh peer set ${channel} ${participant} --path <dir>`);
    console.error('(sem ele, o subcomando síncrono `liaison ask` não se aplica; use o fluxo assíncrono)');
    process.exit(1);
  }
  process.stdout.write(p);
})();
NODEEOF
)" || exit 1
  printf '%s\n' "$out"
  ;;

# ---------------------------------------------------------------------------------------------
transport)
  sub="${1:-}"; shift || true
  channel="${1:-}"; shift || true
  [ -n "$sub" ] && [ -n "$channel" ] || { echo "FAIL: uso: transport set|show|probe <channel> [...]" >&2; exit 1; }
  ch_dir="$LIAISON_DIR/$channel"
  [ -d "$ch_dir/log" ] || { echo "FAIL: canal '$channel' não inicializado (rode 'open' primeiro)" >&2; exit 1; }

  case "$sub" in
  set)
    t_kind=""; t_path=""; t_remote=""; t_branch=""
    while [ $# -gt 0 ]; do case "$1" in
      --kind) t_kind="$2"; shift 2 ;;
      --path) t_path="$2"; shift 2 ;;
      --remote) t_remote="$2"; shift 2 ;;
      --branch) t_branch="$2"; shift 2 ;;
      *) _reject_unknown "transport set" "--kind, --path, --remote, --branch" "$1" ;;
    esac; done
    [ -n "$t_kind" ] || { echo "FAIL: --kind obrigatório (manual|fs|git|gh)" >&2; exit 1; }
    node - "$LIBDIR" "$CONFIG" "$channel" "$t_kind" "$t_path" "$t_remote" "$t_branch" <<'NODEEOF'
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, cfg, channel, kind, path, remote, branch] = process.argv;
  const C = await import(pathToFileURL(join(lib, 'liaison-config.mjs')).href);
  const doc = C.readConfig(cfg);
  if (!doc.self.id) { console.error('self.id não configurado — rode `open` primeiro'); process.exit(1); }
  if (!doc.channels[channel]) { console.error(`canal '${channel}' não registrado no liaison.yaml — rode \`open\` primeiro`); process.exit(1); }
  const transport = { kind };
  if (path) transport.path = path;
  if (remote) transport.remote = remote;
  if (branch) transport.branch = branch;
  const errs = C.validateTransport(transport);
  if (errs.length) { console.error(errs.join('; ')); process.exit(1); }
  doc.channels[channel].transport = transport;
  C.writeConfig(cfg, doc);
})();
NODEEOF
    echo "OK transport set — canal $channel usa transporte $t_kind"
    ;;

  show)
    [ $# -eq 0 ] || _reject_unknown "transport show" "(nenhuma)" "$1"
    conf="$(_read_transport "$channel")" || exit 1
    if [ -z "$conf" ]; then echo "LIAISON/$channel: transporte não configurado"; exit 0; fi
    echo "LIAISON/$channel: $(printf '%s' "$conf" | tr '\n' ' ' | sed 's/ *$//')"
    ;;

  probe)
    [ $# -eq 0 ] || _reject_unknown "transport probe" "(nenhuma)" "$1"
    _load_transport "$channel" || exit 1
    t_probe || exit 1
    echo "OK transport probe — $LIAISON_T_KIND alcançável para o canal $channel"
    ;;

  *) echo "FAIL: subcomando desconhecido 'transport $sub'" >&2; exit 1 ;;
  esac
  ;;

# ---------------------------------------------------------------------------------------------
# sync — publica o próprio log no ponto de encontro e aplica o que os demais publicaram.
# Ordem deliberada: PUSH antes de PULL. Publicar primeiro garante que o que já escrevemos fica
# disponível mesmo que a aplicação do bundle alheio reprove (divergência, teto excedido); e evita
# o caso em que uma réplica atrasada puxa, aprende o estado novo, e então republica logs de
# terceiros — o push só toca o próprio arquivo, mas a ordem torna o invariante evidente.
sync)
  channel="${1:-}"; shift || true
  [ -n "$channel" ] || { echo "FAIL: <channel> obrigatório" >&2; exit 1; }
  ch_dir="$LIAISON_DIR/$channel"
  [ -d "$ch_dir/log" ] || { echo "FAIL: canal '$channel' não inicializado (rode 'open' primeiro)" >&2; exit 1; }
  do_push=1; do_pull=1
  while [ $# -gt 0 ]; do case "$1" in
    --push-only) do_pull=0; shift ;;
    --pull-only) do_push=0; shift ;;
    *) _reject_unknown "sync" "--push-only, --pull-only" "$1" ;;
  esac; done

  _load_transport "$channel" || exit 1
  t_probe || { echo "FAIL: transporte $LIAISON_T_KIND indisponível — sync abortado" >&2; exit 1; }

  if [ "$do_push" -eq 1 ]; then
    t_push || { echo "FAIL: push pelo transporte $LIAISON_T_KIND" >&2; exit 1; }
  fi

  if [ "$do_pull" -eq 0 ]; then
    echo "OK sync — push-only via $LIAISON_T_KIND (log de $LIAISON_SELF publicado)"
    exit 0
  fi

  staging="$(mktemp -d "${TMPDIR:-/tmp}/forge-liaison-sync.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -rf '$staging'" EXIT
  t_pull "$staging" || { echo "FAIL: pull pelo transporte $LIAISON_T_KIND" >&2; exit 1; }
  _apply_bundle "$channel" "$staging" "sync via $LIAISON_T_KIND"
  ;;

# ---------------------------------------------------------------------------------------------
render)
  channel="${1:-}"; shift || true
  [ $# -eq 0 ] || _reject_unknown "render" "(nenhuma)" "$1"
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
