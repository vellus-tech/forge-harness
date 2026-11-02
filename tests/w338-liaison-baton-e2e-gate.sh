#!/usr/bin/env bash
# Gate — TASK-25 de add-liaison-handoff-baton (REQ-03, REQ-05, REQ-15): aceitação ponta a ponta.
#   [e2e-fluxo] oferta, duas reivindicações concorrentes, renovação, liberação, nova
#     reivindicação e conclusão entre duas réplicas com transporte fs
#   [e2e-sem-notify]/[e2e-com-notify] mesmo resultado final do fluxo, com e sem notify no meio
#   [e2e-notify-ponteiro] notify aceita o ponteiro de uma mensagem de bastão publicada
#   [e2e-notify-nao-publicada] notify sobre oferta não publicada continua recusado como antes
#   [e2e-w113] mensagens de bastão (requires_ack sempre false) não disparam o enforcement de
#     ack do w113 — nem em warn nem em block
#
# Nota (tasks.md): esta task não tem implementação própria — fecha verde quando TASK-20/22/24
# terminam. Escrita e vista vermelha retroativamente contra o commit da TASK-18 (8bf78680, antes
# de offer/claim existirem) para a prova ficar registrada, já que o plano original previa
# escrevê-la logo depois da TASK-18 e só este checkpoint a retomou depois da TASK-24.
set -uo pipefail
# Hermético quanto à sessão: a sessão de um agente (Claude Code) exporta CLAUDE_CODE_SESSION_ID para
# todo processo filho e o runner do CI não tem a variável. Sem este unset o gate passa dentro do
# agente e reprova no CI (ou o inverso); quem precisa de sessão a declara explicitamente.
unset CLAUDE_CODE_SESSION_ID
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-liaison-baton-e2e.XXXXXX)"
trap 'rm -rf "$T"' EXIT

fail=0
CH=baton-e2e-gate

