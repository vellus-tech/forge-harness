#!/usr/bin/env bash
# ORDINAL: w285 atribuído no merge de add-liaison-native-bridge
# Gate — subcomando `notify` (REQ-01) e fonte única de classes efêmeras/regex (design §2.2, §2.3):
#   [1] módulo `native-classes.mjs` existe (não pode quebrar por módulo ausente — reporta FAIL
#       nomeando o que falta, nunca um stack trace de import)
#   [2] `EPHEMERAL_CLASSES`, `POINTER_LINE_RE`, `EPHEMERAL_LINE_RE`, `NATIVE_FIELD_MAX`,
#       `NATIVE_EXTRA_TEXT_MAX_BYTES` — valores e comportamento das regex (casos positivos e
#       negativos)
#   [3]-[8] `notify <channel> <msg_id> --to <destino>` sobre um canal de fixture com mensagem
#       própria publicada, própria NÃO publicada e de peer: ponteiro idêntico ao log, recusas
#       "não existe", "não é mensagem própria", "não publicada" (citando o `sync` que falta),
#       `--to` ausente e flag desconhecida
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-liaison-notify.XXXXXX)"
trap 'rm -rf "$T"' EXIT

LIBDIR="$WS/template/.forge/scripts/lib"
CH=contracts

echo "[1] módulo native-classes.mjs existe"
[ -f "$LIBDIR/native-classes.mjs" ] || { echo "FAIL [1]: $LIBDIR/native-classes.mjs ausente — EPHEMERAL_CLASSES ainda não existe (TASK-05 não implementada)"; exit 1; }
echo "OK [1]"

echo "[2] EPHEMERAL_CLASSES, POINTER_LINE_RE, EPHEMERAL_LINE_RE, NATIVE_FIELD_MAX, NATIVE_EXTRA_TEXT_MAX_BYTES"
node - "$LIBDIR" <<'NODEEOF'
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib] = process.argv;
  const M = await import(pathToFileURL(join(lib, 'native-classes.mjs')).href);
  const expectedClasses = ['identification', 'presence', 'schedule', 'turn-notice', 'reread-request', 'internal-coordination'];
  const got = Array.isArray(M.EPHEMERAL_CLASSES) ? M.EPHEMERAL_CLASSES : null;
  if (!got || got.length !== expectedClasses.length || expectedClasses.some((c, i) => got[i] !== c)) {
    console.error(`FAIL [2]: EPHEMERAL_CLASSES deveria ser ${JSON.stringify(expectedClasses)}, veio ${JSON.stringify(got)}`);
    process.exit(1);
  }
  if (!(M.POINTER_LINE_RE instanceof RegExp)) { console.error('FAIL [2]: POINTER_LINE_RE ausente ou não é RegExp'); process.exit(1); }
  if (!M.POINTER_LINE_RE.test('liaison:contracts/me-repo-0002')) { console.error('FAIL [2]: POINTER_LINE_RE não casa um ponteiro válido'); process.exit(1); }
  for (const bad of ['liaison:Contracts/me-repo-0002', 'liaison:contracts', 'liaison:contracts/', 'nao-e-ponteiro', 'liaison:contracts/me repo-0002']) {
    if (M.POINTER_LINE_RE.test(bad)) { console.error(`FAIL [2]: POINTER_LINE_RE casou forma inválida '${bad}'`); process.exit(1); }
  }
  if (!(M.EPHEMERAL_LINE_RE instanceof RegExp)) { console.error('FAIL [2]: EPHEMERAL_LINE_RE ausente ou não é RegExp'); process.exit(1); }
  if (!M.EPHEMERAL_LINE_RE.test('ephemeral: presence')) { console.error('FAIL [2]: EPHEMERAL_LINE_RE não casa uma declaração válida'); process.exit(1); }
  for (const bad of ['ephemeral:presence', 'ephemeral: PRESENCE', 'ephemeral: presence ', ' ephemeral: presence']) {
    if (M.EPHEMERAL_LINE_RE.test(bad)) { console.error(`FAIL [2]: EPHEMERAL_LINE_RE casou forma inválida '${bad}'`); process.exit(1); }
  }
  if (M.NATIVE_FIELD_MAX !== 128) { console.error(`FAIL [2]: NATIVE_FIELD_MAX deveria ser 128, veio ${M.NATIVE_FIELD_MAX}`); process.exit(1); }
  if (M.NATIVE_EXTRA_TEXT_MAX_BYTES !== 1024) { console.error(`FAIL [2]: NATIVE_EXTRA_TEXT_MAX_BYTES deveria ser 1024, veio ${M.NATIVE_EXTRA_TEXT_MAX_BYTES}`); process.exit(1); }
  console.log('OK [2] — EPHEMERAL_CLASSES/POINTER_LINE_RE/EPHEMERAL_LINE_RE/NATIVE_FIELD_MAX/NATIVE_EXTRA_TEXT_MAX_BYTES corretos');
})();
NODEEOF

