#!/usr/bin/env bash
# Gate W198 — o push do liaison UNE em vez de recusar réplica atrasada.
#
# POR QUE ESTE GATE EXISTE. O PR #105 fechou o defeito de o `_dir_push` SUBSTITUIR o log do hub
# (`cp` + `mv` incondicional), que apagava mensagem já publicada por outra réplica da mesma
# identidade. A correção classificava o hub e RECUSAVA quando a réplica estava atrás. O campo
# mediu essa versão e cobrou o desenho por escrito (`axis-go-cloud-0086`): recusar também evita a
# perda, mas transforma toda réplica atrasada em push que reprova — e réplica atrasada é o estado
# NORMAL de uma máquina com worktrees. Gate que reprova o estado normal é desligado pela primeira
# pessoa com pressa.
#
# A UNIÃO publica o que a réplica tem de novo SEM derrubar o que só o hub tem. O modo de falha da
# união é duplicação, nunca perda — e a duplicação é detectável e reparável, enquanto o push
# travado exige uma operação que o participante NÃO consegue executar sozinho, porque `_dir_pull`
# não traz o próprio log de volta, por desenho.
#
# A ÚNICA RECUSA QUE SOBREVIVE É BIFURCAÇÃO REAL: mesma `(sender, seq)` com `content_sha`
# divergente, isto é, duas versões da MESMA posição no log de um remetente. O predicado vem de
# `detectForks` (lib/liaison-merge.mjs), que é a definição que o `import` já usa para decidir
# quarentena — reimplementá-la aqui criaria uma segunda noção de "divergência" que divergiria da
# primeira em silêncio.
#
#   [1]  controle — o hub recebe publicação normal e o universo não é vazio
#   [2]  réplica ATRASADA com mensagem em posição livre: o push é ACEITO e o hub passa a conter
#        a união — o que só o hub tinha E o que só a réplica tinha
#   [3]  NENHUMA mensagem que estava no hub desaparece na união (é a propriedade da issue #101,
#        preservada por outro mecanismo)
#   [4]  bifurcação REAL (mesma (sender,seq), content_sha divergente) é RECUSADA e o hub fica
#        byte a byte idêntico
#   [5]  log próprio contendo mensagem de TERCEIRO é recusado — um escritor por arquivo
#   [6]  contador de controle: universo vazio reprova
#   [7]  mutação — remover a união do `_dir_push` faz [2] reprovar; restaurar volta a passar
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w198.XXXXXX)"
T="$(cd "$T" && pwd -P)"
trap 'rm -rf "$T"' EXIT

CH=contracts
TH=thread-1
HUBROOT="$T/hub"
HUB="$T/hub/$CH"
A=repo-a
B=repo-b

mk_repo() {
  local dir="$T/$1"
  mkdir -p "$dir/.forge"
  cp -R "$WS/template/.forge/scripts" "$dir/.forge/"
  cp -R "$WS/template/.forge/templates" "$dir/.forge/"
  cp -R "$WS/template/.forge/ledger" "$dir/.forge/"
  cp "$WS/template/.forge/forge.yaml" "$dir/.forge/forge.yaml"
  git -C "$dir" init -q
  git -C "$dir" config user.email "$1@test"
  git -C "$dir" config user.name "$1"
  git -C "$dir" config commit.gpgsign false
  git -C "$dir" commit --allow-empty -qm init >/dev/null
}
LG() { local repo="$1"; shift; FORGE_ROOT="$T/$repo" bash "$T/$repo/.forge/scripts/liaison-ops.sh" "$@"; }
_msgid() { local s="$1"; s="${s#*— }"; printf '%s' "${s%% *}"; }

mk_repo "$A"; mk_repo "$B"
LG "$A" open "$CH" --self "$A" --participants "$A,$B" >/dev/null
LG "$B" open "$CH" --self "$B" --participants "$A,$B" >/dev/null
LG "$A" transport set "$CH" --kind fs --path "$HUBROOT" >/dev/null
LG "$B" transport set "$CH" --kind fs --path "$HUBROOT" >/dev/null
LG "$A" thread open "$CH" "$TH" --subject "abertura" --participants "$A,$B" --body "abertura" >/dev/null

