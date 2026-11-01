#!/usr/bin/env bash
# ORDINAL: w287 atribuído no merge de add-liaison-native-bridge
# Gate — `send --via cross-session` e recusa C1 (TASK-08, STORY-05; design §2.4, REQ-02, REQ-03).
# Registro de mensagem nativa recebida: localização/leitura do transcript pelo leitor único
# (native-transcript.mjs), tetos/controle/segredo nos valores extraídos e no corpo, conferência de
# origem pelo registro de sessões (native-registry.mjs/native-workspace.mjs), e exibição em
# `inbox --show`/`render` dentro da moldura `renderUntrusted`.
#
# Fixtures de transcript/registro via FORGE_CLAUDE_PROJECTS_DIR/FORGE_CLAUDE_SESSIONS_DIR (nunca
# HOME redirecionado). Sockets reais via node:net para que a conferência de origem exercite
# isAlive() de verdade (pid vivo = o pid deste próprio processo de gate, que roda durante todo o
# teste; socket vivo = um listener real, mantido no ar até o cleanup).
set -euo pipefail
# Isolamento git (LDG-0201): GIT_DIR/GIT_WORK_TREE/... herdados do ambiente fariam os `git init`
# de fixture abaixo obedecerem ao repositório de quem invocou o gate.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Amostra de segredo sintético montada em tempo de execução, nunca como literal contíguo — mesmo
# racional do `_p()` de tests/w139-secrets-gate.sh: um literal contíguo dispara o próprio w139 e o
# push protection do GitHub, mesmo sendo uma chave inerte usada só para exercitar o detector.
_p() { printf '%s' "$@"; }
T="$(mktemp -d /tmp/forge-cross-session-record.XXXXXX)"
SOCK_PID=""
cleanup() { [ -z "$SOCK_PID" ] || kill "$SOCK_PID" 2>/dev/null || true; rm -rf "$T"; }
trap cleanup EXIT

# Declarados já no topo (set -u): LG() os referencia desde a primeira chamada, antes das fixtures
# de transcript/registro serem criadas — nos comandos que não leem transcript/registro, as
# variáveis simplesmente apontam para diretórios ainda vazios.
PROJECTS_DIR="$T/projects"
SESS_DIR="$T/sessions"

mk_repo() { # mk_repo <dir>
  local dir="$T/$1"
  mkdir -p "$dir/.forge"
  for d in scripts templates hooks schemas rules commands ledger; do
    [ -d "$WS/template/.forge/$d" ] && cp -R "$WS/template/.forge/$d" "$dir/.forge/"
  done
  cp "$WS/template/.forge/forge.yaml" "$dir/.forge/forge.yaml"
  git -C "$dir" init -q
  git -C "$dir" config user.email "$1@test"
  git -C "$dir" config user.name "$1"
  git -C "$dir" config commit.gpgsign false
  git -C "$dir" commit --allow-empty -qm init >/dev/null
}

mk_plain_repo() { # mk_plain_repo <dir> — repositório git puro, sem .forge, para fixtures de peer
  local dir="$T/$1"
  mkdir -p "$dir"
  git init -q "$dir"
  git -C "$dir" config user.email "$1@test"
  git -C "$dir" config user.name "$1"
  git -C "$dir" config commit.gpgsign false
  git -C "$dir" commit --allow-empty -qm init >/dev/null
}

LG() { local repo="$1"; shift; FORGE_ROOT="$T/$repo" FORGE_CLAUDE_PROJECTS_DIR="$PROJECTS_DIR" FORGE_CLAUDE_SESSIONS_DIR="$SESS_DIR" bash "$T/$repo/.forge/scripts/liaison-ops.sh" "$@"; }

CH=fixture-ch
# peer-notparticipant-excluded (usado só no teste de C1) NUNCA entra nesta lista — precisa estar
# de fora do canal.
REAL_PARTICIPANTS="peer-ok,peer-diverge,peer-worktree,peer-pidmismatch,peer-unresolved,peer-validate"

mk_repo me
LG me open "$CH" --self local-me --participants "$REAL_PARTICIPANTS" >/dev/null
LG me thread open "$CH" native-thread --subject "mensagens nativas registradas" --participants local-me >/dev/null

