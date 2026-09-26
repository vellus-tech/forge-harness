#!/usr/bin/env bash
# Gate W220 — `fs-union` como kind de primeira classe do liaison (issue #123), opt-in (DH-4).
#
# POR QUE ESTE GATE EXISTE. `liaison-ops.sh` resolve `ROOT` pelo checkout principal, mas `LIBDIR`
# pela cópia do código da árvore que o invoca. Uma worktree criada de branch anterior ao conserto
# de `_dir_push` carrega o `cp` cru, que sobrescreve o log do hub com a réplica local — perda
# irrecuperável, com rc 0. Nenhuma correção no código versionado alcança essa árvore, porque o
# defeito dela é justamente carregar a versão anterior desse código. O único elo que toda árvore
# lê do tronco é a CONFIGURAÇÃO (`liaison.yaml`), e um kind que só existe a partir do conserto faz a
# árvore antiga falhar fechado antes de tocar o hub. A segunda camada cobre a árvore que já tem o
# backend novo e um `_common.sh` destrutivo por merge feito pela metade: o backend `fs-union`
# carrega o `_common.sh` do TRONCO, e recusa se ele faltar, sem cair para a cópia da árvore.
#
# Topologia sintética: um tronco com a maquinaria nova commitada, uma worktree ligada com o
# `fs-union.sh` novo e o `_common.sh` de `47a914e` (o `cp` cru, sem `_dir_push_union`) ao lado dele,
# e uma segunda worktree com o leitor de configuração de `821178e` (sem o kind) e sem o backend.
#
#   [1]  `transport set --kind fs-union --path` sai rc 0, grava o kind e o `sync` do tronco publica
#   [2]  `fs-union` sem `path` é recusado na gravação, como `fs`
#   [3]  leitor antigo (`liaison-config.mjs` de 821178e), numa worktree, lendo o yaml do tronco:
#        rc≠0 com `kind inválido: fs-union` e o sha do hub idêntico antes e depois
#   [4]  cenário-base, sem FORGE_ROOT, script DA WORKTREE: `<self>.jsonl` do tronco é prefixo
#        estrito do hub, que tem a mensagem de um segundo clone da mesma identidade; o sync sai
#        rc 0 com `OK sync` e a mensagem continua no hub, byte-idêntica
#   [5]  cenário-base com o `_common.sh` do tronco ausente: rc≠0 com a linha de recusa nominal e o
#        sha do hub idêntico antes e depois (restauração conferida por cmp -s)
#   [6]  cenário inline, FORGE_ROOT=<worktree>, script DA WORKTREE: `liaison.yaml` da worktree com
#        o mesmo self e kind+path do hub, `<self>.jsonl` da worktree prefixo estrito do hub, que tem
#        a mensagem publicada pelo tronco; rc 0, `OK sync` e a mensagem continua lá, byte-idêntica
#   [7]  cenário inline com o `_common.sh` do tronco ausente: mesma recusa de [5]
#   [8]  `check-liaison-acks.sh` lê o hub do canal `fs-union` em `<path>/<canal>/log` (DA-26):
#        réplica nunca sincronizada reprova citando o msg_id pendente; depois de sync + ack, passa
#   [9]  contador de controle — universo vazio reprova
#   [10] versão mista ao contrário: tronco com o `_common.sh` de `47a914e` e worktree atualizada
#        (caminho com espaço), base e inline: rc≠0 com a recusa nominal de que o `_common.sh` do
#        tronco não une, sha do hub idêntico e a mensagem do segundo clone preservada
#   [11] instalação fora de git: `transport probe` de um canal `fs-union` recusa nomeando a
#        exigência de checkout git, sem caminho enganoso e sem criar o hub
set -euo pipefail
# Isolamento git: um GIT_DIR herdado faria os `git -C` abaixo gravarem no repositório de quem
# invocou o gate, e não no repositório sintético.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIX="$WS/tests/fixtures/w220"
T="$(mktemp -d /tmp/forge-w220.XXXXXX)"
T="$(cd "$T" && pwd -P)"
trap 'rm -rf "$T"' EXIT

