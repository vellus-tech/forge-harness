#!/usr/bin/env bash
# ORDINAL: wNNN atribuído na hora do merge
# Gate — diagnóstico de cobertura `native check`/`native dispose` e fiação SessionEnd/SessionStart
# (TASK-10, STORY-06; design §2.6, REQ-08).
#
# Parte A: fiação de SessionEnd em sync-adapters.mjs nas quatro combinações de
# handoff.auto/liaison.auto (via instalação real + sync-adapters.sh, settings.json gerado).
# Parte B: comportamento de on-session-end.sh nas mesmas quatro combinações (handoff e native
# check independentes, inclusive quando o script de UMA das partes está ausente); sempre exit 0.
# Parte C: `native check`/`native dispose` — destinação por registro e por dispose, classes,
# outro workspace/workspace desconhecido, moldura (untrusted-render), --session/--transcript/
# ambiente, recusa sem sessão, persistência fora da árvore e entrega única com lista curta.
# Parte D: `on-session-start.sh` exibe o relatório pendente no bloco do liaison.
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-native-coverage.XXXXXX)"
trap 'rm -rf "$T"' EXIT

N=0
pass() { N=$((N + 1)); echo "OK [$N] $1"; }
fail() { N=$((N + 1)); echo "FAIL [$N] $1"; exit 1; }

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
  git -C "$dir" commit --allow-empty -qm "chore: init" >/dev/null
}

# set_auto <forge.yaml-path> <key> <true|false>
set_auto() {
  node - "$1" "$2" "$3" <<'NODEEOF'
const fs = require('fs');
const [, , f, key, v] = process.argv;
let y = fs.readFileSync(f, 'utf8');
const re = new RegExp('^' + key + ':\\n((?:[ ].*\\n)*?)([ ]+auto:[ ]*)(true|false)', 'm');
if (!re.test(y)) { console.error(`chave '${key}' não encontrada`); process.exit(1); }
y = y.replace(re, (m, p1, p2) => `${key}:\n${p1}${p2}${v}`);
fs.writeFileSync(f, y);
NODEEOF
}

echo "=== Parte A: fiação de SessionEnd (sync-adapters.mjs) nas quatro combinações ==="
mk_a_combo() { # mk_a_combo <label> <handoff> <liaison>
  local label="$1" handoff="$2" liaison="$3"
  local dir="$T/wiring-$label"
  "$WS/installer/install.sh" --target "$dir" --slug "fixture-$label" --name "Fixture $label" --desc "Gate native coverage" >/dev/null
  set_auto "$dir/.forge/forge.yaml" handoff "$handoff"
  set_auto "$dir/.forge/forge.yaml" liaison "$liaison"
  (cd "$dir" && bash .forge/scripts/sync-adapters.sh --adapter claude >/dev/null)
  printf '%s' "$dir/.claude/settings.json"
}

s1="$(mk_a_combo ff false false)"
grep -q '"SessionEnd"' "$s1" && fail "fiação [handoff=false,liaison=false] não deveria ter SessionEnd"
pass "fiação SessionEnd — handoff=false liaison=false: ausente"

s2="$(mk_a_combo tf true false)"
grep -q '"SessionEnd"' "$s2" || fail "fiação [handoff=true,liaison=false] deveria ter SessionEnd"
pass "fiação SessionEnd — handoff=true liaison=false: presente"

s3="$(mk_a_combo ft false true)"
grep -q '"SessionEnd"' "$s3" || fail "fiação [handoff=false,liaison=true] deveria ter SessionEnd (liaison.auto sozinho arma)"
pass "fiação SessionEnd — handoff=false liaison=true: presente (comportamento novo)"

s4="$(mk_a_combo tt true true)"
grep -q '"SessionEnd"' "$s4" || fail "fiação [handoff=true,liaison=true] deveria ter SessionEnd"
pass "fiação SessionEnd — handoff=true liaison=true: presente"

