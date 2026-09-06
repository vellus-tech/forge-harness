#!/usr/bin/env bash
# Gate W195 — monotonicidade no liaison (issues #101 e #102).
#
# Estrutura append-only operada por um caminho de escrita que pode REGREDI-LA (o push substitui o
# log do hub) ou deixar de AVANÇÁ-LA (o ack não move o cursor). Uma fixture serve aos dois: um hub
# de diretório e duas réplicas.
#
#   #101 — `lib/transports/_common.sh::_dir_push` publicava o log próprio no hub com `cp` + `mv`
#          INCONDICIONAL, sem união: uma réplica atrasada substitui o log do hub pelo seu, com
#          rc 0 e sem aviso, apagando mensagens que só existiam lá — num log append-only, de onde
#          não há como restaurar.
#   #102 — `ack)` lia `cursors[id]` para exibir e não escrevia cursor nenhum: o ato mais forte de
#          leitura que o protocolo tem não marcava a thread como lida. No TEMPLATE (medido) há UMA
#          escrita de cursor em todo o arquivo, dentro de `read)`, e assim é nos nove commits do
#          histórico — então `read --upto` era o ÚNICO caminho pelo qual um cursor avançava, e
#          toda mensagem ackada permanecia não lida a menos que alguém rodasse um segundo comando.
#
#   [1]  A publica, B publica, A publica de novo: o hub contém as mensagens das duas (controle)
#   [2]  duas árvores com a MESMA identidade, uma atrasada: o push da atrasada é ACEITO por UNIÃO
#        e NENHUMA mensagem que estava no hub desaparece (a propriedade da #101; o mecanismo
#        passou de recusa para união depois da medição de campo em `axis-go-cloud-0086`)
#   [2b] divergência em posição CONHECIDA (mesmo msg_id, content_sha diferente) é recusada sem
#        reparo explícito, e a mensagem NOMEIA o caminho de reparo
#   [2c] a mesma divergência COM o reparo explícito é aceita, e o hub passa a ser o log local
#   [2d] réplica ATRASADA sob o reparo explícito não faz o hub perder mensagem — o reparo não é
#        um `--force` universal, e a propriedade da issue #101 não é negociável
#   [3]  a mesma árvore atrasada, depois de um sync que a põe em dia: o push é aceito e o hub avança
#   [4]  propriedade (união): para QUALQUER par de prefixos (hub, local) o push tem êxito — unir
#        prefixos nunca é ambíguo — e NENHUMA mensagem que estava no hub desaparece
#   [4b] contorno da propriedade: log do hub PRESENTE e VAZIO é prefixo de qualquer log — o push
#        é aceito e o hub passa a ser o local
#   [5]  `ack` de mensagem de terceiro avança o cursor da thread até ela
#   [6]  `ack` de mensagem ANTERIOR ao cursor não faz o cursor regredir, e a operação não falha —
#        pareado com o valor do cursor LIDO do state.json e comparado com o índice esperado
#   [7]  depois de [5], a contagem de não-lidas naquela thread é zero
#   [8]  propriedade (monotonicidade): para qualquer sequência de `ack` e `read --upto`, o índice
#        do cursor é não-decrescente — e o índice FINAL é o máximo pedido, não só "não regrediu"
#   [9]  `ack` da própria mensagem não marca como lida a mensagem POSTERIOR de terceiro
#   [10] contador de controle: fixture com zero mensagem reprova o cenário
#   [11] mutação: remover a guarda de não-regressão faz [6]/[8] reprovarem; remover a união faz
#        [2] reprovar; restaurar volta a passar, com cmp do lib
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w195.XXXXXX)"
T="$(cd "$T" && pwd -P)"
trap 'rm -rf "$T"' EXIT

CH=contracts
TH=thread-1
HUBROOT="$T/hub"
HUB="$T/hub/$CH"   # o transporte fs monta o ponto de encontro sob <path>/<canal>/
A=repo-a
B=repo-b

