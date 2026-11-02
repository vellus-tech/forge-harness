#!/usr/bin/env bash
# Gate — TASK-21/TASK-22 de add-liaison-handoff-baton (REQ-06, REQ-07, design §2.7):
#   [renew-*] titular com lease vencido não renova (retomada é claim); titular corrente
#     renova; outra sessão (mesmo repositório) é recusada nomeando a titular; sem --lease
#     mantém o lease_seconds vigente; --lease fora da faixa recusa; aviso de sync --push-only
#     quando há participante externo e transporte
#   [release-*] titular libera (available, reivindicável de novo); sessão que não é titular
#     é recusada nomeando a titular; corpo com segredo recusa sem gravar
#   [complete-*] titular conclui (terminal); sessão que não é titular é recusada
#   [withdraw-*] ofertante retira oferta sem titular ou com titular expirada além da folga;
#     titular com lease vigente ou dentro da folga recusa nomeando a titular e o lease_until;
#     quem não é o ofertante é recusado; bastão já terminal é recusado
#   expiração/liberação/conclusão/retirada distinguíveis no histórico (mesma dobra, REQ-04)
set -uo pipefail
# Hermético quanto à sessão: a sessão de um agente (Claude Code) exporta CLAUDE_CODE_SESSION_ID para
# todo processo filho e o runner do CI não tem a variável. Sem este unset o gate passa dentro do
# agente e reprova no CI (ou o inverso); quem precisa de sessão a declara explicitamente.
unset CLAUDE_CODE_SESSION_ID
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-liaison-baton-lifecycle.XXXXXX)"
trap 'rm -rf "$T"' EXIT

fail=0
CH=baton-lifecycle-gate

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
own_log() { printf '%s' "$T/$1/.forge/liaison/$CH/log/$2.jsonl"; }
own_log_lines() { wc -l < "$(own_log "$1" "$2")" 2>/dev/null | tr -d ' '; }

mk_repo a
LG a open "$CH" --self repo-a --participants repo-a,repo-b >/dev/null
LG a thread open "$CH" t1 --subject "lifecycle" --participants repo-a,repo-b --body "abertura" >/dev/null

# === [renew-sem-titular] ninguém reivindicou ainda -> rc 1 nomeando titular 'nenhuma' ===
out="$(LGS a s-off1 baton offer "$CH" --thread t1 --subject "renew-sem-titular" 2>&1)"
bat1="$(offer_id "$out")"
before="$(own_log_lines a repo-a)"
out="$(LGS a s-x baton renew "$CH" "$bat1" 2>&1)"; rc=$?
after="$(own_log_lines a repo-a)"
if [ "$rc" -eq 1 ] && [ "$before" = "$after" ] && echo "$out" | grep -qi "nenhuma"; then
  echo "OK [renew-sem-titular]: rc 1 nomeando titular 'nenhuma', nada gravado"
else
  echo "FAIL [renew-sem-titular]: esperava rc 1 nomeando titular, achou rc=$rc before=$before after=$after ($out)"; fail=1
fi

# === [renew-outra-sessao] renew de sessão diferente da titular -> rc 1 nomeando titular ===
LGS a s-h1 baton claim "$CH" "$bat1" --lease 90 >/dev/null 2>&1
before="$(own_log_lines a repo-a)"
out="$(LGS a s-outra baton renew "$CH" "$bat1" 2>&1)"; rc=$?
after="$(own_log_lines a repo-a)"
if [ "$rc" -eq 1 ] && [ "$before" = "$after" ] && echo "$out" | grep -q "s-h1"; then
  echo "OK [renew-outra-sessao]: rc 1 nomeando a titular s-h1, nada gravado"
else
  echo "FAIL [renew-outra-sessao]: esperava rc 1 nomeando s-h1, achou rc=$rc before=$before after=$after ($out)"; fail=1
fi