CH=contracts
TH=thread-1
A=repo-a
B=repo-b
TR="$T/tronco"
WT="$T/wt-cp-cru"
WTV="$T/wt-leitor-antigo"
C2="$T/clone2"
HUBROOT="$T/hub"
HUB="$HUBROOT/$CH"
TRANSP=.forge/scripts/lib/transports
RECUSA='FAIL fs-union: _common.sh do checkout principal ausente'

git_id() { # git_id <repo> — identidade local do repositório sintético, nunca global
  git -C "$1" config user.email "w220@test"
  git -C "$1" config user.name "w220"
  git -C "$1" config commit.gpgsign false
}

mk_repo() { # mk_repo <dir> — repositório com a maquinaria do template commitada
  local dir="$1"
  mkdir -p "$dir/.forge"
  cp -R "$WS/template/.forge/scripts" "$dir/.forge/"
  cp -R "$WS/template/.forge/templates" "$dir/.forge/"
  cp -R "$WS/template/.forge/ledger" "$dir/.forge/"
  cp "$WS/template/.forge/forge.yaml" "$dir/.forge/forge.yaml"
  git -C "$dir" init -q
  git_id "$dir"
  git -C "$dir" add -A
  git -C "$dir" -c core.hooksPath=/dev/null commit -qm init >/dev/null
}

LGR() { local root="$1"; shift; FORGE_ROOT="$root" bash "$root/.forge/scripts/liaison-ops.sh" "$@"; }

hub_sha() { # sha de todo o conteúdo do hub (nomes + bytes), independente de mtime
  (cd "$HUBROOT" && find . -type f | LC_ALL=C sort | while IFS= read -r f; do
    printf '%s %s\n' "$f" "$(shasum -a 256 < "$f" | cut -d' ' -f1)"
  done) | shasum -a 256 | cut -d' ' -f1
}

snap() { rm -rf "$2"; cp -R "$1" "$2"; }

# Cenários de desfecho ([3] a [8]) acumulam a reprovação em vez de sair na primeira: uma mutação
# que derruba mais de um cenário aparece com todos os FAIL [n] que produziu. Pré-condição e
# montagem continuam saindo na hora, porque sem elas o cenário seguinte não mede nada.
falhas=0
falha() { echo "FAIL $*"; falhas=$((falhas + 1)); }
ok_se_limpo() { # ok_se_limpo <n> <falhas no início do cenário>
  if [ "$falhas" -eq "$2" ]; then echo "OK [$1]"; fi
}

prefixo_estrito() { # prefixo_estrito <local> <hub> — local é prefixo estrito, em linhas, do hub
  local nl nh
  nl="$(grep -c . "$1")"; nh="$(grep -c . "$2")"
  [ "$nl" -lt "$nh" ] || return 1
  [ "$(head -n "$nl" "$2")" = "$(cat "$1")" ]
}

# ── topologia: tronco + worktree com `cp` cru + worktree com leitor antigo ──────────────────────
mk_repo "$TR"
git -C "$TR" worktree add -q -b wt-cp-cru "$WT"
git -C "$TR" worktree add -q -b wt-leitor-antigo "$WTV"
cp "$FIX/_common-47a914e.sh.fixture" "$WT/$TRANSP/_common.sh"
cp "$FIX/liaison-config-821178e.mjs.fixture" "$WTV/.forge/scripts/lib/liaison-config.mjs"
cp "$FIX/_common-47a914e.sh.fixture" "$WTV/$TRANSP/_common.sh"
rm -f "$WTV/$TRANSP/fs-union.sh"

