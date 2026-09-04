#!/usr/bin/env bash
# Gate W113 — enforcement opt-in de ack no liaison (Onda 4):
#   [1] enforce:warn — contract-change inbound sem ack AVISA e deixa passar
#   [2] enforce:block — o mesmo caso REPROVA citando o msg_id
#   [3] o ack desbloqueia
#   [4] com três participantes, o ack de UM não desbloqueia o outro (cada um pelo próprio)
#   [5] quem não participa da thread não é cobrado
#   [6] mensagem sem requires_ack nunca bloqueia, mesmo em block
#   [7] ack --reason wont-adopt acka E registra tech-debt no ledger (recusa vira dívida, não silêncio)
#   [8] o pre-push aplica o enforcement e cita o msg_id
#   [9] o pré-flight do archive aplica; spec-close NUNCA é bloqueado
#   [10] o gate nunca invoca `claude -p` (o ask-peer é .md, não .sh)
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w113.XXXXXX)"
trap 'rm -rf "$T"' EXIT

CH=contracts-fare
TH=fare-grpc-v1

mk_repo() { # mk_repo <dir> <self-id>
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

LG() { local repo="$1"; shift; FORGE_ROOT="$T/$repo" bash "$T/$repo/.forge/scripts/liaison-ops.sh" "$@"; }

set_enforce() { # set_enforce <repo> <warn|block>
  node -e '
    const fs=require("fs"); const [f,v]=process.argv.slice(1);
    let y=fs.readFileSync(f,"utf8");
    if (/^liaison:/m.test(y)) y=y.replace(/^(liaison:\n(?:[ ].*\n)*?[ ]+enforce:[ ]*)(warn|block)/m, `$1${v}`);
    else y+=`\nliaison:\n  auto: false\n  enforce: ${v}\n`;
    fs.writeFileSync(f,y);
  ' "$T/$1/.forge/forge.yaml" "$2"
}

# Constrói um bundle com um contract-change de <sender> exigindo ack, e importa em <repo>.
inbound_contract_change() { # inbound_contract_change <repo> <sender> <seq> <thread> <participants-csv>
  local repo="$1" sender="$2" seq="$3" thread="$4" parts="$5"
  local dir="$T/bundle-$sender-$seq"
  mkdir -p "$dir/log"
  node - "$WS/template/.forge/scripts/lib" "$CH" "$sender" "$seq" "$thread" "$parts" <<'NODEEOF' > "$dir/log/$sender.jsonl"
const { join } = require('path'); const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, channel, sender, seqRaw, thread, parts] = process.argv;
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const seq = Number(seqRaw);
  const out = [];
  if (seq === 1) {
    const open = {
      msg_id: `${sender}-0001`, channel, thread_id: thread, sender, seq: 1, lamport: 1,
      kind: 'thread-open', in_reply_to: null, requires_ack: false, subject: `abertura ${thread}`,
      participants: parts.split(','), refs: { change_id: null, contract_files: [], commit: null },
      created_at: '2026-01-01T00:00:00Z',
    };
    open.content_sha = M.computeContentSha(open); open.trust = 'self';
    out.push(open);
  }
  const cc = {
    msg_id: `${sender}-${String(seq + 1).padStart(4, '0')}`, channel, thread_id: thread, sender,
    seq: seq + 1, lamport: seq + 1, kind: 'contract-change', in_reply_to: null, requires_ack: true,
    subject: `mudanca de contrato ${seq}`, body: 'campo novo em fare.proto',
    refs: { change_id: null, contract_files: ['contracts/fare.proto'], commit: null },
    created_at: '2026-01-01T00:00:00Z',
  };
  cc.content_sha = M.computeContentSha(cc); cc.trust = 'self';
  out.push(cc);
  process.stdout.write(out.map((m) => JSON.stringify(m)).join('\n') + '\n');
})();
NODEEOF
  LG "$repo" import "$CH" --from "$dir" >/dev/null
}

CHECK() { # CHECK <repo> -> roda o check de acks; ecoa saída, devolve rc
  set +e
  ACK_OUT="$(cd "$T/$1" && FORGE_ROOT="$T/$1" bash "$T/$1/.forge/scripts/check-liaison-acks.sh" 2>&1)"; ACK_RC=$?
  set -e
}

mk_repo fv axis-fare-validator
LG fv open "$CH" --self axis-fare-validator --participants axis-go-cloud,axis-fare-validator,axis-pad-simulator >/dev/null
inbound_contract_change fv axis-go-cloud 1 "$TH" axis-go-cloud,axis-fare-validator,axis-pad-simulator
MSGID=axis-go-cloud-0002