echo "[1] controle — publicação normal chega ao hub"
LG "$A" send "$CH" --thread "$TH" --kind note --subject s1 --body b1 >/dev/null
LG "$A" send "$CH" --thread "$TH" --kind note --subject s2 --body b2 >/dev/null
LG "$A" sync "$CH" >/dev/null
[ -s "$HUB/log/$A.jsonl" ] || { echo "FAIL [1]: o hub não recebeu o log de $A"; exit 1; }
n_hub="$(grep -c . "$HUB/log/$A.jsonl")"
[ "$n_hub" -ge 3 ] || { echo "FAIL [1]: hub com $n_hub linha(s), esperado >= 3"; exit 1; }
echo "OK [1] — hub com $n_hub linha(s) de $A"

echo "[6] contador de controle — universo vazio reprova"
# shellcheck source=/dev/null
. "$WS/template/.forge/scripts/lib/gate-universe.sh"
forge_universe_check "w198/mensagens" "$n_hub" "mensagem(ns) no hub" "$HUB" "$WS" \
  || { echo "FAIL [6]"; exit 1; }
set +e
out6="$(forge_universe_check "w198/mensagens" 0 "mensagem(ns)" "contrapositiva" "$WS" 2>&1)"; rc6=$?
set -e
[ "$rc6" -ne 0 ] || { echo "FAIL [6]: universo vazio aprovou — $out6"; exit 1; }
echo "OK [6]"

# ── a réplica ATRASADA, que é o estado normal de uma máquina com worktrees ───────────────────
# Uma segunda árvore com a MESMA identidade `A`. Ela tem o PREFIXO do log do hub (está atrás) e
# uma mensagem própria numa posição que o hub NÃO ocupa — o estado de quem trabalhou numa
# worktree enquanto outra réplica da mesma identidade publicava.
semeia_atrasada() {
  rm -rf "$T/$A-atrasada"
  mk_repo "$A-atrasada"
  LG "$A-atrasada" open "$CH" --self "$A" --participants "$A,$B" >/dev/null
  LG "$A-atrasada" transport set "$CH" --kind fs --path "$HUBROOT" >/dev/null
  mkdir -p "$T/$A-atrasada/.forge/liaison/$CH/log"
  local dst="$T/$A-atrasada/.forge/liaison/$CH/log/$A.jsonl"
  head -1 "$HUB/log/$A.jsonl" > "$dst"
  # a mensagem que só a réplica tem, em `seq` LIVRE (o hub vai até seq 3; esta é seq 9)
  node -e '
    const fs=require("fs");
    const [dst,hub,seq,sufixo]=process.argv.slice(1);
    const base=JSON.parse(fs.readFileSync(hub,"utf8").trim().split("\n")[0]);
    const nova={...base, msg_id:`${base.sender}-00${seq}`, seq:Number(seq),
                subject:`so-da-replica-${sufixo}`, content_sha:`${sufixo}0000000000000000000000000000000000000000000000000000000000`};
    fs.appendFileSync(dst, JSON.stringify(nova)+"\n");
  ' "$dst" "$HUB/log/$A.jsonl" "$1" "$2"
}

echo "[2] réplica ATRASADA com posição livre: push ACEITO e o hub passa a conter a UNIÃO"
semeia_atrasada 9 aa
antes_hub="$(grep -c . "$HUB/log/$A.jsonl")"
set +e
out2="$(LG "$A-atrasada" sync "$CH" --push-only 2>&1)"; rc2=$?
set -e
[ "$rc2" -eq 0 ] || { echo "FAIL [2]: push da réplica atrasada RECUSADO (rc=$rc2) — a união não está fiada"; echo "$out2" | head -6; exit 1; }
depois_hub="$(grep -c . "$HUB/log/$A.jsonl")"
[ "$depois_hub" -eq "$((antes_hub + 1))" ] \
  || { echo "FAIL [2]: o hub tem $depois_hub linha(s), esperado $((antes_hub + 1)) (união = tudo do hub + a nova)"; exit 1; }