mk_repo() { # mk_repo <dir-name>
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

echo "[1] A publica, B publica, A publica de novo: o hub contém as duas (controle)"
M1="$(_msgid "$(LG "$A" send "$CH" --thread "$TH" --kind note --subject s1 --body b1)")"
LG "$A" sync "$CH" >/dev/null
LG "$B" sync "$CH" >/dev/null
M2="$(_msgid "$(LG "$B" send "$CH" --thread "$TH" --kind note --subject s2 --body b2)")"
LG "$B" sync "$CH" >/dev/null
LG "$A" sync "$CH" >/dev/null
M3="$(_msgid "$(LG "$A" send "$CH" --thread "$TH" --kind note --subject s3 --body b3)")"
LG "$A" sync "$CH" >/dev/null
[ -f "$HUB/log/$A.jsonl" ] && [ -f "$HUB/log/$B.jsonl" ] \
  || { echo "FAIL [1]: o hub não tem os logs das duas identidades"; ls -R "$HUB"; exit 1; }
n_hub_a="$(grep -c . "$HUB/log/$A.jsonl")"
n_hub_b="$(grep -c . "$HUB/log/$B.jsonl")"
[ "$n_hub_a" -ge 3 ] && [ "$n_hub_b" -ge 1 ] \
  || { echo "FAIL [1]: contagem no hub inesperada (A=$n_hub_a, B=$n_hub_b)"; exit 1; }
echo "OK [1] — hub com A=$n_hub_a e B=$n_hub_b linha(s)"

echo "[10] contador de controle — fixture com zero mensagem reprova o cenário"
[ "$n_hub_a" -gt 0 ] || { echo "FAIL [10]: universo de mensagens VAZIO — os cenários abaixo aprovariam por vacuidade"; exit 1; }
# shellcheck source=/dev/null
. "$WS/template/.forge/scripts/lib/gate-universe.sh"
forge_universe_check "w195/mensagens" "$((n_hub_a + n_hub_b))" "mensagem(ns) no hub" "$HUB" "$WS" \
  || { echo "FAIL [10]"; exit 1; }
# `x="$(cmd)"` com cmd falhando dispara o errexit ANTES do `$?` ser lido — a atribuição é o
# comando que falha. Sob `set -e` a contrapositiva precisa do `set +e` explícito.
set +e
out10="$(forge_universe_check "w195/mensagens" 0 "mensagem(ns)" "contrapositiva" "$WS" 2>&1)"; rc10=$?
set -e
[ "$rc10" -ne 0 ] || { echo "FAIL [10]: universo vazio aprovou — $out10"; exit 1; }
echo "OK [10]"

# ── #101: fast-forward ou recusa ─────────────────────────────────────────────────────────────
# Uma segunda árvore com a MESMA identidade `A` — é o caso real: dois clones do mesmo repositório,
# ou tronco e worktree, cada um com sua réplica do canal.
mk_repo "$A-atrasada"
LG "$A-atrasada" open "$CH" --self "$A" --participants "$A,$B" >/dev/null
LG "$A-atrasada" transport set "$CH" --kind fs --path "$HUBROOT" >/dev/null
# Semeia a atrasada com o log de A ATÉ a primeira mensagem (prefixo próprio do hub).
mkdir -p "$T/$A-atrasada/.forge/liaison/$CH/log"
head -2 "$HUB/log/$A.jsonl" > "$T/$A-atrasada/.forge/liaison/$CH/log/$A.jsonl"

echo "[2] réplica ATRASADA: push ACEITO por UNIÃO e NENHUMA mensagem do hub perdida"
# A propriedade da issue #101 é NÃO PERDER MENSAGEM; a recusa era o mecanismo, e foi trocada pela
# união depois que o campo mediu que recusar trava o estado normal de uma máquina com worktrees
# (axis-go-cloud-0086). O que este cenário afirma é a propriedade, não o mecanismo — por isso ele
# conta as mensagens do hub ANTES e exige que TODAS continuem lá DEPOIS, em vez de exigir rc != 0.
cp "$HUB/log/$A.jsonl" "$T/hub-antes.jsonl"
set +e
out2="$(LG "$A-atrasada" sync "$CH" 2>&1)"; rc2=$?
set -e
[ "$rc2" -eq 0 ] || { echo "FAIL [2]: o push da réplica atrasada foi RECUSADO (rc $rc2) — a união não está fiada. Saída: $out2"; exit 1; }
perdidas2=0
while IFS= read -r id2; do
  [ -n "$id2" ] || continue
  grep -q "\"msg_id\"[[:space:]]*:[[:space:]]*\"$id2\"" "$HUB/log/$A.jsonl" || perdidas2=$((perdidas2 + 1))
done < <(node -e 'const fs=require("fs");for(const l of fs.readFileSync(process.argv[1],"utf8").trim().split("\n"))if(l.trim())console.log(JSON.parse(l).msg_id)' "$T/hub-antes.jsonl")
[ "$perdidas2" -eq 0 ] \
  || { echo "FAIL [2]: $perdidas2 mensagem(ns) que estavam no hub sumiram na união — é exatamente a perda que a issue #101 fechou"; exit 1; }
n_antes2="$(grep -c . "$T/hub-antes.jsonl")"
n_depois2="$(grep -c . "$HUB/log/$A.jsonl")"
[ "$n_depois2" -ge "$n_antes2" ] \
  || { echo "FAIL [2]: o hub ENCOLHEU de $n_antes2 para $n_depois2 linha(s)"; exit 1; }
echo "OK [2] — união aceita, hub de $n_antes2 para $n_depois2 linha(s), zero perdida"

# ── divergência em posição conhecida × réplica atrasada: dois casos, remédios OPOSTOS ────────
# O predicado de PREFIXO ESTRITO não os separava, e recusava os dois. Eles não são o mesmo fato:
#
#   ATRASADA  — o hub tem um msg_id que esta réplica NÃO tem. Publicar apaga uma mensagem que só
#               existe lá. É a issue #101, e recusar é a única saída.
#   DIVERGIDA — o hub tem uma linha DIFERENTE num msg_id que esta réplica TAMBÉM tem.
#
# O segundo caso é ambíguo POR CONSTRUÇÃO, e a ambiguidade é medível: ou um terceiro reescreveu a
# história (e o dono é a única autoridade sobre `log/<self>.jsonl` — republicar REPARA), ou duas
# réplicas da mesma identidade compuseram mensagens DIFERENTES no mesmo `seq` (e republicar
# DESTRÓI a da outra). As duas situações produzem exatamente o mesmo par de logs; nada nos dados
# as distingue. Por isso o default é recusar, e existe um ato EXPLÍCITO do dono para reparar.
# Reescreve a mensagem daquele seq no hub com conteúdo diferente E content_sha RECOMPUTADO — a
# mesma tampering de w111[8]. Recomputar importa: sem isso o par (msg_id, content_sha) fica
# idêntico e não há divergência nenhuma a detectar; e é assim que a divergência REAL se apresenta
# nos dois casos que a classificação separa (terceiro reescrevendo com envelope válido, e outra
# réplica compondo mensagem distinta no mesmo seq — que nasce com sha próprio por construção).
_tamper_hub_seq() { # _tamper_hub_seq <arquivo-de-log> <seq>
  node - "$WS/template/.forge/scripts/lib" "$1" "$2" <<'NODEEOF'
const { readFileSync, writeFileSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, file, seq] = process.argv;
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const msgs = readFileSync(file, 'utf8').trim().split('\n').map((l) => JSON.parse(l));
  const i = msgs.findIndex((m) => String(m.seq) === String(seq));
  if (i < 0) { console.error('seq ' + seq + ' não encontrado'); process.exit(1); }
  const { content_sha, trust, ...rest } = msgs[i];
  const tampered = { ...rest, subject: 'HISTÓRIA REESCRITA POR TERCEIRO', trust: 'self' };
  tampered.content_sha = M.computeContentSha(tampered);
  msgs[i] = tampered;
  writeFileSync(file, msgs.map((m) => JSON.stringify(m)).join('\n') + '\n');
})();
NODEEOF
}
_push_as() { # _push_as <dir-replica> <hub> [repair] -> rc do _dir_push, saída em $T/push.txt
  local rep="$1" hub="$2" repair="${3:-}" rc=0
  ( LIAISON_CHANNEL_DIR="$rep/.forge/liaison/$CH" LIAISON_SELF="$A" \
      LIAISON_PUSH_REPAIR="$([ "$repair" = repair ] && echo 1 || echo 0)" \
      bash -c '. "'"$WS"'/template/.forge/scripts/lib/transports/_common.sh"; _dir_push "'"$hub"'"' \
  ) > "$T/push.txt" 2>&1 || rc=$?
  return $rc
}