echo "[1] enforce:warn avisa e deixa passar"
set_enforce fv warn
CHECK fv
[ "$ACK_RC" -eq 0 ] || { echo "FAIL [1]: warn bloqueou (rc=$ACK_RC): $ACK_OUT"; exit 1; }
grep -q "$MSGID" <<<"$ACK_OUT" || { echo "FAIL [1]: warn não avisou citando o msg_id: $ACK_OUT"; exit 1; }
echo "OK [1]"

echo "[1b] enforce AUSENTE do forge.yaml se comporta como warn, nunca como block"
# Ausência de configuração não pode ser mais severa que a configuração explícita mais branda:
# um repositório que nunca ouviu falar de enforcement não pode ter o push travado por isso.
node -e '
  const fs=require("fs"); const f=process.argv[1];
  fs.writeFileSync(f, fs.readFileSync(f,"utf8").replace(/^liaison:\n(?:[ ].*\n)*/m, ""));
' "$T/fv/.forge/forge.yaml"
grep -q '^liaison:' "$T/fv/.forge/forge.yaml" && { echo "FAIL [1b]: pré-condição — bloco liaison não foi removido"; exit 1; }
CHECK fv
[ "$ACK_RC" -eq 0 ] || { echo "FAIL [1b]: sem bloco liaison no forge.yaml o check bloqueou (default deveria ser warn): $ACK_OUT"; exit 1; }
echo "OK [1b]"

echo "[1c] quem ENVIOU o contract-change não é cobrado pelo próprio ack"
mk_repo gc axis-go-cloud
LG gc open "$CH" --self axis-go-cloud --participants axis-go-cloud,axis-fare-validator >/dev/null
set_enforce gc block
LG gc thread open "$CH" own-thread --subject "minha thread" --participants axis-go-cloud,axis-fare-validator >/dev/null
LG gc send "$CH" --thread own-thread --kind contract-change --subject "eu mesmo mudei" \
  --body "campo novo" --contract-files contracts/fare.proto --requires-ack >/dev/null
CHECK gc
[ "$ACK_RC" -eq 0 ] || { echo "FAIL [1c]: cobrou ack da própria mensagem — ackar a si mesmo não informa ninguém: $ACK_OUT"; exit 1; }
echo "OK [1c]"

echo "[2] enforce:block reprova citando o msg_id"
set_enforce fv block
set_enforce fv block
CHECK fv
[ "$ACK_RC" -ne 0 ] || { echo "FAIL [2]: block deixou passar contract-change sem ack: $ACK_OUT"; exit 1; }
grep -q "$MSGID" <<<"$ACK_OUT" || { echo "FAIL [2]: bloqueio não cita o msg_id pendente: $ACK_OUT"; exit 1; }
echo "OK [2]"

echo "[3] o ack desbloqueia"
LG fv ack "$CH" "$MSGID" >/dev/null
CHECK fv
[ "$ACK_RC" -eq 0 ] || { echo "FAIL [3]: continua bloqueado depois do ack: $ACK_OUT"; exit 1; }
echo "OK [3]"

echo "[4] com três participantes, o ack de um não desbloqueia o outro"
mk_repo pad axis-pad-simulator
LG pad open "$CH" --self axis-pad-simulator --participants axis-go-cloud,axis-fare-validator,axis-pad-simulator >/dev/null
set_enforce pad block
inbound_contract_change pad axis-go-cloud 1 "$TH" axis-go-cloud,axis-fare-validator,axis-pad-simulator
# leva o ack de fv (terceiro) para o repo de pad — não pode contar como ack DELE
LG fv export "$CH" --out "$T/bundle-fv-ack" >/dev/null
LG pad import "$CH" --from "$T/bundle-fv-ack" >/dev/null
CHECK pad
[ "$ACK_RC" -ne 0 ] || { echo "FAIL [4]: o ack de axis-fare-validator desbloqueou axis-pad-simulator: $ACK_OUT"; exit 1; }
grep -q "$MSGID" <<<"$ACK_OUT" || { echo "FAIL [4]: não cita o msg_id"; exit 1; }
echo "OK [4]"

echo "[5] quem não participa da thread não é cobrado"
mk_repo obs observer
LG obs open "$CH" --self observer --participants axis-go-cloud,axis-fare-validator,axis-pad-simulator,observer >/dev/null
set_enforce obs block
LG obs import "$CH" --from "$T/bundle-axis-go-cloud-1" >/dev/null   # vê a thread, mas não é participante
CHECK obs
[ "$ACK_RC" -eq 0 ] || { echo "FAIL [5]: cobrou ack de quem não participa da thread: $ACK_OUT"; exit 1; }
echo "OK [5]"