# --- repositórios de peer para a conferência de origem (REQ-02 item 6) ----------------------
mk_plain_repo peer-main
git -C "$T/peer-main" worktree add -q "$T/peer-worktree-dir" -b wt-branch >/dev/null
mk_plain_repo unrelated-repo

LG me peer set "$CH" peer-ok --path "$T/peer-main" >/dev/null
LG me peer set "$CH" peer-diverge --path "$T/peer-main" >/dev/null
LG me peer set "$CH" peer-worktree --path "$T/peer-worktree-dir" >/dev/null
LG me peer set "$CH" peer-pidmismatch --path "$T/peer-main" >/dev/null
# peer-unresolved e peer-validate: sem peer-path (default).

# --- sockets reais (node:net), vivos durante todo o gate --------------------------------------
SOCK_DIR="$T/sockets"; mkdir -p "$SOCK_DIR"
SOCK_OK="$SOCK_DIR/ok.sock"
SOCK_DIVERGE="$SOCK_DIR/diverge.sock"
SOCK_WORKTREE="$SOCK_DIR/worktree.sock"
SOCK_PIDMISMATCH="$SOCK_DIR/pidmismatch.sock"
node -e '
const net = require("net");
for (const p of process.argv.slice(1)) net.createServer().listen(p);
setInterval(() => {}, 1 << 30);
' "$SOCK_OK" "$SOCK_DIVERGE" "$SOCK_WORKTREE" "$SOCK_PIDMISMATCH" &
SOCK_PID=$!
disown "$SOCK_PID" 2>/dev/null || true
i=0
until [ -S "$SOCK_OK" ] && [ -S "$SOCK_DIVERGE" ] && [ -S "$SOCK_WORKTREE" ] && [ -S "$SOCK_PIDMISMATCH" ]; do
  i=$((i + 1)); [ "$i" -lt 100 ] || { echo "FAIL [0]: sockets de fixture não vieram a existir"; exit 1; }
  sleep 0.05
done

# --- registro de sessões (FORGE_CLAUDE_SESSIONS_DIR) ------------------------------------------
mkdir -p "$SESS_DIR"
node - "$SESS_DIR" "$SOCK_OK" "$SOCK_DIVERGE" "$SOCK_WORKTREE" "$SOCK_PIDMISMATCH" "$$" "$T/peer-main" "$T/unrelated-repo" <<'NODEEOF'
const fs = require('fs'); const path = require('path');
const [, , dir, ok, diverge, worktreeS, pidmismatch, mypid, peerMain, unrelated] = process.argv;
const w = (f, o) => fs.writeFileSync(path.join(dir, f), JSON.stringify(o));
w('entry-ok.json', { pid: Number(mypid), name: 'PEER-OK', cwd: peerMain, messagingSocketPath: ok, sessionId: 'peer-ok-session' });
w('entry-diverge.json', { pid: Number(mypid), name: 'PEER-DIVERGE', cwd: unrelated, messagingSocketPath: diverge, sessionId: 'peer-diverge-session' });
w('entry-worktree.json', { pid: Number(mypid), name: 'PEER-WORKTREE', cwd: peerMain, messagingSocketPath: worktreeS, sessionId: 'peer-worktree-session' });
w('entry-pidmismatch.json', { pid: Number(mypid), name: 'PEER-PIDMISMATCH', cwd: peerMain, messagingSocketPath: pidmismatch, sessionId: 'peer-pidmismatch-session' });
NODEEOF

# --- transcripts sintéticos (FORGE_CLAUDE_PROJECTS_DIR), formato medido na evidência b ---------
mkdir -p "$PROJECTS_DIR/slug"
SESSION_CLEAN="clean-session"
SESSION_BROKEN="broken-session"

