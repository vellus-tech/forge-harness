#!/usr/bin/env bash
# Gate — TASK-26/TASK-27 de add-liaison-handoff-baton (REQ-12, NFR-02, design §2.8/§4.4):
#   [fiacao-*] as quatro combinações de liaison.auto × liaison.baton.auto_renew; desligar e
#     religar sem duplicar nem deixar órfão; doctor.sh reconhece a categoria como derivada
#   [renova-*] renovação automática bem-sucedida pela sessão titular; 10 eventos concorrentes
#     com exatamente uma renovação; nunca renova lease vencido; só a sessão do evento
#   [cache-*] caminho rápido sem gravar nada quando ainda não é a hora; cache invalidado por
#     claim nova, por renew manual e por reescrita externa (tamanho/mtime do log próprio)
#   [aviso-*] perda tardia importada limpa o cache; JSON additionalContext emitido (e não
#     repetido) para perda; configuração inválida avisa e não renova
#   [destacado-*] sync --push-only destacado não prende o evento com o push parado de verdade
#     (barreira de teste no meio da publicação); renew gravado e publicado ao liberar; o
#     destacado roda com FORGE_LIAISON_PUSH_DEADLINE_S=25 (PLAT-202)
#   [aviso-json-unico] dois avisos no mesmo evento saem num único documento JSON (PLAT-203)
#   [aviso-perda-repetida] perder, reivindicar e perder de novo avisa duas vezes (LGC-202)
#   [trava-local-curta] trava local ocupada não prende o evento pelo default de 10 s (PLAT-205)
#   [perf-*] caminho sem bastão e fora da hora termina rápido (ordem de grandeza, não p95
#     estatístico — máquina compartilhada e sob carga variável, ver nota)
#
# Técnica geral: em vez de esperar o relógio real passar de lease_until/next_renew_at (minutos
# reais por cenário), os testes que precisam de "já é hora de renovar" ou "lease vencido"
# REESCREVEM a claim já gravada no log (stamped_at/lease_seconds/lease_until, com content_sha
# real recalculado) e o baton-local.json correspondente, igual à técnica já usada nos gates de
# status/lifecycle. A claim PRECISA respeitar max_lease_seconds da oferta (achado de teste: um
# primeiro rascunho usou lease_seconds acima do máximo e a dobra classificou a claim como
# 'lease-over-max', não 'won' — invalidando o resto do cenário).
set -uo pipefail
# Hermético quanto à sessão: a sessão de um agente (Claude Code) exporta CLAUDE_CODE_SESSION_ID para
# todo processo filho e o runner do CI não tem a variável. Sem este unset o gate passa dentro do
# agente e reprova no CI (ou o inverso); quem precisa de sessão a declara explicitamente.
unset CLAUDE_CODE_SESSION_ID
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib"
T="$(mktemp -d /tmp/forge-liaison-baton-autorenew.XXXXXX)"
trap 'rm -rf "$T"' EXIT

fail=0
CH=baton-autorenew-gate

judge() {
  local tag="$1" out="$2" rc="$3"
  if echo "$out" | grep -q '^FAIL \['; then
    echo "$out"
    fail=1
  elif [ "$rc" -ne 0 ]; then
    echo "FAIL [$tag]: comando falhou inesperadamente (rc=$rc): $(echo "$out" | tr '\n' ' ' | cut -c1-200)"
    fail=1
  else
    echo "$out"
  fi
}

