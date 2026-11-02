#!/usr/bin/env bash
# Gate — TASK-19/TASK-20 de add-liaison-handoff-baton (REQ-02, REQ-03, REQ-11, design §2.7):
#   [offer-*] oferta sem reivindicação implícita; recusas sem gravar (thread só interna, --for
#     fora da thread, eligible só com o próprio); eligible gravado igual aos participantes
#   [claim-*] 10 claims concorrentes de 10 sessões (exatamente um vencedor); pré-condições sem
#     gravar (oferta desconhecida, --lease fora da faixa, sessão já titular com lease vigente);
#     redução do lease ao máximo da oferta; lost-held dentro da folga; aviso de sync antes de
#     tomada por vencimento contra titular de outro repositório
#   [escrita] nenhuma escrita de offer/claim fora de log/<self>.jsonl, blobs/, CHANNEL.md e
#     estado local em .forge/cache/liaison-baton|liaison-locks
#   [acks]/[trust] check-liaison-acks.sh e trust sobre fixture de três repositórios com todas
#     as operações de bastão
#   [import-sender] sender adulterado numa mensagem de bastão no import -> conflito (regra
#     existente, sem bypass para o bastão)
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPS="$WS/template/.forge/scripts/liaison-ops.sh"
T="$(mktemp -d /tmp/forge-liaison-baton-claim.XXXXXX)"
trap 'rm -rf "$T"' EXIT

fail=0
CH=baton-claim-gate

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