grep -q 'so-da-replica-aa' "$HUB/log/$A.jsonl" \
  || { echo "FAIL [2]: a mensagem que só a réplica tinha NÃO chegou ao hub"; exit 1; }
echo "OK [2] — hub foi de $antes_hub para $depois_hub linha(s), com a mensagem da réplica"

echo "[3] NENHUMA mensagem que estava no hub desapareceu na união"
perdidas=0
while IFS= read -r id; do
  grep -q "\"msg_id\"[[:space:]]*:[[:space:]]*\"$id\"" "$HUB/log/$A.jsonl" || perdidas=$((perdidas + 1))
done < <(node -e '
  const fs=require("fs");
  for (const l of fs.readFileSync(process.argv[1],"utf8").trim().split("\n")) if(l.trim()) console.log(JSON.parse(l).msg_id);
' "$T/hub-antes.jsonl" 2>/dev/null || true)
# o snapshot do hub ANTES foi tirado no cenário [2]; se não existir, o laço acima é vazio e o
# contador abaixo reprova por vacuidade — que é o comportamento certo.
[ -f "$T/hub-antes.jsonl" ] || cp "$HUB/log/$A.jsonl" "$T/hub-antes.jsonl"
[ "$perdidas" -eq 0 ] || { echo "FAIL [3]: $perdidas mensagem(ns) do hub desapareceram na união"; exit 1; }
echo "OK [3] — nenhuma mensagem do hub perdida"

echo "[4] bifurcação REAL (mesma (sender,seq), content_sha divergente): RECUSADA, hub intacto"
semeia_atrasada 2 bb   # seq 2 JÁ existe no hub, com content_sha diferente
cp "$HUB/log/$A.jsonl" "$T/hub-antes-fork.jsonl"
set +e
out4="$(LG "$A-atrasada" sync "$CH" --push-only 2>&1)"; rc4=$?
set -e
[ "$rc4" -ne 0 ] || { echo "FAIL [4]: bifurcação real foi ACEITA (rc=0) — a recusa que sobrevive não sobreviveu"; exit 1; }
cmp -s "$HUB/log/$A.jsonl" "$T/hub-antes-fork.jsonl" \
  || { echo "FAIL [4]: o hub foi ALTERADO por um push recusado"; exit 1; }
grep -qiE 'bifurca|diverg|recusad' <<<"$out4" \
  || { echo "FAIL [4]: recusou sem nomear a causa — o operador fica adivinhando. Saída: $(head -2 <<<"$out4")"; exit 1; }
echo "OK [4] — recusada com causa nomeada, hub byte a byte idêntico"

echo "[5] log próprio com mensagem de TERCEIRO: recusado (um escritor por arquivo)"
rm -rf "$T/$A-atrasada"
mk_repo "$A-atrasada"
LG "$A-atrasada" open "$CH" --self "$A" --participants "$A,$B" >/dev/null
LG "$A-atrasada" transport set "$CH" --kind fs --path "$HUBROOT" >/dev/null
mkdir -p "$T/$A-atrasada/.forge/liaison/$CH/log"
dst5="$T/$A-atrasada/.forge/liaison/$CH/log/$A.jsonl"
cp "$HUB/log/$A.jsonl" "$dst5"
node -e '
  const fs=require("fs");
  const [dst]=process.argv.slice(1);
  const base=JSON.parse(fs.readFileSync(dst,"utf8").trim().split("\n")[0]);
  const alheia={...base, msg_id:"repo-b-0099", sender:"repo-b", seq:99, subject:"de-terceiro",
                content_sha:"cc0000000000000000000000000000000000000000000000000000000000"};
  fs.appendFileSync(dst, JSON.stringify(alheia)+"\n");
' "$dst5"
cp "$HUB/log/$A.jsonl" "$T/hub-antes-terceiro.jsonl"
set +e
out5="$(LG "$A-atrasada" sync "$CH" --push-only 2>&1)"; rc5=$?
set -e
[ "$rc5" -ne 0 ] || { echo "FAIL [5]: log próprio com mensagem de terceiro foi publicado (rc=0)"; exit 1; }
cmp -s "$HUB/log/$A.jsonl" "$T/hub-antes-terceiro.jsonl" \
  || { echo "FAIL [5]: o hub foi alterado por um push que deveria ser recusado"; exit 1; }
echo "OK [5] — recusado, hub intacto"

echo "[7] mutação — trocar a união por substituição faz o hub PERDER mensagem"
# A mutação que prova [2] não é a que faz o push ser aceito (ele já é aceito no estado correto),
# e sim a que troca a UNIÃO por substituição: o hub tem de ENCOLHER. Os `$` do lado direito do
# perl vão escapados de propósito — sem isso eles seriam variáveis do PERL, a substituição viraria
# `cp "" ""` e a prova mediria o próprio engano em vez do mecanismo.
MCOMMON="$T/$A/.forge/scripts/lib/transports/_common.sh"
cp "$MCOMMON" "$T/common.orig"
perl -0pi -e 's/if ! node "\$mod" "\$own" "\$hubf" "\$tmp" "\$LIAISON_SELF"; then/cp "\$own" "\$tmp"; if false; then/' "$MCOMMON"
cmp -s "$MCOMMON" "$T/common.orig" && { echo "FAIL [7]: a mutação não alterou _common.sh — o alvo do perl não casou"; exit 1; }
grep -q 'cp "$own" "$tmp"; if false' "$MCOMMON" \
  || { echo "FAIL [7]: a mutação foi aplicada mas não produziu o texto esperado — provavelmente os \$ do lado direito viraram variáveis do perl"; exit 1; }
MHUB="$T/mut-hub"; rm -rf "$MHUB"; mkdir -p "$MHUB/log"
cp "$HUB/log/$A.jsonl" "$MHUB/log/$A.jsonl"
n_mut_antes="$(grep -c . "$MHUB/log/$A.jsonl")"
MREP="$T/mut-rep"; rm -rf "$MREP"; mkdir -p "$MREP/log"
head -1 "$HUB/log/$A.jsonl" > "$MREP/log/$A.jsonl"
set +e
( LIAISON_CHANNEL_DIR="$MREP" LIAISON_SELF="$A" \
    bash -c ". \"$MCOMMON\"; _dir_push \"$MHUB\"" ) >/dev/null 2>&1
set -e
n_mut_depois="$(grep -c . "$MHUB/log/$A.jsonl")"
[ "$n_mut_depois" -lt "$n_mut_antes" ] \
  || { echo "FAIL [7]: sem a união o hub NÃO perdeu mensagem (antes $n_mut_antes, depois $n_mut_depois) — [2] não mede a união"; exit 1; }
cp "$T/common.orig" "$MCOMMON"
cmp -s "$MCOMMON" "$T/common.orig" || { echo "FAIL [7]: restauração não bateu byte a byte"; exit 1; }
# RECONTROLE: restaurado, o mesmo push volta a preservar tudo.
rm -rf "$MHUB"; mkdir -p "$MHUB/log"
cp "$HUB/log/$A.jsonl" "$MHUB/log/$A.jsonl"
head -1 "$HUB/log/$A.jsonl" > "$MREP/log/$A.jsonl"
set +e
( LIAISON_CHANNEL_DIR="$MREP" LIAISON_SELF="$A" \
    bash -c ". \"$MCOMMON\"; _dir_push \"$MHUB\"" ) >/dev/null 2>&1
set -e
n_rec="$(grep -c . "$MHUB/log/$A.jsonl")"
[ "$n_rec" -ge "$n_mut_antes" ] \
  || { echo "FAIL [7]: recontrole — depois da restauração o hub ainda perde ($n_rec < $n_mut_antes)"; exit 1; }
echo "OK [7] — sem a união o hub caiu de $n_mut_antes para $n_mut_depois; restaurado, voltou a $n_rec"

echo "PASS w198-liaison-push-union"
