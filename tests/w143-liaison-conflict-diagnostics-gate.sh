#!/usr/bin/env bash
# Gate W143 — diagnóstico de causalidade, escritor único e recuperação assistida no liaison (issue #36).
#
# O caso reportado em produção interna: um `ack` legítimo ficou inacessível ao destinatário porque
# a posição `seq` do remetente havia sido escrita por DUAS cópias do mesmo log em paralelo. Duas
# coisas passaram em silêncio — o `created_at` do ack era quase um dia ANTERIOR ao da mensagem que
# ele responde (relógio de Lamport coerente, relógio de parede não), e não havia caminho de
# recuperação: foi preciso ler `conflicts/*.divergence.json` à mão.
#
#   [1] ack com created_at ANTERIOR ao da mensagem respondida é sinalizado no render (caso literal)
#   [2] o mesmo caso é NOMEADO no status do canal e no status global
#   [3] o diagnóstico NÃO bloqueia — render, status e sync seguem com rc 0
#   [4] resposta causalmente coerente NÃO é sinalizada, sobre conjunto varrido comprovadamente não vazio
#   [5] o log de um remetente tem ESCRITOR ÚNICO: `send` de dentro de um worktree linkado escreve no
#       canal do TRONCO, e não numa segunda cópia do log com contador próprio
#   [6] os LEITORES do canal (cobrança de ack e SessionStart) resolvem o mesmo tronco — um leitor
#       preso ao worktree ficaria cego para o canal de quem trabalha numa branch
#   [7] `conflicts list` ENUMERA as posições retidas (hoje só dava para lê-las abrindo conflicts/ à mão)
#   [8] `conflicts resolve` republica o conteúdo retido numa sequência NOVA, preservando conteúdo e
#       procedência — o caminho legítimo num log append-only — sem tocar a posição divergente
#   [9] resolve repetido RECUSA (não duplica o conteúdo) e o marcador sobrevive ao sync seguinte
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w143.XXXXXX)"
trap 'rm -rf "$T"' EXIT

CH=axis-contracts
TH=msa-tenant-canonical-identity
TH2=e2e-tap-bancada-t10
HUB="$T/hub"
OWNER=axis-go-cloud
CONSUMER=axis-fare-validator

# Datas LITERAIS da issue: a mensagem respondida é de 2026-07-31T12:52:03-03:00 e o ack que a
# responde é de 2026-07-30T19:18:26-03:00 — quase um dia antes. created_at vem do commit HEAD
# (nunca wall clock), então fixar a data do commit fixa o created_at das mensagens do repositório.
LATE='2026-07-31T12:52:03-03:00'
EARLY='2026-07-30T19:18:26-03:00'

mk_repo() { # mk_repo <dir-name> <commit-date>
  local dir="$T/$1"
  mkdir -p "$dir/.forge"
  cp -R "$WS/template/.forge/scripts" "$dir/.forge/" || return 1
  cp -R "$WS/template/.forge/templates" "$dir/.forge/" || return 1
  git -C "$dir" init -q || return 1
  git -C "$dir" config user.email "$1@test"
  git -C "$dir" config user.name "$1"
  git -C "$dir" config commit.gpgsign false
  GIT_AUTHOR_DATE="$2" GIT_COMMITTER_DATE="$2" git -C "$dir" commit --allow-empty -qm init >/dev/null || return 1
}

LG() { # LG <repo> <args...>
  local repo="$1"; shift
  FORGE_ROOT="$T/$repo" bash "$T/$repo/.forge/scripts/liaison-ops.sh" "$@"
}

replies_in_log() { # replies_in_log <dir-do-canal> -> quantas mensagens têm in_reply_to não nulo
  node -e '
const fs = require("fs"), path = require("path");
const dir = path.join(process.argv[1], "log");
if (!fs.existsSync(dir)) { process.stdout.write("0"); process.exit(0); }
let n = 0;
for (const f of fs.readdirSync(dir).filter((x) => x.endsWith(".jsonl"))) {
  const s = fs.readFileSync(path.join(dir, f), "utf8").trim();
  if (!s) continue;
  for (const l of s.split("\n")) { const m = JSON.parse(l); if (m.in_reply_to) n++; }
}
process.stdout.write(String(n));
' "$1"
}

# --- montagem ------------------------------------------------------------------------------------
mk_repo owner "$LATE"       || { echo "FAIL [setup]: não foi possível montar o repositório do dono do contrato"; exit 1; }
mk_repo consumer "$EARLY"   || { echo "FAIL [setup]: não foi possível montar o repositório consumidor"; exit 1; }

