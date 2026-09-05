#!/usr/bin/env bash
# Gate W168 — merge=union no log do liaison: driver + gate, os DOIS (issue #80).
#
# O driver sozinho é insuficiente: o modo de falha do union é sempre duplicação, nunca perda, mas
# duplicação silenciosa (rc=0, sem marcador) corrompe contagem/ack/reconciliação de quem
# sincronizar. Este gate prova as duas metades — o `.gitattributes` (driver) e
# check-liaison-log-integrity.sh (gate), fiado em post-merge (detector, qualquer branch) e
# pre-push (bloqueio) — e é dirigido pelo CANAL REAL (rule testing/gate-delivery-channel.md): os
# hooks são invocados como o git os invoca, nunca só o script do check isolado.
#
#   [1] installer/install.sh: merge=union aplicado no path do liaison (git check-attr confirma)
#   [2] bin/forge.mjs init E update: mesmo resultado pelo caminho npx
#   [3] escopo DELIBERADO: ledger.json/state.json/LEDGER.md/CHANNEL.md ficam FORA do driver
#   [4] check-liaison-log-integrity.sh: log limpo passa; canal configurado com log vazio reprova
#       (controle positivo); msg_id duplicado reprova nomeando o arquivo
#   [5] delegação ausente (issue #49): script sumido com .forge/scripts/ presente → post-merge
#       FALHA (nunca sucesso silencioso); pre-push AVISA e segue, nunca bloqueia por alvo ausente
#       (mesma classe de check-worktree-prereqs.sh, issue #81/#73 — hooksPath é compartilhado
#       entre worktrees, .forge/scripts/ não é)
#   [6] CANAL REAL — pre-push: log com msg_id duplicado (fabricado, simulando o merge=union que já
#       rodou antes deste commit) faz o hook BLOQUEAR citando o defeito
#   [7] CANAL REAL — post-merge: um `git merge` de verdade que aciona o union e duplica uma
#       mensagem (cenário 5 da issue) faz o hook reportar FALHOU, mesmo sabendo que o git ignora
#       o exit status dele (é DETECTOR, não bloqueio)
#   [8] controle: push e merge limpos passam pelos dois hooks sem menção a log duplicado
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w168.XXXXXX)"
trap 'rm -rf "$T"' EXIT

echo "[1] installer/install.sh aplica merge=union no path do liaison"
T1="$T/inst1"
bash "$WS/installer/install.sh" --target "$T1" --slug fixture --name Fixture --desc t >/dev/null
git -C "$T1" init -q >/dev/null 2>&1 || true
attr1="$(git -C "$T1" check-attr merge -- .forge/liaison/qualquer/log/x.jsonl)"
grep -q "merge: union" <<<"$attr1" || { echo "FAIL [1]: check-attr não confirma union: $attr1"; exit 1; }
echo "OK [1]"

echo "[2] bin/forge.mjs init E update aplicam o mesmo bloco"
T2="$T/inst2"
mkdir -p "$T2"; git -C "$T2" init -q -b main
node "$WS/bin/forge.mjs" init --target "$T2" --slug fixture2 --name Fixture2 --desc t --yes --no-plugin >/dev/null 2>&1 \
  || { echo "FAIL [2]: init via bin/forge.mjs reprovou"; exit 1; }
attr2a="$(git -C "$T2" check-attr merge -- .forge/liaison/qualquer/log/x.jsonl)"
grep -q "merge: union" <<<"$attr2a" || { echo "FAIL [2]: init via bin/forge.mjs não aplicou union: $attr2a"; exit 1; }
# simula um consumidor ANTIGO sem o bloco (removendo o .gitattributes) e roda update
rm -f "$T2/.gitattributes"
node "$WS/bin/forge.mjs" update --target "$T2" --no-plugin --no-backup >/dev/null 2>&1 \
  || { echo "FAIL [2]: update via bin/forge.mjs reprovou"; exit 1; }
attr2b="$(git -C "$T2" check-attr merge -- .forge/liaison/qualquer/log/x.jsonl)"
grep -q "merge: union" <<<"$attr2b" || { echo "FAIL [2]: update via bin/forge.mjs não trouxe union para consumidor antigo: $attr2b"; exit 1; }
echo "OK [2]"