echo "[1] transport set --kind fs-union --path sai rc 0, grava o kind e o sync do tronco publica"
LGR "$TR" open "$CH" --self "$A" --participants "$A,$B" >/dev/null
set +e
out1="$(LGR "$TR" transport set "$CH" --kind fs-union --path "$HUBROOT" 2>&1)"; rc1=$?
set -e
[ "$rc1" -eq 0 ] || { echo "FAIL [1]: transport set --kind fs-union saiu rc=$rc1 — $out1"; exit 1; }
grep -q 'kind: "fs-union"' "$TR/.forge/liaison/liaison.yaml" \
  || { echo "FAIL [1]: o liaison.yaml do tronco não gravou kind: \"fs-union\""; exit 1; }
LGR "$TR" thread open "$CH" "$TH" --subject abertura --participants "$A,$B" --body abertura >/dev/null
LGR "$TR" send "$CH" --thread "$TH" --kind note --subject m1 --body b1 >/dev/null
set +e
out1s="$(LGR "$TR" sync "$CH" 2>&1)"; rc1s=$?
set -e
[ "$rc1s" -eq 0 ] || { echo "FAIL [1]: sync do tronco via fs-union saiu rc=$rc1s — $out1s"; exit 1; }
grep -q '^OK sync' <<<"$out1s" || { echo "FAIL [1]: sync sem a linha OK sync — $out1s"; exit 1; }
cmp -s "$HUB/log/$A.jsonl" "$TR/.forge/liaison/$CH/log/$A.jsonl" \
  || { echo "FAIL [1]: o hub não recebeu o log do tronco"; exit 1; }
echo "OK [1]"
# S0: a réplica do tronco com [abertura, m1] — o estado ATRASADO dos cenários abaixo.
snap "$TR/.forge/liaison" "$T/S0"

echo "[2] fs-union sem path é recusado na gravação"
mk_repo "$T/avulso"
LGR "$T/avulso" open "$CH" --self "$A" --participants "$A,$B" >/dev/null
set +e
out2="$(LGR "$T/avulso" transport set "$CH" --kind fs-union 2>&1)"; rc2=$?
set -e
[ "$rc2" -ne 0 ] || { echo "FAIL [2]: fs-union sem path foi gravado (rc 0)"; exit 1; }
grep -q 'transporte fs-union exige path' <<<"$out2" \
  || { echo "FAIL [2]: a recusa não nomeia a exigência de path — $out2"; exit 1; }
echo "OK [2]"

# Segundo clone da MESMA identidade: parte da réplica do tronco e publica m2, que o tronco não tem.
mk_repo "$C2"
snap "$T/S0" "$C2/.forge/liaison"
MSG_C2="$(LGR "$C2" send "$CH" --thread "$TH" --kind note --subject m2-do-clone --body b2)"
MSG_C2="${MSG_C2#*— }"; MSG_C2="${MSG_C2%% *}"
LGR "$C2" sync "$CH" >/dev/null
LINHA_CLONE="$(grep -F "\"msg_id\":\"$MSG_C2\"" "$HUB/log/$A.jsonl" || true)"
[ -n "$LINHA_CLONE" ] || { echo "FAIL [4]: pré-condição — a mensagem do segundo clone ($MSG_C2) não chegou ao hub"; exit 1; }
snap "$HUBROOT" "$T/H1"

echo "[3] leitor antigo (821178e) numa worktree lendo o yaml do tronco: recusa e hub intacto"
f3="$falhas"
antes3="$(hub_sha)"
set +e
out3="$(cd "$WTV" && env -u FORGE_ROOT .forge/scripts/liaison-ops.sh sync "$CH" 2>&1)"; rc3=$?
set -e
[ "$rc3" -ne 0 ] || falha "[3]: o leitor antigo aceitou o kind fs-union (rc 0) — $out3"
grep -q 'kind inválido: fs-union' <<<"$out3" \
  || falha "[3]: a recusa não é a do leitor antigo (kind inválido: fs-union) — $out3"
[ "$(hub_sha)" = "$antes3" ] || falha "[3]: o hub mudou numa recusa"
ok_se_limpo 3 "$f3"

reset_base() { snap "$T/S0" "$TR/.forge/liaison"; snap "$T/H1" "$HUBROOT"; }