for r in owner:$OWNER consumer:$CONSUMER; do
  repo="${r%%:*}"; id="${r##*:}"
  LG "$repo" open "$CH" --self "$id" --participants "$OWNER,$CONSUMER" >/dev/null \
    || { echo "FAIL [setup]: open do canal em $repo reprovou"; exit 1; }
  LG "$repo" transport set "$CH" --kind fs --path "$HUB" >/dev/null \
    || { echo "FAIL [setup]: transport set em $repo reprovou"; exit 1; }
  LG "$repo" transport probe "$CH" >/dev/null \
    || { echo "FAIL [setup]: probe do transporte fs em $repo reprovou"; exit 1; }
done

# Thread do dono do contrato: thread-open (0001), nota (0002), contract-change (0003) — o
# `in_reply_to: axis-go-cloud-0003` do caso reportado.
LG owner thread open "$CH" "$TH" --subject "identidade canônica de tenant" --participants "$OWNER,$CONSUMER" >/dev/null \
  || { echo "FAIL [setup]: thread open reprovou"; exit 1; }
LG owner send "$CH" --thread "$TH" --kind note --subject "contexto do rollout" >/dev/null \
  || { echo "FAIL [setup]: send da nota reprovou"; exit 1; }
LG owner send "$CH" --thread "$TH" --kind contract-change --subject "tenant_id passa a ser obrigatório" --requires-ack >/dev/null \
  || { echo "FAIL [setup]: send do contract-change reprovou"; exit 1; }
LG owner sync "$CH" >/dev/null || { echo "FAIL [setup]: sync do owner reprovou"; exit 1; }
LG consumer sync "$CH" >/dev/null || { echo "FAIL [setup]: sync do consumer reprovou"; exit 1; }

TARGET="$OWNER-0003"
grep -q "\"msg_id\":\"$TARGET\"" "$T/consumer/.forge/liaison/$CH/log/$OWNER.jsonl" \
  || { echo "FAIL [setup]: $TARGET não chegou ao consumidor — o cenário não reproduz a issue"; exit 1; }

# O ack do consumidor nasce com created_at do commit dele — 2026-07-30, ANTERIOR ao 2026-07-31 da
# mensagem respondida. É exatamente a incoerência do caso reportado, produzida pelo CLI real.
LG consumer ack "$CH" "$TARGET" --subject "ack do contract-change" >/dev/null \
  || { echo "FAIL [setup]: ack reprovou"; exit 1; }

# Controle causalmente COERENTE, na outra thread: pergunta do consumidor (2026-07-30) respondida
# pelo dono do contrato (2026-07-31). Sem ele, um diagnóstico que sinalizasse tudo passaria.
LG consumer thread open "$CH" "$TH2" --subject "bancada t10" --participants "$OWNER,$CONSUMER" >/dev/null \
  || { echo "FAIL [setup]: thread open do controle reprovou"; exit 1; }
LG consumer send "$CH" --thread "$TH2" --kind question --subject "qual campo carrega o tenant no tap?" --requires-ack >/dev/null \
  || { echo "FAIL [setup]: send da pergunta reprovou"; exit 1; }
LG consumer sync "$CH" >/dev/null || { echo "FAIL [setup]: sync do consumer (2) reprovou"; exit 1; }
LG owner sync "$CH" >/dev/null || { echo "FAIL [setup]: sync do owner (2) reprovou"; exit 1; }
QUESTION="$CONSUMER-0003"
grep -q "\"msg_id\":\"$QUESTION\"" "$T/owner/.forge/liaison/$CH/log/$CONSUMER.jsonl" \
  || { echo "FAIL [setup]: a pergunta $QUESTION não chegou ao dono do contrato"; exit 1; }
LG owner send "$CH" --thread "$TH2" --kind answer --subject "campo tenant_id no header" --in-reply-to "$QUESTION" >/dev/null \
  || { echo "FAIL [setup]: send da resposta reprovou"; exit 1; }
LG owner sync "$CH" >/dev/null || { echo "FAIL [setup]: sync do owner (3) reprovou"; exit 1; }
LG consumer sync "$CH" >/dev/null || { echo "FAIL [setup]: sync do consumer (3) reprovou"; exit 1; }

CHDIR="$T/consumer/.forge/liaison/$CH"
ACK="$CONSUMER-0001"