mk_repo() { # mk_repo <nome>
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

LG() { # LG <nome-repo> <args...>
  local repo="$1"; shift
  FORGE_ROOT="$T/$repo" bash "$T/$repo/.forge/scripts/liaison-ops.sh" "$@"
}

LGS() { # LGS <nome-repo> <session> <args...> — injeta CLAUDE_CODE_SESSION_ID
  local repo="$1" session="$2"; shift 2
  FORGE_ROOT="$T/$repo" CLAUDE_CODE_SESSION_ID="$session" bash "$T/$repo/.forge/scripts/liaison-ops.sh" "$@"
}

ACKCHECK() { # ACKCHECK <nome-repo>
  local repo="$1"
  FORGE_ROOT="$T/$repo" bash "$T/$repo/.forge/scripts/liaison-ops.sh" >/dev/null 2>&1 # no-op de aquecimento
  FORGE_ROOT="$T/$repo" bash "$T/$repo/.forge/scripts/check-liaison-acks.sh"
}

offer_id() { # offer_id <saida-de-baton-offer> -> baton_id
  printf '%s' "$1" | grep '^OK baton offer' | sed -E 's/^OK baton offer — //'
}

own_log() { # own_log <nome-repo> <self>
  printf '%s' "$T/$1/.forge/liaison/$CH/log/$2.jsonl"
}

# === setup base: repo-a self repo-a, thread com repo-a e repo-b ===
mk_repo a
LG a open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG a thread open "$CH" t1 --subject "trabalho compartilhado" --participants repo-a,repo-b --body "abertura" >/dev/null

# === [offer-sem-reivindicacao] oferta não cria titular ===
out="$(LGS a s-offer baton offer "$CH" --thread t1 --subject "tarefa 1" 2>&1)"; rc=$?
out="$(judge offer-sem-reivindicacao "$out" "$rc")"
batid1="$(offer_id "$out")"
if [ -n "$batid1" ]; then
  status_log="$(own_log a repo-a)"
  held="$(node -e '
const fs = require("fs");
const lines = fs.readFileSync(process.argv[1], "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
const claims = lines.filter((m) => m.baton && m.baton.op !== "offer");
process.stdout.write(String(claims.length));
' "$status_log")"
  [ "$held" = "0" ] || { echo "FAIL [offer-sem-reivindicacao]: oferta gravou $held mensagem(ns) além da própria oferta"; fail=1; }
else
  echo "FAIL [offer-sem-reivindicacao]: não consegui extrair baton_id de: $out"; fail=1
fi

# === [offer-eligible-gravado] eligible == participantes da thread (sem --for) ===
elig="$(node -e '
const fs = require("fs");
const lines = fs.readFileSync(process.argv[1], "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
const offer = lines.find((m) => m.msg_id === process.argv[2]);
process.stdout.write(JSON.stringify((offer.baton.eligible || []).slice().sort()));
' "$(own_log a repo-a)" "$batid1")"
[ "$elig" = '["repo-a","repo-b"]' ] && echo "OK [offer-eligible-gravado]: eligible = $elig" \
  || { echo "FAIL [offer-eligible-gravado]: esperava [\"repo-a\",\"repo-b\"], achou $elig"; fail=1; }

# === [offer-thread-interna] thread só com o próprio -> rc 1 sem gravar ===
LG a open "$CH-solo" --self repo-a --participants repo-a >/dev/null
LG a thread open "$CH-solo" t1 --subject "s" --participants repo-a --body "x" >/dev/null
before="$(wc -l < "$(printf '%s' "$T/a/.forge/liaison/$CH-solo/log/repo-a.jsonl")" 2>/dev/null || echo 0)"
out="$(LGS a s-x baton offer "$CH-solo" --thread t1 --subject "oferta solo" 2>&1)"; rc=$?
after="$(wc -l < "$(printf '%s' "$T/a/.forge/liaison/$CH-solo/log/repo-a.jsonl")" 2>/dev/null || echo 0)"
if [ "$rc" -eq 1 ] && [ "$before" = "$after" ]; then
  echo "OK [offer-thread-interna]: rc 1, nada gravado ($out)"
else
  echo "FAIL [offer-thread-interna]: esperava rc 1 sem gravar, achou rc=$rc before=$before after=$after ($out)"; fail=1
fi

# === [offer-for-fora] --for cita id fora da thread -> rc 1 sem gravar ===
before="$(wc -l < "$(own_log a repo-a)")"
out="$(LGS a s-x baton offer "$CH" --thread t1 --subject "oferta 2" --for repo-z 2>&1)"; rc=$?
after="$(wc -l < "$(own_log a repo-a)")"
if [ "$rc" -eq 1 ] && [ "$before" = "$after" ] && echo "$out" | grep -q "repo-z"; then
  echo "OK [offer-for-fora]: rc 1 nomeando 'repo-z', nada gravado"
else
  echo "FAIL [offer-for-fora]: esperava rc 1 nomeando repo-z sem gravar, achou rc=$rc before=$before after=$after ($out)"; fail=1
fi

# === [offer-eligible-self] --for só com o próprio -> rc 1 sem gravar ===
before="$(wc -l < "$(own_log a repo-a)")"
out="$(LGS a s-x baton offer "$CH" --thread t1 --subject "oferta 3" --for repo-a 2>&1)"; rc=$?
after="$(wc -l < "$(own_log a repo-a)")"
if [ "$rc" -eq 1 ] && [ "$before" = "$after" ]; then
  echo "OK [offer-eligible-self]: rc 1, nada gravado"
else
  echo "FAIL [offer-eligible-self]: esperava rc 1 sem gravar, achou rc=$rc before=$before after=$after ($out)"; fail=1
fi

# === [offer-max-lease-fora] --max-lease fora de [60, config] -> rc 1 sem gravar ===
before="$(wc -l < "$(own_log a repo-a)")"
out="$(LGS a s-x baton offer "$CH" --thread t1 --subject "oferta 4" --max-lease 99999 2>&1)"; rc=$?
after="$(wc -l < "$(own_log a repo-a)")"
if [ "$rc" -eq 1 ] && [ "$before" = "$after" ]; then
  echo "OK [offer-max-lease-fora]: rc 1, nada gravado"
else
  echo "FAIL [offer-max-lease-fora]: esperava rc 1 sem gravar, achou rc=$rc before=$before after=$after ($out)"; fail=1
fi

# === [claim-concorrencia] 10 claims concorrentes de 10 sessões -> exatamente 1 won ===
out="$(LGS a s-offer2 baton offer "$CH" --thread t1 --subject "concorrencia" 2>&1)"; rc=$?
out="$(judge claim-concorrencia-oferta "$out" "$rc")"
batid2="$(offer_id "$out")"
for i in $(seq 1 10); do
  ( LGS a "sess-$i" baton claim "$CH" "$batid2" >"$T/claim-$i.out" 2>&1; echo $? >"$T/claim-$i.rc" ) &
done
wait
won=0; lost=0; other=0
for i in $(seq 1 10); do
  rc_i="$(cat "$T/claim-$i.rc")"
  case "$rc_i" in 0) won=$((won+1));; 3) lost=$((lost+1));; *) other=$((other+1));; esac