echo "[3] canal de fixture: mensagem própria publicada, própria não publicada e de peer"
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

HUB="$T/hub"
mk_repo me me-repo
mk_repo peer peer-repo
LG me open "$CH" --self me-repo --participants me-repo,peer-repo >/dev/null
LG peer open "$CH" --self peer-repo --participants me-repo,peer-repo >/dev/null
LG me transport set "$CH" --kind fs --path "$HUB" >/dev/null
LG peer transport set "$CH" --kind fs --path "$HUB" >/dev/null

LG me thread open "$CH" th1 --subject "thread de fixture" --participants me-repo,peer-repo >/dev/null   # me-repo-0001
LG me send "$CH" --thread th1 --kind note --subject "nota publicada" --body "corpo publicado" >/dev/null # me-repo-0002
LG me sync "$CH" >/dev/null                                                                               # publica 0001+0002
LG me send "$CH" --thread th1 --kind note --subject "nota ainda não publicada" --body "corpo novo" >/dev/null # me-repo-0003 (fica sem sync)

LG peer sync "$CH" >/dev/null               # pull: traz o th1 de me-repo (0001+0002); push: log vazio, no-op
LG peer thread join "$CH" th1 >/dev/null    # peer-repo-0001
LG peer send "$CH" --thread th1 --kind note --subject "nota do peer" --body "corpo do peer" >/dev/null # peer-repo-0002
LG peer sync "$CH" >/dev/null               # publica peer-repo-0001+0002 no hub

LG me sync "$CH" --pull-only >/dev/null     # traz as mensagens do peer SEM publicar o me-repo-0003

ME_CH_DIR="$T/me/.forge/liaison/$CH"
[ -f "$ME_CH_DIR/log/me-repo.jsonl" ] || { echo "FAIL [3]: log próprio de me-repo ausente após a fixture"; exit 1; }
[ -f "$ME_CH_DIR/log/peer-repo.jsonl" ] || { echo "FAIL [3]: log de peer-repo não chegou em me-repo após o pull"; exit 1; }
grep -q '"msg_id":"me-repo-0003"' "$ME_CH_DIR/log/me-repo.jsonl" || { echo "FAIL [3]: me-repo-0003 deveria existir no log próprio"; exit 1; }
grep -q '"msg_id":"peer-repo-0001"' "$ME_CH_DIR/log/peer-repo.jsonl" || { echo "FAIL [3]: peer-repo-0001 deveria ter chegado pelo pull"; exit 1; }
echo "OK [3] — fixture pronta: me-repo-0002 (própria publicada), me-repo-0003 (própria não publicada), peer-repo-0001 (de peer)"

NOTIFY() { # NOTIFY <msg_id> [extra args...] -> ecoa saída, devolve rc em $NOTIFY_RC
  set +e
  NOTIFY_OUT="$(FORGE_ROOT="$T/me" bash "$T/me/.forge/scripts/liaison-ops.sh" notify "$CH" "$@" 2>&1)"; NOTIFY_RC=$?
  set -e
}

echo "[4] notify sobre mensagem própria publicada — ponteiro idêntico ao log"
NOTIFY me-repo-0002 --to "uds:/tmp/cc-socks/999.sock"
[ "$NOTIFY_RC" -eq 0 ] || { echo "FAIL [4]: notify deveria aceitar me-repo-0002 (própria, publicada): $NOTIFY_OUT"; exit 1; }
expected_log="$(node -e '
  const fs=require("fs");
  const lines=fs.readFileSync(process.argv[1],"utf8").trim().split("\n").map(l=>JSON.parse(l));
  const m=lines.find(x=>x.msg_id==="me-repo-0002");
  process.stdout.write(JSON.stringify({ thread_id: m.thread_id, content_sha: m.content_sha, subject: m.subject }));