mk_repo() {
  local dir="$T/$1"
  mkdir -p "$dir/.forge"
  cp -R "$WS/template/.forge/scripts" "$dir/.forge/"
  cp -R "$WS/template/.forge/templates" "$dir/.forge/"
  cp "$WS/template/.forge/forge.yaml" "$dir/.forge/forge.yaml"
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

# run_flow <sufixo> <usar-notify:true|false> -> imprime "estado-final:<msg_id-vencedor-final>"
# Fluxo completo: oferta (repo-a) -> duas reivindicações concorrentes (repo-a e repo-b) ->
# renovação pela vencedora -> liberação -> nova reivindicação (pela outra sessão) -> conclusão.
run_flow() {
  local suf="$1" use_notify="$2"
  local a="e2e_a_$suf" b="e2e_b_$suf" hub="$T/hub_$suf"
  mk_repo "$a"; mk_repo "$b"
  LG "$a" open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
  LG "$a" thread open "$CH" t1 --subject "fluxo $suf" --participants repo-a,repo-b --body "abertura" >/dev/null
  LG "$a" transport set "$CH" --kind fs --path "$hub" >/dev/null
  LG "$a" sync "$CH" --push-only >/dev/null 2>&1
  LG "$b" open "$CH" --self repo-b --participants repo-a,repo-b >/dev/null
  LG "$b" transport set "$CH" --kind fs --path "$hub" >/dev/null
  LG "$b" sync "$CH" >/dev/null 2>&1

  local outoff batid
  outoff="$(LGS "$a" s-off baton offer "$CH" --thread t1 --subject "tarefa $suf" 2>&1)" || { echo "FAIL-STEP:offer:$outoff"; return 1; }
  batid="$(offer_id "$outoff")"
  [ -n "$batid" ] || { echo "FAIL-STEP:offer-sem-id:$outoff"; return 1; }
  LG "$a" sync "$CH" --push-only >/dev/null 2>&1
  LG "$b" sync "$CH" >/dev/null 2>&1

  if [ "$use_notify" = "true" ]; then
    local notify_out notify_rc
    notify_out="$(LG "$a" notify "$CH" "$batid" --to repo-b 2>&1)"; notify_rc=$?
    [ "$notify_rc" -eq 0 ] || { echo "FAIL-STEP:notify-oferta:$notify_out"; return 1; }
  fi

  # Duas reivindicações concorrentes: repo-a e repo-b, ambas sem ter visto a claim uma da outra.
  local rc_a rc_b
  LGS "$a" s-h1 baton claim "$CH" "$batid" --lease 90 >/dev/null 2>&1; rc_a=$?
  LGS "$b" s-h2 baton claim "$CH" "$batid" --lease 90 >/dev/null 2>&1; rc_b=$?
  if [ "$rc_a" -ne 0 ] && [ "$rc_b" -ne 0 ]; then
    echo "FAIL-STEP:ambas-claims-recusaram:a=$rc_a,b=$rc_b"; return 1
  fi
  LG "$a" sync "$CH" --push-only >/dev/null 2>&1
  LG "$b" sync "$CH" --push-only >/dev/null 2>&1
  LG "$a" sync "$CH" >/dev/null 2>&1
  LG "$b" sync "$CH" >/dev/null 2>&1

  # Determina a vencedora global via baton status (fiel à mesma dobra nos dois lados).
  local holder_a holder_b
  holder_a="$(LG "$a" baton status "$CH" "$batid" --json | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{const o=JSON.parse(d);const h=o.batons[0].holder;process.stdout.write(h?h.sender+"/"+h.session:"none");})')"
  holder_b="$(LG "$b" baton status "$CH" "$batid" --json | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{const o=JSON.parse(d);const h=o.batons[0].holder;process.stdout.write(h?h.sender+"/"+h.session:"none");})')"
  if [ "$holder_a" != "$holder_b" ] || [ "$holder_a" = "none" ]; then
    echo "FAIL-STEP:titulares-divergem:a=$holder_a,b=$holder_b"; return 1
  fi

  local winner_repo="$a" winner_session loser_repo="$b" loser_session
  case "$holder_a" in
    repo-a/*) winner_repo="$a"; winner_session="${holder_a#repo-a/}"; loser_repo="$b"; loser_session="s-h2" ;;
    repo-b/*) winner_repo="$b"; winner_session="${holder_a#repo-b/}"; loser_repo="$a"; loser_session="s-h1" ;;
  esac

  # Renovação pela vencedora.
  local renew_out renew_rc
  renew_out="$(LGS "$winner_repo" "$winner_session" baton renew "$CH" "$batid" 2>&1)"; renew_rc=$?
  [ "$renew_rc" -eq 0 ] || { echo "FAIL-STEP:renovacao:$renew_out"; return 1; }
  LG "$winner_repo" sync "$CH" --push-only >/dev/null 2>&1

  # Liberação pela vencedora.
  local release_out release_rc
  release_out="$(LGS "$winner_repo" "$winner_session" baton release "$CH" "$batid" 2>&1)"; release_rc=$?
  [ "$release_rc" -eq 0 ] || { echo "FAIL-STEP:liberacao:$release_out"; return 1; }
  LG "$winner_repo" sync "$CH" --push-only >/dev/null 2>&1
  LG "$loser_repo" sync "$CH" >/dev/null 2>&1

  # Nova reivindicação, agora pela sessão perdedora da rodada anterior.
  local reclaim_out reclaim_rc reclaim_msg_id
  reclaim_out="$(LGS "$loser_repo" "$loser_session" baton claim "$CH" "$batid" --lease 90 2>&1)"; reclaim_rc=$?
  [ "$reclaim_rc" -eq 0 ] || { echo "FAIL-STEP:nova-reivindicacao:$reclaim_out"; return 1; }
  reclaim_msg_id="$(printf '%s' "$reclaim_out" | grep '^OK baton claim' | sed -E 's/^OK baton claim — ([^ ]+).*/\1/')"
  LG "$loser_repo" sync "$CH" --push-only >/dev/null 2>&1

  if [ "$use_notify" = "true" ]; then
    local notify_out2 notify_rc2
    # notify sobre a mensagem da claim NOVA (mensagem própria de loser_repo) — não sobre a
    # oferta, que é própria de quem ofertou, não de quem reivindicou.
    notify_out2="$(LG "$loser_repo" notify "$CH" "$reclaim_msg_id" --to "$winner_repo" 2>&1)"
    notify_rc2=$?
    [ "$notify_rc2" -eq 0 ] || { echo "FAIL-STEP:notify-claim:$notify_out2"; return 1; }
  fi

  # Conclusão pela sessão que detém agora.
  local complete_out complete_rc
  complete_out="$(LGS "$loser_repo" "$loser_session" baton complete "$CH" "$batid" --body "feito" 2>&1)"; complete_rc=$?
  [ "$complete_rc" -eq 0 ] || { echo "FAIL-STEP:conclusao:$complete_out"; return 1; }
  LG "$loser_repo" sync "$CH" --push-only >/dev/null 2>&1
  LG "$winner_repo" sync "$CH" >/dev/null 2>&1

  local final_a final_b
  final_a="$(LG "$winner_repo" baton status "$CH" "$batid" --json | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{process.stdout.write(JSON.parse(d).batons[0].state);})')"
  final_b="$(LG "$loser_repo" baton status "$CH" "$batid" --json | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{process.stdout.write(JSON.parse(d).batons[0].state);})')"
  echo "FINAL:$final_a:$final_b:$batid"
  return 0
}

# === [e2e-sem-notify] / [e2e-fluxo] ===
out_sem="$(run_flow sem false)"; rc_sem=$?
if [ "$rc_sem" -eq 0 ] && printf '%s' "$out_sem" | grep -q "^FINAL:completed:completed:"; then
  echo "OK [e2e-fluxo]: oferta, duas claims concorrentes, renovação, liberação, nova reivindicação e conclusão, sem notify"
  echo "OK [e2e-sem-notify]: as duas réplicas convergem para 'completed'"
else
  echo "FAIL [e2e-fluxo]: fluxo sem notify falhou em algum passo ou não convergiu: $out_sem"
  fail=1
fi

# === [e2e-com-notify] mesmo resultado final, chamando notify no meio do fluxo ===
out_com="$(run_flow com true)"; rc_com=$?
if [ "$rc_com" -eq 0 ] && printf '%s' "$out_com" | grep -q "^FINAL:completed:completed:"; then
  echo "OK [e2e-com-notify]: mesmo resultado final (completed nas duas réplicas) com notify no meio do fluxo"
else
  echo "FAIL [e2e-com-notify]: fluxo com notify falhou em algum passo ou não convergiu: $out_com"
  fail=1
fi

# === [e2e-notify-ponteiro] notify aceita o ponteiro de uma mensagem de bastão publicada ===
mk_repo nrepo
LG nrepo open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG nrepo thread open "$CH" t1 --subject "notify" --participants repo-a,repo-b --body "x" >/dev/null
HUBN="$T/hub-n"
LG nrepo transport set "$CH" --kind fs --path "$HUBN" >/dev/null
LG nrepo sync "$CH" --push-only >/dev/null 2>&1
outnf="$(LGS nrepo s-offn baton offer "$CH" --thread t1 --subject "tarefa notify" 2>&1)"
batn="$(offer_id "$outnf")"
LG nrepo sync "$CH" --push-only >/dev/null 2>&1
notify_pub_out="$(LG nrepo notify "$CH" "$batn" --to repo-b 2>&1)"; notify_pub_rc=$?
if [ "$notify_pub_rc" -eq 0 ] && echo "$notify_pub_out" | grep -q "liaison:$CH/$batn"; then
  echo "OK [e2e-notify-ponteiro]: notify aceita o ponteiro de uma oferta publicada"
else
  echo "FAIL [e2e-notify-ponteiro]: esperava ponteiro liaison:$CH/$batn, achou rc=$notify_pub_rc out=$notify_pub_out"
  fail=1
fi

# === [e2e-notify-nao-publicada] notify sobre oferta NÃO publicada continua recusado ===
outnf2="$(LGS nrepo s-offn2 baton offer "$CH" --thread t1 --subject "tarefa nao publicada" 2>&1)"
batn2="$(offer_id "$outnf2")"
# Deliberadamente SEM sync --push-only — a oferta existe só no log local, nunca chegou ao hub.
notify_unpub_out="$(LG nrepo notify "$CH" "$batn2" --to repo-b 2>&1)"; notify_unpub_rc=$?
if [ "$notify_unpub_rc" -ne 0 ]; then
  echo "OK [e2e-notify-nao-publicada]: notify sobre oferta não publicada continua recusado (rc=$notify_unpub_rc)"
else
  echo "FAIL [e2e-notify-nao-publicada]: esperava recusa, achou rc=0: $notify_unpub_out"
  fail=1
fi

# === [e2e-w113] mensagens de bastão nunca disparam o enforcement de ack (requires_ack sempre
# false, REQ-01) — roda check-liaison-acks.sh (o mesmo mecanismo que o w113 testa) sobre um
# canal só com operações de bastão, em enforce:block ===
mk_repo w113rep
LG w113rep open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG w113rep thread open "$CH" t1 --subject "w113" --participants repo-a,repo-b --body "x" >/dev/null
node -e '
const fs = require("fs");
const path = process.argv[1];
let text = fs.readFileSync(path, "utf8");
const next = text.replace(/enforce:\s*warn/, "enforce: block");
if (next === text) { console.error("FAIL: padrao \"enforce: warn\" nao encontrado em forge.yaml"); process.exit(1); }
fs.writeFileSync(path, next);
' "$T/w113rep/.forge/forge.yaml"
outw113="$(LGS w113rep s-offw baton offer "$CH" --thread t1 --subject "tarefa w113" 2>&1)"
batw113="$(offer_id "$outw113")"
LGS w113rep s-hw baton claim "$CH" "$batw113" --lease 90 >/dev/null 2>&1
LGS w113rep s-hw baton renew "$CH" "$batw113" >/dev/null 2>&1
LGS w113rep s-hw baton release "$CH" "$batw113" >/dev/null 2>&1
ack_out="$(FORGE_ROOT="$T/w113rep" bash "$T/w113rep/.forge/scripts/check-liaison-acks.sh" 2>&1)"; ack_rc=$?
if [ "$ack_rc" -eq 0 ]; then
  echo "OK [e2e-w113]: check-liaison-acks.sh (enforce:block) não bloqueia mensagens de bastão (requires_ack sempre false)"
else
  echo "FAIL [e2e-w113]: check-liaison-acks.sh reprovou mensagens de bastão: $ack_out"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS — aceitação ponta a ponta do bastão (REQ-03, REQ-05, REQ-15)"
exit 0