echo "=== Parte B: comportamento de on-session-end.sh nas quatro combinações ==="
mk_repo be
PROJ_B="$T/projects-b/slug"; mkdir -p "$PROJ_B"
node - "$PROJ_B/be-session.jsonl" <<'NODEEOF'
const fs = require('fs');
const from = 'uds:/tmp/cc-socks/60001.sock', fromName = 'PEER-B', fromMode = 'default', body = 'corpo-b';
const tag = `<cross-session-message from="${from}" from-name="${fromName}" from-mode="${fromMode}">\n${body}\n</cross-session-message>`;
const content = `Another Claude session sent a message:\n${tag}\n\n(fixo)`;
const obj = { type: 'user', isMeta: true, isSidechain: false, turnOrigin: 'peer', promptSource: 'system', uuid: 'u', sessionId: 'B', timestamp: '2026-10-30T00:00:00.000Z', message: { role: 'user', content } };
fs.writeFileSync(process.argv[2], JSON.stringify(obj) + '\n');
NODEEOF
PAYLOAD_B='{"transcript_path":"'"$PROJ_B"'/be-session.jsonl","session_id":"be-session"}'

run_end() { # run_end <handoff> <liaison> -> ecoa o rc
  set_auto "$T/be/.forge/forge.yaml" handoff "$1"
  set_auto "$T/be/.forge/forge.yaml" liaison "$2"
  rm -f "$T/be/.forge/HANDOFF_MARKER"
  rm -rf "$T/be/.git/forge-native"
  local rc
  (cd "$T/be" && FORGE_CLAUDE_PROJECTS_DIR="$T/projects-b" printf '%s' "$PAYLOAD_B" | bash .forge/hooks/session/on-session-end.sh >/tmp/oses-out.$$.log 2>&1)
  rc=$?
  echo "$rc"
}

cat > "$T/be/.forge/scripts/handoff-gen.sh" <<'EOF'
#!/usr/bin/env bash
touch "$(dirname "$0")/../HANDOFF_MARKER"
EOF
chmod +x "$T/be/.forge/scripts/handoff-gen.sh"

rc="$(run_end false false)"
[ "$rc" -eq 0 ] || fail "on-session-end.sh [handoff=false,liaison=false] não saiu exit 0"
[ ! -f "$T/be/.forge/HANDOFF_MARKER" ] || fail "handoff rodou com handoff.auto=false"
[ ! -d "$T/be/.git/forge-native" ] || fail "liaison (native check) rodou com liaison.auto=false"
pass "on-session-end — handoff=false liaison=false: nenhuma parte roda, exit 0"

rc="$(run_end true false)"
[ "$rc" -eq 0 ] || fail "on-session-end.sh [handoff=true,liaison=false] não saiu exit 0"
[ -f "$T/be/.forge/HANDOFF_MARKER" ] || fail "handoff NÃO rodou com handoff.auto=true"
[ ! -d "$T/be/.git/forge-native" ] || fail "liaison rodou com liaison.auto=false"
pass "on-session-end — handoff=true liaison=false: só o handoff roda"

rc="$(run_end false true)"
[ "$rc" -eq 0 ] || fail "on-session-end.sh [handoff=false,liaison=true] não saiu exit 0"
[ ! -f "$T/be/.forge/HANDOFF_MARKER" ] || fail "handoff rodou com handoff.auto=false"
[ -f "$T/be/.git/forge-native/reports/be-session.json" ] || fail "native check --report NÃO rodou com liaison.auto=true"
# brokenInstrument:false prova que o transcript de fixture foi de fato lido (não só "relatório
# existe" — um relatório de leitura FALHADA também seria persistido, e esconderia uma fixture
# quebrada por trás de um "OK" enganoso).
node - "$T/be/.git/forge-native/reports/be-session.json" <<'NODEEOF'
const fs = require('fs');
const r = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (r.brokenInstrument !== false) { console.error(`relatório com brokenInstrument=${r.brokenInstrument} — o transcript de fixture não foi lido de verdade`); process.exit(1); }
if (!r.counts || r.counts.total !== 1) { console.error(`esperava 1 recepção no relatório, veio ${r.counts && r.counts.total}`); process.exit(1); }
NODEEOF
pass "on-session-end — handoff=false liaison=true: só o native check roda (relatório reflete leitura real)"