echo "[4] cenário-base, sem FORGE_ROOT, script da worktree: preserva a mensagem do segundo clone"
f4="$falhas"
reset_base
[ -f "$WT/$TRANSP/fs-union.sh" ] || { echo "FAIL [4]: pré-condição — a worktree não tem o backend fs-union.sh"; exit 1; }
! grep -q '_dir_push_union' "$WT/$TRANSP/_common.sh" \
  || { echo "FAIL [4]: pré-condição — o _common.sh da worktree deveria ser o cp cru"; exit 1; }
grep -q '_dir_push_union' "$TR/$TRANSP/_common.sh" \
  || { echo "FAIL [4]: pré-condição — o _common.sh do tronco deveria unir"; exit 1; }
prefixo_estrito "$TR/.forge/liaison/$CH/log/$A.jsonl" "$HUB/log/$A.jsonl" \
  || { echo "FAIL [4]: pré-condição — o log do tronco não é prefixo estrito do hub"; exit 1; }
set +e
out4="$(cd "$WT" && env -u FORGE_ROOT .forge/scripts/liaison-ops.sh sync "$CH" 2>&1)"; rc4=$?
set -e
[ "$rc4" -eq 0 ] || falha "[4]: sync saiu rc=$rc4 — $out4"
grep -q '^OK sync' <<<"$out4" || falha "[4]: sync sem a linha OK sync — $out4"
grep -Fxq "$LINHA_CLONE" "$HUB/log/$A.jsonl" \
  || falha "[4]: a mensagem do segundo clone ($MSG_C2) sumiu do hub — o push não uniu"
ok_se_limpo 4 "$f4"

tira_common() { cp "$TR/$TRANSP/_common.sh" "$T/common.salvo"; mv "$TR/$TRANSP/_common.sh" "$TR/$TRANSP/_common.sh.fora"; }
repoe_common() {
  mv "$TR/$TRANSP/_common.sh.fora" "$TR/$TRANSP/_common.sh"
  cmp -s "$TR/$TRANSP/_common.sh" "$T/common.salvo" \
    || { echo "FAIL: o _common.sh do tronco não foi restaurado byte a byte"; exit 1; }
}

echo "[5] cenário-base com o _common.sh do tronco ausente: recusa nominal e hub intacto"
f5="$falhas"
reset_base
tira_common
antes5="$(hub_sha)"
set +e
out5="$(cd "$WT" && env -u FORGE_ROOT .forge/scripts/liaison-ops.sh sync "$CH" 2>&1)"; rc5=$?
set -e
depois5="$(hub_sha)"
repoe_common
[ "$rc5" -ne 0 ] || falha "[5]: sync saiu rc 0 sem o _common.sh do tronco — caiu para a cópia da árvore"
grep -qF "$RECUSA" <<<"$out5" || falha "[5]: sem a linha de recusa nominal — $out5"
[ "$depois5" = "$antes5" ] || falha "[5]: o hub mudou numa recusa"
ok_se_limpo 5 "$f5"

# Estado do inline: o tronco (código bom) alcança o hub, publica m3; a worktree fica com S0.
reset_base
LGR "$TR" sync "$CH" >/dev/null
MSG_TR="$(LGR "$TR" send "$CH" --thread "$TH" --kind note --subject m3-do-tronco --body b3)"
MSG_TR="${MSG_TR#*— }"; MSG_TR="${MSG_TR%% *}"
LGR "$TR" sync "$CH" >/dev/null
LINHA_TRONCO="$(grep -F "\"msg_id\":\"$MSG_TR\"" "$HUB/log/$A.jsonl" || true)"
[ -n "$LINHA_TRONCO" ] || { echo "FAIL [6]: pré-condição — a mensagem do tronco ($MSG_TR) não chegou ao hub"; exit 1; }
snap "$HUBROOT" "$T/H2"
reset_inline() { snap "$T/S0" "$WT/.forge/liaison"; snap "$T/H2" "$HUBROOT"; }