' "$ME_CH_DIR/log/me-repo.jsonl")"
exp_thread="$(node -e "process.stdout.write(JSON.parse(process.argv[1]).thread_id)" "$expected_log")"
exp_sha="$(node -e "process.stdout.write(JSON.parse(process.argv[1]).content_sha)" "$expected_log")"
exp_subject="$(node -e "process.stdout.write(JSON.parse(process.argv[1]).subject)" "$expected_log")"
grep -qF "liaison:$CH/me-repo-0002" <<<"$NOTIFY_OUT" || { echo "FAIL [4]: ponteiro ausente na saída: $NOTIFY_OUT"; exit 1; }
grep -qF "thread_id: $exp_thread" <<<"$NOTIFY_OUT" || { echo "FAIL [4]: thread_id não idêntico ao log ($exp_thread): $NOTIFY_OUT"; exit 1; }
grep -qF "content_sha: $exp_sha" <<<"$NOTIFY_OUT" || { echo "FAIL [4]: content_sha não idêntico ao log ($exp_sha): $NOTIFY_OUT"; exit 1; }
grep -qF "subject: $exp_subject" <<<"$NOTIFY_OUT" || { echo "FAIL [4]: subject não idêntico ao log ($exp_subject): $NOTIFY_OUT"; exit 1; }
grep -qF "to: uds:/tmp/cc-socks/999.sock" <<<"$NOTIFY_OUT" || { echo "FAIL [4]: linha 'to:' informativa ausente: $NOTIFY_OUT"; exit 1; }
echo "OK [4] — ponteiro idêntico ao log (thread_id, content_sha, subject)"

echo "[5] notify sobre msg_id inexistente — 'não existe'"
NOTIFY nao-existe-nada-0099 --to x
[ "$NOTIFY_RC" -ne 0 ] || { echo "FAIL [5]: deveria recusar msg_id inexistente: $NOTIFY_OUT"; exit 1; }
grep -qi "não existe" <<<"$NOTIFY_OUT" || { echo "FAIL [5]: recusa não cita 'não existe': $NOTIFY_OUT"; exit 1; }
echo "OK [5]"

echo "[6] notify sobre mensagem de PEER — 'não é mensagem própria'"
NOTIFY peer-repo-0001 --to x
[ "$NOTIFY_RC" -ne 0 ] || { echo "FAIL [6]: deveria recusar mensagem de peer: $NOTIFY_OUT"; exit 1; }
grep -qi "não é mensagem própria" <<<"$NOTIFY_OUT" || { echo "FAIL [6]: recusa não cita 'não é mensagem própria': $NOTIFY_OUT"; exit 1; }
echo "OK [6]"

echo "[7] notify sobre mensagem própria NÃO publicada — 'não publicada' + comando sync"
NOTIFY me-repo-0003 --to x
[ "$NOTIFY_RC" -ne 0 ] || { echo "FAIL [7]: deveria recusar mensagem própria não publicada: $NOTIFY_OUT"; exit 1; }
grep -qi "não publicada" <<<"$NOTIFY_OUT" || { echo "FAIL [7]: recusa não cita 'não publicada': $NOTIFY_OUT"; exit 1; }
grep -q "sync" <<<"$NOTIFY_OUT" || { echo "FAIL [7]: recusa não nomeia o comando 'sync' que falta: $NOTIFY_OUT"; exit 1; }
echo "OK [7]"

echo "[8] --to ausente e flag desconhecida — nomeiam 'notify' e as flags aceitas"
NOTIFY me-repo-0002
[ "$NOTIFY_RC" -ne 0 ] || { echo "FAIL [8]: --to ausente deveria recusar: $NOTIFY_OUT"; exit 1; }
grep -q "notify" <<<"$NOTIFY_OUT" || { echo "FAIL [8]: recusa de --to ausente não nomeia 'notify': $NOTIFY_OUT"; exit 1; }
grep -q -- "--to" <<<"$NOTIFY_OUT" || { echo "FAIL [8]: recusa de --to ausente não nomeia '--to': $NOTIFY_OUT"; exit 1; }
NOTIFY me-repo-0002 --bogus x
[ "$NOTIFY_RC" -ne 0 ] || { echo "FAIL [8]: flag desconhecida deveria recusar: $NOTIFY_OUT"; exit 1; }
grep -q "notify" <<<"$NOTIFY_OUT" || { echo "FAIL [8]: recusa de flag desconhecida não nomeia 'notify': $NOTIFY_OUT"; exit 1; }
grep -q -- "--to" <<<"$NOTIFY_OUT" || { echo "FAIL [8]: recusa de flag desconhecida não lista '--to' entre as flags aceitas: $NOTIFY_OUT"; exit 1; }
echo "OK [8]"

echo "PASS liaison-notify-gate"