# === [renew-mantem-lease] sem --lease, mantém o lease_seconds vigente (90s) ===
out="$(LGS a s-h1 baton renew "$CH" "$bat1" 2>&1)"; rc=$?
renewed_secs="$(node -e '
const fs = require("fs");
const lines = fs.readFileSync(process.argv[1], "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
const rs = lines.filter((m) => m.baton && m.baton.op === "renew" && m.in_reply_to === process.argv[2]);
const last = rs[rs.length - 1];
process.stdout.write(String(last ? last.baton.lease_seconds : "none"));
' "$(own_log a repo-a)" "$bat1")"
if [ "$rc" -eq 0 ] && [ "$renewed_secs" = "90" ]; then
  echo "OK [renew-mantem-lease]: lease_seconds gravado na renovação = 90 (o vigente, sem --lease)"
else
  echo "FAIL [renew-mantem-lease]: esperava lease_seconds=90, achou rc=$rc secs=$renewed_secs ($out)"; fail=1
fi

# === [renew-lease-fora] --lease fora de [60, max_lease_seconds da oferta] -> rc 1 sem gravar ===
before="$(own_log_lines a repo-a)"
out="$(LGS a s-h1 baton renew "$CH" "$bat1" --lease 5 2>&1)"; rc=$?
after="$(own_log_lines a repo-a)"
if [ "$rc" -eq 1 ] && [ "$before" = "$after" ]; then
  echo "OK [renew-lease-fora]: --lease fora da faixa, rc 1 sem gravar"
else
  echo "FAIL [renew-lease-fora]: esperava rc 1 sem gravar, achou rc=$rc before=$before after=$after ($out)"; fail=1
fi

# === [renew-vencido] lease vencido -> renew recusa (retomada é claim); release/complete dela
# continuam válidos (REQ-06) ===
out="$(LGS a s-off2 baton offer "$CH" --thread t1 --subject "renew-vencido" --max-lease 60 2>&1)"
bat2="$(offer_id "$out")"
LGS a s-h2 baton claim "$CH" "$bat2" --lease 60 >/dev/null 2>&1
sleep 2
# ainda não venceu de verdade (lease 60s); simula vencimento criando outra oferta já expirada
# via reivindicação com --lease no mínimo e aguardando — para manter o gate rápido, usamos o
# teste de pré-condição diretamente sobre o estado JÁ held, mas carimbado no futuro não é
# possível pelo CLI (stamped_at é sempre "agora"); portanto este cenário espera o lease mínimo
# de 60s uma única vez (sem repetir em outro bloco).
sleep 59
before="$(own_log_lines a repo-a)"
out="$(LGS a s-h2 baton renew "$CH" "$bat2" 2>&1)"; rc=$?
after="$(own_log_lines a repo-a)"
if [ "$rc" -eq 1 ] && [ "$before" = "$after" ] && echo "$out" | grep -qi "claim"; then
  echo "OK [renew-vencido]: lease vencido, renew recusa sem gravar citando 'baton claim'"
else
  echo "FAIL [renew-vencido]: esperava rc 1 sem gravar citando claim, achou rc=$rc before=$before after=$after ($out)"; fail=1
fi
# release dela continua válido depois de vencido.
out="$(LGS a s-h2 baton release "$CH" "$bat2" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  echo "OK [release-apos-vencimento]: release da titular com lease vencido continua válido"
else
  echo "FAIL [release-apos-vencimento]: esperava rc 0, achou rc=$rc ($out)"; fail=1
fi

# === [release-titular] titular libera -> available, reivindicável de novo (inclusive pela
# mesma sessão) ===
# bat2 foi ofertado com --max-lease 60; usa --lease 60 (não 90, que excederia o máximo).
out="$(LGS a s-h2 baton claim "$CH" "$bat2" --lease 60 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [release-titular]: claim pós-release deveria vencer, rc=$rc ($out)"; fail=1; }
out="$(LGS a s-h2 baton release "$CH" "$bat2" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [release-titular]: release deveria vencer, rc=$rc ($out)"; fail=1; }
out="$(LGS a s-h2 baton claim "$CH" "$bat2" --lease 60 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  echo "OK [release-titular]: depois do release, a MESMA sessão reivindica de novo com sucesso"
else
  echo "FAIL [release-titular]: reivindicação pós-release deveria vencer, rc=$rc ($out)"; fail=1
fi