echo "[6] cenário inline, FORGE_ROOT=<worktree>, script da worktree: preserva a mensagem do tronco"
f6="$falhas"
reset_inline
grep -q 'kind: "fs-union"' "$WT/.forge/liaison/liaison.yaml" && grep -qF "path: \"$HUBROOT\"" "$WT/.forge/liaison/liaison.yaml" \
  || { echo "FAIL [6]: pré-condição — o liaison.yaml da worktree não declara kind fs-union e o path do hub"; exit 1; }
grep -q "id: $A\$" "$WT/.forge/liaison/liaison.yaml" \
  || { echo "FAIL [6]: pré-condição — o liaison.yaml da worktree não tem o self do tronco"; exit 1; }
prefixo_estrito "$WT/.forge/liaison/$CH/log/$A.jsonl" "$HUB/log/$A.jsonl" \
  || { echo "FAIL [6]: pré-condição — o log da worktree não é prefixo estrito do hub"; exit 1; }
set +e
out6="$(cd "$WT" && FORGE_ROOT="$WT" .forge/scripts/liaison-ops.sh sync "$CH" 2>&1)"; rc6=$?
set -e
[ "$rc6" -eq 0 ] || falha "[6]: sync inline saiu rc=$rc6 — $out6"
grep -q '^OK sync' <<<"$out6" || falha "[6]: sync inline sem a linha OK sync — $out6"
grep -Fxq "$LINHA_TRONCO" "$HUB/log/$A.jsonl" \
  || falha "[6]: a mensagem publicada pelo tronco ($MSG_TR) sumiu do hub — o push não uniu"
grep -Fxq "$LINHA_CLONE" "$HUB/log/$A.jsonl" \
  || falha "[6]: a mensagem do segundo clone ($MSG_C2) sumiu do hub"
ok_se_limpo 6 "$f6"

echo "[7] cenário inline com o _common.sh do tronco ausente: recusa nominal e hub intacto"
f7="$falhas"
reset_inline
tira_common
antes7="$(hub_sha)"
set +e
out7="$(cd "$WT" && FORGE_ROOT="$WT" .forge/scripts/liaison-ops.sh sync "$CH" 2>&1)"; rc7=$?
set -e
depois7="$(hub_sha)"
repoe_common
[ "$rc7" -ne 0 ] || falha "[7]: sync inline saiu rc 0 sem o _common.sh do tronco — caiu para a cópia da árvore"
grep -qF "$RECUSA" <<<"$out7" || falha "[7]: sem a linha de recusa nominal — $out7"
[ "$depois7" = "$antes7" ] || falha "[7]: o hub mudou numa recusa"
ok_se_limpo 7 "$f7"

echo "[8] check-liaison-acks lê o hub do canal fs-union em <path>/<canal>/log (DA-26)"
f8="$falhas"
CHA=contracts-ack
HUBACK="$T/hub-ack"
OW="$T/owner"; CO="$T/consumer"
mk_repo "$OW"; mk_repo "$CO"
LGR "$OW" open "$CHA" --self owner --participants owner,consumer >/dev/null
LGR "$CO" open "$CHA" --self consumer --participants owner,consumer >/dev/null
LGR "$OW" transport set "$CHA" --kind fs --path "$HUBACK" >/dev/null
LGR "$CO" transport set "$CHA" --kind fs-union --path "$HUBACK" >/dev/null
# enforce: block no consumidor — edita o bloco `liaison:` existente (o awk do script lê o primeiro).
node -e '
  const fs=require("fs"); const f=process.argv[1];
  let y=fs.readFileSync(f,"utf8");
  if (/^liaison:/m.test(y)) y=y.replace(/^(liaison:\n(?:[ ].*\n)*?[ ]+enforce:[ ]*)(warn|block)/m, "$1block");
  else y+="\nliaison:\n  auto: false\n  enforce: block\n";
  fs.writeFileSync(f,y);