done
seqs="$(node -e '
const fs = require("fs");
const lines = fs.readFileSync(process.argv[1], "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
const claims = lines.filter((m) => m.baton && m.in_reply_to === process.argv[2]);
const seqs = claims.map((m) => Number(m.seq)).sort((a, b) => a - b);
let contig = true;
for (let i = 1; i < seqs.length; i++) if (seqs[i] !== seqs[i - 1] + 1) contig = false;
process.stdout.write(JSON.stringify({ count: claims.length, contig }));
' "$(own_log a repo-a)" "$batid2")"
count_ok="$(printf '%s' "$seqs" | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{const o=JSON.parse(d);process.stdout.write(o.count===10&&o.contig?"1":"0");})')"
if [ "$won" = "1" ] && [ "$lost" = "9" ] && [ "$other" = "0" ] && [ "$count_ok" = "1" ]; then
  echo "OK [claim-concorrencia]: 1 vencedor, 9 lost-held, 10 claims com seq contíguo ($seqs)"
else
  echo "FAIL [claim-concorrencia]: won=$won lost=$lost other=$other seqs=$seqs"; fail=1
fi

# === [claim-pre-condicao] oferta desconhecida / lease fora da faixa / sessão já titular ===
out="$(LGS a s-pc baton claim "$CH" "$CH-nao-existe-0000" 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && echo "$out" | grep -qi "desconhecida" \
  && echo "OK [claim-pre-condicao-oferta]: rc 1 nomeando oferta desconhecida" \
  || { echo "FAIL [claim-pre-condicao-oferta]: rc=$rc out=$out"; fail=1; }

out="$(LGS a s-offer3 baton offer "$CH" --thread t1 --subject "pre-condicao" 2>&1)"
batid3="$(offer_id "$out")"
before="$(wc -l < "$(own_log a repo-a)")"
out="$(LGS a s-pc baton claim "$CH" "$batid3" --lease 5 2>&1)"; rc=$?
after="$(wc -l < "$(own_log a repo-a)")"
if [ "$rc" -eq 1 ] && [ "$before" = "$after" ]; then
  echo "OK [claim-pre-condicao-lease]: --lease fora da faixa, rc 1 sem gravar"
else
  echo "FAIL [claim-pre-condicao-lease]: esperava rc 1 sem gravar, achou rc=$rc before=$before after=$after ($out)"; fail=1
fi

out="$(LGS a s-holder baton claim "$CH" "$batid3" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [claim-pre-condicao-titular]: primeira claim deveria vencer (rc 0), achou rc=$rc ($out)"; fail=1; }
before="$(wc -l < "$(own_log a repo-a)")"
out="$(LGS a s-holder baton claim "$CH" "$batid3" 2>&1)"; rc=$?
after="$(wc -l < "$(own_log a repo-a)")"
if [ "$rc" -eq 0 ] && [ "$before" = "$after" ] && echo "$out" | grep -qi "já detém"; then
  echo "OK [claim-pre-condicao-titular]: sessão já titular com lease vigente, rc 0 sem gravar"
else
  echo "FAIL [claim-pre-condicao-titular]: esperava rc 0 sem gravar, achou rc=$rc before=$before after=$after ($out)"; fail=1
fi