echo "[1] created_at anterior ao da mensagem respondida é sinalizado no render"
LG consumer render "$CH" >/dev/null || { echo "FAIL [1]: render reprovou"; exit 1; }
CHMD="$CHDIR/CHANNEL.md"
[ -f "$CHMD" ] || { echo "FAIL [1]: CHANNEL.md não foi gerado"; exit 1; }
grep -qi "created_at" "$CHMD" \
  || { echo "FAIL [1]: o render não menciona created_at incoerente — o relógio errado segue passando em silêncio"; exit 1; }
grep -q "$ACK" "$CHMD" \
  || { echo "FAIL [1]: o render não nomeia a mensagem incoerente ($ACK)"; exit 1; }
grep -q "$TARGET" "$CHMD" \
  || { echo "FAIL [1]: o render não nomeia a mensagem referenciada em in_reply_to ($TARGET)"; exit 1; }
grep -q "2026-07-30T19:18:26-03:00" "$CHMD" \
  || { echo "FAIL [1]: o render não mostra o created_at da mensagem incoerente"; exit 1; }
grep -q "2026-07-31T12:52:03-03:00" "$CHMD" \
  || { echo "FAIL [1]: o render não mostra o created_at da mensagem referenciada"; exit 1; }
echo "OK [1]"

echo "[2] status do canal e status global nomeiam o caso"
st="$(LG consumer status "$CH" 2>&1)"
grep -qi "created_at" <<<"$st" \
  || { echo "FAIL [2]: status do canal não sinaliza created_at incoerente: $st"; exit 1; }
grep -q "$ACK" <<<"$st" \
  || { echo "FAIL [2]: status do canal não nomeia a mensagem incoerente ($ACK): $st"; exit 1; }
grep -q "$TARGET" <<<"$st" \
  || { echo "FAIL [2]: status do canal não nomeia a mensagem referenciada ($TARGET): $st"; exit 1; }
stg="$(LG consumer status 2>&1)"
grep -qi "created_at" <<<"$stg" \
  || { echo "FAIL [2]: status global não sinaliza created_at incoerente: $stg"; exit 1; }
grep -q "$ACK" <<<"$stg" \
  || { echo "FAIL [2]: status global não nomeia a mensagem incoerente ($ACK): $stg"; exit 1; }
echo "OK [2]"

echo "[3] o diagnóstico não bloqueia — render, status e sync seguem com rc 0"
LG consumer render "$CH" >/dev/null 2>&1; rc_r=$?
[ "$rc_r" -eq 0 ] || { echo "FAIL [3]: render reprovou (rc $rc_r) — o diagnóstico tem de ser não bloqueante"; exit 1; }
LG consumer status "$CH" >/dev/null 2>&1; rc_s=$?
[ "$rc_s" -eq 0 ] || { echo "FAIL [3]: status do canal reprovou (rc $rc_s)"; exit 1; }
LG consumer status >/dev/null 2>&1; rc_g=$?
[ "$rc_g" -eq 0 ] || { echo "FAIL [3]: status global reprovou (rc $rc_g)"; exit 1; }
LG consumer sync "$CH" >/dev/null 2>&1; rc_y=$?
[ "$rc_y" -eq 0 ] || { echo "FAIL [3]: sync reprovou (rc $rc_y) — created_at incoerente não pode reter mensagem"; exit 1; }
out_sync="$(LG owner sync "$CH" 2>&1)"; rc_o=$?
[ "$rc_o" -eq 0 ] || { echo "FAIL [3]: sync do dono do contrato reprovou (rc $rc_o): $out_sync"; exit 1; }
grep -q "\"msg_id\":\"$ACK\"" "$T/owner/.forge/liaison/$CH/log/$CONSUMER.jsonl" \
  || { echo "FAIL [3]: o ack incoerente não foi aplicado no destinatário — o diagnóstico virou bloqueio"; exit 1; }
echo "OK [3]"

echo "[4] resposta causalmente coerente não é sinalizada (conjunto varrido não vazio)"
n_replies="$(replies_in_log "$CHDIR")"
[ "${n_replies:-0}" -ge 2 ] \
  || { echo "FAIL [4]: só $n_replies mensagem(ns) com in_reply_to no canal — a varredura seria vácua e o 'OK' não mediria nada"; exit 1; }
ANSWER="$OWNER-0004"
grep -q "\"msg_id\":\"$ANSWER\"" "$CHDIR/log/$OWNER.jsonl" \
  || { echo "FAIL [4]: a resposta coerente ($ANSWER) não está no canal — o controle não existe"; exit 1; }