echo "[3] escopo deliberado: ledger.json/state.json/LEDGER.md/CHANNEL.md ficam FORA"
for rel in .forge/liaison/ch/ledger.json .forge/liaison/ch/state.json .forge/liaison/ch/LEDGER.md .forge/liaison/ch/CHANNEL.md; do
  out="$(git -C "$T1" check-attr merge -- "$rel")"
  grep -q "merge: unspecified" <<<"$out" || { echo "FAIL [3]: '$rel' deveria ficar unspecified (JSON/render, não mensagem): $out"; exit 1; }
done
echo "OK [3]"

echo "[4] check-liaison-log-integrity.sh: limpo passa, vazio reprova (controle), duplicata reprova"
T4="$T/repo4"
mkdir -p "$T4/.forge"
cp -R "$WS/template/.forge/scripts" "$T4/.forge/"
cp -R "$WS/template/.forge/templates" "$T4/.forge/"
git -C "$T4" init -q
git -C "$T4" config user.email t@test; git -C "$T4" config user.name t; git -C "$T4" config commit.gpgsign false
git -C "$T4" commit --allow-empty -qm init >/dev/null
CHK() { FORGE_ROOT="$T4" bash "$T4/.forge/scripts/check-liaison-log-integrity.sh"; }
LG4() { FORGE_ROOT="$T4" bash "$T4/.forge/scripts/liaison-ops.sh" "$@"; }
CH4=contracts-fare
LOG4="$T4/.forge/liaison/$CH4/log/axis-go-cloud.jsonl"

out4a="$(CHK)"; rc4a=$?
[ "$rc4a" -eq 0 ] || { echo "FAIL [4a]: sem canal deveria passar: $out4a"; exit 1; }
grep -qi "sem canal" <<<"$out4a" || { echo "FAIL [4a]: mensagem não diz 'sem canal': $out4a"; exit 1; }

# `open` real via liaison-ops.sh — cria liaison.yaml (self.id + canal), SEM publicar mensagem
# nenhuma ainda. É o estado transitório entre 'open' e o primeiro 'send'.
LG4 open "$CH4" --self axis-go-cloud --participants axis-go-cloud,axis-fare-validator >/dev/null
set +e
out4b="$(CHK 2>&1)"; rc4b=$?
set -e
[ "$rc4b" -ne 0 ] || { echo "FAIL [4b]: canal configurado com ZERO log deveria reprovar (guarda cega): $out4b"; exit 1; }
grep -qi "guarda cega\|nenhum log" <<<"$out4b" || { echo "FAIL [4b]: mensagem não fala em guarda cega/nenhum log: $out4b"; exit 1; }

LG4 thread open "$CH4" th1 --subject "abertura" --participants axis-go-cloud,axis-fare-validator --body x >/dev/null
out4c="$(CHK)"; rc4c=$?
[ "$rc4c" -eq 0 ] || { echo "FAIL [4c]: log limpo (thread-open, 1 msg_id) deveria passar: $out4c"; exit 1; }

# fabrica a duplicata (o que o merge=union sobreposto produziria — w169 já prova o mecanismo)
dup_line="$(head -1 "$LOG4")"
printf '%s\n' "$dup_line" >> "$LOG4"
set +e
out4d="$(CHK 2>&1)"; rc4d=$?
set -e
[ "$rc4d" -ne 0 ] || { echo "FAIL [4d]: msg_id duplicado deveria reprovar: $out4d"; exit 1; }
grep -q "axis-go-cloud.jsonl" <<<"$out4d" || { echo "FAIL [4d]: reprovação não nomeia o arquivo: $out4d"; exit 1; }
echo "OK [4]"

echo "[5] delegação ausente: script sumido com .forge/scripts/ presente BLOQUEIA (pre-push) e FALHA (post-merge)"
T5="$T/repo5"
cp -R "$WS/template/.forge" "$T5/.forge" 2>/dev/null || { mkdir -p "$T5"; cp -R "$WS/template/.forge" "$T5/.forge"; }
git -C "$T5" init -q -b main
git -C "$T5" config user.email t@test; git -C "$T5" config user.name t; git -C "$T5" config commit.gpgsign false
printf 'x\n' > "$T5/a.txt"; git -C "$T5" add -A >/dev/null; git -C "$T5" commit -qm init >/dev/null
rm -f "$T5/.forge/scripts/check-liaison-log-integrity.sh"