# === [release-outra-sessao] release de quem não é titular -> rc 1 nomeando titular ===
before="$(own_log_lines a repo-a)"
out="$(LGS a s-outra2 baton release "$CH" "$bat2" 2>&1)"; rc=$?
after="$(own_log_lines a repo-a)"
if [ "$rc" -eq 1 ] && [ "$before" = "$after" ] && echo "$out" | grep -q "s-h2"; then
  echo "OK [release-outra-sessao]: rc 1 nomeando a titular s-h2, nada gravado"
else
  echo "FAIL [release-outra-sessao]: esperava rc 1 nomeando s-h2, achou rc=$rc before=$before after=$after ($out)"; fail=1
fi

# === [release-segredo] corpo com segredo recusa sem gravar ===
before="$(own_log_lines a repo-a)"
# Chave falsa montada em tempo de execução (prefixo + sufixo), como no w166: o literal inteiro
# versionado aqui seria achado pelo w139-secrets-gate. A recusa continua exercitada sobre o valor concatenado.
FAKE_AWS_KEY="AKIA""ABCDEFGHIJKLMNOP"
out="$(LGS a s-h2 baton release "$CH" "$bat2" --body "$FAKE_AWS_KEY" 2>&1)"; rc=$?
after="$(own_log_lines a repo-a)"
if [ "$rc" -ne 0 ] && [ "$before" = "$after" ]; then
  echo "OK [release-segredo]: corpo com segredo recusado sem gravar"
else
  echo "FAIL [release-segredo]: esperava recusa sem gravar, achou rc=$rc before=$before after=$after"; fail=1
fi

# === [complete-titular] titular conclui -> terminal ===
out="$(LGS a s-h2 baton complete "$CH" "$bat2" --body "feito" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  echo "OK [complete-titular]: complete da titular grava, terminal"
else
  echo "FAIL [complete-titular]: esperava rc 0, achou rc=$rc ($out)"; fail=1
fi
# bastão completed não aceita mais claim/renew/release/complete.
out="$(LGS a s-h2 baton claim "$CH" "$bat2" 2>&1)"; rc=$?
if [ "$rc" -eq 3 ] && echo "$out" | grep -qi "closed"; then
  echo "OK [complete-terminal]: claim sobre bastão completed recebe 'closed'"
else
  echo "FAIL [complete-terminal]: esperava rc 3 'closed', achou rc=$rc ($out)"; fail=1
fi

# === [complete-outra-sessao] complete de quem não é titular -> rc 1 nomeando titular ===
out="$(LGS a s-off3 baton offer "$CH" --thread t1 --subject "complete-outra-sessao" 2>&1)"
bat3="$(offer_id "$out")"
LGS a s-h3 baton claim "$CH" "$bat3" --lease 90 >/dev/null 2>&1
before="$(own_log_lines a repo-a)"
out="$(LGS a s-outra3 baton complete "$CH" "$bat3" 2>&1)"; rc=$?
after="$(own_log_lines a repo-a)"
if [ "$rc" -eq 1 ] && [ "$before" = "$after" ] && echo "$out" | grep -q "s-h3"; then
  echo "OK [complete-outra-sessao]: rc 1 nomeando a titular s-h3, nada gravado"
else
  echo "FAIL [complete-outra-sessao]: esperava rc 1 nomeando s-h3, achou rc=$rc before=$before after=$after ($out)"; fail=1
fi

# === [withdraw-available] ofertante retira oferta sem titular -> terminal ===
out="$(LGS a s-off4 baton offer "$CH" --thread t1 --subject "withdraw-available" 2>&1)"
bat4="$(offer_id "$out")"
out="$(LGS a s-off4 baton withdraw "$CH" "$bat4" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  echo "OK [withdraw-available]: ofertante retira oferta sem titular"
else
  echo "FAIL [withdraw-available]: esperava rc 0, achou rc=$rc ($out)"; fail=1
fi