st4="$(LG consumer status "$CH" 2>&1)"
grep -q "created_at.*$ANSWER\|$ANSWER.*created_at" <<<"$st4" \
  && { echo "FAIL [4]: a resposta causalmente coerente ($ANSWER) foi sinalizada — falso positivo: $st4"; exit 1; }
n_flag="$(grep -c "^  ! created_at incoerente" <<<"$st4")"
[ "${n_flag:-0}" -eq 1 ] \
  || { echo "FAIL [4]: esperado exatamente 1 caso sinalizado, obtidos ${n_flag:-0}: $st4"; exit 1; }
echo "OK [4]"

echo "[5] send de dentro de um worktree linkado escreve no canal do TRONCO (escritor único)"
# A causa-raiz da colisão de seq da issue: duas cópias do mesmo log de remetente escrevendo em
# paralelo, cada uma com o contador local. Dentro de um clone, o caso é o worktree linkado — o
# canal é estado durável de PROJETO, e resolver o ROOT por --show-toplevel dá a cada branch a sua
# própria cópia do log, com o próprio contador. Mesma classe da rule conventions/machinery-propagation.md.
# pwd -P: no macOS /tmp é symlink para /private/tmp e o git devolve o caminho REAL.
MAIN="$T/single-writer"
mkdir -p "$MAIN/.forge"
cp -R "$WS/template/.forge/scripts" "$MAIN/.forge/" || { echo "FAIL [5]: cópia dos scripts falhou"; exit 1; }
cp -R "$WS/template/.forge/templates" "$MAIN/.forge/" || { echo "FAIL [5]: cópia dos templates falhou"; exit 1; }
MAIN="$(cd "$MAIN" && pwd -P)"
git -C "$MAIN" init -q -b main || { echo "FAIL [5]: git init falhou"; exit 1; }
git -C "$MAIN" config user.email w143@test
git -C "$MAIN" config user.name w143
git -C "$MAIN" config commit.gpgsign false
git -C "$MAIN" commit --allow-empty -qm init >/dev/null || { echo "FAIL [5]: commit inicial falhou"; exit 1; }
CHW=contracts-worktree
THW=grpc-v1
FORGE_ROOT="$MAIN" bash "$MAIN/.forge/scripts/liaison-ops.sh" open "$CHW" --self "$OWNER" --participants "$OWNER,$CONSUMER" >/dev/null \
  || { echo "FAIL [5]: open no tronco reprovou"; exit 1; }
FORGE_ROOT="$MAIN" bash "$MAIN/.forge/scripts/liaison-ops.sh" thread open "$CHW" "$THW" --subject "contrato grpc" --participants "$OWNER,$CONSUMER" >/dev/null \
  || { echo "FAIL [5]: thread open no tronco reprovou"; exit 1; }
FORGE_ROOT="$MAIN" bash "$MAIN/.forge/scripts/liaison-ops.sh" send "$CHW" --thread "$THW" --kind note --subject "do tronco" >/dev/null \
  || { echo "FAIL [5]: send no tronco reprovou"; exit 1; }
git -C "$MAIN" add -A >/dev/null 2>&1
git -C "$MAIN" commit -q -m "harness + canal" >/dev/null 2>&1 \
  || { echo "FAIL [5]: commit do fixture falhou"; exit 1; }

WT="$MAIN/.forge/worktrees/wt1"
git -C "$MAIN" worktree add -q -b feature/x "$WT" >/dev/null 2>&1 \
  || { echo "FAIL [5]: git worktree add falhou"; exit 1; }
MAINLOG="$MAIN/.forge/liaison/$CHW/log/$OWNER.jsonl"
WTLOG="$WT/.forge/liaison/$CHW/log/$OWNER.jsonl"
[ -f "$MAINLOG" ] || { echo "FAIL [5]: log do tronco ausente — cenário sem valor"; exit 1; }
[ -f "$WTLOG" ] || { echo "FAIL [5]: o worktree não recebeu a cópia do canal — o cenário da colisão não existe"; exit 1; }
wt_sha_antes="$(shasum "$WTLOG" | cut -d' ' -f1)"
n_main_antes="$(grep -c . "$MAINLOG")"
[ "${n_main_antes:-0}" -ge 2 ] || { echo "FAIL [5]: log do tronco com ${n_main_antes:-0} mensagem(ns) — cenário sem valor"; exit 1; }