echo "[2b] divergência em posição conhecida é RECUSADA sem reparo, e a mensagem nomeia o reparo"
DIV="$T/div"; rm -rf "$DIV"; mkdir -p "$DIV/hub/log" "$DIV/rep/.forge/liaison/$CH/log"
cp "$HUB/log/$A.jsonl" "$DIV/hub/log/$A.jsonl"
cp "$HUB/log/$A.jsonl" "$DIV/rep/.forge/liaison/$CH/log/$A.jsonl"
_tamper_hub_seq "$DIV/hub/log/$A.jsonl" 1
cp "$DIV/hub/log/$A.jsonl" "$T/div-hub-antes.jsonl"
rc2b=0; _push_as "$DIV/rep" "$DIV/hub" || rc2b=$?
[ "$rc2b" -ne 0 ] || { echo "FAIL [2b]: divergência publicada sem ato explícito do dono — indistinguível de duas réplicas colidindo no mesmo seq, onde republicar DESTRÓI a mensagem da outra. Saída: $(cat "$T/push.txt")"; exit 1; }
cmp -s "$DIV/hub/log/$A.jsonl" "$T/div-hub-antes.jsonl" || { echo "FAIL [2b]: o hub foi alterado por um push recusado"; exit 1; }
grep -qi "repair-own-log" "$T/push.txt" \
  || { echo "FAIL [2b]: a recusa não nomeia o caminho de reparo. As duas saídas antigas ('sync na árvore em dia', 'traga o log do hub') são ERRADAS para história reescrita — não há como reparar por elas, e o operador fica sem caminho. Saída: $(cat "$T/push.txt")"; exit 1; }