echo "[6] mensagem sem requires_ack nunca bloqueia"
mk_repo nr no-req
LG nr open "$CH" --self no-req --participants axis-go-cloud,no-req >/dev/null
set_enforce nr block
mkdir -p "$T/bundle-noack/log"
node - "$WS/template/.forge/scripts/lib" "$CH" <<'NODEEOF' > "$T/bundle-noack/log/axis-go-cloud.jsonl"
const { join } = require('path'); const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, channel] = process.argv;
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const mk = (o) => { const m = { ...o }; m.content_sha = M.computeContentSha(m); m.trust = 'self'; return m; };
  const open = mk({ msg_id: 'axis-go-cloud-0001', channel, thread_id: 'no-ack-thread', sender: 'axis-go-cloud', seq: 1, lamport: 1, kind: 'thread-open', in_reply_to: null, requires_ack: false, subject: 'abertura', participants: ['axis-go-cloud', 'no-req'], refs: { change_id: null, contract_files: [], commit: null }, created_at: '2026-01-01T00:00:00Z' });
  const cc = mk({ msg_id: 'axis-go-cloud-0002', channel, thread_id: 'no-ack-thread', sender: 'axis-go-cloud', seq: 2, lamport: 2, kind: 'contract-change', in_reply_to: null, requires_ack: false, subject: 'mudou mas nao cobra ack', body: 'x', refs: { change_id: null, contract_files: ['contracts/fare.proto'], commit: null }, created_at: '2026-01-01T00:00:00Z' });
  process.stdout.write([open, cc].map((m) => JSON.stringify(m)).join('\n') + '\n');
})();
NODEEOF
LG nr import "$CH" --from "$T/bundle-noack" >/dev/null
CHECK nr
[ "$ACK_RC" -eq 0 ] || { echo "FAIL [6]: bloqueou mensagem sem requires_ack: $ACK_OUT"; exit 1; }
echo "OK [6]"

echo "[7] ack --reason wont-adopt acka e registra tech-debt no ledger"
CHECK pad
[ "$ACK_RC" -ne 0 ] || { echo "FAIL [7]: pré-condição — pad deveria estar bloqueado"; exit 1; }
# --reason wont-adopt exige --body/--body-file desde a issue #83 (w166 cobre a reprovação em si:
# recusa sem justificativa é o próprio drift que o canal existe para evitar).
LG pad ack "$CH" "$MSGID" --reason wont-adopt --body "avaliamos e decidimos não adotar" >/dev/null
CHECK pad
[ "$ACK_RC" -eq 0 ] || { echo "FAIL [7]: wont-adopt não desbloqueou: $ACK_OUT"; exit 1; }
[ -f "$T/pad/.forge/ledger/ledger.json" ] || { echo "FAIL [7]: ledger não foi criado"; exit 1; }
node -e '
  const fs=require("fs");
  const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const hit=(d.entries||[]).find(e=>e.type==="tech-debt" && JSON.stringify(e).includes(process.argv[2]));
  if(!hit){ console.error("nenhum tech-debt citando o msg_id no ledger"); process.exit(1); }
' "$T/pad/.forge/ledger/ledger.json" "$MSGID" || { echo "FAIL [7]: recusa não virou dívida registrada"; exit 1; }
echo "OK [7]"

echo "[8] o pre-push aplica o enforcement e cita o msg_id"
mk_repo pp push-repo
LG pp open "$CH" --self push-repo --participants axis-go-cloud,push-repo >/dev/null
set_enforce pp block
inbound_contract_change pp axis-go-cloud 1 "$TH" axis-go-cloud,push-repo
git -C "$T/pp" add -A >/dev/null 2>&1 || true
git -C "$T/pp" commit -qm "chore: estado" >/dev/null 2>&1 || true
parent="$(git -C "$T/pp" rev-parse HEAD~1 2>/dev/null || git -C "$T/pp" rev-parse HEAD)"
head_sha="$(git -C "$T/pp" rev-parse HEAD)"
set +e
pp_out="$(cd "$T/pp" && printf '%s\n' "refs/heads/main $head_sha refs/heads/main $parent" | bash .forge/hooks/git/pre-push origin "file://$T/pp" 2>&1)"; pp_rc=$?
set -e
[ "$pp_rc" -ne 0 ] || { echo "FAIL [8]: pre-push passou com ack pendente em enforce:block: $pp_out"; exit 1; }
grep -q "$MSGID" <<<"$pp_out" || { echo "FAIL [8]: pre-push não cita o msg_id: $pp_out"; exit 1; }
echo "OK [8]"

echo "[9] o pré-flight do archive aplica o enforcement"
grep -q "check-liaison-acks" "$WS/template/.forge/scripts/archive-spec.sh" \
  || { echo "FAIL [9]: archive-spec.sh não consulta o check de acks"; exit 1; }
grep -q "check-liaison-acks" "$WS/template/.forge/scripts/spec-close.sh" \
  && { echo "FAIL [9]: spec-close consulta o check — fechar um change nunca pode ser bloqueado por ack de peer"; exit 1; }
echo "OK [9]"