rc="$(run_end true true)"
[ "$rc" -eq 0 ] || fail "on-session-end.sh [handoff=true,liaison=true] não saiu exit 0"
[ -f "$T/be/.forge/HANDOFF_MARKER" ] || fail "handoff NÃO rodou com os dois flags true"
[ -f "$T/be/.git/forge-native/reports/be-session.json" ] || fail "native check NÃO rodou com os dois flags true"
pass "on-session-end — handoff=true liaison=true: as duas partes rodam"

# Ausência do SCRIPT de uma parte nunca impede a outra (design §2.6).
rm -f "$T/be/.forge/scripts/handoff-gen.sh"
rc="$(run_end true true)"
[ "$rc" -eq 0 ] || fail "on-session-end.sh sem handoff-gen.sh não saiu exit 0"
[ -f "$T/be/.git/forge-native/reports/be-session.json" ] || fail "native check não rodou mesmo sem handoff-gen.sh presente"
pass "on-session-end — ausência de handoff-gen.sh não impede o native check"

mv "$T/be/.forge/scripts/liaison-ops.sh" "$T/liaison-ops.sh.hidden"
cat > "$T/be/.forge/scripts/handoff-gen.sh" <<'EOF'
#!/usr/bin/env bash
touch "$(dirname "$0")/../HANDOFF_MARKER"
EOF
chmod +x "$T/be/.forge/scripts/handoff-gen.sh"
rc="$(run_end true true)"
[ "$rc" -eq 0 ] || fail "on-session-end.sh sem liaison-ops.sh não saiu exit 0"
[ -f "$T/be/.forge/HANDOFF_MARKER" ] || fail "handoff não rodou mesmo sem liaison-ops.sh presente"
pass "on-session-end — ausência de liaison-ops.sh não impede o handoff"
mv "$T/liaison-ops.sh.hidden" "$T/be/.forge/scripts/liaison-ops.sh"

echo "=== Parte C: native check / native dispose ==="
mk_repo c
# CLAUDE_CODE_SESSION_ID: sempre despido (env -u) — este gate roda DENTRO de uma sessão real do
# Claude Code, e a variável do ambiente real apontaria para o transcript/projeto REAL do
# orquestrador, não para a fixture, em qualquer chamada que omita --session.
# FORGE_CLAUDE_PROJECTS_DIR é o PAI de "slug" — o glob de locateTranscript é
# <projectsDir>/*/<sessionId>.jsonl (PROJ_C já inclui o "slug").
LG() { env -u CLAUDE_CODE_SESSION_ID FORGE_ROOT="$T/c" FORGE_CLAUDE_PROJECTS_DIR="$T/projects-c" FORGE_CLAUDE_SESSIONS_DIR="$SESS_C" bash "$T/c/.forge/scripts/liaison-ops.sh" "$@"; }
LG_PLAIN() { env -u CLAUDE_CODE_SESSION_ID FORGE_ROOT="$T/c" bash "$T/c/.forge/scripts/liaison-ops.sh" "$@"; }

PROJ_C="$T/projects-c/slug"; mkdir -p "$PROJ_C"
SESS_C="$T/sessions-c"; mkdir -p "$SESS_C"

mkdir -p "$T/other-repo"
git init -q "$T/other-repo"
git -C "$T/other-repo" config user.email o@test; git -C "$T/other-repo" config user.name o; git -C "$T/other-repo" config commit.gpgsign false
git -C "$T/other-repo" commit --allow-empty -qm "chore: init" >/dev/null