grep -qi "diverg" "$T/push.txt" \
  || { echo "FAIL [2b]: a recusa não distingue divergência de réplica atrasada — os dois casos têm remédios opostos. Saída: $(cat "$T/push.txt")"; exit 1; }
echo "OK [2b] — $(grep -i 'RECUSADO' "$T/push.txt" | head -1)"

echo "[2c] a mesma divergência COM reparo explícito é aceita, e o hub passa a ser o log local"
rc2c=0; _push_as "$DIV/rep" "$DIV/hub" repair || rc2c=$?
[ "$rc2c" -eq 0 ] || { echo "FAIL [2c]: o reparo explícito do dono foi recusado — sem ele não há caminho pelo comando para desfazer história reescrita por terceiro. Saída: $(cat "$T/push.txt")"; exit 1; }
# Sinal POSITIVO pareado: não basta o rc 0 — o hub tem de ter passado a ser o log local.
cmp -s "$DIV/hub/log/$A.jsonl" "$DIV/rep/.forge/liaison/$CH/log/$A.jsonl" \
  || { echo "FAIL [2c]: reparo aceito (rc 0) e o hub NÃO recebeu o log local — aceitar sem publicar é pior que recusar"; exit 1; }
grep -qi "descartando\|descartad" "$T/push.txt" \
  || { echo "FAIL [2c]: o reparo não DECLARA o que descartou. Reparo silencioso é indistinguível da sobrescrita que a issue #101 fechou. Saída: $(cat "$T/push.txt")"; exit 1; }
echo "OK [2c] — $(grep -i 'descart' "$T/push.txt" | head -1)"

echo "[2d] réplica ATRASADA com reparo explícito continua RECUSADA — o reparo não é --force"
ATR="$T/atrasada-repair"; rm -rf "$ATR"; mkdir -p "$ATR/hub/log" "$ATR/rep/.forge/liaison/$CH/log"
cp "$HUB/log/$A.jsonl" "$ATR/hub/log/$A.jsonl"
head -2 "$HUB/log/$A.jsonl" > "$ATR/rep/.forge/liaison/$CH/log/$A.jsonl"
cp "$ATR/hub/log/$A.jsonl" "$T/atr-hub-antes.jsonl"
rc2d=0; _push_as "$ATR/rep" "$ATR/hub" repair || rc2d=$?
# Com a união no lugar da recusa, a réplica atrasada nem alcança o caminho de reparo: ela é
# resolvida antes, sem descartar nada. O que este cenário guarda continua sendo a linha vermelha
# da issue #101, e ela NÃO é negociável — `--repair-own-log` não pode ser a porta pela qual uma
# réplica atrasada faz o hub perder mensagem. Por isso a asserção mede a PERDA, não o rc: um
# reparo que apagasse o que só existia no hub reprovaria aqui mesmo saindo com rc 0.
perdidas2d=0
while IFS= read -r id2d; do
  [ -n "$id2d" ] || continue
  grep -q "\"msg_id\"[[:space:]]*:[[:space:]]*\"$id2d\"" "$ATR/hub/log/$A.jsonl" || perdidas2d=$((perdidas2d + 1))
done < <(node -e 'const fs=require("fs");for(const l of fs.readFileSync(process.argv[1],"utf8").trim().split("\n"))if(l.trim())console.log(JSON.parse(l).msg_id)' "$T/atr-hub-antes.jsonl")
[ "$perdidas2d" -eq 0 ] \
  || { echo "FAIL [2d]: sob --repair-own-log, $perdidas2d mensagem(ns) que só existiam no hub foram apagadas por uma réplica ATRASADA — é a issue #101 reaberta por uma porta nova (rc foi $rc2d). Saída: $(cat "$T/push.txt")"; exit 1; }
echo "OK [2d] — réplica atrasada sob reparo explícito: zero mensagem do hub perdida (rc $rc2d)"

echo "[3] a mesma réplica, depois de posta em dia: push aceito e o hub avança"
cp "$HUB/log/$A.jsonl" "$T/$A-atrasada/.forge/liaison/$CH/log/$A.jsonl"
M4="$(_msgid "$(LG "$A-atrasada" send "$CH" --thread "$TH" --kind note --subject s4 --body b4)")"
LG "$A-atrasada" sync "$CH" >/dev/null || { echo "FAIL [3]: push de réplica em dia foi recusado"; exit 1; }
grep -q "$M4" "$HUB/log/$A.jsonl" || { echo "FAIL [3]: o hub não avançou com a mensagem nova ($M4)"; exit 1; }
echo "OK [3] — hub avançou até $M4"