# Sem FORGE_ROOT: é exatamente como o script é invocado por um agente trabalhando no worktree.
out5="$( (cd "$WT" && bash "$WT/.forge/scripts/liaison-ops.sh" send "$CHW" --thread "$THW" --kind note --subject "do worktree") 2>&1 )"; rc5=$?
[ "$rc5" -eq 0 ] || { echo "FAIL [5]: send de dentro do worktree reprovou (rc $rc5): $out5"; exit 1; }
NEW_ID="$OWNER-0003"
grep -q "\"msg_id\":\"$NEW_ID\"" "$MAINLOG" \
  || { echo "FAIL [5]: a mensagem enviada do worktree não entrou no log do TRONCO — segunda cópia do log com contador próprio, que é a colisão de seq da issue. Tronco: $(grep -c . "$MAINLOG") linha(s); worktree: $(grep -c . "$WTLOG" 2>/dev/null || echo 0)"; exit 1; }
[ "$(shasum "$WTLOG" | cut -d' ' -f1)" = "$wt_sha_antes" ] \
  || { echo "FAIL [5]: o log da cópia do worktree foi escrito — dois escritores no mesmo log de remetente"; exit 1; }
n_main_depois="$(grep -c . "$MAINLOG")"
[ "$n_main_depois" -eq "$((n_main_antes + 1))" ] \
  || { echo "FAIL [5]: o log do tronco foi de $n_main_antes para $n_main_depois linha(s), esperado $((n_main_antes + 1))"; exit 1; }
st_main="$( (cd "$MAIN" && bash "$MAIN/.forge/scripts/liaison-ops.sh" status "$CHW") 2>&1 )"
st_wt="$(   (cd "$WT"   && bash "$WT/.forge/scripts/liaison-ops.sh"   status "$CHW") 2>&1 )"
[ -n "$st_main" ] || { echo "FAIL [5]: status vazio no tronco — asserção seria vácua"; exit 1; }
[ "$st_main" = "$st_wt" ] \
  || { echo "FAIL [5]: status difere entre tronco e worktree — o canal está duplicado
  tronco:   $st_main
  worktree: $st_wt"; exit 1; }
echo "OK [5]"

echo "[6] os leitores do canal (cobrança de ack e SessionStart) resolvem o mesmo tronco"
# Primeiro o worktree é posto em dia com o tronco (hooks + forge.yaml com liaison.auto), e SÓ
# DEPOIS o débito é criado no tronco, sem commit. Assim a cópia do worktree comprovadamente não o
# tem, e um leitor preso ao worktree devolve OK para uma dívida que existe.
cp "$WS/template/.forge/forge.yaml" "$MAIN/.forge/forge.yaml" || { echo "FAIL [6]: cópia do forge.yaml falhou"; exit 1; }
mkdir -p "$MAIN/.forge/hooks"
cp -R "$WS/template/.forge/hooks/session" "$MAIN/.forge/hooks/" || { echo "FAIL [6]: cópia dos hooks falhou"; exit 1; }
node -e '
  const fs=require("fs"); const f=process.argv[1];
  let y=fs.readFileSync(f,"utf8");
  if (/^liaison:/m.test(y)) y=y.replace(/^(liaison:\n(?:[ ].*\n)*?[ ]+auto:[ ]*)(true|false)/m, "$1true");
  else y+="\nliaison:\n  auto: true\n  enforce: warn\n";
  fs.writeFileSync(f,y);
' "$MAIN/.forge/forge.yaml" || { echo "FAIL [6]: não foi possível ligar liaison.auto"; exit 1; }
git -C "$MAIN" add -A >/dev/null 2>&1
git -C "$MAIN" commit -q -m "hooks + forge.yaml" >/dev/null 2>&1
git -C "$WT" reset -q --hard main >/dev/null 2>&1 || { echo "FAIL [6]: não foi possível pôr o worktree em dia"; exit 1; }
[ -f "$WT/.forge/hooks/session/on-session-start.sh" ] || { echo "FAIL [6]: o worktree não recebeu o hook — cenário sem valor"; exit 1; }

mkdir -p "$T/bundle-wt/log"
node - "$WS/template/.forge/scripts/lib" "$CHW" "$CONSUMER" "$THW" "$OWNER,$CONSUMER" <<'NODEEOF' > "$T/bundle-wt/log/$CONSUMER.jsonl"
const { join } = require('path'); const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, channel, sender, thread, parts] = process.argv;
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const mk = (o) => { const m = { ...o }; m.content_sha = M.computeContentSha(m); m.trust = 'self'; return m; };
  const cc = mk({ msg_id: `${sender}-0001`, channel, thread_id: thread, sender, seq: 1, lamport: 5, kind: 'contract-change', in_reply_to: null, requires_ack: true, subject: 'campo novo em fare.proto', body: 'campo novo em fare.proto', refs: { change_id: null, contract_files: ['contracts/fare.proto'], commit: null }, created_at: '2026-08-01T00:00:00Z' });
  process.stdout.write(JSON.stringify(cc) + '\n');
})();
NODEEOF
[ -s "$T/bundle-wt/log/$CONSUMER.jsonl" ] || { echo "FAIL [6]: bundle de débito não foi gerado"; exit 1; }
FORGE_ROOT="$MAIN" bash "$MAIN/.forge/scripts/liaison-ops.sh" import "$CHW" --from "$T/bundle-wt" >/dev/null \
  || { echo "FAIL [6]: import do débito no tronco reprovou"; exit 1; }