' "$CO/.forge/forge.yaml"
grep -Eq '^[ ]+enforce:[ ]*block' "$CO/.forge/forge.yaml" \
  || { echo "FAIL [8]: pré-condição — enforce: block não gravado no consumidor"; exit 1; }
LGR "$OW" thread open "$CHA" "$TH" --subject contrato --participants owner,consumer --body abertura >/dev/null
MSGA="$(LGR "$OW" send "$CHA" --thread "$TH" --kind contract-change --subject campo --body "campo novo" \
  --contract-files contracts/a.proto --requires-ack)"
MSGA="${MSGA#*— }"; MSGA="${MSGA%% *}"
LGR "$OW" sync "$CHA" >/dev/null
[ ! -s "$CO/.forge/liaison/$CHA/log/owner.jsonl" ] \
  || { echo "FAIL [8]: pré-condição — a réplica do consumidor não deveria conhecer o log do owner"; exit 1; }
ACKCHECK() { (cd "$1" && FORGE_ROOT="$1" bash "$1/.forge/scripts/check-liaison-acks.sh"); }
set +e
out8="$(ACKCHECK "$CO" 2>&1)"; rc8=$?
set -e
[ "$rc8" -ne 0 ] || falha "[8]: acks aprovou com o ack devido só no hub fs-union — leu a réplica local: $out8"
grep -q "$MSGA" <<<"$out8" || falha "[8]: a reprovação não cita o msg_id pendente no hub ($MSGA): $out8"
LGR "$CO" sync "$CHA" >/dev/null
LGR "$CO" ack "$CHA" "$MSGA" --body "de acordo" >/dev/null
set +e
out8b="$(ACKCHECK "$CO" 2>&1)"; rc8b=$?
set -e
[ "$rc8b" -eq 0 ] || falha "[8]: depois de sync + ack o canal fs-union continuou reprovando: $out8b"
ok_se_limpo 8 "$f8"

echo "[9] contador de controle — universo vazio reprova"
n_hub="$(grep -c . "$HUB/log/$A.jsonl")"
# shellcheck source=/dev/null
. "$WS/template/.forge/scripts/lib/gate-universe.sh"
forge_universe_check "w220/mensagens" "$n_hub" "mensagem(ns) no hub" "$HUB" "$WS" \
  || { echo "FAIL [9]"; exit 1; }
set +e
out9="$(forge_universe_check "w220/mensagens" 0 "mensagem(ns)" "contrapositiva" "$WS" 2>&1)"; rc9=$?
set -e
[ "$rc9" -ne 0 ] || { echo "FAIL [9]: universo vazio aprovou — $out9"; exit 1; }
echo "OK [9]"

echo "[10] tronco com o _common.sh de 47a914e e worktree atualizada: recusa nominal e hub intacto"
# Versão mista ao contrário de [4]: a worktree tem o código novo inteiro e o TRONCO é que não une
# (update feito numa branch, opt-in feito dali antes do merge no tronco). Carregar o `_common.sh`
# do tronco sem conferir que ele une rodaria o `cp` cru e apagaria do hub a mensagem do segundo
# clone, com rc 0 — protegendo menos que o próprio `fs`, que usaria o `_common.sh` da worktree.
f10="$falhas"
WTN="$T/wt nova"
git -C "$TR" worktree add -q -b wt-nova "$WTN"
grep -q '_dir_push_union' "$WTN/$TRANSP/_common.sh" \
  || { echo "FAIL [10]: pré-condição — o _common.sh da worktree nova deveria unir"; exit 1; }
cp "$TR/$TRANSP/_common.sh" "$T/common10.salvo"
cp "$FIX/_common-47a914e.sh.fixture" "$TR/$TRANSP/_common.sh"
RECUSA_UNIAO='FAIL fs-union: o _common.sh do checkout principal não une o log'
# base: sem FORGE_ROOT, estado do tronco, script DA WORKTREE nova
reset_base
prefixo_estrito "$TR/.forge/liaison/$CH/log/$A.jsonl" "$HUB/log/$A.jsonl" \
  || { echo "FAIL [10]: pré-condição — o log do tronco não é prefixo estrito do hub"; exit 1; }