echo "[4] propriedade (união) — prefixos sempre publicam, e o hub NUNCA perde mensagem"
PROPDIR="$T/prop"; mkdir -p "$PROPDIR"
_prop_push() { # _prop_push <linhas-hub> <linhas-local> -> imprime "rc <0|1> mudou <0|1>"
  local nh="$1" nl="$2" d="$PROPDIR/case-$nh-$nl"
  rm -rf "$d"; mkdir -p "$d/hub/log" "$d/rep/.forge/liaison/$CH/log"
  head -"$nh" "$HUB/log/$A.jsonl" > "$d/hub/log/$A.jsonl"
  head -"$nl" "$HUB/log/$A.jsonl" > "$d/rep/.forge/liaison/$CH/log/$A.jsonl"
  cp "$d/hub/log/$A.jsonl" "$d/hub-antes.jsonl"
  local rc=0
  ( set +e
    LIAISON_CHANNEL_DIR="$d/rep/.forge/liaison/$CH" LIAISON_SELF="$A" \
      bash -c '. "'"$WS"'/template/.forge/scripts/lib/transports/_common.sh"; _dir_push "'"$d"'/hub"' >/dev/null 2>&1
    echo $? > "$d/rc" ) || true
  rc="$(cat "$d/rc")"
  local mudou=0
  cmp -s "$d/hub/log/$A.jsonl" "$d/hub-antes.jsonl" || mudou=1
  d_atual="$d"
  echo "rc $rc mudou $mudou"
}
total_hub="$(grep -c . "$HUB/log/$A.jsonl")"
prop_n=0; prop_bad=0
for nh in 1 2 3; do
  for nl in 1 2 3 4; do
    [ "$nh" -le "$total_hub" ] && [ "$nl" -le "$total_hub" ] || continue
    r="$(_prop_push "$nh" "$nl")"
    rc="${r#rc }"; rc="${rc%% *}"
    mudou="${r##*mudou }"
    prop_n=$((prop_n + 1))
    # A propriedade NÃO é mais "fast-forward ou recusa": com a união, prefixo em qualquer direção
    # é publicável, porque unir prefixos nunca é ambíguo. O que precisa valer para QUALQUER par é
    # (a) o push tem êxito — não há bifurcação entre prefixos do mesmo log — e (b) NENHUMA
    # mensagem que estava no hub desaparece, que é a propriedade da issue #101 e o motivo de tudo.
    [ "$rc" -eq 0 ] || { echo "  hub=$nh local=$nl: push de prefixos RECUSADO (rc=$rc) — não há bifurcação aqui"; prop_bad=$((prop_bad + 1)); }
    perdidas_p=0
    while IFS= read -r idp; do
      [ -n "$idp" ] || continue
      grep -q "\"msg_id\"[[:space:]]*:[[:space:]]*\"$idp\"" "$d_atual/hub/log/$A.jsonl" || perdidas_p=$((perdidas_p + 1))
    done < <(node -e 'const fs=require("fs");for(const l of fs.readFileSync(process.argv[1],"utf8").trim().split("\n"))if(l.trim())console.log(JSON.parse(l).msg_id)' "$d_atual/hub-antes.jsonl")
    [ "$perdidas_p" -eq 0 ] \
      || { echo "  hub=$nh local=$nl: $perdidas_p mensagem(ns) do hub PERDIDA(S) — issue #101"; prop_bad=$((prop_bad + 1)); }
  done
done
[ "$prop_n" -gt 0 ] || { echo "FAIL [4]: matriz vazia"; exit 1; }
[ "$prop_bad" -eq 0 ] || { echo "FAIL [4]: $prop_bad violação(ões) em $prop_n pares"; exit 1; }
echo "OK [4] — $prop_n pares (hub, local) examinados, zero perda em todos"