mk_repo() { # mk_repo <nome> [liaison-auto] [auto-renew-false]
  local dir="$T/$1" liaison_auto="${2:-true}" renew_false="${3:-false}"
  mkdir -p "$dir/.forge"
  cp -R "$WS/template/.forge/scripts" "$dir/.forge/"
  cp -R "$WS/template/.forge/templates" "$dir/.forge/"
  cp -R "$WS/template/.forge/hooks" "$dir/.forge/"
  cp "$WS/template/.forge/forge.yaml" "$dir/.forge/forge.yaml"
  if [ "$liaison_auto" = "true" ]; then
    node -e '
const fs = require("fs");
const p = process.argv[1];
let text = fs.readFileSync(p, "utf8");
let seen = false;
text = text.split("\n").map((line) => {
  if (!seen && /^liaison:/.test(line)) { seen = "enter"; return line; }
  if (seen === "enter" && /^  auto: false$/.test(line)) { seen = true; return "  auto: true"; }
  return line;
}).join("\n");
fs.writeFileSync(p, text);
' "$dir/.forge/forge.yaml"
  fi
  if [ "$renew_false" = "true" ]; then
    node -e '
const fs = require("fs");
const p = process.argv[1];
let text = fs.readFileSync(p, "utf8");
text = text.replace(/^  # baton:$/m, "  baton:");
text = text.replace(/^  #   auto_renew: true.*$/m, "    auto_renew: false");
fs.writeFileSync(p, text);
' "$dir/.forge/forge.yaml"
  fi
  git -C "$dir" init -q
  git -C "$dir" config user.email "$1@test"
  git -C "$dir" config user.name "$1"
  git -C "$dir" config commit.gpgsign false
  git -C "$dir" add -A >/dev/null
  git -C "$dir" commit -q -m "chore: init $1" >/dev/null
}

LG() { local repo="$1"; shift; FORGE_ROOT="$T/$repo" bash "$T/$repo/.forge/scripts/liaison-ops.sh" "$@"; }
LGS() { local repo="$1" session="$2"; shift 2; FORGE_ROOT="$T/$repo" CLAUDE_CODE_SESSION_ID="$session" bash "$T/$repo/.forge/scripts/liaison-ops.sh" "$@"; }
offer_id() { printf '%s' "$1" | grep '^OK baton offer' | sed -E 's/^OK baton offer — //'; }
HOOK_FOR() { printf '%s/.forge/hooks/session/on-post-tool-use.sh' "$T/$1"; }
run_hook() { # run_hook <repo> <session_id>
  local repo="$1" sid="$2"
  (cd "$T/$repo" && printf '{"session_id":"%s"}' "$sid" | FORGE_ROOT="$T/$repo" bash "$(HOOK_FOR "$repo")")
}

# own_log_stat <repo> <channel> <self> -> "size mtime_s"
own_log_stat() {
  local f="$T/$1/.forge/liaison/$2/log/$3.jsonl"
  echo "$(stat -c %s "$f" 2>/dev/null || stat -f %z "$f") $(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f")"
}

# rewrite_claim_due <repo> <channel> <lease_seconds> <seconds-until-lease-end> -> edita a claim
# gravada (REESCRITA REAL, content_sha recalculado) para que ela já tenha passado da metade do
# prazo mas ainda não tenha vencido, e sincroniza o baton-local.json correspondente.
rewrite_claim_due() {
  local repo="$1" channel="$2" lease_seconds="$3" seconds_left="$4"
  local logf="$T/$repo/.forge/liaison/$channel/log/repo-a.jsonl"
  node -e '
const { join } = require("path");
const { pathToFileURL } = require("url");
(async () => {
  const fs = require("fs");
  const path = process.argv[1];
  const { computeContentSha } = await import(pathToFileURL(join(process.argv[2], "liaison-merge.mjs")).href);
  const lines = fs.readFileSync(path, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
  const claim = [...lines].reverse().find((m) => m.baton && (m.baton.op === "claim" || m.baton.op === "renew"));
  const leaseSeconds = Number(process.argv[3]);
  const secondsLeft = Number(process.argv[4]);
  const leaseUntilMs = Date.now() + secondsLeft * 1000;
  const stampedAtMs = leaseUntilMs - leaseSeconds * 1000;
  claim.baton.op = "claim";
  claim.baton.stamped_at = new Date(stampedAtMs).toISOString().replace(/\.\d+Z$/, "Z");
  claim.baton.lease_seconds = leaseSeconds;
  claim.baton.lease_until = new Date(leaseUntilMs).toISOString().replace(/\.\d+Z$/, "Z");
  claim.content_sha = computeContentSha(claim);
  fs.writeFileSync(path, lines.map((m) => JSON.stringify(m)).join("\n") + "\n");
  console.log(claim.baton.lease_until);
})();
' "$logf" "$LIB" "$lease_seconds" "$seconds_left"
}

# sync_cache_after_rewrite <repo> <channel> <baton_id> <session> <lease_until> -- regrava
# baton-local.json para refletir a claim recém-editada (tamanho/mtime atuais do arquivo, para o
# caminho rápido não invalidar por engano, e next_renew_at no passado para 'devido').
sync_cache_after_rewrite() {
  local repo="$1" channel="$2" baton_id="$3" session="$4" lease_until="$5"
  local stat size mtime_s
  stat="$(own_log_stat "$repo" "$channel" repo-a)"
  size="${stat% *}"; mtime_s="${stat#* }"
  node -e '
const fs = require("fs");
const path = process.argv[1], batonId = process.argv[2], session = process.argv[3];
const leaseUntil = process.argv[4], size = Number(process.argv[5]), mtimeMs = Number(process.argv[6]) * 1000;
let state = { claims: {}, holders: {} };
try { state = JSON.parse(fs.readFileSync(path, "utf8")); } catch {}
const nextRenewAt = new Date(Date.now() - 5000).toISOString().replace(/\.\d+Z$/, "Z");
state.holders[batonId] = { session, leaseUntil, nextRenewAt, ownLogSize: size, ownLogMtimeMs: mtimeMs };
fs.mkdirSync(require("path").dirname(path), { recursive: true });
fs.writeFileSync(path, JSON.stringify(state, null, 2));
' "$T/$repo/.forge/cache/liaison-baton/$channel/baton-local.json" "$baton_id" "$session" "$lease_until" "$size" "$mtime_s"
}

# === [fiacao-quatro-combinacoes] liaison.auto x liaison.baton.auto_renew ===
mk_repo fw_tt true false   # liaison.auto=true, auto_renew ausente (vale true)
mk_repo fw_tf true true    # liaison.auto=true, auto_renew=false explícito
mk_repo fw_ft false false  # liaison.auto=false, auto_renew ausente
mk_repo fw_ff false true   # liaison.auto=false, auto_renew=false
check_wiring() { # check_wiring <repo> <esperado:yes|no>
  local repo="$1" esperado="$2" got
  got="$(node -e '
const { join } = require("path");
const { pathToFileURL } = require("url");
(async () => {
  const m = await import(pathToFileURL(join(process.argv[1], "sync-adapters.mjs")).href);
  console.log(m.preToolUseWiring(process.argv[2]).PostToolUse ? "yes" : "no");
})();
' "$LIB" "$T/$repo")"
  [ "$got" = "$esperado" ]
}
ok_fiacao=1
check_wiring fw_tt yes || { echo "FAIL [fiacao-ligado]: liaison.auto=true + auto_renew ausente deveria ligar PostToolUse"; ok_fiacao=0; }
check_wiring fw_tf no  || { echo "FAIL [fiacao-desligado-explicito]: auto_renew=false deveria desligar PostToolUse"; ok_fiacao=0; }
check_wiring fw_ft no  || { echo "FAIL [fiacao-liaison-desligado]: liaison.auto=false deveria desligar PostToolUse mesmo com auto_renew ausente"; ok_fiacao=0; }
check_wiring fw_ff no  || { echo "FAIL [fiacao-ambos-desligados]: ambos desligados deveria desligar PostToolUse"; ok_fiacao=0; }
[ "$ok_fiacao" -eq 1 ] && echo "OK [fiacao-quatro-combinacoes]: as quatro combinações de liaison.auto × liaison.baton.auto_renew decidem corretamente"

# === [fiacao-sem-duplicar] desligar e religar não duplica nem deixa órfão ===
settings_posttooluse_count() { # settings_posttooluse_count <repo>
  node -e '
const fs = require("fs");
try {
  const s = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
  const groups = (s.hooks && s.hooks.PostToolUse) || [];
  let n = 0;
  for (const g of groups) for (const h of (g.hooks || [])) if (h && h.command && h.command.includes("on-post-tool-use.sh")) n++;
  console.log(n);
} catch { console.log(0); }
' "$T/$1/.claude/settings.json"
}
mkdir -p "$T/fw_tt/.claude"
echo '{}' > "$T/fw_tt/.claude/settings.json"
node -e '
const { join } = require("path");
const { pathToFileURL } = require("url");
(async () => {
  const fs = require("fs");
  const m = await import(pathToFileURL(join(process.argv[1], "sync-adapters.mjs")).href);
  const wiring = m.preToolUseWiring(process.argv[2]);
  const settingsPath = process.argv[3];
  const current = JSON.parse(fs.readFileSync(settingsPath, "utf8"));
  current.hooks = wiring;
  fs.writeFileSync(settingsPath, JSON.stringify(current, null, 2));
})();
' "$LIB" "$T/fw_tt" "$T/fw_tt/.claude/settings.json"
first_count="$(settings_posttooluse_count fw_tt)"
# "religa" aplicando a MESMA fiação de novo (simula um segundo sync sem mudança de config).
node -e '
const { join } = require("path");
const { pathToFileURL } = require("url");
(async () => {
  const fs = require("fs");
  const m = await import(pathToFileURL(join(process.argv[1], "sync-adapters.mjs")).href);
  const wiring = m.preToolUseWiring(process.argv[2]);
  const settingsPath = process.argv[3];
  const current = JSON.parse(fs.readFileSync(settingsPath, "utf8"));
  current.hooks = wiring;
  fs.writeFileSync(settingsPath, JSON.stringify(current, null, 2));
})();
' "$LIB" "$T/fw_tt" "$T/fw_tt/.claude/settings.json"
second_count="$(settings_posttooluse_count fw_tt)"
if [ "$first_count" = "1" ] && [ "$second_count" = "1" ]; then
  echo "OK [fiacao-sem-duplicar]: reaplicar a fiação não duplica PostToolUse (1 entrada nas duas rodadas)"
else
  echo "FAIL [fiacao-sem-duplicar]: esperava 1 entrada nas duas rodadas, achou first=$first_count second=$second_count"
  fail=1
fi

# === [fiacao-doctor-deriva] doctor.sh reconhece PostToolUse como categoria derivada ===
doctor_src="$T/fw_tt/.forge/scripts/doctor.sh"
if grep -q 'on-post-tool-use.sh' "$doctor_src"; then
  echo "OK [fiacao-doctor-deriva]: doctor.sh (_settings_hooks_is_derived) conhece on-post-tool-use.sh no universo owned"
else
  echo "FAIL [fiacao-doctor-deriva]: doctor.sh não lista on-post-tool-use.sh no universo owned"
  fail=1
fi

# === setup compartilhado para os cenários de renovação/cache/aviso ===
mk_repo a true false
LG a open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG a thread open "$CH" t1 --subject "autorenew" --participants repo-a,repo-b --body "x" >/dev/null

# === [renova-sucesso] renovação automática bem-sucedida pela sessão titular ===
out="$(LGS a s-off1 baton offer "$CH" --thread t1 --subject "tarefa 1" --max-lease 280 2>&1)"
bat1="$(offer_id "$out")"
LGS a sess-1 baton claim "$CH" "$bat1" --lease 280 >/dev/null 2>&1
lease_until="$(rewrite_claim_due a "$CH" 280 100)"
sync_cache_after_rewrite a "$CH" "$bat1" sess-1 "$lease_until"
out_renova="$(run_hook a sess-1)"; rc_renova=$?
status_after="$(LG a baton status "$CH" "$bat1" 2>&1)"
if [ "$rc_renova" -eq 0 ] && echo "$status_after" | grep -q "renewed"; then
  echo "OK [renova-sucesso]: evento PostToolUse da sessão titular renova automaticamente (rc 0)"
else
  echo "FAIL [renova-sucesso]: esperava rc 0 e histórico com 'renewed', achou rc=$rc_renova status=$status_after"
  fail=1
fi

# === [renova-so-sessao-do-evento] outra sessão (mesmo repositório) não é renovada por este evento
out2="$(LGS a s-off2 baton offer "$CH" --thread t1 --subject "tarefa 2" --max-lease 280 2>&1)"
bat2="$(offer_id "$out2")"
LGS a sess-2 baton claim "$CH" "$bat2" --lease 280 >/dev/null 2>&1
lease_until2="$(rewrite_claim_due a "$CH" 280 100)"
sync_cache_after_rewrite a "$CH" "$bat2" sess-2 "$lease_until2"
before2="$(LG a baton status "$CH" "$bat2" --json)"
run_hook a sess-NAO-E-ESTA >/dev/null 2>&1
after2="$(LG a baton status "$CH" "$bat2" --json)"
if [ "$before2" = "$after2" ]; then
  echo "OK [renova-so-sessao-do-evento]: evento de outra sessão não renova o bastão de sess-2"
else
  echo "FAIL [renova-so-sessao-do-evento]: estado mudou sem ser a sessão titular"
  fail=1
fi

# === [renova-nunca-vencido] lease já vencido não é renovado pelo gancho (fica para 'baton claim')
out3="$(LGS a s-off3 baton offer "$CH" --thread t1 --subject "tarefa 3" --max-lease 280 2>&1)"
bat3="$(offer_id "$out3")"
LGS a sess-3 baton claim "$CH" "$bat3" --lease 280 >/dev/null 2>&1
lease_until3="$(rewrite_claim_due a "$CH" 280 -5)" # lease_until 5s no PASSADO -- já vencido
sync_cache_after_rewrite a "$CH" "$bat3" sess-3 "$lease_until3"
run_hook a sess-3 >/dev/null 2>&1
status3="$(LG a baton status "$CH" "$bat3" 2>&1)"
if echo "$status3" | grep -qE "won$|^bastão.*held"; then
  if ! echo "$status3" | grep -q "renewed"; then
    echo "OK [renova-nunca-vencido]: lease já vencido não é renovado pelo gancho"
  else
    echo "FAIL [renova-nunca-vencido]: o gancho renovou um lease já vencido (viola REQ-12)"
    fail=1
  fi
else
  echo "FAIL [renova-nunca-vencido]: estado inesperado: $status3"
  fail=1
fi

# === [renova-concorrencia] 10 eventos concorrentes da mesma sessão titular -> exatamente uma
# renovação grava (as demais, já publicadas pela primeira, encontram o lease fresco e não
# renovam de novo -- o próprio renew exige now >= metade do prazo VIGENTE, que a primeira já
# empurrou para o futuro) ===
out4="$(LGS a s-off4 baton offer "$CH" --thread t1 --subject "tarefa concorrencia" --max-lease 280 2>&1)"
bat4="$(offer_id "$out4")"
LGS a sess-4 baton claim "$CH" "$bat4" --lease 280 >/dev/null 2>&1
lease_until4="$(rewrite_claim_due a "$CH" 280 100)"
sync_cache_after_rewrite a "$CH" "$bat4" sess-4 "$lease_until4"
for i in $(seq 1 10); do
  ( run_hook a sess-4 >"$T/conc-$i.out" 2>/dev/null ) &
done
wait
# ARCH-001/LGC-001/NODE-004: os eventos que perdem a corrida (trava ocupada, "ainda não é hora"
# depois da renovação da primeira) NÃO são perda de titularidade — nenhum pode avisar perda nem
# tirar a entrada do cache, ou a renovação automática para e o lease vence.
conc_ctx="$(cat "$T"/conc-*.out 2>/dev/null)"
if grep -q "additionalContext" <<<"$conc_ctx"; then
  echo "FAIL [renova-concorrencia-sem-aviso]: $(grep -c additionalContext <<<"$conc_ctx") evento(s) concorrente(s) da própria titular emitiram additionalContext: $(tr '\n' ' ' <<<"$conc_ctx" | cut -c1-300)"
  fail=1
else
  echo "OK [renova-concorrencia-sem-aviso]: nenhum dos 10 eventos concorrentes avisou perda"
fi
conc_holder="$(node -e '
const fs = require("fs");
const state = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
console.log(state.holders[process.argv[2]] ? "presente" : "ausente");
' "$T/a/.forge/cache/liaison-baton/$CH/baton-local.json" "$bat4")"
if [ "$conc_holder" = "presente" ]; then
  echo "OK [renova-concorrencia-cache]: a entrada da titular continua no cache depois dos 10 eventos"
else
  echo "FAIL [renova-concorrencia-cache]: a entrada de $bat4 sumiu do cache (renovação automática parou) enquanto a sessão continua titular"
  fail=1
fi
renew_count="$(node -e '
const fs = require("fs");
const lines = fs.readFileSync(process.argv[1], "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
const rs = lines.filter((m) => m.baton && m.baton.op === "renew" && m.in_reply_to === process.argv[2]);
console.log(rs.length);
' "$T/a/.forge/liaison/$CH/log/repo-a.jsonl" "$bat4")"
if [ "$renew_count" = "1" ]; then
  echo "OK [renova-concorrencia]: 10 eventos concorrentes da titular -> exatamente 1 renovação gravada"
else
  echo "FAIL [renova-concorrencia]: esperava exatamente 1 renovação, achou $renew_count"
  fail=1
fi

# === ARCH-001/LGC-001/NODE-004: códigos de saída distintos do `baton renew` e o gancho só trata
# como perda o rc de perda real ===
holder_state() { # holder_state <repo> <baton_id> -> presente|ausente
  node -e '
const fs = require("fs");
let state = { holders: {} };
try { state = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); } catch {}
console.log(state.holders && state.holders[process.argv[2]] ? "presente" : "ausente");
' "$T/$1/.forge/cache/liaison-baton/$CH/baton-local.json" "$2"
}
fresh_claim() { # fresh_claim <repo> <sessão> <lease> -> baton_id (repo já aberto com thread t1)
  local repo="$1" sess="$2" lease="$3" o
  o="$(LGS "$repo" "off-$sess" baton offer "$CH" --thread t1 --subject "tarefa $sess" --max-lease "$lease" 2>&1)"
  o="$(offer_id "$o")"
  LGS "$repo" "$sess" baton claim "$CH" "$o" --lease "$lease" >/dev/null 2>&1
  printf '%s' "$o"
}
mk_repo rcs true false
LG rcs open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG rcs thread open "$CH" t1 --subject "rc" --participants repo-a,repo-b --body "x" >/dev/null

# [renew-rc-distintos] não titular -> 4; lease vencido -> 4; IF_DUE fora da hora -> 5
bat_rc="$(fresh_claim rcs sess-rc 280)"
LGS rcs outra-sessao baton renew "$CH" "$bat_rc" >/dev/null 2>&1; rc_nh=$?
FORGE_BATON_RENEW_IF_DUE=1 LGS rcs sess-rc baton renew "$CH" "$bat_rc" >/dev/null 2>&1; rc_cedo=$?
rewrite_claim_due rcs "$CH" 280 -5 >/dev/null
LGS rcs sess-rc baton renew "$CH" "$bat_rc" >/dev/null 2>&1; rc_venc=$?
if [ "$rc_nh" -eq 4 ] && [ "$rc_venc" -eq 4 ] && [ "$rc_cedo" -eq 5 ]; then
  echo "OK [renew-rc-distintos]: não titular rc 4, lease vencido rc 4, ainda não é hora rc 5"
else
  echo "FAIL [renew-rc-distintos]: esperava não titular=4, vencido=4, cedo=5; achou não titular=$rc_nh, vencido=$rc_venc, cedo=$rc_cedo"
  fail=1
fi

# [nao-e-hora-nao-e-perda] cache diz "devido" mas o renew diz "ainda não é hora" (rc 5): o gancho
# não avisa perda e mantém a entrada (o cache é regravado com a dobra).
bat_cedo="$(fresh_claim rcs sess-cedo 280)"
lu_cedo="$(node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log(s.holders[process.argv[2]].leaseUntil)' "$T/rcs/.forge/cache/liaison-baton/$CH/baton-local.json" "$bat_cedo")"
sync_cache_after_rewrite rcs "$CH" "$bat_cedo" sess-cedo "$lu_cedo"
ctx_cedo="$(run_hook rcs sess-cedo 2>/dev/null)"
if grep -q "additionalContext" <<<"$ctx_cedo" || [ "$(holder_state rcs "$bat_cedo")" != "presente" ]; then
  echo "FAIL [nao-e-hora-nao-e-perda]: 'ainda não é hora' virou perda — ctx=$(tr '\n' ' ' <<<"$ctx_cedo" | cut -c1-200) entrada=$(holder_state rcs "$bat_cedo")"
  fail=1
else
  echo "OK [nao-e-hora-nao-e-perda]: 'ainda não é hora' não avisa perda e mantém a entrada"
fi

# [trava-ocupada-nao-e-perda] renew devido, mas a trava do log próprio está ocupada (o gancho
# espera 300 ms): erro transitório, rc 1 — nada de aviso, entrada mantida.
bat_trava="$(fresh_claim rcs sess-trava 280)"
lu_trava="$(rewrite_claim_due rcs "$CH" 280 100)"
sync_cache_after_rewrite rcs "$CH" "$bat_trava" sess-trava "$lu_trava"
node -e '
const { join } = require("path");
const { pathToFileURL } = require("url");
(async () => {
  const fs = require("fs");
  const [, lib, root, channel, ready] = process.argv;
  const { withOwnLogLock } = await import(pathToFileURL(join(lib, "liaison-lock.mjs")).href);
  await withOwnLogLock({ root, channel, self: "repo-a" }, async () => {
    fs.writeFileSync(ready, "1");
    await new Promise((r) => setTimeout(r, 4000));
  });
})();
' "$LIB" "$T/rcs" "$CH" "$T/trava.ready" &
trava_pid=$!
for _ in $(seq 1 50); do [ -f "$T/trava.ready" ] && break; node -e 'setTimeout(()=>{},100)'; done
ctx_trava="$(run_hook rcs sess-trava 2>/dev/null)"
estado_trava="$(holder_state rcs "$bat_trava")"
wait "$trava_pid" 2>/dev/null
if [ ! -f "$T/trava.ready" ]; then
  echo "FAIL [trava-ocupada-nao-e-perda]: fixture — a trava do log próprio não foi tomada a tempo"
  fail=1
elif grep -q "additionalContext" <<<"$ctx_trava" || [ "$estado_trava" != "presente" ]; then
  echo "FAIL [trava-ocupada-nao-e-perda]: trava ocupada virou perda — ctx=$(tr '\n' ' ' <<<"$ctx_trava" | cut -c1-200) entrada=$estado_trava"
  fail=1
else
  echo "OK [trava-ocupada-nao-e-perda]: trava ocupada não avisa perda e mantém a entrada"
fi

# [perda-real-avisa] não titular de verdade (lease vencido) continua avisando e limpando (rc 4)
bat_venc="$(fresh_claim rcs sess-venc 280)"
lu_venc="$(rewrite_claim_due rcs "$CH" 280 -5)"
sync_cache_after_rewrite rcs "$CH" "$bat_venc" sess-venc "$lu_venc"
ctx_venc="$(run_hook rcs sess-venc 2>/dev/null)"
if grep -q "additionalContext" <<<"$ctx_venc" && [ "$(holder_state rcs "$bat_venc")" = "ausente" ]; then
  echo "OK [perda-real-avisa]: lease vencido (rc 4) avisa e tira a entrada do cache"
else
  echo "FAIL [perda-real-avisa]: perda real não avisou ou não limpou — ctx=$(tr '\n' ' ' <<<"$ctx_venc" | cut -c1-200) entrada=$(holder_state rcs "$bat_venc")"
  fail=1
fi

# [lease-impar] com lease_seconds ímpar, o next_renew_at do cache nunca fica ANTES da metade que o
# renew usa (arredondado para cima por segundo), na claim (recordWon) e no caminho frio
# (rebuildHolders).
bat_impar="$(fresh_claim rcs sess-impar 281)"
check_impar() { # check_impar <rótulo>
  node -e '
const s = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
const h = s.holders[process.argv[2]];
if (!h) { console.log("ausente"); process.exit(0); }
const half = Date.parse(h.leaseUntil) - 281 * 1000 / 2;
console.log(Date.parse(h.nextRenewAt) >= half ? "ok" : `antes da metade: nextRenewAt=${h.nextRenewAt} metade=${new Date(half).toISOString()}`);
' "$T/rcs/.forge/cache/liaison-baton/$CH/baton-local.json" "$bat_impar"
}
impar_claim="$(check_impar)"
rm -f "$T/rcs/.forge/cache/liaison-baton/$CH/baton-local.json"
node -e '
const { join } = require("path");
const { pathToFileURL } = require("url");
(async () => {
  const { rebuildHolders } = await import(pathToFileURL(join(process.argv[1], "liaison-baton-local.mjs")).href);
  await rebuildHolders({ root: process.argv[2], channel: process.argv[3], chDir: process.argv[4], self: "repo-a" });
})();
' "$LIB" "$T/rcs" "$CH" "$T/rcs/.forge/liaison/$CH"
impar_frio="$(check_impar)"
if [ "$impar_claim" = "ok" ] && [ "$impar_frio" = "ok" ]; then
  echo "OK [lease-impar]: next_renew_at arredondado para cima na claim e no caminho frio"
else
  echo "FAIL [lease-impar]: claim=$impar_claim; caminho frio=$impar_frio"
  fail=1
fi

# === [cache-caminho-rapido] ainda não é a hora -> nada gravado, cache inalterado ===
out5="$(LGS a s-off5 baton offer "$CH" --thread t1 --subject "tarefa 5" --max-lease 280 2>&1)"
bat5="$(offer_id "$out5")"
LGS a sess-5 baton claim "$CH" "$bat5" --lease 280 >/dev/null 2>&1
cache_before="$(cat "$T/a/.forge/cache/liaison-baton/$CH/baton-local.json")"
run_hook a sess-5 >/dev/null 2>&1
cache_after="$(cat "$T/a/.forge/cache/liaison-baton/$CH/baton-local.json")"
if [ "$cache_before" = "$cache_after" ]; then
  echo "OK [cache-caminho-rapido]: ainda não é a hora de renovar -- cache inalterado, nada gravado"
else
  echo "FAIL [cache-caminho-rapido]: cache mudou sem ser a hora de renovar"
  fail=1
fi

# === [cache-invalidado-reescrita] tamanho/mtime do log próprio mudando por fora força caminho
# frio (uma claim manual nova, sem passar pelo gancho, precisa ser refletida) ===
out6="$(LGS a s-off6 baton offer "$CH" --thread t1 --subject "tarefa 6" --max-lease 280 2>&1)"
bat6="$(offer_id "$out6")"
LGS a sess-6 baton claim "$CH" "$bat6" --lease 280 >/dev/null 2>&1
# Simula mudança externa: mais uma mensagem qualquer no log próprio (muda tamanho/mtime) sem
# passar pelo gancho -- um release manual, por exemplo.
LGS a sess-6 baton renew "$CH" "$bat6" >/dev/null 2>&1
cache_stale="$(cat "$T/a/.forge/cache/liaison-baton/$CH/baton-local.json")"
# Volta o relógio do cache artificialmente para FORÇAR mismatch de tamanho (simula reescrita
# externa entre o registro do cache e a leitura do gancho).
node -e '
const fs = require("fs");
const path = process.argv[1];
const state = JSON.parse(fs.readFileSync(path, "utf8"));
for (const k of Object.keys(state.holders)) state.holders[k].ownLogSize = 1;
fs.writeFileSync(path, JSON.stringify(state, null, 2));
' "$T/a/.forge/cache/liaison-baton/$CH/baton-local.json"
run_hook a sess-6 >/dev/null 2>&1
cache_rebuilt="$(node -e '
const fs = require("fs");
const state = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
console.log(state.holders[process.argv[2]] ? state.holders[process.argv[2]].ownLogSize : "ausente");
' "$T/a/.forge/cache/liaison-baton/$CH/baton-local.json" "$bat6")"
real_size="$(stat -c %s "$T/a/.forge/liaison/$CH/log/repo-a.jsonl" 2>/dev/null || stat -f %z "$T/a/.forge/liaison/$CH/log/repo-a.jsonl")"
if [ "$cache_rebuilt" = "$real_size" ]; then
  echo "OK [cache-invalidado-reescrita]: mismatch de tamanho força caminho frio e regrava o cache correto"
else
  echo "FAIL [cache-invalidado-reescrita]: esperava ownLogSize=$real_size depois da invalidação, achou $cache_rebuilt"
  fail=1
fi

# === [aviso-perda-limpa-cache] recusa not-holder/lease vencido no modo IF_DUE apaga a entrada e
# avisa uma vez (JSON additionalContext), não duas ===
out7="$(LGS a s-off7 baton offer "$CH" --thread t1 --subject "tarefa 7" --max-lease 280 2>&1)"
bat7="$(offer_id "$out7")"
LGS a sess-7 baton claim "$CH" "$bat7" --lease 280 >/dev/null 2>&1
lease_until7="$(rewrite_claim_due a "$CH" 280 -5)"
sync_cache_after_rewrite a "$CH" "$bat7" sess-7 "$lease_until7"
ctx1="$(run_hook a sess-7)"
holders_after7="$(node -e '
const fs = require("fs");
const state = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
console.log(state.holders[process.argv[2]] ? "presente" : "ausente");
' "$T/a/.forge/cache/liaison-baton/$CH/baton-local.json" "$bat7")"
if echo "$ctx1" | grep -q "additionalContext" && [ "$holders_after7" = "ausente" ]; then
  echo "OK [aviso-perda-limpa-cache]: recusa IF_DUE apaga a entrada do cache e emite additionalContext"
else
  echo "FAIL [aviso-perda-limpa-cache]: esperava additionalContext + entrada removida, achou ctx=$ctx1 holders=$holders_after7"
  fail=1
fi
# segunda chamada, mesma sessão/bastão -- já não há entrada no cache (não deveria renovar nem
# avisar de novo, porque o cache já reflete a ausência de titularidade).
ctx2="$(run_hook a sess-7)"
if [ -z "$ctx2" ]; then
  echo "OK [aviso-nao-repete]: evento seguinte não repete o additionalContext (cache já reflete a perda)"
else
  echo "FAIL [aviso-nao-repete]: esperava saída vazia na segunda chamada, achou: $ctx2"
  fail=1
fi

# === [aviso-config-invalida] liaison.baton inválido avisa e não renova ===
# A config precisa ser VÁLIDA no momento da oferta/claim (offer já se recusa com config
# inválida — TASK-17/18/19, caminho diferente deste) e só se tornar inválida DEPOIS, antes do
# evento do gancho — é esse o cenário que este teste cobre: renew (chamado pelo gancho) lendo
# config que ficou inválida depois da claim.
mk_repo invcfg true false
LG invcfg open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG invcfg thread open "$CH" t1 --subject "cfg invalida" --participants repo-a,repo-b --body "x" >/dev/null
outcfg="$(LGS invcfg s-offcfg baton offer "$CH" --thread t1 --subject "tarefa cfg" --max-lease 280 2>&1)"
batcfg="$(offer_id "$outcfg")"
LGS invcfg sess-cfg baton claim "$CH" "$batcfg" --lease 280 >/dev/null 2>&1
lease_until_cfg="$(rewrite_claim_due invcfg "$CH" 280 100)"
sync_cache_after_rewrite invcfg "$CH" "$batcfg" sess-cfg "$lease_until_cfg"
# SÓ AGORA a config vira inválida — depois da oferta e da claim, antes do evento do gancho.
node -e '
const fs = require("fs");
const p = process.argv[1];
let text = fs.readFileSync(p, "utf8");
text = text.replace(/^  # baton:$/m, "  baton:");
text = text.replace(/^  #   default_lease_seconds: 1800.*$/m, "    default_lease_seconds: 10");
fs.writeFileSync(p, text);
' "$T/invcfg/.forge/forge.yaml"
run_hook invcfg sess-cfg >/dev/null 2>&1
statuscfg="$(LG invcfg baton status "$CH" "$batcfg" 2>&1)"
if ! echo "$statuscfg" | grep -q "renewed"; then
  echo "OK [aviso-config-invalida]: liaison.baton inválido (default_lease_seconds fora da faixa) não renova"
else
  echo "FAIL [aviso-config-invalida]: renovou com configuração inválida: $statuscfg"
  fail=1
fi

# === [destacado-nao-prende-evento] sync --push-only destacado com transporte TRAVADO DE VERDADE não
# prende o retorno do gancho (QLT-002). O FIFO antigo fazia o `sync` abortar em ~200 ms ("não foi
# possível criar o hub"): nada bloqueava, e o cenário passaria com o sync em primeiro plano. Aqui o
# hub é válido e a barreira de teste (FORGE_LIAISON_TEST_BARRIER, `_liaison_test_barrier` em
# lib/transports/_common.sh) segura o push em `after-blobs` até o gate liberar — o destacado fica
# de fato parado no meio da publicação enquanto o evento já voltou. O cenário confere também que
# a renovação foi gravada, que o destacado foi disparado (parou na barreira) e que, liberado, ele
# publica a renovação no hub. Mutação de controle (provada uma vez, descrita no commit, fora do
# código): com o `sync` em primeiro plano no gancho, o evento fica preso na barreira e o cenário
# reprova por tempo.
mk_repo det true false
LG det open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG det thread open "$CH" t1 --subject "detached" --participants repo-a,repo-b --body "x" >/dev/null
mk_repo det_b true false
LG det_b open "$CH" --self repo-b --participants repo-a,repo-b >/dev/null
LG det transport set "$CH" --kind fs --path "$T/hub-det" >/dev/null
LG det sync "$CH" --push-only >/dev/null 2>&1
LG det_b transport set "$CH" --kind fs --path "$T/hub-det" >/dev/null
LG det_b sync "$CH" >/dev/null 2>&1
outdet="$(LGS det s-offdet baton offer "$CH" --thread t1 --subject "tarefa detached" --max-lease 280 2>&1)"
batdet="$(offer_id "$outdet")"
LG det sync "$CH" --push-only >/dev/null 2>&1
LG det_b sync "$CH" >/dev/null 2>&1
LGS det sess-det baton claim "$CH" "$batdet" --lease 280 >/dev/null 2>&1
lease_until_det="$(rewrite_claim_due det "$CH" 280 100)"
sync_cache_after_rewrite det "$CH" "$batdet" sess-det "$lease_until_det"
renews_in() { # renews_in <arquivo de log> -> número de renews deste bastão
  node -e '
const fs = require("fs");
let n = 0;
try { for (const l of fs.readFileSync(process.argv[1], "utf8").split("\n")) { if (!l.trim()) continue; const m = JSON.parse(l); if (m.baton && m.baton.op === "renew" && m.in_reply_to === process.argv[2]) n++; } } catch {}
console.log(n);
' "$1" "$batdet"
}
BARRIER_DET="$T/barrier-det"
mkdir -p "$BARRIER_DET"
# PLAT-202: shim transparente de `node` que registra o FORGE_LIAISON_PUSH_DEADLINE_S de cada
# chamada ao módulo de E/S do hub — só o push do `sync` destacado chama esse módulo, então o
# registro é o ambiente do destacado (a norma do liaison-protocol.md: 25 s no destacado).
SHIM_DET="$T/shim-det"; DEADLINE_LOG="$T/det-deadline.log"
mkdir -p "$SHIM_DET"; : > "$DEADLINE_LOG"
cat > "$SHIM_DET/node" <<SHIM
#!/bin/sh
case "\$1" in */liaison-hub-io.mjs) printf '%s\n' "\${FORGE_LIAISON_PUSH_DEADLINE_S:-ausente}" >> "$DEADLINE_LOG" ;; esac
exec "$(command -v node)" "\$@"
SHIM
chmod +x "$SHIM_DET/node"
start_ms="$(node -e 'console.log(Date.now())')"
(cd "$T/det" && printf '{"session_id":"%s"}' sess-det | PATH="$SHIM_DET:$PATH" FORGE_LIAISON_TEST_BARRIER="$BARRIER_DET" FORGE_ROOT="$T/det" bash "$(HOOK_FOR det)") >/dev/null 2>&1
end_ms="$(node -e 'console.log(Date.now())')"
elapsed=$((end_ms - start_ms))
# o destacado precisa chegar à barreira (prova de que foi disparado e de que o transporte está
# de fato parado nele) — espera até 15 s
ready=""
for _ in $(seq 1 150); do
  for r in "$BARRIER_DET"/after-blobs.*.ready; do [ -e "$r" ] && { ready="$r"; break; }; done
  [ -n "$ready" ] && break
  node -e 'setTimeout(()=>{},100)'
done
renew_local="$(renews_in "$T/det/.forge/liaison/$CH/log/repo-a.jsonl")"
renew_hub_parado="$(renews_in "$T/hub-det/$CH/log/repo-a.jsonl")"
det_ok=1
if [ "$elapsed" -ge 5000 ]; then
  echo "FAIL [destacado-nao-prende-evento]: evento levou ${elapsed}ms (>=5000ms) com o push parado na barreira -- o sync prendeu o retorno"
  det_ok=0
fi
if [ "$renew_local" != "1" ]; then
  echo "FAIL [destacado-nao-prende-evento]: esperava 1 renew gravado no log próprio, achei $renew_local"
  det_ok=0
fi
deadlines_det="$(sort -u "$DEADLINE_LOG" | tr '\n' ' ')"
if [ -z "$ready" ]; then
  echo "FAIL [destacado-nao-prende-evento]: o sync destacado nunca chegou à barreira after-blobs (não foi disparado, ou abortou antes de travar)"
  det_ok=0
elif [ "$deadlines_det" != "25 " ]; then
  echo "FAIL [destacado-prazo-25s]: o sync destacado rodou com FORGE_LIAISON_PUSH_DEADLINE_S='${deadlines_det% }' (esperado 25, a norma do liaison-protocol.md; sem ela vale 300 s e o vigia de 30 s vira o caminho normal)"
  det_ok=0
elif [ "$renew_hub_parado" != "0" ]; then
  echo "FAIL [destacado-nao-prende-evento]: o hub já tinha o renew com o push parado na barreira ($renew_hub_parado) -- a barreira não travou nada"
  det_ok=0
fi
# libera o destacado e confere que ele publica a renovação. `_dir_push` tem mais de um ponto de
# barreira (after-blobs, after-union, after-mv): cada um que aparecer é liberado no mesmo laço.
if [ -n "$ready" ]; then
  renew_hub=0
  for _ in $(seq 1 150); do
    for r in "$BARRIER_DET"/*.ready; do [ -e "$r" ] && : > "${r%.ready}.go"; done
    renew_hub="$(renews_in "$T/hub-det/$CH/log/repo-a.jsonl")"
    [ "$renew_hub" = "1" ] && break
    node -e 'setTimeout(()=>{},100)'
  done
  if [ "$renew_hub" != "1" ]; then
    echo "FAIL [destacado-nao-prende-evento]: liberada a barreira, o destacado não publicou o renew no hub (achei $renew_hub)"
    det_ok=0
  fi
fi
# solta qualquer outro ponto de barreira que tenha sobrado, para nada ficar esperando 30 s
for r in "$BARRIER_DET"/*.ready; do [ -e "$r" ] && : > "${r%.ready}.go"; done
if [ "$det_ok" -eq 1 ]; then
  echo "OK [destacado-nao-prende-evento]: evento voltou em ${elapsed}ms com o push destacado parado na barreira (prazo de 25 s no destacado); renew gravado e, liberada a barreira, publicado no hub"
else
  fail=1
fi

# === [aviso-json-unico] PLAT-203: dois bastões perdidos no MESMO evento produzem UM documento JSON
# no stdout, com os dois avisos no additionalContext. Dois objetos seguidos não são JSON válido, e
# o Claude Code descarta o additionalContext inteiro. ===
mk_repo mj true false
LG mj open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG mj thread open "$CH" t1 --subject "json unico" --participants repo-a,repo-b --body "x" >/dev/null
bat_mj1="$(fresh_claim mj sess-mj 280)"
lu_mj1="$(rewrite_claim_due mj "$CH" 280 -5)"
bat_mj2="$(fresh_claim mj sess-mj 280)"
lu_mj2="$(rewrite_claim_due mj "$CH" 280 -5)"
sync_cache_after_rewrite mj "$CH" "$bat_mj1" sess-mj "$lu_mj1"
sync_cache_after_rewrite mj "$CH" "$bat_mj2" sess-mj "$lu_mj2"
ctx_mj="$(run_hook mj sess-mj 2>/dev/null)"
veredito_mj="$(printf '%s' "$ctx_mj" | node -e '
let d = ""; process.stdin.on("data", (c) => d += c); process.stdin.on("end", () => {
  let o;
  try { o = JSON.parse(d.trim()); } catch (e) { console.log("stdout não é UM documento JSON: " + d.replace(/\n/g, "\\n").slice(0, 300)); return; }
  const ctx = o && o.hookSpecificOutput && o.hookSpecificOutput.additionalContext;
  if (typeof ctx !== "string") { console.log("sem hookSpecificOutput.additionalContext"); return; }
  const faltam = process.argv.slice(1).filter((b) => !ctx.includes(b));
  console.log(faltam.length ? "additionalContext sem o aviso de " + faltam.join(", ") : "ok");
});
' "$bat_mj1" "$bat_mj2")"
if [ "$veredito_mj" = "ok" ]; then
  echo "OK [aviso-json-unico]: dois bastões perdidos no mesmo evento saem num único documento JSON com os dois avisos"
else
  echo "FAIL [aviso-json-unico]: $veredito_mj"
  fail=1
fi

# === [aviso-perda-repetida] LGC-202: perde, reivindica de novo, perde de novo -> dois avisos. A
# chave do aviso inclui a claim que deu a posse; com a chave só por bastão, a segunda perda calava. ===
mk_repo lr true false
LG lr open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG lr thread open "$CH" t1 --subject "perda repetida" --participants repo-a,repo-b --body "x" >/dev/null
bat_lr="$(fresh_claim lr sess-lr 280)"
lu_lr="$(rewrite_claim_due lr "$CH" 280 -5)"
sync_cache_after_rewrite lr "$CH" "$bat_lr" sess-lr "$lu_lr"
ctx_lr1="$(run_hook lr sess-lr 2>/dev/null)"
LGS lr sess-lr baton claim "$CH" "$bat_lr" --lease 280 >/dev/null 2>&1
estado_lr="$(holder_state lr "$bat_lr")"
lu_lr="$(rewrite_claim_due lr "$CH" 280 -5)"
sync_cache_after_rewrite lr "$CH" "$bat_lr" sess-lr "$lu_lr"
ctx_lr2="$(run_hook lr sess-lr 2>/dev/null)"
if ! grep -q "$bat_lr" <<<"$ctx_lr1"; then
  echo "FAIL [aviso-perda-repetida]: fixture — a primeira perda não avisou: $(tr '\n' ' ' <<<"$ctx_lr1" | cut -c1-200)"
  fail=1
elif [ "$estado_lr" != "presente" ]; then
  echo "FAIL [aviso-perda-repetida]: fixture — a nova claim depois da perda não deu a posse (entrada $estado_lr no cache)"
  fail=1
elif ! grep -q "$bat_lr" <<<"$ctx_lr2"; then
  echo "FAIL [aviso-perda-repetida]: a segunda perda do mesmo bastão (depois de reivindicar de novo) não avisou: '$(tr '\n' ' ' <<<"$ctx_lr2" | cut -c1-200)'"
  fail=1
else
  echo "OK [aviso-perda-repetida]: perder, reivindicar e perder de novo produz dois avisos"
fi

# === [trava-local-curta] PLAT-205: com a trava LOCAL do canal ocupada por 5 s, o gancho não fica
# esperando o default de 10 s em _consume_publish_results/_rebuild_cold/_mark_warned_once/
# _remove_holder_entry — todas usam a mesma espera curta (300 ms) do renew. ===
mk_repo lk true false
LG lk open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG lk thread open "$CH" t1 --subject "trava local" --participants repo-a,repo-b --body "x" >/dev/null
mkdir -p "$T/lk/.forge/cache/liaison-baton/$CH"
printf '{"rc":1,"at":"2026-01-01T00:00:00Z","attempts":1,"repairs":0}' > "$T/lk/.forge/cache/liaison-baton/$CH/publish-result-1.json"
node -e '
const { join } = require("path");
const { pathToFileURL } = require("url");
(async () => {
  const fs = require("fs");
  const [, lib, root, channel, ready] = process.argv;
  const { withLocalLock } = await import(pathToFileURL(join(lib, "liaison-lock.mjs")).href);
  await withLocalLock({ root, channel, self: "repo-a" }, async () => {
    fs.writeFileSync(ready, "1");
    await new Promise((r) => setTimeout(r, 5000));
  });
})();
' "$LIB" "$T/lk" "$CH" "$T/lk.ready" &
lk_pid=$!
for _ in $(seq 1 50); do [ -f "$T/lk.ready" ] && break; node -e 'setTimeout(()=>{},100)'; done
start_ms="$(node -e 'console.log(Date.now())')"
run_hook lk sess-lk >/dev/null 2>&1
end_ms="$(node -e 'console.log(Date.now())')"
elapsed_lk=$((end_ms - start_ms))
wait "$lk_pid" 2>/dev/null
if [ ! -f "$T/lk.ready" ]; then
  echo "FAIL [trava-local-curta]: fixture — a trava local do canal não foi tomada a tempo"
  fail=1
elif [ "$elapsed_lk" -ge 3000 ]; then
  echo "FAIL [trava-local-curta]: com a trava local ocupada o evento levou ${elapsed_lk}ms (>=3000ms) — alguma chamada do gancho esperou o default de 10 s"
  fail=1
else
  echo "OK [trava-local-curta]: com a trava local ocupada o evento voltou em ${elapsed_lk}ms"
fi

# === [perf-caminho-rapido] ordem de grandeza do caminho sem bastão/fora da hora (não é p95
# estatístico rigoroso -- máquina compartilhada sob carga variável; mede só que o caminho NÃO
# invoca node nenhuma vez, que é a garantia estrutural real do NFR-02, não um cronômetro) ===
mk_repo perfrepo true false
LG perfrepo open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG perfrepo thread open "$CH" t1 --subject "perf" --participants repo-a,repo-b --body "x" >/dev/null
out_perf="$(LGS perfrepo s-offperf baton offer "$CH" --thread t1 --subject "tarefa perf" --max-lease 280 2>&1)"
bat_perf="$(offer_id "$out_perf")"
LGS perfrepo sess-perf baton claim "$CH" "$bat_perf" --lease 280 >/dev/null 2>&1
# Sem bastão nenhum detido por OUTRA sessão: caminho sem bastão.
start_ms="$(node -e 'console.log(Date.now())')"
run_hook perfrepo sess-sem-bastao-nenhum >/dev/null 2>&1
end_ms="$(node -e 'console.log(Date.now())')"
elapsed_sembastao=$((end_ms - start_ms))
# Mesma sessão, mas ainda não é a hora: caminho fora da hora (cache já existe e bate).
start_ms="$(node -e 'console.log(Date.now())')"
run_hook perfrepo sess-perf >/dev/null 2>&1
end_ms="$(node -e 'console.log(Date.now())')"
elapsed_forada=$((end_ms - start_ms))
if [ "$elapsed_sembastao" -lt 2000 ] && [ "$elapsed_forada" -lt 2000 ]; then
  echo "OK [perf-caminho-rapido]: sem bastão (${elapsed_sembastao}ms) e fora da hora (${elapsed_forada}ms) terminam em ordem de grandeza compatível com NFR-02 nesta máquina"
else
  echo "FAIL [perf-caminho-rapido]: sem bastão=${elapsed_sembastao}ms fora-da-hora=${elapsed_forada}ms -- acima do razoável para um caminho sem node"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS — renovação automática do bastão (REQ-12, NFR-02)"
exit 0