node - "$SESS_C" "$T/c" "$T/other-repo" "$$" <<'NODEEOF'
const fs = require('fs'); const path = require('path');
const [, , dir, sameRepo, otherRepo, mypid] = process.argv;
fs.writeFileSync(path.join(dir, 'entry-same.json'), JSON.stringify({ pid: Number(mypid), name: 'PEER-SAME', cwd: sameRepo, messagingSocketPath: path.join(dir, 'same.sock'), sessionId: 'same-session' }));
fs.writeFileSync(path.join(dir, 'entry-other.json'), JSON.stringify({ pid: Number(mypid), name: 'PEER-OTHER', cwd: otherRepo, messagingSocketPath: path.join(dir, 'other.sock'), sessionId: 'other-session' }));
NODEEOF
# sockets reais (as entradas acima só são "vivas" com socket existente de verdade).
node -e '
const net = require("net");
for (const p of process.argv.slice(1)) net.createServer().listen(p);
setInterval(() => {}, 1 << 30);
' "$SESS_C/same.sock" "$SESS_C/other.sock" &
SOCK_PID_C=$!
disown "$SOCK_PID_C" 2>/dev/null || true
i=0
until [ -S "$SESS_C/same.sock" ] && [ -S "$SESS_C/other.sock" ]; do
  i=$((i + 1)); [ "$i" -lt 100 ] || { echo "FAIL [0]: sockets da Parte C não vieram a existir"; exit 1; }
  sleep 0.05
done
_cleanup_c() { kill "$SOCK_PID_C" 2>/dev/null || true; }
trap '_cleanup_c; rm -rf "$T"' EXIT

FP_MAP_C="$(node - "$WS/template/.forge/scripts/lib" "$PROJ_C/c-session.jsonl" "$SESS_C" "$$" <<'NODEEOF'
const fs = require('fs');
const { pathToFileURL } = require('url');
const { join } = require('path');
(async () => {
  const [, , lib, outFile, sessDir, mypid] = process.argv;
  const T = await import(pathToFileURL(join(lib, 'native-transcript.mjs')).href);

  function line({ from, fromName, fromMode, body, verifiedPeerPid }) {
    const tag = `<cross-session-message from="${from}" from-name="${fromName}" from-mode="${fromMode}">\n${body}\n</cross-session-message>`;
    const content = `Another Claude session sent a message:\n${tag}\n\n(fixo).`;
    const obj = { type: 'user', isMeta: true, isSidechain: false, turnOrigin: 'peer', promptSource: 'system', uuid: 'u', sessionId: 'C', timestamp: '2026-10-30T00:00:00.000Z', message: { role: 'user', content } };
    if (typeof verifiedPeerPid === 'number') obj.origin = { kind: 'peer', from, verifiedPeerPid, msg_id: 'uuid', name: fromName, fromMode, body };
    return JSON.stringify(obj);
  }

  const scenarios = {
    PENDING: { from: 'uds:/tmp/cc-socks/70001.sock', fromName: 'PEER-PENDING', fromMode: 'default', body: 'corpo-pending' },
    REGISTERED: { from: 'uds:/tmp/cc-socks/70002.sock', fromName: 'PEER-REGISTERED', fromMode: 'default', body: 'corpo-registered' },
    DISPOSED: { from: 'uds:/tmp/cc-socks/70003.sock', fromName: 'PEER-DISPOSED', fromMode: 'default', body: 'corpo-disposed' },
    SAME: { from: `uds:${join(sessDir, 'same.sock')}`, fromName: 'PEER-SAME', fromMode: 'default', body: 'corpo-same', verifiedPeerPid: Number(mypid) },
  };
  const lines = [];
  const out = [];
  for (const [name, s] of Object.entries(scenarios)) { lines.push(line(s)); out.push(`${name}=${T.fingerprint(s.from, s.fromName, s.body)}`); }
  fs.writeFileSync(outFile, lines.join('\n') + '\n');
  process.stdout.write(out.join('\n') + '\n');
})();
NODEEOF
)"
FP_FILE_C="$T/fingerprints-c.txt"
printf '%s\n' "$FP_MAP_C" > "$FP_FILE_C"
fp_of_c() { awk -F= -v k="$1" '$1==k{print $2; found=1} END{if(!found) exit 1}' "$FP_FILE_C"; }