echo "[4b] hub com log PRESENTE e VAZIO: qualquer publicação avança, e o push é ACEITO"
# A matriz de [4] varre `nh` a partir de 1 e nunca chega ao contorno onde o log do hub existe com
# ZERO linha — o estado em que um `mv` interrompido, um arquivo commitado vazio no hub `git` ou uma
# cópia manual deixam o ponto de encontro. Ali o predicado do fast-forward tinha o clássico
# `NR == FNR` do awk: com o PRIMEIRO arquivo vazio, `NR == FNR` continua verdadeiro na primeira
# linha do SEGUNDO, e o log local inteiro era carregado como se fosse o do hub — `nh > nl` e a
# publicação recusada para sempre, com uma mensagem que afirma que o hub tem linhas que a réplica
# não tem quando o hub não tem linha nenhuma. Um log vazio é prefixo de qualquer log.
D4B="$T/vazio"; rm -rf "$D4B"; mkdir -p "$D4B/hub/log" "$D4B/rep/.forge/liaison/$CH/log"
: > "$D4B/hub/log/$A.jsonl"
cp "$HUB/log/$A.jsonl" "$D4B/rep/.forge/liaison/$CH/log/$A.jsonl"
set +e
( LIAISON_CHANNEL_DIR="$D4B/rep/.forge/liaison/$CH" LIAISON_SELF="$A" \
    bash -c '. "'"$WS"'/template/.forge/scripts/lib/transports/_common.sh"; _dir_push "'"$D4B"'/hub"' ) > "$T/out4b.txt" 2>&1
rc4b=$?
set -e
[ "$rc4b" -eq 0 ] \
  || { echo "FAIL [4b]: push RECUSADO contra um hub cujo log está vazio — log vazio é prefixo de qualquer log, e recusar aqui tranca a publicação para sempre sem caminho de saída. Saída: $(cat "$T/out4b.txt")"; exit 1; }
# Sinal POSITIVO pareado: não basta o rc — o hub tem de ter passado a ser o local.
cmp -s "$D4B/hub/log/$A.jsonl" "$HUB/log/$A.jsonl" \
  || { echo "FAIL [4b]: push aceito (rc 0) e o hub NÃO recebeu o log local — aceitar sem publicar é pior que recusar"; exit 1; }
echo "OK [4b] — hub vazio aceita a publicação e passa a conter $(grep -c . "$D4B/hub/log/$A.jsonl") linha(s)"

# ── #102: o ack avança o cursor ──────────────────────────────────────────────────────────────
STATE="$T/$B/.forge/liaison/$CH/state.json"
_cursor_of() { # _cursor_of <state.json> <thread>
  node -e '
    const fs=require("fs");
    let s={}; try { s=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); } catch {}
    const c=(s.cursors||{})[process.argv[2]];
    process.stdout.write(c && c.msg_id ? c.msg_id : "");
  ' "$1" "$2"
}
_unread_of() { # _unread_of <repo> <thread> -> quantas não lidas a thread reporta
  LG "$1" list "$CH" 2>/dev/null | awk -v th="$2" '$0 ~ th { for (i=1;i<=NF;i++) if ($i ~ /^[0-9]+$/) { print $i; exit } }'
}

LG "$B" sync "$CH" >/dev/null

echo "[5] ack de mensagem de terceiro avança o cursor da thread até ela"
before5="$(_cursor_of "$STATE" "$TH")"
LG "$B" ack "$CH" "$M3" --subject "recebido" >/dev/null
after5="$(_cursor_of "$STATE" "$TH")"
[ "$after5" = "$M3" ] \
  || { echo "FAIL [5]: o ack NÃO avançou o cursor (antes='$before5', depois='$after5', esperado '$M3') — o ato mais forte de leitura do protocolo não marca a thread como lida"; exit 1; }
echo "OK [5] — cursor '$before5' -> '$after5'"

echo "[6] ack de mensagem ANTERIOR ao cursor não faz o cursor regredir, e não falha"
set +e
out6="$(LG "$B" ack "$CH" "$M1" --subject "ack tardio" 2>&1)"; rc6=$?
set -e
[ "$rc6" -eq 0 ] || { echo "FAIL [6]: ack de mensagem anterior FALHOU (rc=$rc6) — ackar algo já lido é legítimo. Saída: $out6"; exit 1; }
after6="$(_cursor_of "$STATE" "$TH")"
# Sinal POSITIVO obrigatório: o VALOR do cursor lido do state.json, comparado com o esperado.
# "não regrediu" sozinho é satisfeito por um harness em que o ack nunca escreve cursor — e era
# esse o estado antes desta correção.
[ "$after6" = "$M3" ] \
  || { echo "FAIL [6]: cursor mudou para '$after6' (esperado continuar em '$M3')"; exit 1; }
echo "OK [6] — cursor permaneceu em $after6"

echo "[7] depois de [5], a thread não reporta não-lidas"
LG "$B" read "$CH" --upto "$M3" >/dev/null 2>&1 || true
after7="$(_cursor_of "$STATE" "$TH")"
[ -n "$after7" ] || { echo "FAIL [7]: cursor vazio"; exit 1; }
echo "OK [7] — cursor em $after7 (mensagens até ela deixam de contar como não lidas)"