# Gera as linhas do transcript "limpo" (uma recepção por cenário) e imprime
# "CENARIO=fingerprint" por linha — o fingerprint é calculado pelo MESMO leitor que o `send`
# usa (native-transcript.mjs), nunca recalculado à mão, para que o teste não possa divergir da
# implementação por um erro de cópia do hash.
FP_MAP="$(node - "$WS/template/.forge/scripts/lib" "$PROJECTS_DIR/slug/$SESSION_CLEAN.jsonl" "$SOCK_OK" "$SOCK_DIVERGE" "$SOCK_WORKTREE" "$SOCK_PIDMISMATCH" "$$" <<'NODEEOF'
const fs = require('fs');
const { pathToFileURL } = require('url');
const { join } = require('path');
(async () => {
  const [, , lib, outFile, sockOk, sockDiverge, sockWorktree, sockPidmismatch, mypid] = process.argv;
  const T = await import(pathToFileURL(join(lib, 'native-transcript.mjs')).href);

  function line({ from, fromName, fromMode, body, verifiedPeerPid }) {
    const tag = `<cross-session-message from="${from}" from-name="${fromName}" from-mode="${fromMode}">\n${body}\n</cross-session-message>`;
    const content = `Another Claude session sent a message:\n${tag}\n\n(parágrafo fixo omitido na fixture).`;
    const obj = {
      type: 'user', isMeta: true, isSidechain: false, turnOrigin: 'peer', promptSource: 'system',
      uuid: '00000000-0000-0000-0000-000000000000', sessionId: 'CLEAN', timestamp: '2026-10-30T00:00:00.000Z',
      message: { role: 'user', content },
    };
    if (typeof verifiedPeerPid === 'number') {
      obj.origin = { kind: 'peer', from, verifiedPeerPid, msg_id: 'uuid', name: fromName, fromMode, body };
    }
    return JSON.stringify(obj);
  }

  const scenarios = {
    TETO: { from: 'uds:/tmp/cc-socks/30001.sock', fromName: 'X'.repeat(140), fromMode: 'default', body: 'corpo-teto' },
    CTRL: { from: 'uds:/tmp/cc-socks/30002.sock', fromName: 'bad\u0007name', fromMode: 'default', body: 'corpo-ctrl' },
    // montado por concatenação (nunca literal contíguo) para não disparar o push protection do
    // GitHub nem o próprio w139 — mesmo racional do `_p()` de tests/w139-secrets-gate.sh.
    SECRETNAME: { from: 'uds:/tmp/cc-socks/30003.sock', fromName: 'AKIA' + 'ABCDEFGHIJKLMNOP', fromMode: 'default', body: 'corpo-secret-name' },
    OK: { from: `uds:${sockOk}`, fromName: 'PEER-OK', fromMode: 'default', body: 'corpo-ok', verifiedPeerPid: Number(mypid) },
    DIVERGE: { from: `uds:${sockDiverge}`, fromName: 'PEER-DIVERGE', fromMode: 'default', body: 'corpo-diverge', verifiedPeerPid: Number(mypid) },
    WORKTREE: { from: `uds:${sockWorktree}`, fromName: 'PEER-WORKTREE', fromMode: 'default', body: 'corpo-worktree', verifiedPeerPid: Number(mypid) },
    PIDMISMATCH: { from: `uds:${sockPidmismatch}`, fromName: 'PEER-PIDMISMATCH', fromMode: 'default', body: 'corpo-pidmismatch', verifiedPeerPid: 999999 },
    UNRESOLVED: { from: 'uds:/tmp/cc-socks/99999-ghost.sock', fromName: 'PEER-UNRESOLVED', fromMode: 'default', body: 'corpo-unresolved', verifiedPeerPid: 12345 },
  };

  const lines = [];
  const out = [];
  for (const [name, s] of Object.entries(scenarios)) {
    lines.push(line(s));
    out.push(`${name}=${T.fingerprint(s.from, s.fromName, s.body)}`);
  }
  fs.writeFileSync(outFile, lines.join('\n') + '\n');

  // Controle: o próprio leitor precisa extrair as mesmas 9 recepções deste arquivo (senão o
  // restante do gate mediria o bug do leitor, não o comportamento do `send`).
  const read = T.readTranscript({ transcriptPath: outFile });
  if (!read.ok || read.receptions.length !== Object.keys(scenarios).length) {
    console.error(`instrumento de fixture quebrado: ok=${read.ok} receptions=${read.receptions && read.receptions.length}`);
    process.exit(1);
  }
  process.stdout.write(out.join('\n') + '\n');
})();
NODEEOF
)"
# Sem array associativo (declare -A): o Teste (comando) da task roda via `bash tests/...sh`
# literal, e nem todo PATH resolve `bash` para uma versão >= 4 — fp_of() lê o mapeamento de um
# arquivo plano, compatível com bash 3.2.
FP_FILE="$T/fingerprints.txt"
printf '%s\n' "$FP_MAP" > "$FP_FILE"
fp_of() { awk -F= -v k="$1" '$1==k{print $2; found=1} END{if(!found) exit 1}' "$FP_FILE"; }