# OTHER scenario precisa do mypid na última posição — adicionado por chamada separada (evita
# reaproveitar o node acima, que já fechou o array).
node - "$PROJ_C/c-session.jsonl" "$SESS_C" "$$" "$FP_FILE_C" <<'NODEEOF'
const fs = require('fs'); const { join } = require('path');
const [, , transcriptFile, sessDir, mypid, fpFile] = process.argv;
const from = `uds:${join(sessDir, 'other.sock')}`, fromName = 'PEER-OTHERWS', fromMode = 'default', body = 'corpo-other';
const tag = `<cross-session-message from="${from}" from-name="${fromName}" from-mode="${fromMode}">\n${body}\n</cross-session-message>`;
const content = `Another Claude session sent a message:\n${tag}\n\n(fixo).`;
const obj = { type: 'user', isMeta: true, isSidechain: false, turnOrigin: 'peer', promptSource: 'system', uuid: 'u2', sessionId: 'C', timestamp: '2026-10-30T00:00:01.000Z', message: { role: 'user', content }, origin: { kind: 'peer', from, verifiedPeerPid: Number(mypid), msg_id: 'u2', name: fromName, fromMode, body } };
fs.appendFileSync(transcriptFile, JSON.stringify(obj) + '\n');
const crypto = require('crypto');
const fp = crypto.createHash('sha256').update(Buffer.from(JSON.stringify([from, fromName, body]), 'utf8')).digest('hex');
fs.appendFileSync(fpFile, `OTHERWS=${fp}\n`);
NODEEOF

echo "=== recusa sem sessão identificável ==="
set +e
out="$(LG_PLAIN native check 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] && grep -qi 'sessão não identificável' <<<"$out" || fail "native check sem --session/--transcript/ambiente deveria recusar: $out"
pass "native check sem sessão identificável recusa (único caso de rc != 0)"

echo "=== destinação por registro (send --via cross-session) ==="
LG open native-ch --self local-c --participants native-peer >/dev/null
LG thread open native-ch native-thread --subject "cobertura" --participants local-c >/dev/null
LG send native-ch --thread native-thread --kind note --subject "nativo" --body "resumo" \
  --authored-by native-peer --via cross-session --native-ref "$(fp_of_c REGISTERED)" --session c-session >/dev/null

echo "=== destinação por dispose ==="
LG_PLAIN native dispose "$(fp_of_c DISPOSED)" --ephemeral presence >/dev/null

echo "=== classes inválidas recusam ==="
set +e
out="$(LG_PLAIN native dispose "$(fp_of_c PENDING)" --ephemeral nao-existe 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] && grep -qi 'classe' <<<"$out" || fail "native dispose com classe inválida deveria recusar: $out"
pass "native dispose — classe efêmera inválida recusa"

echo "=== native check --session agrega destinação, workspace e moldura ==="
check_out="$(LG native check --session c-session)"
grep -q "$(fp_of_c PENDING)" <<<"$check_out" || fail "native check não listou a recepção PENDING: $check_out"
grep -q "$(fp_of_c REGISTERED)" <<<"$check_out" && fail "native check listou REGISTERED como pendente (já destinada por registro): $check_out"
grep -q "$(fp_of_c DISPOSED)" <<<"$check_out" && fail "native check listou DISPOSED como pendente (já destinada por dispose): $check_out"
grep -q 'outro workspace' <<<"$check_out" || fail "native check não sinalizou nenhuma recepção de outro workspace: $check_out"
grep -q 'workspace desconhecido' <<<"$check_out" || fail "native check não sinalizou nenhuma recepção de workspace desconhecido: $check_out"
grep -qi 'UNTRUSTED' <<<"$check_out" || fail "native check não embrulhou o relatório na moldura untrusted-render: $check_out"
pass "native check --session: destinação por registro/dispose, outro/desconhecido, moldura"

echo "=== --transcript explícito dá o mesmo resultado que --session ==="
check_out2="$(LG native check --transcript "$PROJ_C/c-session.jsonl")"
grep -q "$(fp_of_c PENDING)" <<<"$check_out2" || fail "native check --transcript não listou PENDING: $check_out2"
pass "native check --transcript <path> funciona sem --session"