echo "[8] propriedade (monotonicidade) — o índice do cursor é não-decrescente, e o final é o máximo"
LG "$B" sync "$CH" >/dev/null
ORDER=("$M1" "$M2" "$M3" "$M4")
_idx_of() { local m="$1" i=0 x; for x in "${ORDER[@]}"; do [ "$x" = "$m" ] && { echo "$i"; return 0; }; i=$((i+1)); done; echo -1; }
seq_n=0; seq_bad=0; max_pedido=-1
prev_idx="$(_idx_of "$(_cursor_of "$STATE" "$TH")")"
for op in "ack:$M2" "read:$M4" "ack:$M1" "ack:$M4" "read:$M2" "ack:$M3"; do
  kind="${op%%:*}"; target="${op#*:}"
  set +e
  LG "$B" "$kind" "$CH" $([ "$kind" = read ] && echo --upto) "$target" >/dev/null 2>&1
  set -e
  cur="$(_cursor_of "$STATE" "$TH")"
  cur_idx="$(_idx_of "$cur")"
  seq_n=$((seq_n + 1))
  pedido="$(_idx_of "$target")"
  [ "$pedido" -gt "$max_pedido" ] && max_pedido="$pedido"
  if [ "$cur_idx" -lt "$prev_idx" ]; then
    echo "  '$kind $target': cursor regrediu de índice $prev_idx para $cur_idx"
    seq_bad=$((seq_bad + 1))
  fi
  prev_idx="$cur_idx"
done
[ "$seq_n" -gt 0 ] || { echo "FAIL [8]: sequência vazia"; exit 1; }
[ "$seq_bad" -eq 0 ] || { echo "FAIL [8]: $seq_bad regressão(ões) em $seq_n operações"; exit 1; }
# Sinal POSITIVO: o cursor chegou ao MÁXIMO pedido, não apenas "não regrediu" (que um cursor
# imóvel satisfaz).
[ "$prev_idx" -eq "$max_pedido" ] \
  || { echo "FAIL [8]: o cursor terminou no índice $prev_idx e o máximo pedido foi $max_pedido — 'não regride' é satisfeito por um cursor que nunca se move"; exit 1; }
echo "OK [8] — $seq_n operações, 0 regressões, cursor no máximo pedido (índice $prev_idx)"

echo "[9] ack da PRÓPRIA mensagem não marca como lida a mensagem POSTERIOR de terceiro"
# A réplica original de A ficou ATRÁS do hub depois de [3] (foi a `$A-atrasada`, já em dia, que
# publicou M4). Com fast-forward-ou-recusa isso agora BLOQUEIA o push — que é o comportamento
# correto e o que a mensagem de recusa manda fazer: trazer o log do hub antes de publicar.
cp "$HUB/log/$A.jsonl" "$T/$A/.forge/liaison/$CH/log/$A.jsonl"
M5="$(_msgid "$(LG "$A" send "$CH" --thread "$TH" --kind note --subject s5 --body b5)")"
LG "$A" sync "$CH" >/dev/null
LG "$B" sync "$CH" >/dev/null
MB="$(_msgid "$(LG "$B" send "$CH" --thread "$TH" --kind note --subject sb --body bb)")"
LG "$B" sync "$CH" >/dev/null
antes9="$(_cursor_of "$STATE" "$TH")"
set +e
LG "$B" ack "$CH" "$MB" --subject "ack da propria" >/dev/null 2>&1
set -e
depois9="$(_cursor_of "$STATE" "$TH")"
[ "$depois9" != "$M5" ] \
  || { echo "FAIL [9]: ackar a PRÓPRIA mensagem marcou como lida a mensagem $M5 de terceiro — participação não é leitura"; exit 1; }
[ -n "$depois9" ] \
  || { echo "FAIL [9]: cursor vazio depois do ack — o cenário mediria ausência de mecanismo. antes='$antes9'"; exit 1; }
echo "OK [9] — cursor em '$depois9', a mensagem $M5 de terceiro segue não marcada por participação"

echo "[11] mutação — remover a guarda de não-regressão e a união reprova os cenários certos"
CUR_LIB="$T/$B/.forge/scripts/lib/liaison-cursor.mjs"
[ -f "$CUR_LIB" ] || { echo "FAIL [11]: o avanço de cursor não vive num lib compartilhado ($CUR_LIB ausente) — duplicá-lo é criar a segunda implementação de 'avançar cursor sem regredir' no mesmo arquivo em que se corrige um defeito de leitura"; exit 1; }
cp "$CUR_LIB" "$T/cursor.orig"
perl -0pi -e 's/if \(idx < prevIdx\)/if (false)/' "$CUR_LIB"
cmp -s "$CUR_LIB" "$T/cursor.orig" && { echo "FAIL [11]: a mutação não alterou o lib de cursor"; exit 1; }
set +e
LG "$B" ack "$CH" "$M1" --subject "regressao" >/dev/null 2>&1
set -e
mut_cur="$(_cursor_of "$STATE" "$TH")"
[ "$mut_cur" = "$M1" ] \
  || { echo "FAIL [11]: sem a guarda o cursor NÃO regrediu (ficou em '$mut_cur') — a guarda não é o que decide"; exit 1; }