# === [claim-lease-reduzido] sem --lease, config default > max_lease da oferta -> reduz ===
out="$(LGS a s-offer4 baton offer "$CH" --thread t1 --subject "lease reduzido" --max-lease 120 2>&1)"
batid4="$(offer_id "$out")"
out="$(LGS a s-red baton claim "$CH" "$batid4" 2>&1)"; rc=$?
leaseSecs="$(node -e '
const fs = require("fs");
const lines = fs.readFileSync(process.argv[1], "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
const c = lines.find((m) => m.baton && m.baton.op === "claim" && m.in_reply_to === process.argv[2] && m.baton.session === "s-red");
process.stdout.write(String(c ? c.baton.lease_seconds : "none"));
' "$(own_log a repo-a)" "$batid4")"
if [ "$rc" -eq 0 ] && [ "$leaseSecs" = "120" ] && echo "$out" | grep -qi "reduzido"; then
  echo "OK [claim-lease-reduzido]: lease gravado = 120 (max da oferta), aviso de redução presente"
else
  echo "FAIL [claim-lease-reduzido]: esperava lease=120 com aviso, achou lease=$leaseSecs out=$out"; fail=1
fi

# === [claim-lost-held-folga] outra sessão reivindica dentro da folga (skew) -> lost-held ===
out="$(LGS a s-offer5 baton offer "$CH" --thread t1 --subject "folga" 2>&1)"
batid5="$(offer_id "$out")"
LGS a s-holder5 baton claim "$CH" "$batid5" --lease 60 >/dev/null 2>&1
before="$(wc -l < "$(own_log a repo-a)")"
out="$(LGS a s-outro5 baton claim "$CH" "$batid5" 2>&1)"; rc=$?
after="$(wc -l < "$(own_log a repo-a)")"
if [ "$rc" -eq 3 ] && [ "$after" -eq $((before + 1)) ] && echo "$out" | grep -q "lost-held"; then
  echo "OK [claim-lost-held-folga]: dentro da folga, lost-held gravado (rc 3)"
else
  echo "FAIL [claim-lost-held-folga]: esperava rc 3 com lost-held gravado, achou rc=$rc before=$before after=$after ($out)"; fail=1
fi

# === [claim-aviso-sync] tomada por vencimento contra titular de OUTRO repositório ===
# skew_tolerance_seconds reduzido a 1s na config de av_a (quem oferta grava esse valor na
# oferta) para que a janela de espera real do gate seja ~60s (lease mínimo) + 1s, em vez dos
# 14400s/120s default — sem isso o cenário exigiria esperar horas.
mk_repo av_a; mk_repo av_b
sed -i.bak -E '
  s/^  # baton:$/  baton:/
  s/^  #   skew_tolerance_seconds: 120.*$/    skew_tolerance_seconds: 1/
' "$T/av_a/.forge/forge.yaml"
rm -f "$T/av_a/.forge/forge.yaml.bak"
HUBAV="$T/hub-aviso"
LG av_a open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG av_a thread open "$CH" t1 --subject "aviso" --participants repo-a,repo-b --body "abertura" >/dev/null
LG av_a transport set "$CH" --kind fs --path "$HUBAV" >/dev/null
LG av_a sync "$CH" --push-only >/dev/null 2>&1
LG av_b open "$CH" --self repo-b --participants repo-a,repo-b >/dev/null
LG av_b transport set "$CH" --kind fs --path "$HUBAV" >/dev/null
LG av_b sync "$CH" >/dev/null 2>&1

# Ciclo 1: av_b NÃO faz sync --pull-only depois do claim de av_a (pulled_at fica anterior ao
# lease_until da titular) -> aviso presente, e a claim ainda vence (aviso não bloqueia).
outoffer="$(LGS av_a s-offav baton offer "$CH" --thread t1 --subject "titular remota 1" --max-lease 60 2>&1)"
batidav="$(offer_id "$outoffer")"
LG av_a sync "$CH" --push-only >/dev/null 2>&1
LG av_b sync "$CH" >/dev/null 2>&1
LGS av_a s-holdav baton claim "$CH" "$batidav" --lease 60 >/dev/null 2>&1
LG av_a sync "$CH" --push-only >/dev/null 2>&1
# av_b precisa ver a claim de av_a AGORA (para saber que o bastão está held) — mas esta é a
# ÚLTIMA vez que av_b sincroniza antes de tentar a tomada: pulled_at fica datado deste instante,
# ANTERIOR ao lease_until (60s de lease ainda não decorridos), o que é exatamente o cenário
# "sem pull recente" que o aviso cobre.
LG av_b sync "$CH" >/dev/null 2>&1
sleep 63
out="$(LGS av_b s-takeav baton claim "$CH" "$batidav" 2>&1)"; rc=$?
if echo "$out" | grep -qi "rode 'sync'\|rode .sync. antes" && [ "$rc" -eq 0 ]; then
  echo "OK [claim-aviso-sync]: avisou antes de tomar por vencimento sem pull recente, e a tomada venceu (rc=0)"
else
  echo "FAIL [claim-aviso-sync]: esperava aviso + rc 0 (tomada vencida), achou rc=$rc out=$out"; fail=1
fi

# Ciclo 2 (nova oferta/claim, outra titular expirada): av_b faz sync --pull-only ANTES de
# reivindicar, de modo que pulled_at >= lease_until da titular -> aviso ausente.
outoffer2="$(LGS av_a s-offav2 baton offer "$CH" --thread t1 --subject "titular remota 2" --max-lease 60 2>&1)"
batidav2="$(offer_id "$outoffer2")"
LG av_a sync "$CH" --push-only >/dev/null 2>&1
LG av_b sync "$CH" >/dev/null 2>&1
LGS av_a s-holdav2 baton claim "$CH" "$batidav2" --lease 60 >/dev/null 2>&1
LG av_a sync "$CH" --push-only >/dev/null 2>&1
sleep 63
LG av_b sync "$CH" --pull-only >/dev/null 2>&1
out2="$(LGS av_b s-takeav3 baton claim "$CH" "$batidav2" 2>&1)"; rc2=$?
if [ "$rc2" -eq 0 ] && ! echo "$out2" | grep -qi "rode 'sync'\|rode .sync. antes"; then
  echo "OK [claim-aviso-sync-silencio]: com sync --pull-only recente (pulled_at >= lease_until), aviso não aparece"
else
  echo "FAIL [claim-aviso-sync-silencio]: esperava rc 0 sem aviso, achou rc=$rc2 out=$out2"; fail=1
fi

# === [escrita] offer+claim só tocam log/<self>.jsonl, blobs/, CHANNEL.md, cache local ===
mk_repo wscope
LG wscope open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG wscope thread open "$CH" t1 --subject "escrita" --participants repo-a,repo-b --body "x" >/dev/null
snapshot_before="$(find "$T/wscope" -type f | sort)"
outwb="$(LGS wscope s-wb baton offer "$CH" --thread t1 --subject "escrita teste" 2>&1)"
batidwb="$(offer_id "$outwb")"
LGS wscope s-wc baton claim "$CH" "$batidwb" >/dev/null 2>&1
snapshot_after="$(find "$T/wscope" -type f | sort)"
new_files="$(comm -13 <(echo "$snapshot_before") <(echo "$snapshot_after"))"
bad=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  case "$f" in
    */.forge/liaison/"$CH"/log/*.jsonl) ;;
    */.forge/liaison/"$CH"/blobs/*) ;;
    */.forge/liaison/"$CH"/CHANNEL.md) ;;
    */.forge/cache/liaison-baton/"$CH"/*) ;;
    */.forge/cache/liaison-locks/*) ;;
    *) bad=1; echo "FAIL [escrita]: arquivo novo fora do escopo permitido: $f" ;;
  esac
done <<< "$new_files"
[ "$bad" -eq 0 ] && echo "OK [escrita]: todo arquivo novo de offer+claim está no escopo permitido" || fail=1

# === [acks]/[trust] fixture de três repositórios com todas as operações de bastão ===
mk_repo r_a; mk_repo r_b; mk_repo r_c
HUB3="$T/hub3"
LG r_a open "$CH" --self repo-a --participants repo-a,repo-b,repo-c >/dev/null
LG r_a thread open "$CH" t1 --subject "tres repos" --participants repo-a,repo-b,repo-c --body "abertura" >/dev/null
LG r_a transport set "$CH" --kind fs --path "$HUB3" >/dev/null
LG r_a sync "$CH" --push-only >/dev/null 2>&1
LG r_b open "$CH" --self repo-b --participants repo-a,repo-b,repo-c >/dev/null
LG r_b transport set "$CH" --kind fs --path "$HUB3" >/dev/null
LG r_b sync "$CH" >/dev/null 2>&1
LG r_c open "$CH" --self repo-c --participants repo-a,repo-b,repo-c >/dev/null
LG r_c transport set "$CH" --kind fs --path "$HUB3" >/dev/null
LG r_c sync "$CH" >/dev/null 2>&1

out3="$(LGS r_a s-off3 baton offer "$CH" --thread t1 --subject "tres repos tarefa" 2>&1)"
batid3r="$(offer_id "$out3")"
LG r_a sync "$CH" --push-only >/dev/null 2>&1
LG r_b sync "$CH" >/dev/null 2>&1
LGS r_b s-claim3 baton claim "$CH" "$batid3r" >/dev/null 2>&1
LG r_b sync "$CH" --push-only >/dev/null 2>&1
LG r_a sync "$CH" >/dev/null 2>&1
LG r_c sync "$CH" >/dev/null 2>&1

acks_ok=1
for r in r_a r_b r_c; do
  out_ack="$(ACKCHECK "$r" 2>&1)"; rc_ack=$?
  if [ "$rc_ack" -ne 0 ]; then
    echo "FAIL [acks]: check-liaison-acks.sh reprovou em $r: $out_ack"
    acks_ok=0
  fi
done
[ "$acks_ok" -eq 1 ] && echo "OK [acks]: check-liaison-acks.sh sem violação nos três repositórios com operações de bastão"

trust_ok=1
for pair in "r_a:repo-b" "r_a:repo-c" "r_b:repo-a" "r_b:repo-c" "r_c:repo-a" "r_c:repo-b"; do
  repo="${pair%%:*}"; peer="${pair##*:}"
  peer_file="$T/$repo/.forge/liaison/$CH/log/$peer.jsonl"
  [ -f "$peer_file" ] || continue
  bad_trust="$(node -e '
const fs = require("fs");
const lines = fs.readFileSync(process.argv[1], "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
const withBaton = lines.filter((m) => m.baton);
const bad = withBaton.filter((m) => m.trust !== "untrusted-peer" || m.authored_by);
process.stdout.write(String(bad.length));
' "$peer_file")"
  if [ "$bad_trust" != "0" ]; then
    echo "FAIL [trust]: $repo vê mensagens de bastão de $peer com trust/authored_by incorreto ($bad_trust)"
    trust_ok=0
  fi
done
[ "$trust_ok" -eq 1 ] && echo "OK [trust]: mensagens de bastão de peer chegam como untrusted-peer, sem authored_by"

# === [import-sender] sender adulterado numa mensagem de bastão -> conflito no import ===
mk_repo imp_src; mk_repo imp_dst
LG imp_src open "$CH" --self repo-src --participants repo-src,repo-dst >/dev/null
LG imp_src thread open "$CH" t1 --subject "import" --participants repo-src,repo-dst --body "x" >/dev/null
LGS imp_src s-off-imp baton offer "$CH" --thread t1 --subject "import tarefa" >/dev/null 2>&1
mkdir -p "$T/imp-export"
LG imp_src export "$CH" --out "$T/imp-export" >/dev/null 2>&1
# Adultera o sender da mensagem de bastão no arquivo exportado (continua se chamando repo-src.jsonl).
node -e '
const fs = require("fs");
const path = process.argv[1];
const lines = fs.readFileSync(path, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
for (const m of lines) if (m.baton) m.sender = "repo-forjado";
fs.writeFileSync(path, lines.map((m) => JSON.stringify(m)).join("\n") + "\n");
' "$T/imp-export/$CH/log/repo-src.jsonl" 2>/dev/null || true
LG imp_dst open "$CH" --self repo-dst --participants repo-src,repo-dst >/dev/null
out_imp="$(LG imp_dst import "$CH" --from "$T/imp-export" 2>&1)"; rc_imp=$?
if echo "$out_imp" | grep -qi "conflito\|conflict"; then
  echo "OK [import-sender]: sender adulterado em mensagem de bastão -> conflito no import"
else
  echo "FAIL [import-sender]: esperava conflito, achou rc=$rc_imp out=$out_imp"; fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS — baton offer/claim (REQ-02, REQ-03, REQ-11)"
exit 0
