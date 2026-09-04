#!/usr/bin/env bash
# Gate W166 — o ack ganha caminho de corpo (issue #83): 1138 de 1138 acks medidos no ecossistema
# Axis não tinham body_ref porque a ferramenta simplesmente não oferecia --body/--body-file no
# ack — só o send tinha. Este gate prova o caminho novo, reusando (não reimplementando) a varredura
# de segredo e a escrita de blob que o send já tinha:
#   [1] ack --body grava body_ref? NÃO — texto curto vai inline em `body`, sem blob
#   [2] ack --body-file grava blob, calcula body_ref, e a mensagem NÃO carrega `body` inline
#   [3] --body e --body-file juntos reprovam (mesma mensagem do send)
#   [4] segredo no corpo do ack reprova — mesma varredura do send, sem porta frouxa
#   [5] --reason wont-adopt SEM corpo reprova (a ausência de justificativa é o defeito)
#   [6] --reason wont-adopt COM --body desbloqueia normalmente
#   [7] ack sem corpo nenhum continua funcionando (retrocompatibilidade do recibo puro)
#   [8] --subject continua aceito e independente do corpo
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w166.XXXXXX)"
trap 'rm -rf "$T"' EXIT

CH=contracts-fare
TH=fare-grpc-v1

mk_repo() { # mk_repo <dir>
  local dir="$T/$1"
  mkdir -p "$dir/.forge"
  cp -R "$WS/template/.forge/scripts" "$dir/.forge/"
  cp -R "$WS/template/.forge/templates" "$dir/.forge/"
  git -C "$dir" init -q
  git -C "$dir" config user.email "$1@test"
  git -C "$dir" config user.name "$1"
  git -C "$dir" config commit.gpgsign false
  git -C "$dir" commit --allow-empty -qm init >/dev/null
}

LG() { local repo="$1"; shift; FORGE_ROOT="$T/$repo" bash "$T/$repo/.forge/scripts/liaison-ops.sh" "$@"; }

last_msg() { # last_msg <repo> <self> -> última linha do próprio log, parseada
  node -e '
    const fs=require("fs");
    const lines=fs.readFileSync(process.argv[1],"utf8").trim().split("\n");
    console.log(lines[lines.length-1]);
  ' "$T/$1/.forge/liaison/$CH/log/$2.jsonl"
}

mk_repo gc
mk_repo fv
LG gc open "$CH" --self axis-go-cloud --participants axis-go-cloud,axis-fare-validator >/dev/null
LG fv open "$CH" --self axis-fare-validator --participants axis-go-cloud,axis-fare-validator >/dev/null
LG gc thread open "$CH" "$TH" --subject "abertura" --participants axis-go-cloud,axis-fare-validator --body "abertura" >/dev/null
LG fv import "$CH" --from "$T/gc/.forge/liaison/$CH" >/dev/null 2>&1 || {
  # thread open + import via bundle real (export/import), evitando depender de sync/transport
  mkdir -p "$T/bundle1"
  LG gc export "$CH" --out "$T/bundle1" >/dev/null
  LG fv import "$CH" --from "$T/bundle1" >/dev/null
}

echo "[1] ack --body grava corpo INLINE, sem body_ref"
MSGID1="$(LG gc send "$CH" --thread "$TH" --kind note --subject "pede posição" --body "confirma o tipo" --requires-ack)"
MSGID1="${MSGID1#*— }"; MSGID1="${MSGID1%% *}"
mkdir -p "$T/bundle2"; LG gc export "$CH" --out "$T/bundle2" >/dev/null
LG fv import "$CH" --from "$T/bundle2" >/dev/null
ACK1_OUT="$(LG fv ack "$CH" "$MSGID1" --body "concordo, sigo com uint64")"
ACK1_ID="${ACK1_OUT#*— }"; ACK1_ID="${ACK1_ID%% *}"
node -e '
  const fs=require("fs");
  const lines=fs.readFileSync(process.argv[1],"utf8").trim().split("\n").map(l=>JSON.parse(l));
  const m=lines.find(x=>x.msg_id===process.argv[2]);
  if(!m){ console.error("ack não encontrado no log"); process.exit(1); }
  if(m.kind!=="ack"){ console.error("kind não é ack: "+m.kind); process.exit(1); }
  if(m.body!=="concordo, sigo com uint64"){ console.error("body inline não gravado: "+JSON.stringify(m.body)); process.exit(1); }
  if(m.body_ref){ console.error("body curto não deveria virar blob: "+m.body_ref); process.exit(1); }