cp "$T/cursor.orig" "$CUR_LIB"
cmp -s "$CUR_LIB" "$T/cursor.orig" || { echo "FAIL [11]: restauração do lib de cursor não bateu byte a byte"; exit 1; }
set +e
LG "$B" ack "$CH" "$M4" --subject "recontrole" >/dev/null 2>&1
LG "$B" ack "$CH" "$M1" --subject "recontrole regressao" >/dev/null 2>&1
set -e
rec_cur="$(_cursor_of "$STATE" "$TH")"
[ "$rec_cur" != "$M1" ] || { echo "FAIL [11]: recontrole — depois da restauração o cursor voltou a regredir"; exit 1; }

# A mutação que importa agora NÃO é a que faz o push ser aceito — com a união ele já é aceito
# sem mutação nenhuma, e uma asserção de "rc 0 depois de mutar" seria satisfeita pelo estado
# correto, medindo nada. O que decide é a UNIÃO: trocá-la por substituição tem de fazer o hub
# PERDER a mensagem que só ele tinha.
COMMON="$T/$A-atrasada/.forge/scripts/lib/transports/_common.sh"
cp "$COMMON" "$T/common.orig"
perl -0pi -e 's/if ! node "\$mod" "\$own" "\$hubf" "\$tmp" "\$LIAISON_SELF"; then/cp "\$own" "\$tmp"; if false; then/' "$COMMON"
cmp -s "$COMMON" "$T/common.orig" && { echo "FAIL [11]: a mutação não alterou _common.sh — o alvo do perl não casou"; exit 1; }
MUT="$T/mut-hub"; rm -rf "$MUT"; mkdir -p "$MUT/log"
cp "$HUB/log/$A.jsonl" "$MUT/log/$A.jsonl"
cp "$MUT/log/$A.jsonl" "$T/mut-hub-antes.jsonl"
head -1 "$HUB/log/$A.jsonl" > "$T/$A-atrasada/.forge/liaison/$CH/log/$A.jsonl"
set +e
( LIAISON_CHANNEL_DIR="$T/$A-atrasada/.forge/liaison/$CH" LIAISON_SELF="$A" \
    bash -c '. "'"$COMMON"'"; _dir_push "'"$MUT"'"' ) >/dev/null 2>&1
set -e
n_mut_antes="$(grep -c . "$T/mut-hub-antes.jsonl")"
n_mut_depois="$(grep -c . "$MUT/log/$A.jsonl")"
[ "$n_mut_depois" -lt "$n_mut_antes" ] \
  || { echo "FAIL [11]: sem a união o hub NÃO perdeu mensagem (antes $n_mut_antes, depois $n_mut_depois) — [2] não mede a união"; exit 1; }
cp "$T/common.orig" "$COMMON"
cmp -s "$COMMON" "$T/common.orig" || { echo "FAIL [11]: restauração de _common.sh não bateu byte a byte"; exit 1; }
# RECONTROLE: com o arquivo restaurado, o mesmo push volta a preservar tudo.
rm -rf "$MUT"; mkdir -p "$MUT/log"
cp "$HUB/log/$A.jsonl" "$MUT/log/$A.jsonl"
head -1 "$HUB/log/$A.jsonl" > "$T/$A-atrasada/.forge/liaison/$CH/log/$A.jsonl"
set +e
( LIAISON_CHANNEL_DIR="$T/$A-atrasada/.forge/liaison/$CH" LIAISON_SELF="$A" \
    bash -c '. "'"$COMMON"'"; _dir_push "'"$MUT"'"' ) >/dev/null 2>&1
set -e
n_rec="$(grep -c . "$MUT/log/$A.jsonl")"
[ "$n_rec" -ge "$n_mut_antes" ] \
  || { echo "FAIL [11]: recontrole — depois da restauração o hub ainda perde ($n_rec < $n_mut_antes)"; exit 1; }
echo "OK [11] — duas mutações reintroduziram os defeitos (a segunda com perda medida: $n_mut_antes para $n_mut_depois), restauração e recontrole verificados"

echo "PASS w195-liaison-monotonicity"
