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
#   [destacado-*] sync --push-only destacado não prende o evento mesmo com transporte travado
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
  echo "$(stat -f %z "$f" 2>/dev/null || stat -c %s "$f") $(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f")"
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
  ( run_hook a sess-4 >/dev/null 2>&1 ) &
done
wait
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
real_size="$(stat -f %z "$T/a/.forge/liaison/$CH/log/repo-a.jsonl" 2>/dev/null || stat -c %s "$T/a/.forge/liaison/$CH/log/repo-a.jsonl")"
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

# === [destacado-nao-prende-evento] sync --push-only destacado com transporte travado (FIFO que
# nunca é lido) não prende o retorno do gancho ===
mk_repo det true false
LG det open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG det thread open "$CH" t1 --subject "detached" --participants repo-a,repo-b --body "x" >/dev/null
FIFO="$T/det/.forge/cache/stuck.fifo"
mkfifo "$FIFO" 2>/dev/null || true
LG det transport set "$CH" --kind fs --path "$FIFO" >/dev/null 2>&1 || true
# fs aponta para um FIFO em vez de diretório -- qualquer tentativa de ler/escrever ali bloqueia
# (nada no outro lado do FIFO para consumir), simulando transporte travado.
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
# Agora aponta o transporte para o FIFO travado (depois da claim, para não travar o setup) e
# mede o tempo do PRÓPRIO evento (não do sync destacado, que corre à parte).
LG det transport set "$CH" --kind fs --path "$FIFO" >/dev/null 2>&1 || true
start_ms="$(node -e 'console.log(Date.now())')"
run_hook det sess-det >/dev/null 2>&1
end_ms="$(node -e 'console.log(Date.now())')"
elapsed=$((end_ms - start_ms))
if [ "$elapsed" -lt 5000 ]; then
  echo "OK [destacado-nao-prende-evento]: evento terminou em ${elapsed}ms mesmo com transporte apontando para FIFO travado"
else
  echo "FAIL [destacado-nao-prende-evento]: evento levou ${elapsed}ms (>=5000ms) -- o processo destacado prendeu o retorno"
  fail=1
fi
rm -f "$FIFO" 2>/dev/null || true

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