echo "[10] nenhum .sh do liaison invoca claude -p"
if grep -rEl 'claude[[:space:]]+-p' "$WS/template/.forge/scripts/" "$WS/template/.forge/hooks/" 2>/dev/null | head -1 | grep -q .; then
  echo "FAIL [10]: script invoca 'claude -p' (o ask-peer é .md, executado pelo agente, nunca por .sh)"
  grep -rEl 'claude[[:space:]]+-p' "$WS/template/.forge/scripts/" "$WS/template/.forge/hooks/"
  exit 1
fi
# A consulta síncrona é subcomando do liaison, não comando de topo: é o padrão da casa (ledger,
# capabilities, red, wave e o próprio liaison já expõem subcomandos) e o ask COMPÕE o liaison —
# internamente chama `send` duas vezes, para a pergunta e para a resposta. Um comando que é
# composição de outro mora dentro dele; separado, só é encontrável por quem já sabe que existe.
LIAISON_MD="$WS/template/.forge/commands/harness/liaison.md"
[ -f "$LIAISON_MD" ] || { echo "FAIL [10]: commands/harness/liaison.md ausente"; exit 1; }
[ ! -f "$WS/template/.forge/commands/harness/ask-peer.md" ] \
  || { echo "FAIL [10]: ask-peer.md ainda existe como comando de topo — deveria ser subcomando de liaison"; exit 1; }
grep -q 'liaison ask' "$LIAISON_MD" || { echo "FAIL [10]: liaison.md não documenta o subcomando 'ask'"; exit 1; }
grep -q 'ask' <<<"$(grep -m1 '^argument-hint:' "$LIAISON_MD")" \
  || { echo "FAIL [10]: 'ask' fora do argument-hint do liaison — não seria descoberto"; exit 1; }
# o mandato de segurança precisa continuar visível: consolidar não pode diluí-lo
grep -qi 'somente leitura\|read-only' "$LIAISON_MD" || { echo "FAIL [10]: o mandato read-only da consulta sumiu na consolidação"; exit 1; }
grep -q 'dangerously-skip-permissions' "$LIAISON_MD" || { echo "FAIL [10]: a proibição de skip-permissions sumiu na consolidação"; exit 1; }
# nenhum resquício do comando antigo na superfície gerada
[ ! -f "$WS/plugin/forge/commands/ask-peer.md" ] || { echo "FAIL [10]: plugin ainda expõe /forge:ask-peer"; exit 1; }
grep -rq 'forge:ask-peer' "$WS/docs/refer/slash-commands.md" && { echo "FAIL [10]: índice de comandos ainda lista /forge:ask-peer"; exit 1; }
echo "OK [10]"

echo "[11] peer-path resolve o repositório do participante (e reprova o desconhecido)"
LG fv peer set "$CH" axis-go-cloud --path "$T/gc-repo" >/dev/null 2>&1 || true
out11="$(LG fv peer-path "$CH" axis-go-cloud 2>&1)" || { echo "FAIL [11]: peer-path falhou: $out11"; exit 1; }
grep -q "$T/gc-repo" <<<"$out11" || { echo "FAIL [11]: peer-path não devolveu o caminho configurado: $out11"; exit 1; }
set +e
out11b="$(LG fv peer-path "$CH" ninguem-conhecido 2>&1)"; rc11b=$?
set -e
[ "$rc11b" -ne 0 ] || { echo "FAIL [11]: peer-path aceitou participante desconhecido: $out11b"; exit 1; }
echo "OK [11]"

echo "[12] answer com --authored-by/--via preserva a autoria real e carimba untrusted-peer"
LG fv send "$CH" --thread "$TH" --kind answer --subject "resposta do peer" \
  --body "uint64" --authored-by axis-go-cloud --via ask-peer >/dev/null
node -e '
  const fs=require("fs");
  const lines=fs.readFileSync(process.argv[1],"utf8").trim().split("\n").map(l=>JSON.parse(l));
  const m=lines.find(x=>x.subject==="resposta do peer");
  if(!m){ console.error("mensagem não encontrada"); process.exit(1); }
  if(m.sender!=="axis-fare-validator"){ console.error("sender deveria ser o repo local (um escritor por arquivo): "+m.sender); process.exit(1); }
  if(m.authored_by!=="axis-go-cloud"){ console.error("authored_by não preservado: "+m.authored_by); process.exit(1); }
  if(m.via!=="ask-peer"){ console.error("via não registrado: "+m.via); process.exit(1); }
  if(m.trust!=="untrusted-peer"){ console.error("conteúdo de terceiro deveria ser untrusted-peer, veio: "+m.trust); process.exit(1); }
' "$T/fv/.forge/liaison/$CH/log/axis-fare-validator.jsonl" || { echo "FAIL [12]"; exit 1; }
echo "OK [12]"

echo "PASS w113-liaison-enforce-gate"