set +e
pm5_out="$(cd "$T5" && bash .forge/hooks/git/post-merge 2>&1)"; pm5_rc=$?
set -e
[ "$pm5_rc" -ne 0 ] || { echo "FAIL [5]: post-merge concluiu com sucesso delegando para alvo ausente: $pm5_out"; exit 1; }
grep -q "check-liaison-log-integrity" <<<"$pm5_out" || { echo "FAIL [5]: post-merge não nomeia o alvo ausente: $pm5_out"; exit 1; }

ZERO=0000000000000000000000000000000000000000
head5="$(git -C "$T5" rev-parse HEAD)"
set +e
pp5_out="$(cd "$T5" && printf '%s\n' "refs/heads/main $head5 refs/heads/main $ZERO" | bash .forge/hooks/git/pre-push origin "file://$T5" 2>&1)"; pp5_rc=$?
set -e
# pre-push, diferente do post-merge, NÃO bloqueia por alvo ausente aqui — mesma classe de
# check-worktree-prereqs.sh (issue #81): core.hooksPath é compartilhado por TODOS os worktrees,
# mas .forge/scripts/ é conteúdo próprio de cada um (issue #41); bloquear travaria uma worktree
# que ainda não trouxe o commit deste script por causa alheia (a classe que a issue #73 corrigiu).
# O aviso nomeando o alvo ausente é o que substitui o bloqueio — nunca silêncio.
[ "$pp5_rc" -eq 0 ] || { echo "FAIL [5]: pre-push bloqueou por alvo ausente — deveria avisar e seguir (issue #73/#81): $pp5_out"; exit 1; }
grep -q "check-liaison-log-integrity" <<<"$pp5_out" || { echo "FAIL [5]: pre-push não nomeia o alvo ausente: $pp5_out"; exit 1; }
grep -qi "NÃO VERIFICADO" <<<"$pp5_out" || { echo "FAIL [5]: pre-push não sinaliza explicitamente a checagem não verificada: $pp5_out"; exit 1; }
echo "OK [5]"

echo "[6] CANAL REAL — pre-push BLOQUEIA log duplicado (dirigido pelo hook, stdin no formato do git)"
T6="$T/repo6"
mkdir -p "$T6/.forge"
cp -R "$WS/template/.forge/scripts" "$T6/.forge/"
cp -R "$WS/template/.forge/templates" "$T6/.forge/"
cp -R "$WS/template/.forge/hooks" "$T6/.forge/"
sed -n '/^\.forge\/liaison/p' "$WS/installer/gitattributes.patch" > "$T6/.gitattributes"
git -C "$T6" init -q -b main
git -C "$T6" config user.email t@test; git -C "$T6" config user.name t; git -C "$T6" config commit.gpgsign false
git -C "$T6" commit --allow-empty -qm init >/dev/null
LG6() { FORGE_ROOT="$T6" bash "$T6/.forge/scripts/liaison-ops.sh" "$@"; }
CH6=contracts-fare
LOG6="$T6/.forge/liaison/$CH6/log/axis-go-cloud.jsonl"
LG6 open "$CH6" --self axis-go-cloud --participants axis-go-cloud,axis-fare-validator >/dev/null
LG6 thread open "$CH6" th1 --subject "abertura" --participants axis-go-cloud,axis-fare-validator --body x >/dev/null
git -C "$T6" add -A >/dev/null; git -C "$T6" commit -qm "limpo" >/dev/null
base6="$(git -C "$T6" rev-parse HEAD)"
# fabrica a duplicata NO PRÓPRIO log — o que um merge=union sobreposto (w169 já prova o mecanismo
# do git) já teria produzido antes deste commit chegar ao push
dup_line6="$(head -1 "$LOG6")"
printf '%s\n' "$dup_line6" >> "$LOG6"
git -C "$T6" add -A >/dev/null; git -C "$T6" commit -qm "duplicado" >/dev/null
head6="$(git -C "$T6" rev-parse HEAD)"
set +e
pp6_out="$(cd "$T6" && printf '%s\n' "refs/heads/main $head6 refs/heads/main $base6" | bash .forge/hooks/git/pre-push origin "file://$T6" 2>&1)"; pp6_rc=$?
set -e
[ "$pp6_rc" -ne 0 ] || { echo "FAIL [6]: pre-push deixou passar log duplicado: $pp6_out"; exit 1; }
grep -qi "log duplicado" <<<"$pp6_out" || { echo "FAIL [6]: pre-push não cita o motivo (log duplicado): $pp6_out"; exit 1; }
echo "OK [6]"