DEBT="$CONSUMER-0001"
grep -q "\"msg_id\":\"$DEBT\"" "$MAIN/.forge/liaison/$CHW/log/$CONSUMER.jsonl" \
  || { echo "FAIL [6]: o débito não entrou no tronco — cenário sem valor"; exit 1; }
grep -q "$DEBT" "$WT/.forge/liaison/$CHW/log/$CONSUMER.jsonl" 2>/dev/null \
  && { echo "FAIL [6]: a cópia do worktree também tem o débito — o cenário não discrimina"; exit 1; }

acks_main="$( (cd "$MAIN" && bash "$MAIN/.forge/scripts/check-liaison-acks.sh") 2>&1 )"
acks_wt="$(   (cd "$WT"   && bash "$WT/.forge/scripts/check-liaison-acks.sh")   2>&1 )"
grep -q "$DEBT" <<<"$acks_main" \
  || { echo "FAIL [6]: a cobrança de ack no tronco não cita o débito — asserção seria vácua: $acks_main"; exit 1; }
grep -q "$DEBT" <<<"$acks_wt" \
  || { echo "FAIL [6]: a cobrança de ack rodada do worktree não vê o débito do tronco: $acks_wt"; exit 1; }

hook_main="$( (cd "$MAIN" && bash "$MAIN/.forge/hooks/session/on-session-start.sh") 2>&1 )"
hook_wt="$(   (cd "$WT"   && bash "$WT/.forge/hooks/session/on-session-start.sh")   2>&1 )"
grep -q "LIAISON — canal entre repositórios" <<<"$hook_main" \
  || { echo "FAIL [6]: o SessionStart no tronco não resume o canal — asserção seria vácua: $hook_main"; exit 1; }
grep -q "$DEBT" <<<"$hook_main" \
  || { echo "FAIL [6]: o SessionStart no tronco não destaca o ack pendente — asserção seria vácua: $hook_main"; exit 1; }
grep -q "LIAISON — canal entre repositórios" <<<"$hook_wt" \
  || { echo "FAIL [6]: o SessionStart aberto no worktree não enxerga o canal do tronco: $hook_wt"; exit 1; }
grep -q "$DEBT" <<<"$hook_wt" \
  || { echo "FAIL [6]: o SessionStart no worktree não destaca o ack pendente do tronco: $hook_wt"; exit 1; }
echo "OK [6]"

# --- recuperação assistida de posição retida ------------------------------------------------------
# Um remetente cuja posição foi reescrita na origem fica com a mensagem RETIDA: ela nunca entra no
# log local, e no caso reportado era um ack legítimo — o consumidor achava ter respondido, o dono do
# contrato achava não ter recebido resposta. O conteúdo está no registro de conflito; falta o
# caminho para trazê-lo de volta ao canal sem reescrever história alheia.
CHR=contracts-retido
THR=tap-bancada
HUBR="$T/hub-retido"
mk_repo replica "$LATE" || { echo "FAIL [setup 7]: não foi possível montar a réplica"; exit 1; }
LG replica open "$CHR" --self "$OWNER" --participants "$OWNER,$CONSUMER" >/dev/null \
  || { echo "FAIL [setup 7]: open do canal $CHR reprovou"; exit 1; }
LG replica transport set "$CHR" --kind fs --path "$HUBR" >/dev/null \
  || { echo "FAIL [setup 7]: transport set reprovou"; exit 1; }
LG replica transport probe "$CHR" >/dev/null || { echo "FAIL [setup 7]: probe reprovou"; exit 1; }