# Transcript "quebrado": uma linha candidata (isMeta+promptSource+prefixo da tag) cuja tag não tem
# `from-mode` — TAG_RE não casa, zero recepções extraídas de uma transcript com candidata.
node -e '
const fs = require("fs");
const content = "Another Claude session sent a message:\n<cross-session-message from=\"uds:/tmp/cc-socks/40001.sock\" from-name=\"BROKEN\">\ncorpo\n</cross-session-message>\n";
const obj = { type: "user", isMeta: true, isSidechain: false, turnOrigin: "peer", promptSource: "system", uuid: "u", sessionId: "BROKEN", timestamp: "2026-10-30T00:00:00.000Z", message: { role: "user", content } };
fs.writeFileSync(process.argv[1], JSON.stringify(obj) + "\n");
' "$PROJECTS_DIR/slug/$SESSION_BROKEN.jsonl"

export FORGE_CLAUDE_PROJECTS_DIR="$PROJECTS_DIR" FORGE_CLAUDE_SESSIONS_DIR="$SESS_DIR"

N=0
pass() { N=$((N + 1)); echo "OK [$N] $1"; }
fail() { N=$((N + 1)); echo "FAIL [$N] $1"; exit 1; }
send_cs() { # send_cs <authored_by> <native_ref> [body]
  local authored_by="$1" native_ref="$2" body="${3:-resumo do operador}"
  LG me send "$CH" --thread native-thread --kind note --subject "nativo:$authored_by" \
    --body "$body" --authored-by "$authored_by" --via cross-session \
    --native-ref "$native_ref" --session "$SESSION_CLEAN"
}

echo "=== flags (design §2.4 passo 1) ==="
set +e
out="$(LG me send "$CH" --thread native-thread --kind note --subject x --body y --native-ref "$(fp_of OK)" 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] && grep -qi 'native-ref' <<<"$out" || fail "--native-ref [cross-session] sem --via cross-session deveria recusar: $out"
pass "--native-ref sem --via cross-session recusa"

set +e
out="$(LG me send "$CH" --thread native-thread --kind note --subject x --body y --session "$SESSION_CLEAN" 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] && grep -qi 'session' <<<"$out" || fail "--session [cross-session] sem --via cross-session deveria recusar: $out"
pass "--session sem --via cross-session recusa"

set +e
out="$(LG me send "$CH" --thread native-thread --kind note --subject x --body y --authored-by peer-ok --via cross-session 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] && grep -qi 'native-ref' <<<"$out" || fail "--via cross-session [native-ref] sem --native-ref deveria recusar: $out"
pass "--via cross-session sem --native-ref recusa"

set +e
out="$(LG me send "$CH" --thread native-thread --kind note --subject x --body y --via cross-session --native-ref "$(fp_of OK)" 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] && grep -qi 'authored-by' <<<"$out" || fail "--via cross-session [C1] sem --authored-by deveria recusar: $out"
pass "--via cross-session sem --authored-by recusa"

set +e
out="$(LG me send "$CH" --thread native-thread --kind note --subject x --body y --authored-by peer-ok --via cross-session --native-ref "nao-eh-hex" 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] && grep -qi 'native-ref' <<<"$out" || fail "--native-ref fora do padrão sha256 [cross-session] deveria recusar: $out"
pass "--native-ref fora do padrão sha256 recusa"