echo "[7] CANAL REAL — post-merge DETECTA duplicata produzida por um merge=union de verdade"
T7="$T/repo7"
mkdir -p "$T7/.forge"
cp -R "$WS/template/.forge/scripts" "$T7/.forge/"
cp -R "$WS/template/.forge/templates" "$T7/.forge/"
cp -R "$WS/template/.forge/hooks" "$T7/.forge/"
sed -n '/^\.forge\/liaison/p' "$WS/installer/gitattributes.patch" > "$T7/.gitattributes"
git -C "$T7" init -q -b main
git -C "$T7" config user.email t@test; git -C "$T7" config user.name t; git -C "$T7" config commit.gpgsign false
git -C "$T7" commit --allow-empty -qm init >/dev/null
LG7() { FORGE_ROOT="$T7" bash "$T7/.forge/scripts/liaison-ops.sh" "$@"; }
CH7=contracts-fare
LOG7="$T7/.forge/liaison/$CH7/log/axis-go-cloud.jsonl"
LG7 open "$CH7" --self axis-go-cloud --participants axis-go-cloud,axis-fare-validator >/dev/null
git -C "$T7" add -A >/dev/null; git -C "$T7" commit -qm "abertura do canal" >/dev/null
# a partir daqui o CONTEÚDO do log é escrito diretamente (não via 'send') para reproduzir, byte a
# byte, o cenário 5 medido na issue #80 e já provado em w169 — o que importa aqui é o HOOK, o
# mecanismo do union já está provado.
printf 'B1\nB2\nB3\nB4\nB5\nB6\nB7\nB8\nB9\nB10\n' > "$LOG7"
git -C "$T7" add -A >/dev/null; git -C "$T7" commit -qm base >/dev/null
git -C "$T7" branch feature >/dev/null
printf 'B1\nB2\nB3\nB5\nB4\nB6\nB7\nB8\nB9\nB10\n' > "$LOG7"
git -C "$T7" add -A >/dev/null; git -C "$T7" commit -qm left >/dev/null
git -C "$T7" checkout -q feature
printf 'B1\nB2\nB3\nB4\nB6\nB5\nB7\nB8\nB9\nB10\n' > "$LOG7"
git -C "$T7" add -A >/dev/null; git -C "$T7" commit -qm right >/dev/null
git -C "$T7" checkout -q main
merge7_out="$(git -C "$T7" merge feature --no-edit 2>&1)"; merge7_rc=$?
[ "$merge7_rc" -eq 0 ] || { echo "FAIL [7]: pré-condição — o próprio merge deveria resolver sozinho (union): $merge7_out"; exit 1; }
n7="$(grep -c . "$LOG7")"
[ "$n7" = "11" ] || { echo "FAIL [7]: pré-condição — o merge deveria ter produzido 11 linhas (a duplicata do cenário 5), obteve $n7"; exit 1; }
set +e
pm7_out="$(cd "$T7" && bash .forge/hooks/git/post-merge 2>&1)"; pm7_rc=$?
set -e
[ "$pm7_rc" -ne 0 ] || { echo "FAIL [7]: post-merge não detectou a duplicata que o próprio union produziu: $pm7_out"; exit 1; }
grep -qi "log duplicado" <<<"$pm7_out" || { echo "FAIL [7]: post-merge não cita o motivo: $pm7_out"; exit 1; }
echo "OK [7]"

echo "[8] controle: push e merge LIMPOS não mencionam log duplicado"
ZERO8=0000000000000000000000000000000000000000
set +e
pp8_out="$(cd "$T6" && printf '%s\n' "refs/heads/main $base6 refs/heads/main $ZERO8" | bash .forge/hooks/git/pre-push origin "file://$T6" 2>&1)"
set -e
! grep -qi "log duplicado" <<<"$pp8_out" || { echo "FAIL [8]: pre-push citou log duplicado num commit limpo: $pp8_out"; exit 1; }
echo "OK [8]"

echo "PASS w168-liaison-log-merge-union-gate"