# gen_peer <out> <subject-da-seq-3> <body-da-seq-3>
gen_peer() {
  node - "$WS/template/.forge/scripts/lib" "$1" "$CHR" "$CONSUMER" "$THR" "$OWNER" "$2" "$3" <<'NODEEOF'
const { writeFileSync, mkdirSync } = require('fs');
const { join, dirname } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, out, channel, sender, thread, peer, subj3, body3] = process.argv;
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const mk = (o) => { const m = { ...o }; m.content_sha = M.computeContentSha(m); return m; };
  const base = { channel, thread_id: thread, sender, in_reply_to: null, requires_ack: false,
    refs: { change_id: null, contract_files: [], commit: null }, created_at: '2026-07-30T19:18:26-03:00', trust: 'self' };
  const msgs = [
    mk({ ...base, msg_id: `${sender}-0001`, seq: 1, lamport: 1, kind: 'thread-open', subject: 'abertura da bancada', participants: [sender, peer] }),
    mk({ ...base, msg_id: `${sender}-0002`, seq: 2, lamport: 2, kind: 'note', subject: 'contexto da bancada' }),
    mk({ ...base, msg_id: `${sender}-0003`, seq: 3, lamport: 3, kind: 'ack', in_reply_to: `${peer}-0001`, subject: subj3, body: body3 }),
    mk({ ...base, msg_id: `${sender}-0004`, seq: 4, lamport: 4, kind: 'note', subject: 'relatório da bancada' }),
  ];
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, msgs.map((m) => JSON.stringify(m)).join('\n') + '\n');
})();
NODEEOF
}

PEERLOG_HUB="$HUBR/$CHR/log/$CONSUMER.jsonl"
gen_peer "$PEERLOG_HUB" "ack da versao original" "corpo original" || { echo "FAIL [setup 7]: gen_peer v1 falhou"; exit 1; }
out_r1="$(LG replica sync "$CHR" 2>&1)"
grep -q "4 nova" <<<"$out_r1" || { echo "FAIL [setup 7]: a réplica não recebeu as 4 mensagens iniciais: $out_r1"; exit 1; }

# A origem REESCREVE a posição seq=3 — mesmo msg_id, outro conteúdo. É o ack legítimo que fica
# retido: a réplica mantém a versão que já conhecia e nunca vê esta.
LOST_SUBJ="ack do contract-change perdido"
LOST_BODY="adotamos tenant_id obrigatorio no tap"
gen_peer "$PEERLOG_HUB" "$LOST_SUBJ" "$LOST_BODY" || { echo "FAIL [setup 7]: gen_peer v2 falhou"; exit 1; }
LG replica sync "$CHR" >/dev/null 2>&1
CONFR="$T/replica/.forge/liaison/$CHR/conflicts"
[ -f "$CONFR/$CONSUMER.seq-3.divergence.json" ] \
  || { echo "FAIL [setup 7]: a posição seq=3 não ficou retida — cenário sem valor (achado: $(ls "$CONFR" 2>/dev/null | tr '\n' ' '))"; exit 1; }
SELFLOG_R="$T/replica/.forge/liaison/$CHR/log/$OWNER.jsonl"
grep -q "$LOST_SUBJ" "$T/replica/.forge/liaison/$CHR/log/$CONSUMER.jsonl" \
  && { echo "FAIL [setup 7]: o conteúdo retido entrou no log — o cenário não reproduz a retenção"; exit 1; }

echo "[7] conflicts list enumera as posições retidas"
list7="$(LG replica conflicts list "$CHR" 2>&1)"; rc7=$?
[ "$rc7" -eq 0 ] || { echo "FAIL [7]: conflicts list reprovou (rc $rc7): $list7"; exit 1; }
grep -q "$CONSUMER" <<<"$list7" || { echo "FAIL [7]: conflicts list não nomeia o remetente: $list7"; exit 1; }
grep -q "seq=3" <<<"$list7" || { echo "FAIL [7]: conflicts list não nomeia a posição seq=3: $list7"; exit 1; }
grep -q "$CONSUMER-0003" <<<"$list7" || { echo "FAIL [7]: conflicts list não nomeia o msg_id retido: $list7"; exit 1; }
# Canal sem retenção nenhuma responde explicitamente, e não com silêncio ambíguo.
list7b="$(LG consumer conflicts list "$CH" 2>&1)"; rc7b=$?
[ "$rc7b" -eq 0 ] || { echo "FAIL [7]: conflicts list em canal sem retenção reprovou (rc $rc7b): $list7b"; exit 1; }
[ -n "$list7b" ] || { echo "FAIL [7]: conflicts list em canal sem retenção não respondeu nada — silêncio é ambíguo"; exit 1; }
grep -qi "nenhuma" <<<"$list7b" || { echo "FAIL [7]: conflicts list não diz explicitamente que não há posição retida: $list7b"; exit 1; }
echo "OK [7]"