antes10="$(hub_sha)"
set +e
out10="$(cd "$WTN" && env -u FORGE_ROOT .forge/scripts/liaison-ops.sh sync "$CH" 2>&1)"; rc10=$?
set -e
depois10="$(hub_sha)"
[ "$rc10" -ne 0 ] || falha "[10]: base — sync saiu rc 0 com o _common.sh do tronco que não une — $out10"
grep -qF "$RECUSA_UNIAO" <<<"$out10" || falha "[10]: base — sem a linha de recusa nominal — $out10"
[ "$depois10" = "$antes10" ] || falha "[10]: base — o hub mudou numa recusa"
grep -Fxq "$LINHA_CLONE" "$HUB/log/$A.jsonl" \
  || falha "[10]: base — a mensagem do segundo clone ($MSG_C2) sumiu do hub"
# inline: FORGE_ROOT=<worktree nova>, estado da worktree com o mesmo self e kind+path do hub
snap "$T/S0" "$WTN/.forge/liaison"; snap "$T/H1" "$HUBROOT"
antes10i="$(hub_sha)"
set +e
out10i="$(cd "$WTN" && FORGE_ROOT="$WTN" .forge/scripts/liaison-ops.sh sync "$CH" 2>&1)"; rc10i=$?
set -e
depois10i="$(hub_sha)"
[ "$rc10i" -ne 0 ] || falha "[10]: inline — sync saiu rc 0 com o _common.sh do tronco que não une — $out10i"
grep -qF "$RECUSA_UNIAO" <<<"$out10i" || falha "[10]: inline — sem a linha de recusa nominal — $out10i"
[ "$depois10i" = "$antes10i" ] || falha "[10]: inline — o hub mudou numa recusa"
cp "$T/common10.salvo" "$TR/$TRANSP/_common.sh"
cmp -s "$TR/$TRANSP/_common.sh" "$T/common10.salvo" \
  || { echo "FAIL: o _common.sh do tronco não foi restaurado byte a byte"; exit 1; }
ok_se_limpo 10 "$f10"

echo "[11] fora de um repositório git, fs-union recusa nomeando a exigência de checkout git"
# Sem git alcançável não há tronco a resolver. A recusa tem de dizer isso, e não imprimir um
# caminho de `_common.sh` que não existe, derivado do diretório do próprio backend.
f11="$falhas"
NG="$T/sem git/c"
mkdir -p "$NG/.forge"
cp -R "$WS/template/.forge/scripts" "$NG/.forge/"
cp -R "$WS/template/.forge/templates" "$NG/.forge/"
cp "$WS/template/.forge/forge.yaml" "$NG/.forge/forge.yaml"
HUBNG="$T/sem git/hub"
set +e
out11="$(cd "$NG" && export GIT_CEILING_DIRECTORIES="$T" && \
  LGR "$NG" open "$CH" --self "$A" --participants "$A,$B" >/dev/null && \
  LGR "$NG" transport set "$CH" --kind fs-union --path "$HUBNG" >/dev/null && \
  LGR "$NG" transport probe "$CH" 2>&1)"; rc11=$?
set -e
[ "$rc11" -ne 0 ] || falha "[11]: transport probe fora de git saiu rc 0 — $out11"
grep -qF 'FAIL fs-union: exige um checkout git' <<<"$out11" \
  || falha "[11]: a recusa não nomeia a exigência de checkout git — $out11"
[ ! -e "$HUBNG" ] || falha "[11]: o hub foi criado numa recusa"
ok_se_limpo 11 "$f11"

[ "$falhas" -eq 0 ] || { echo "FAIL w220 — $falhas asserção(ões) de desfecho reprovada(s)"; exit 1; }
echo "OK w220 — fs-union opt-in: kind aceito, leitor antigo recusa, backend carrega o _common.sh do tronco e acks leem o hub"