echo "=== persistência fora da árvore e entrega única ==="
state_dir="$(cd "$T/c" && git rev-parse --path-format=absolute --git-common-dir)/forge-native"
[ -d "$T/c/.forge" ] && [ ! -d "$T/c/forge-native" ] || true
LG native check --session c-session --report >/dev/null
[ -f "$state_dir/reports/c-session.json" ] || fail "native check --report não persistiu em $state_dir/reports/c-session.json"
# fora da árvore versionada (não sob .forge/)
case "$state_dir" in "$T/c/.forge"*) fail "estado nativo persistido DENTRO de .forge (deveria ser git-common-dir/forge-native)";; esac
pass "persistência em <git-common-dir>/forge-native/, fora da árvore de trabalho"

pending1="$(LG_PLAIN native check --pending)"
grep -q 'c-session' <<<"$pending1" || fail "native check --pending não mostrou o relatório recém-persistido: $pending1"
pending2="$(LG_PLAIN native check --pending)"
grep -q 'c-session' <<<"$pending2" && fail "native check --pending mostrou o MESMO relatório duas vezes (entrega única violada): $pending2"
pass "native check --pending — entrega única (segunda chamada não repete)"

echo "=== lista curta (máx. 5 linhas + contagem) ==="
node - "$state_dir/reports" <<'NODEEOF'
const fs = require('fs'); const path = require('path');
const dir = process.argv[2];
for (let i = 0; i < 7; i++) {
  fs.writeFileSync(path.join(dir, `many-${i}.json`), JSON.stringify({
    sessionId: `many-${i}`, generatedAt: `2026-10-${10 + i}T00:00:00Z`, delivered: false,
    brokenInstrument: false, counts: { total: 1, pending: 1, otherWorkspace: 0, unknownWorkspace: 0 }, pending: [],
  }));
}
NODEEOF
many_out="$(LG_PLAIN native check --pending)"
shown_lines="$(grep -c 'sessão' <<<"$many_out" || true)"
[ "$shown_lines" -le 5 ] || fail "native check --pending mostrou mais de 5 linhas individuais: $many_out"
grep -qE '\+[0-9]+ relatório' <<<"$many_out" || fail "native check --pending não resumiu o excedente em '+N relatório(s)': $many_out"
pass "native check --pending — lista curta (máx. 5) + contagem do excedente"

echo "=== Parte D: on-session-start.sh exibe o relatório pendente ==="
mk_repo d
set_auto "$T/d/.forge/forge.yaml" liaison true
LG_D() { FORGE_ROOT="$T/d" bash "$T/d/.forge/scripts/liaison-ops.sh" "$@"; }
LG_D open native-ch-d --self local-d --participants peer-d >/dev/null
# relatório pendente fabricado diretamente no estado local de "d" (equivalente a um SessionEnd
# anterior que já persistiu).
state_dir_d="$(cd "$T/d" && git rev-parse --path-format=absolute --git-common-dir)/forge-native"
mkdir -p "$state_dir_d/reports"
node - "$state_dir_d/reports/d-session.json" <<'NODEEOF'
const fs = require('fs');
fs.writeFileSync(process.argv[2], JSON.stringify({
  sessionId: 'd-session', generatedAt: '2026-10-30T00:00:00Z', delivered: false,
  brokenInstrument: false, counts: { total: 1, pending: 1, otherWorkspace: 0, unknownWorkspace: 0 }, pending: [],
}));
NODEEOF
start_out="$(cd "$T/d" && bash .forge/hooks/session/on-session-start.sh)"
grep -q 'mensagens nativas recebidas' <<<"$start_out" || fail "on-session-start.sh não exibiu o bloco de relatório pendente: $start_out"
grep -q 'd-session' <<<"$start_out" || fail "on-session-start.sh não citou a sessão do relatório pendente: $start_out"
pass "on-session-start.sh — bloco do liaison exibe native check --pending"

echo "PASS native-coverage-gate ($N assertions)"