echo "[8] conflicts resolve republica o conteúdo retido numa sequência NOVA"
n_self_antes="$(grep -c . "$SELFLOG_R" 2>/dev/null || echo 0)"
peer_sha_antes="$(shasum "$T/replica/.forge/liaison/$CHR/log/$CONSUMER.jsonl" | cut -d' ' -f1)"
out8="$(LG replica conflicts resolve "$CHR" "$CONSUMER" 3 2>&1)"; rc8=$?
[ "$rc8" -eq 0 ] || { echo "FAIL [8]: conflicts resolve reprovou (rc $rc8): $out8"; exit 1; }
n_self_depois="$(grep -c . "$SELFLOG_R" 2>/dev/null || echo 0)"
[ "$n_self_depois" -eq "$((n_self_antes + 1))" ] \
  || { echo "FAIL [8]: o log próprio foi de $n_self_antes para $n_self_depois linha(s) — a republicação não gerou uma sequência nova"; exit 1; }
grep -q "$LOST_SUBJ" "$SELFLOG_R" \
  || { echo "FAIL [8]: o assunto do conteúdo retido não foi preservado na republicação"; exit 1; }
grep -q "$LOST_BODY" "$SELFLOG_R" \
  || { echo "FAIL [8]: o corpo do conteúdo retido não foi preservado na republicação"; exit 1; }
grep -q "\"authored_by\":\"$CONSUMER\"" "$SELFLOG_R" \
  || { echo "FAIL [8]: a republicação não registra a autoria real ($CONSUMER) — procedência perdida"; exit 1; }
grep -q "$CONSUMER-0003" "$SELFLOG_R" \
  || { echo "FAIL [8]: a republicação não aponta para a posição de origem ($CONSUMER-0003)"; exit 1; }
grep -q "\"trust\":\"untrusted-peer\"" "$SELFLOG_R" \
  || { echo "FAIL [8]: conteúdo de terceiro republicado não pode entrar como trust=self"; exit 1; }
[ "$(shasum "$T/replica/.forge/liaison/$CHR/log/$CONSUMER.jsonl" | cut -d' ' -f1)" = "$peer_sha_antes" ] \
  || { echo "FAIL [8]: o log do remetente divergente foi tocado — republicar não reescreve história alheia"; exit 1; }
LG replica render "$CHR" >/dev/null || { echo "FAIL [8]: render após resolve reprovou"; exit 1; }
grep -q "$LOST_SUBJ" "$T/replica/.forge/liaison/$CHR/CHANNEL.md" \
  || { echo "FAIL [8]: o conteúdo republicado não aparece no CHANNEL.md — segue inacessível a quem lê"; exit 1; }
echo "OK [8]"

echo "[9] resolve repetido recusa, e o marcador de republicação sobrevive ao sync"
n_before9="$(grep -c . "$SELFLOG_R")"
out9="$(LG replica conflicts resolve "$CHR" "$CONSUMER" 3 2>&1)"; rc9=$?
[ "$rc9" -ne 0 ] || { echo "FAIL [9]: resolve repetido devolveu rc 0 — duplicaria o conteúdo no canal: $out9"; exit 1; }
[ "$(grep -c . "$SELFLOG_R")" -eq "$n_before9" ] \
  || { echo "FAIL [9]: resolve repetido escreveu no log mesmo assim"; exit 1; }
list9="$(LG replica conflicts list "$CHR" 2>&1)"
grep -qi "republicad" <<<"$list9" \
  || { echo "FAIL [9]: conflicts list não mostra que a posição já foi republicada: $list9"; exit 1; }
# A divergência na origem CONTINUA existindo, então o sync reescreve o registro — o marcador não
# pode ser perdido nisso, ou o operador republica o mesmo conteúdo de novo a cada sync.
LG replica sync "$CHR" >/dev/null 2>&1
list9b="$(LG replica conflicts list "$CHR" 2>&1)"
grep -qi "republicad" <<<"$list9b" \
  || { echo "FAIL [9]: o marcador de republicação foi perdido no sync seguinte: $list9b"; exit 1; }
out9b="$(LG replica conflicts resolve "$CHR" "$CONSUMER" 3 2>&1)"; rc9b=$?
[ "$rc9b" -ne 0 ] || { echo "FAIL [9]: após o sync, resolve voltou a aceitar e duplicaria o conteúdo: $out9b"; exit 1; }
echo "OK [9]"

echo "PASS w143-liaison-conflict-diagnostics-gate"
