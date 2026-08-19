#!/usr/bin/env bash
# Gate W136 — SessionStart destaca acks pendentes do liaison (issue #47):
#   [1] com débito real (contract-change requires_ack sem ack) o hook imprime um bloco
#       "LIAISON — ACKS PENDENTES" ANTES do resumo agregado "LIAISON — canal entre repositórios"
#   [1b] checkout que perdeu o bit de execução do check-liaison-acks.sh não pula o check em silêncio
#   [2] sem débito (check-liaison-acks.sh volta OK) o bloco de acks pendentes NÃO aparece,
#       mas o resumo agregado continua aparecendo normalmente
#   [3] depois de ackar a mensagem pendente, o bloco some (a mesma transição do incidente real)
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w136.XXXXXX)"
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

# liaison.auto:true — o mesmo requisito que o bloco existente (liaison.auto) já exige para o
# hook falar de liaison; sem isso a asserção de ausência do bloco (cenário [2]) passaria por
# vacuidade (auto:false já esconde tudo, com ou sem correção).
set_auto_true() {
  node -e '
    const fs=require("fs"); const f=process.argv[1];
    let y=fs.readFileSync(f,"utf8");
    if (/^liaison:/m.test(y)) y=y.replace(/^(liaison:\n(?:[ ].*\n)*?[ ]+auto:[ ]*)(true|false)/m, "$1true");
    else y+="\nliaison:\n  auto: true\n  enforce: warn\n";
    fs.writeFileSync(f,y);
  ' "$T/$1/.forge/forge.yaml"
}

# Bundle com thread-open + contract-change (requires_ack:true) de <sender>, importado em <repo>.
inbound_contract_change() { # inbound_contract_change <repo> <sender> <parts-csv>
  local repo="$1" sender="$2" parts="$3"
  local dir="$T/bundle-$sender"
  mkdir -p "$dir/log"
  node - "$WS/template/.forge/scripts/lib" "$CH" "$sender" "$TH" "$parts" <<'NODEEOF' > "$dir/log/$sender.jsonl"
const { join } = require('path'); const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, channel, sender, thread, parts] = process.argv;
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const mk = (o) => { const m = { ...o }; m.content_sha = M.computeContentSha(m); m.trust = 'self'; return m; };
  const open = mk({ msg_id: `${sender}-0001`, channel, thread_id: thread, sender, seq: 1, lamport: 1, kind: 'thread-open', in_reply_to: null, requires_ack: false, subject: `abertura ${thread}`, participants: parts.split(','), refs: { change_id: null, contract_files: [], commit: null }, created_at: '2026-01-01T00:00:00Z' });
  const cc = mk({ msg_id: `${sender}-0002`, channel, thread_id: thread, sender, seq: 2, lamport: 2, kind: 'contract-change', in_reply_to: null, requires_ack: true, subject: 'mudanca de contrato: campo novo em fare.proto', body: 'campo novo em fare.proto', refs: { change_id: null, contract_files: ['contracts/fare.proto'], commit: null }, created_at: '2026-01-01T00:00:00Z' });
  process.stdout.write([open, cc].map((m) => JSON.stringify(m)).join('\n') + '\n');
})();
NODEEOF
  LG "$repo" import "$CH" --from "$dir" >/dev/null
}

MSGID=axis-go-cloud-0002

mk_repo fv axis-fare-validator
LG fv open "$CH" --self axis-fare-validator --participants axis-go-cloud,axis-fare-validator >/dev/null
set_auto_true fv
inbound_contract_change fv axis-go-cloud axis-go-cloud,axis-fare-validator

echo "[1] com débito real o bloco de acks pendentes aparece ANTES do resumo agregado"
hook_out="$(cd "$T/fv" && bash "$T/fv/.forge/hooks/session/on-session-start.sh" 2>&1)"
[ -n "$hook_out" ] || { echo "FAIL [1]: o hook não produziu saída nenhuma — o teste não pode passar por vacuidade"; exit 1; }
grep -q "LIAISON — ACKS PENDENTES" <<<"$hook_out" || { echo "FAIL [1]: bloco de acks pendentes ausente com débito real: $hook_out"; exit 1; }
grep -q "$MSGID" <<<"$hook_out" || { echo "FAIL [1]: bloco de acks pendentes não cita o msg_id pendente: $hook_out"; exit 1; }
grep -q "LIAISON — canal entre repositórios" <<<"$hook_out" || { echo "FAIL [1]: resumo agregado de liaison sumiu"; exit 1; }
pos_acks="$(grep -n "LIAISON — ACKS PENDENTES" <<<"$hook_out" | head -1 | cut -d: -f1)"
pos_summary="$(grep -n "LIAISON — canal entre repositórios" <<<"$hook_out" | head -1 | cut -d: -f1)"
[ "$pos_acks" -lt "$pos_summary" ] || { echo "FAIL [1]: bloco de acks pendentes não veio ANTES do resumo agregado (acks=$pos_acks, resumo=$pos_summary)"; exit 1; }
echo "OK [1]"