# === [withdraw-held-vigente] titular com lease vigente -> rc 1 nomeando titular e lease_until ===
out="$(LGS a s-off5 baton offer "$CH" --thread t1 --subject "withdraw-held-vigente" 2>&1)"
bat5="$(offer_id "$out")"
LGS a s-h5 baton claim "$CH" "$bat5" --lease 90 >/dev/null 2>&1
before="$(own_log_lines a repo-a)"
out="$(LGS a s-off5 baton withdraw "$CH" "$bat5" 2>&1)"; rc=$?
after="$(own_log_lines a repo-a)"
if [ "$rc" -eq 1 ] && [ "$before" = "$after" ] && echo "$out" | grep -q "s-h5" && echo "$out" | grep -qi "lease_until"; then
  echo "OK [withdraw-held-vigente]: rc 1 nomeando titular s-h5 e lease_until, nada gravado"
else
  echo "FAIL [withdraw-held-vigente]: esperava rc 1 nomeando titular e lease_until, achou rc=$rc before=$before after=$after ($out)"; fail=1
fi

# === [withdraw-nao-ofertante] quem não é o ofertante não pode retirar (dois repositórios reais)
mk_repo off; mk_repo other
HUBWD="$T/hub-withdraw"
LG off open "$CH" --self repo-off --participants repo-off,repo-other >/dev/null
LG off thread open "$CH" t1 --subject "withdraw-nao-ofertante" --participants repo-off,repo-other --body "x" >/dev/null
LG off transport set "$CH" --kind fs --path "$HUBWD" >/dev/null
LG off sync "$CH" --push-only >/dev/null 2>&1
LG other open "$CH" --self repo-other --participants repo-off,repo-other >/dev/null
LG other transport set "$CH" --kind fs --path "$HUBWD" >/dev/null
LG other sync "$CH" >/dev/null 2>&1
outwd="$(LGS off s-off baton offer "$CH" --thread t1 --subject "tarefa cross" 2>&1)"
batwd="$(offer_id "$outwd")"
LG off sync "$CH" --push-only >/dev/null 2>&1
LG other sync "$CH" >/dev/null 2>&1
out="$(LGS other s-other baton withdraw "$CH" "$batwd" 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && echo "$out" | grep -q "repo-off"; then
  echo "OK [withdraw-nao-ofertante]: rc 1 nomeando o ofertante repo-off"
else
  echo "FAIL [withdraw-nao-ofertante]: esperava rc 1 nomeando repo-off, achou rc=$rc out=$out"; fail=1
fi

# === [withdraw-expirado-folga] titular expirada além da folga -> ofertante retira ===
# skew_tolerance_seconds reduzido a 1s na config ANTES da oferta (a oferta grava o valor da
# config no momento em que roda — editar depois não afetaria esta oferta, só as próximas).
sed -i.bak -E '
  s/^  # baton:$/  baton:/
  s/^  #   skew_tolerance_seconds: 120.*$/    skew_tolerance_seconds: 1/
' "$T/a/.forge/forge.yaml"
rm -f "$T/a/.forge/forge.yaml.bak"
out="$(LGS a s-off6 baton offer "$CH" --thread t1 --subject "withdraw-expirado-folga" --max-lease 60 2>&1)"
bat6="$(offer_id "$out")"
LGS a s-h6 baton claim "$CH" "$bat6" --lease 60 >/dev/null 2>&1
sleep 62
out="$(LGS a s-off6 baton withdraw "$CH" "$bat6" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  echo "OK [withdraw-expirado-folga]: titular expirada além da folga, ofertante retira"
else
  echo "FAIL [withdraw-expirado-folga]: esperava rc 0, achou rc=$rc ($out)"; fail=1
fi

# === [renew-aviso-sync] depois de renew manual, com participante externo e transporte, a
# saída imprime 'sync --push-only' ===
out="$(LGS off s-off2 baton offer "$CH" --thread t1 --subject "aviso sync" 2>&1)"
batsync="$(offer_id "$out")"
LG off sync "$CH" --push-only >/dev/null 2>&1
LGS off s-hsync baton claim "$CH" "$batsync" --lease 90 >/dev/null 2>&1
out="$(LGS off s-hsync baton renew "$CH" "$batsync" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -q "sync $CH --push-only"; then
  echo "OK [renew-aviso-sync]: saída imprime o comando sync --push-only (participante externo + transporte)"
else
  echo "FAIL [renew-aviso-sync]: esperava dica de sync --push-only, achou rc=$rc out=$out"; fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS — baton renew/release/complete/withdraw (REQ-06, REQ-07)"
exit 0