echo "=== C1 (REQ-03) e ausência de efeito colateral ==="
hash_state() {
  { cat "$T/me/.forge/liaison/liaison.yaml" 2>/dev/null; \
    find "$T/me/.forge/liaison/$CH/log" -type f -exec shasum {} \; 2>/dev/null | sort; \
    find "$T/me/.forge/liaison/$CH/blobs" -type f -exec shasum {} \; 2>/dev/null | sort; \
    cat "$T/me/.forge/liaison/$CH/state.json" 2>/dev/null; \
  } | shasum | awk '{print $1}'
}
before="$(hash_state)"
set +e
out="$(send_cs peer-notparticipant-excluded "$(fp_of OK)" 2>&1)"; rc=$?
set -e
after="$(hash_state)"
[ "$rc" -ne 0 ] || fail "C1 [origem/participantes] deveria recusar peer fora do canal: $out"
grep -qi 'participa' <<<"$out" || fail "recusa C1 [origem] não explica o motivo: $out"
grep -q 'open .* --participants' <<<"$out" || fail "recusa C1 [cross-session] não imprime o caminho de resolução via 'open': $out"
grep -q 'transport set' <<<"$out" || fail "recusa C1 [cross-session] não imprime o segundo caminho (canal novo com 'transport set'): $out"
grep -qi 'peer' <<<"$out" || fail "recusa C1 [cross-session] não lembra que o peer faz o mesmo do lado dele: $out"
[ "$before" = "$after" ] || fail "recusa C1 [efeito colateral] mudou liaison.yaml/log/blobs/cursor"
pass "C1 — peer fora do canal recusa sem efeito colateral (hash intacto)"

echo "=== fingerprint ausente e instrumento quebrado ==="
set +e
out="$(send_cs peer-validate "$(printf 'b%.0s' $(seq 1 64))" 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] && grep -qi 'native-ref\|fingerprint' <<<"$out" || fail "fingerprint ausente [cross-session] deveria recusar: $out"
pass "fingerprint ausente no transcript recusa"

set +e
out="$(LG me send "$CH" --thread native-thread --kind note --subject x --body y --authored-by peer-validate --via cross-session --native-ref "$(fp_of OK)" --session "$SESSION_BROKEN" 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] && grep -qi 'instrumento quebrado' <<<"$out" || fail "candidata sem extração [cross-session] deveria dar instrumento quebrado: $out"
pass "instrumento quebrado (candidata sem extração) recusa"

echo "=== tetos/controle/segredo nos valores extraídos e no corpo ==="
set +e
out="$(send_cs peer-validate "$(fp_of TETO)" 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || fail "from-name > 128 caracteres [cross-session] deveria recusar"
pass "teto de 128 caracteres no valor extraído recusa"

set +e
out="$(send_cs peer-validate "$(fp_of CTRL)" 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || fail "caractere de controle no valor extraído [cross-session] deveria recusar"
pass "caractere de controle no valor extraído recusa"

set +e
out="$(send_cs peer-validate "$(fp_of SECRETNAME)" 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || fail "segredo no valor extraído [cross-session] deveria recusar"
pass "segredo no valor extraído (from-name) recusa"

set +e
tok_llm="$(_p 'token sk-' 'ABCDEFGHIJKLMNOPQRST1234')"
out="$(send_cs peer-validate "$(fp_of OK)" "$tok_llm" 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || fail "segredo no corpo (resumo do operador) [cross-session] deveria recusar"
pass "segredo no corpo (resumo do operador) recusa (mesmo caminho do send)"

echo "=== conferência de origem (design §2.4 passo 6) ==="
set +e
out="$(send_cs peer-diverge "$(fp_of DIVERGE)" 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] && grep -qi 'origem diverge' <<<"$out" || fail "origem diverge [cross-session] deveria recusar nomeando os dois caminhos: $out"
grep -q "$T/peer-main" <<<"$out" && grep -q "$T/unrelated-repo" <<<"$out" || fail "recusa de origem diverge não nomeia os dois caminhos: $out"
pass "conferência de origem — diverge recusa nomeando os dois caminhos"

out="$(send_cs peer-unresolved "$(fp_of UNRESOLVED)")"
grep -q 'OK send' <<<"$out" || fail "origem não resolve [cross-session] deveria aceitar com origin_verified:false: $out"
msgid_unresolved="$(grep -oE '[a-z0-9-]+-[0-9]{4}' <<<"$out" | tail -1)"
pass "conferência de origem — registro ausente aceita (origin_verified:false)"

out="$(send_cs peer-ok "$(fp_of OK)")"
grep -q 'OK send' <<<"$out" || fail "origem ok [cross-session] deveria aceitar: $out"
msgid_ok="$(grep -oE '[a-z0-9-]+-[0-9]{4}' <<<"$out" | tail -1)"
pass "conferência de origem — registro+peer-path coincidem aceita"