echo "[1b] checkout sem bit de execução no check-liaison-acks.sh continua reportando o débito"
# Um checkout pode perder o modo do arquivo (tarball, Windows/WSL, cópia por ferramenta que não
# preserva permissão). O script é invocado por `bash`, então rodá-lo não depende do bit — e um
# guard que exigisse -x transformaria isso num pulo SILENCIOSO, escondendo débito real exatamente
# como o defeito que esta issue corrige.
chmod -x "$T/fv/.forge/scripts/check-liaison-acks.sh"
hook_out1b="$(cd "$T/fv" && bash "$T/fv/.forge/hooks/session/on-session-start.sh" 2>&1)"
chmod +x "$T/fv/.forge/scripts/check-liaison-acks.sh"
[ -n "$hook_out1b" ] || { echo "FAIL [1b]: o hook não produziu saída nenhuma"; exit 1; }
grep -q "LIAISON — ACKS PENDENTES" <<<"$hook_out1b" \
  || { echo "FAIL [1b]: sem o bit de execução o hook pulou o check em silêncio e o débito sumiu do relatório"; echo "$hook_out1b"; exit 1; }
echo "OK [1b]"

echo "[2] sem débito (check-liaison-acks OK) o bloco NÃO aparece, mas o resumo agregado continua"
mk_repo obs observer
LG obs open "$CH" --self observer --participants axis-go-cloud,observer,axis-fare-validator >/dev/null
set_auto_true obs
# obs recebe a mesma thread, mas NÃO participa dela (regra de escopo do check-liaison-acks:
# só cobra quem participa) — garante débito zero de verdade, não ausência de dado.
LG fv export "$CH" --out "$T/bundle-export" >/dev/null
LG obs import "$CH" --from "$T/bundle-export" >/dev/null
ack_check="$(cd "$T/obs" && FORGE_ROOT="$T/obs" bash "$T/obs/.forge/scripts/check-liaison-acks.sh" 2>&1)"
grep -q "^OK" <<<"$ack_check" || { echo "FAIL [2]: pré-condição — check-liaison-acks deveria voltar OK para observer: $ack_check"; exit 1; }
hook_out2="$(cd "$T/obs" && bash "$T/obs/.forge/hooks/session/on-session-start.sh" 2>&1)"
[ -n "$hook_out2" ] || { echo "FAIL [2]: o hook não produziu saída nenhuma — o teste não pode passar por vacuidade"; exit 1; }
grep -q "LIAISON — ACKS PENDENTES" <<<"$hook_out2" && { echo "FAIL [2]: bloco de acks pendentes apareceu sem débito real: $hook_out2"; exit 1; }
grep -q "LIAISON — canal entre repositórios" <<<"$hook_out2" || { echo "FAIL [2]: resumo agregado sumiu quando não há débito (regressão à vacuidade)"; exit 1; }
echo "OK [2]"

echo "[3] depois do ack a mensagem some do bloco (mesma transição do incidente real)"
LG fv ack "$CH" "$MSGID" >/dev/null
hook_out3="$(cd "$T/fv" && bash "$T/fv/.forge/hooks/session/on-session-start.sh" 2>&1)"
[ -n "$hook_out3" ] || { echo "FAIL [3]: o hook não produziu saída nenhuma após o ack"; exit 1; }
grep -q "LIAISON — ACKS PENDENTES" <<<"$hook_out3" && { echo "FAIL [3]: bloco de acks pendentes persistiu depois do ack: $hook_out3"; exit 1; }
grep -q "LIAISON — canal entre repositórios" <<<"$hook_out3" || { echo "FAIL [3]: resumo agregado sumiu depois do ack"; exit 1; }
echo "OK [3]"

echo "PASS w136-session-start-liaison-acks-gate"