' "$T/fv/.forge/liaison/$CH/log/axis-fare-validator.jsonl" "$ACK1_ID" || { echo "FAIL [1]"; exit 1; }
echo "OK [1]"

echo "[2] ack --body-file grava blob e body_ref, sem body inline"
echo "posição detalhada: uint64, sem sinal, unidade centavos" > "$T/pos.md"
MSGID2="$(LG gc send "$CH" --thread "$TH" --kind question --subject "outra pergunta" --body "tipo?" --requires-ack)"
MSGID2="${MSGID2#*— }"; MSGID2="${MSGID2%% *}"
mkdir -p "$T/bundle3"; LG gc export "$CH" --out "$T/bundle3" >/dev/null
LG fv import "$CH" --from "$T/bundle3" >/dev/null
ACK2_OUT="$(LG fv ack "$CH" "$MSGID2" --body-file "$T/pos.md")"
ACK2_ID="${ACK2_OUT#*— }"; ACK2_ID="${ACK2_ID%% *}"
node -e '
  const fs=require("fs");
  const lines=fs.readFileSync(process.argv[1],"utf8").trim().split("\n").map(l=>JSON.parse(l));
  const m=lines.find(x=>x.msg_id===process.argv[2]);
  if(!m){ console.error("ack não encontrado"); process.exit(1); }
  if(m.body){ console.error("body-file deveria virar blob, não body inline: "+JSON.stringify(m.body)); process.exit(1); }
  if(!m.body_ref || !/^blobs\//.test(m.body_ref)){ console.error("body_ref ausente/malformado: "+JSON.stringify(m.body_ref)); process.exit(1); }
' "$T/fv/.forge/liaison/$CH/log/axis-fare-validator.jsonl" "$ACK2_ID" || { echo "FAIL [2]"; exit 1; }
BLOB_REL="$(node -e '
  const fs=require("fs");
  const lines=fs.readFileSync(process.argv[1],"utf8").trim().split("\n").map(l=>JSON.parse(l));
  console.log(lines.find(x=>x.msg_id===process.argv[2]).body_ref);
' "$T/fv/.forge/liaison/$CH/log/axis-fare-validator.jsonl" "$ACK2_ID")"
[ -f "$T/fv/.forge/liaison/$CH/$BLOB_REL" ] || { echo "FAIL [2]: blob não existe em disco: $BLOB_REL"; exit 1; }
grep -q "unidade centavos" "$T/fv/.forge/liaison/$CH/$BLOB_REL" || { echo "FAIL [2]: conteúdo do blob não confere"; exit 1; }
echo "OK [2]"

echo "[3] --body e --body-file juntos reprovam"
set +e
OUT3="$(LG fv ack "$CH" "$MSGID2" --body "x" --body-file "$T/pos.md" 2>&1)"; RC3=$?
set -e
[ "$RC3" -ne 0 ] || { echo "FAIL [3]: aceitou os dois ao mesmo tempo"; exit 1; }
grep -qi "não os dois\|use --body ou --body-file" <<<"$OUT3" || { echo "FAIL [3]: mensagem não explica o conflito: $OUT3"; exit 1; }
echo "OK [3]"

echo "[4] segredo no corpo do ack reprova (mesma varredura do send)"
set +e
OUT4="$(LG fv ack "$CH" "$MSGID2" --body "AKIAABCDEFGHIJKLMNOP" 2>&1)"; RC4=$?
set -e
[ "$RC4" -ne 0 ] || { echo "FAIL [4]: ack com segredo no corpo passou: $OUT4"; exit 1; }
grep -qi "segredo" <<<"$OUT4" || { echo "FAIL [4]: mensagem não cita segredo: $OUT4"; exit 1; }
echo "OK [4]"

echo "[5] --reason wont-adopt SEM corpo reprova"
MSGID5="$(LG gc send "$CH" --thread "$TH" --kind contract-change --subject "campo novo" --body "fare_cents" --contract-files contracts/fare.proto --requires-ack)"
MSGID5="${MSGID5#*— }"; MSGID5="${MSGID5%% *}"
mkdir -p "$T/bundle5"; LG gc export "$CH" --out "$T/bundle5" >/dev/null
LG fv import "$CH" --from "$T/bundle5" >/dev/null
set +e
OUT5="$(LG fv ack "$CH" "$MSGID5" --reason wont-adopt 2>&1)"; RC5=$?
set -e
[ "$RC5" -ne 0 ] || { echo "FAIL [5]: wont-adopt sem corpo passou: $OUT5"; exit 1; }
grep -qi "corpo\|body\|justificativa" <<<"$OUT5" || { echo "FAIL [5]: mensagem não explica a ausência de corpo: $OUT5"; exit 1; }
echo "OK [5]"

echo "[6] --reason wont-adopt COM --body desbloqueia normalmente e registra dívida"
OUT6="$(LG fv ack "$CH" "$MSGID5" --reason wont-adopt --body "avaliamos e não vamos adotar fare_cents; mantemos fare_amount")"
grep -q "OK ack" <<<"$OUT6" || { echo "FAIL [6]: ack com corpo e wont-adopt não confirmou: $OUT6"; exit 1; }
[ -f "$T/fv/.forge/ledger/ledger.json" ] || { echo "FAIL [6]: ledger não foi criado"; exit 1; }
node -e '
  const fs=require("fs");
  const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const hit=(d.entries||[]).find(e=>e.type==="tech-debt" && JSON.stringify(e).includes(process.argv[2]));
  if(!hit){ console.error("tech-debt não registrado"); process.exit(1); }
' "$T/fv/.forge/ledger/ledger.json" "$MSGID5" || { echo "FAIL [6]: dívida não registrada"; exit 1; }
echo "OK [6]"

echo "[7] ack sem corpo nenhum continua funcionando (retrocompat do recibo puro)"
MSGID7="$(LG gc send "$CH" --thread "$TH" --kind note --subject "aviso simples" --body "fyi" --requires-ack)"
MSGID7="${MSGID7#*— }"; MSGID7="${MSGID7%% *}"
mkdir -p "$T/bundle7"; LG gc export "$CH" --out "$T/bundle7" >/dev/null
LG fv import "$CH" --from "$T/bundle7" >/dev/null
OUT7="$(LG fv ack "$CH" "$MSGID7")"
grep -q "OK ack" <<<"$OUT7" || { echo "FAIL [7]: ack puro (sem corpo) parou de funcionar: $OUT7"; exit 1; }
echo "OK [7]"

echo "[8] --subject continua aceito e independente do corpo"
MSGID8="$(LG gc send "$CH" --thread "$TH" --kind note --subject "mais um aviso" --body "fyi2" --requires-ack)"
MSGID8="${MSGID8#*— }"; MSGID8="${MSGID8%% *}"
mkdir -p "$T/bundle8"; LG gc export "$CH" --out "$T/bundle8" >/dev/null
LG fv import "$CH" --from "$T/bundle8" >/dev/null
ACK8_OUT="$(LG fv ack "$CH" "$MSGID8" --subject "recebido" --body "obrigado")"
ACK8_ID="${ACK8_OUT#*— }"; ACK8_ID="${ACK8_ID%% *}"
node -e '
  const fs=require("fs");
  const lines=fs.readFileSync(process.argv[1],"utf8").trim().split("\n").map(l=>JSON.parse(l));
  const m=lines.find(x=>x.msg_id===process.argv[2]);
  if(m.subject!=="recebido"){ console.error("subject não preservado: "+m.subject); process.exit(1); }
  if(m.body!=="obrigado"){ console.error("body não preservado: "+m.body); process.exit(1); }
' "$T/fv/.forge/liaison/$CH/log/axis-fare-validator.jsonl" "$ACK8_ID" || { echo "FAIL [8]"; exit 1; }
echo "OK [8]"

echo "PASS w166-liaison-ack-body-gate"