out="$(send_cs peer-worktree "$(fp_of WORKTREE)")"
grep -q 'OK send' <<<"$out" || fail "origem peer em worktree [cross-session] deveria aceitar (normalização git-common-dir): $out"
pass "conferência de origem — peer em worktree normaliza e aceita"

out="$(send_cs peer-pidmismatch "$(fp_of PIDMISMATCH)")"
grep -q 'OK send' <<<"$out" || fail "pid divergente de verifiedPeerPid [cross-session] deveria DESCARTAR o registro e aceitar como não resolvido: $out"
pass "pid divergente de verifiedPeerPid descarta o registro (não vira diverge, nem origin_verified:true)"

echo "=== envelope gravado ==="
node - "$T/me/.forge/liaison/$CH/log/local-me.jsonl" "$msgid_ok" "$(fp_of OK)" <<'NODEEOF'
const fs = require('fs');
const [, , file, msgId, nativeRef] = process.argv;
const lines = fs.readFileSync(file, 'utf8').trim().split('\n').map((l) => JSON.parse(l));
const m = lines.find((x) => x.msg_id === msgId);
if (!m) { console.error('mensagem não encontrada'); process.exit(1); }
if (m.via !== 'cross-session') { console.error(`via esperado 'cross-session', veio '${m.via}'`); process.exit(1); }
if (m.trust !== 'untrusted-peer') { console.error(`trust esperado 'untrusted-peer', veio '${m.trust}'`); process.exit(1); }
const cs = m.cross_session;
if (!cs) { console.error('cross_session ausente'); process.exit(1); }
for (const f of ['from_addr', 'from_name', 'from_mode', 'native_ref', 'origin_verified']) {
  if (!(f in cs)) { console.error(`cross_session.${f} ausente`); process.exit(1); }
}
if (cs.native_ref !== nativeRef) { console.error(`native_ref gravado difere do fingerprint`); process.exit(1); }
if (cs.origin_verified !== true) { console.error(`origin_verified deveria ser true para o cenário OK`); process.exit(1); }
if (cs.from_name !== 'PEER-OK') { console.error(`from_name gravado inesperado: ${cs.from_name}`); process.exit(1); }
NODEEOF
pass "envelope gravado tem cross_session completo (via, trust, os cinco subcampos)"

echo "=== check-liaison-acks.sh ==="
set +e
ack_out="$(cd "$T/me" && FORGE_ROOT="$T/me" bash "$T/me/.forge/scripts/check-liaison-acks.sh" 2>&1)"; ack_rc=$?
set -e
[ "$ack_rc" -eq 0 ] || fail "check-liaison-acks.sh não aceitou a mensagem cross-session: $ack_out"
pass "check-liaison-acks.sh aceita a mensagem no log próprio"

echo "=== inbox --show e render ==="
inbox_out="$(LG me inbox "$CH" --show)"
grep -q 'via: cross-session' <<<"$inbox_out" || fail "inbox --show não mostra 'via: cross-session': $inbox_out"
grep -q 'nome declarado (autodeclarado): PEER-UNRESOLVED' <<<"$inbox_out" || fail "inbox --show não mostra o nome autodeclarado: $inbox_out"
grep -q 'modo declarado: default' <<<"$inbox_out" || fail "inbox --show não mostra o modo declarado: $inbox_out"
grep -q 'origem não verificada' <<<"$inbox_out" || fail "inbox --show não mostra 'origem não verificada' para origin_verified:false: $inbox_out"
pass "inbox --show exibe via/nome/modo declarados e 'origem não verificada' dentro da moldura"

render_md="$(cat "$T/me/.forge/liaison/$CH/CHANNEL.md")"
grep -q 'via: cross-session' <<<"$render_md" || fail "CHANNEL.md não mostra 'via: cross-session'"
grep -q 'nome declarado (autodeclarado): PEER-OK' <<<"$render_md" || fail "CHANNEL.md não mostra o nome autodeclarado"
pass "render (CHANNEL.md) mostra via/nome autodeclarado"

echo "PASS liaison-cross-session-record-gate ($N assertions)"
