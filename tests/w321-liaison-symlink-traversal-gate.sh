#!/usr/bin/env bash
# Gate W321 — o hub do liaison nunca escreve fora da árvore do canal, nem por symlink plantado,
# nem por temporário previsível, nem por troca de diretório durante o sync (SEC-001).
#
# POR QUE ESTE GATE EXISTE. `_dir_push`/`_dir_pull` (lib/transports/_common.sh) faziam
# `mkdir -p "$hub/log" "$hub/blobs"` seguido de `cp`/`mv` sem nunca checar se o hub, `log/` ou
# `blobs/` eram links simbólicos, e publicavam por um temporário de nome PREVISÍVEL dentro do hub
# (`log/.<self>.jsonl.tmp`, `blobs/.<nome>.tmp`). Quem tem escrita no ponto de encontro (push na
# branch do canal no transporte `git`, escrita no diretório compartilhado em `fs`/`fs-union`/
# `manual`) planta um symlink num desses nomes e o próximo sync da vítima escreve onde o link
# aponta — `.bashrc`, `.git/hooks/`, `.git/config` —, isto é, execução de código na máquina dela.
#
# O QUE O GATE MEDE, sempre pelo canal de entrega real (`liaison-ops.sh sync`) e com a sentinela
# FORA da árvore conferida. Cada cenário de ataque incrementa um contador medido; o [5] reprova
# se nenhum ataque foi exercitado ou se algum deles não terminou neutralizado.
#
#   [1]  controle — push/pull legítimos por `fs` continuam funcionando (mensagem e blob chegam)
#   [2]  ataque `fs`/push: hub `blobs/` é symlink para fora — push RECUSADO, sentinela vazia
#   [3]  ataque `fs`/pull: hub `log/` é symlink para fora — pull RECUSADO
#   [4]  ataque `git`: branch do canal com `<canal>/blobs` symlink — sync RECUSADO antes do
#        checkout, cache local nunca materializa o link
#   [A1] `fs`: symlink plantado no antigo temporário do log (`log/.<self>.jsonl.tmp`) — o push da
#        união escreve num temporário privado e publica com nome aleatório: sentinela intacta
#   [A2] o mesmo pelo `fs-union`
#   [A3] o mesmo no caminho de reparo (`--repair-own-log`)
#   [A4] symlink plantado no antigo temporário de blob (`blobs/.<nome>.tmp`): sentinela intacta
#   [A5] blob publicado a partir de origem com `+x` sai sem bit de execução no hub
#   [A6] `log/<self>.jsonl` do hub é symlink — push RECUSADO citando SEC-001, sentinela intacta
#   [A7] `blobs/<nome>` do hub é symlink — push RECUSADO (rc≠0), nunca `continue` silencioso
#   [5]  contador de controle medido — ataques exercitados = ataques neutralizados, e > 0
#   [M2] mutação pelo canal real — o helper de publicação volta a escrever num temporário
#        previsível sem O_EXCL: [A1] passa a contaminar a sentinela; restaurado, volta a segurar
set -euo pipefail
# Isolamento git (LDG-0201): GIT_DIR herdado do ambiente faria os comandos git abaixo obedecerem
# ao repositório de quem invocou o gate, e não aos repositórios sintéticos criados aqui.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d "${TMPDIR:-/tmp}/forge-w321.XXXXXX")"
T="$(cd "$T" && pwd -P)"
trap 'rm -rf "$T"' EXIT

CH="ch"
SENT_TXT='conteúdo original da sentinela — nada do liaison pode chegar aqui'

# Contadores MEDIDOS: cada cenário de ataque declara-se em `ataque` ao começar e em `neutralizado`
# só depois de todas as suas asserções; uma falha registra e segue para o próximo cenário, para
# que uma execução mostre todos os vermelhos de uma vez.
FALHAS=0; ATAQUES=0; NEUTRALIZADOS=0
falha() { echo "FAIL $*"; FALHAS=$((FALHAS + 1)); }
ataque() { ATAQUES=$((ATAQUES + 1)); }
neutralizado() { NEUTRALIZADOS=$((NEUTRALIZADOS + 1)); }

mk_repo() { # mk_repo <dir-relativo> — réplica sintética própria, nunca o repositório real
  local dir="$T/$1"
  mkdir -p "$dir/.forge"
  cp -R "$WS/template/.forge/scripts" "$dir/.forge/"
  cp -R "$WS/template/.forge/templates" "$dir/.forge/"
  git -C "$dir" init -q
  git -C "$dir" config user.email "teste@test"
  git -C "$dir" config user.name "teste"
  git -C "$dir" config commit.gpgsign false
  git -C "$dir" commit --allow-empty -qm "chore: init" >/dev/null
}

LG() { local repo="$1"; shift; FORGE_ROOT="$T/$repo" bash "$T/$repo/.forge/scripts/liaison-ops.sh" "$@"; }

sentinela() { # sentinela <caminho-absoluto> — arquivo FORA do hub e do repositório, conteúdo conhecido
  mkdir -p "$(dirname "$1")"
  printf '%s\n' "$SENT_TXT" > "$1"
}
intacta() { [ -f "$1" ] && [ ! -L "$1" ] && [ "$(cat "$1")" = "$SENT_TXT" ]; }

tem_bit_x() { [ -n "$(find "$1" \( -perm -0100 -o -perm -0010 -o -perm -0001 \) -print)" ]; }

# prepara <id> <kind> — réplica "v" (self v) com transporte <kind> num hub próprio do cenário,
# thread aberta e um push legítimo já feito. Define R (repo, relativo a $T), H (raiz configurada
# no `path`), HC (hub do canal), LOC (canal local da réplica).
prepara() {
  local id="$1" kind="$2"
  R="$id/v"; H="$T/$id/hub"; HC="$H/$CH"; LOC="$T/$id/v/.forge/liaison/$CH"
  mk_repo "$R"
  LG "$R" open "$CH" --self v --participants v,x >/dev/null
  if [ "$kind" = manual ]; then mkdir -p "$H"; HC="$H"; fi
  LG "$R" transport set "$CH" --kind "$kind" --path "$H" >/dev/null
  LG "$R" thread open "$CH" t1 --subject abertura --participants v,x --body "abertura" >/dev/null
  LG "$R" sync "$CH" --push-only >/dev/null
}

# ───────────────────────────────────────────────────────────────────────────────────────────────
echo "[1] controle fs — push normal popula o hub, pull normal traz mensagem e blob"
mk_repo base1/a; mk_repo base1/b
HUB1="$T/base1/hub"
LG base1/a open "$CH" --self a --participants a,b >/dev/null
LG base1/b open "$CH" --self b --participants a,b >/dev/null
LG base1/a transport set "$CH" --kind fs --path "$HUB1" >/dev/null
LG base1/b transport set "$CH" --kind fs --path "$HUB1" >/dev/null
LG base1/a thread open "$CH" t1 --subject abertura --participants a,b --body abertura >/dev/null
printf 'corpo legítimo — conteúdo irrelevante\n' > "$T/base1/corpo.md"
LG base1/a send "$CH" --thread t1 --kind note --subject "c1" --body-file "$T/base1/corpo.md" >/dev/null
if ! LG base1/a sync "$CH" --push-only >/dev/null; then
  falha "[1]: push normal (controle) reprovou"
elif [ -z "$(ls -A "$HUB1/$CH/blobs" 2>/dev/null)" ]; then
  falha "[1]: hub sem blob após push legítimo"
elif ! LG base1/b sync "$CH" --pull-only >/dev/null; then
  falha "[1]: pull normal (controle) reprovou"
elif [ -z "$(ls -A "$T/base1/b/.forge/liaison/$CH/blobs" 2>/dev/null)" ]; then
  falha "[1]: b não recebeu o blob após pull legítimo"
else
  echo "OK [1] — push/pull legítimos continuam funcionando"
fi

# ───────────────────────────────────────────────────────────────────────────────────────────────
echo "[2] ataque fs/push — hub blobs/ é symlink para fora: push RECUSADO, sentinela vazia"
c_2() {
  ataque
  prepara base2 fs
  local fora="$T/base2/fora-blobs"; mkdir -p "$fora"
  rm -rf "$HC/blobs"; ln -s "$fora" "$HC/blobs"
  printf 'corpo malicioso — não deveria sair da árvore do canal\n' > "$T/base2/corpo.md"
  LG "$R" send "$CH" --thread t1 --kind note --subject "c2" --body-file "$T/base2/corpo.md" >/dev/null
  local out rc
  set +e; out="$(LG "$R" sync "$CH" --push-only 2>&1)"; rc=$?; set -e
  [ "$rc" -ne 0 ] || { falha "[2]: push com hub/blobs symlink foi ACEITO (rc=0)"; return 0; }
  grep -qF 'é um link simbólico — recusado (SEC-001)' <<<"$out" \
    || { falha "[2]: recusou sem a causa da guarda (SEC-001). Saída: $(head -3 <<<"$out")"; return 0; }
  [ -z "$(ls -A "$fora")" ] || { falha "[2]: a sentinela fora da árvore recebeu arquivo"; return 0; }
  [ -L "$HC/blobs" ] || { falha "[2]: o symlink do hub foi alterado pelo push recusado"; return 0; }
  neutralizado; echo "OK [2] — push recusado citando SEC-001, sentinela e link do hub intactos"
}
c_2

echo "[3] ataque fs/pull — hub log/ é symlink para fora: pull RECUSADO"
c_3() {
  ataque
  prepara base3 fs
  local fora="$T/base3/fora-log"; mkdir -p "$fora"
  mv "$HC/log" "$T/base3/log-real"; ln -s "$fora" "$HC/log"
  local out rc
  set +e; out="$(LG "$R" sync "$CH" --pull-only 2>&1)"; rc=$?; set -e
  [ "$rc" -ne 0 ] || { falha "[3]: pull com hub/log symlink foi ACEITO (rc=0)"; return 0; }
  grep -qF 'é um link simbólico — recusado (SEC-001)' <<<"$out" \
    || { falha "[3]: recusou sem a causa da guarda (SEC-001). Saída: $(head -3 <<<"$out")"; return 0; }
  neutralizado; echo "OK [3] — pull recusado citando SEC-001"
}
c_3

echo "[4] ataque git — branch do canal com <canal>/blobs symlink: sync recusado antes do checkout"
c_4() {
  ataque
  local att="$T/base4/att" bare="$T/base4/hub.git"
  mkdir -p "$att"; git init -q --bare "$bare"
  git -C "$att" init -q; git -C "$att" remote add origin "$bare"
  git -C "$att" config user.email a@test; git -C "$att" config user.name a
  git -C "$att" config commit.gpgsign false
  git -C "$att" checkout -q --orphan "liaison/$CH"
  mkdir -p "$att/$CH/log"; : > "$att/$CH/log/.keep"
  ln -s "../../../../../../fora-git" "$att/$CH/blobs"
  git -C "$att" add -A; git -C "$att" commit -qm "chore: ataque" >/dev/null
  git -C "$att" push -q origin "liaison/$CH"
  mk_repo base4/v
  LG base4/v open "$CH" --self v --participants v,a >/dev/null
  LG base4/v transport set "$CH" --kind git --remote "$bare" --branch "liaison/$CH" >/dev/null
  local out rc
  set +e; out="$(LG base4/v sync "$CH" --pull-only 2>&1)"; rc=$?; set -e
  [ "$rc" -ne 0 ] || { falha "[4]: sync via git com symlink na branch foi ACEITO (rc=0)"; return 0; }
  grep -qF 'contém symlink ou submódulo' <<<"$out" \
    || { falha "[4]: recusou sem a causa da varredura da árvore. Saída: $(head -4 <<<"$out")"; return 0; }
  [ ! -L "$T/base4/v/.forge/cache/liaison/$CH/$CH/blobs" ] \
    || { falha "[4]: o cache local materializou o symlink de verdade"; return 0; }
  neutralizado; echo "OK [4] — sync via git recusado antes do checkout, cache sem link"
}
c_4

# ───────────────────────────────────────────────────────────────────────────────────────────────
# Cluster A — temporários previsíveis no hub (SEC-101/102, NODE-001, ARCH-001, LOG-001).

# c_tmp_log <id> <kind> — symlink plantado no antigo temporário do log. O push tem de seguir
# funcionando (o nome plantado é inerte) e a sentinela tem de sair intacta.
c_tmp_log() {
  local id="$1" kind="$2"
  ataque
  prepara "$id" "$kind"
  local alvo="$T/$id/fora/.bashrc"; sentinela "$alvo"
  ln -s "$alvo" "$HC/log/.v.jsonl.tmp"
  LG "$R" send "$CH" --thread t1 --kind note --subject "segunda" --body "segunda mensagem" >/dev/null
  local out rc
  set +e; out="$(LG "$R" sync "$CH" --push-only 2>&1)"; rc=$?; set -e
  intacta "$alvo" || { falha "[$id]: a escrita do log seguiu o symlink plantado — sentinela fora do hub sobrescrita"; return 0; }
  [ "$rc" -eq 0 ] || { falha "[$id]: push legítimo reprovou só porque havia um nome inerte plantado (rc=$rc): $(head -3 <<<"$out")"; return 0; }
  [ -f "$HC/log/v.jsonl" ] && [ ! -L "$HC/log/v.jsonl" ] \
    || { falha "[$id]: o log do hub não é um arquivo regular depois do push"; return 0; }
  cmp -s "$HC/log/v.jsonl" "$LOC/log/v.jsonl" \
    || { falha "[$id]: o log do hub não ficou igual à união local"; return 0; }
  neutralizado; echo "OK [$id] — $kind: temporário privado + nome aleatório; sentinela intacta, log publicado"
}
echo "[A1] fs — symlink no antigo temporário do log não desvia a escrita da união"
c_tmp_log A1 fs
echo "[A2] fs-union — idem"
c_tmp_log A2 fs-union

echo "[A3] reparo (--repair-own-log) — symlink no antigo temporário do log não desvia a escrita"
c_A3() {
  ataque
  prepara A3 fs
  local alvo="$T/A3/fora/.zshrc"; sentinela "$alvo"
  # Divergência real: o hub passa a ter content_sha diferente num msg_id que a réplica também tem.
  perl -pi -e 's/("content_sha":")[0-9a-f]/${1}z/ if $. == 1' "$HC/log/v.jsonl"
  ln -s "$alvo" "$HC/log/.v.jsonl.tmp"
  local out rc
  set +e; out="$(LG "$R" sync "$CH" --push-only --repair-own-log 2>&1)"; rc=$?; set -e
  intacta "$alvo" || { falha "[A3]: o reparo seguiu o symlink plantado — sentinela sobrescrita"; return 0; }
  [ "$rc" -eq 0 ] || { falha "[A3]: reparo declarado reprovou (rc=$rc): $(head -3 <<<"$out")"; return 0; }
  [ ! -L "$HC/log/v.jsonl" ] || { falha "[A3]: o log do hub virou symlink depois do reparo"; return 0; }
  cmp -s "$HC/log/v.jsonl" "$LOC/log/v.jsonl" \
    || { falha "[A3]: o reparo não publicou a versão local"; return 0; }
  neutralizado; echo "OK [A3] — reparo publica por nome aleatório; sentinela intacta"
}
c_A3

echo "[A4] blob — symlink no antigo temporário de blob não desvia a escrita"
c_A4() {
  ataque
  prepara A4 fs
  printf 'touch %s/A4/PWNED\n' "$T" > "$T/A4/anexo.sh"
  LG "$R" send "$CH" --thread t1 --kind note --subject anexo --body-file "$T/A4/anexo.sh" >/dev/null
  LG "$R" sync "$CH" --push-only >/dev/null
  local x; x="$(ls "$HC/blobs")"
  [ -n "$x" ] || { falha "[A4]: pré-condição — o push não publicou o blob"; return 0; }
  local alvo="$T/A4/fora/.zshrc"; sentinela "$alvo"
  rm -f "$HC/blobs/$x"; ln -s "$alvo" "$HC/blobs/.$x.tmp"
  local out rc
  set +e; out="$(LG "$R" sync "$CH" --push-only 2>&1)"; rc=$?; set -e
  intacta "$alvo" || { falha "[A4]: a cópia do blob seguiu o symlink plantado — sentinela sobrescrita"; return 0; }
  [ "$rc" -eq 0 ] || { falha "[A4]: push legítimo reprovou (rc=$rc): $(head -3 <<<"$out")"; return 0; }
  cmp -s "$HC/blobs/$x" "$LOC/blobs/$x" || { falha "[A4]: o blob não foi republicado no hub"; return 0; }
  neutralizado; echo "OK [A4] — blob republicado por nome aleatório; sentinela intacta"
}
c_A4

echo "[A5] blob com +x na origem sai sem bit de execução no hub"
c_A5() {
  prepara A5 fs
  printf '#!/bin/sh\necho anexo\n' > "$T/A5/anexo.sh"
  LG "$R" send "$CH" --thread t1 --kind note --subject anexo --body-file "$T/A5/anexo.sh" >/dev/null
  local b; for b in "$LOC"/blobs/*; do chmod 0755 "$b"; done
  LG "$R" sync "$CH" --push-only >/dev/null || { falha "[A5]: push legítimo reprovou"; return 0; }
  local x; x="$(ls "$HC/blobs")"
  [ -n "$x" ] || { falha "[A5]: o push não publicou o blob"; return 0; }
  if tem_bit_x "$HC/blobs/$x"; then falha "[A5]: blob publicado no hub com bit de execução"; return 0; fi
  echo "OK [A5] — blob publicado sem bit de execução"
}
c_A5

echo "[A6] log/<self>.jsonl do hub é symlink — push RECUSADO"
c_A6() {
  ataque
  prepara A6 fs
  local alvo="$T/A6/fora/.profile"; sentinela "$alvo"
  rm -f "$HC/log/v.jsonl"; ln -s "$alvo" "$HC/log/v.jsonl"
  LG "$R" send "$CH" --thread t1 --kind note --subject "segunda" --body "segunda" >/dev/null
  local out rc
  set +e; out="$(LG "$R" sync "$CH" --push-only 2>&1)"; rc=$?; set -e
  intacta "$alvo" || { falha "[A6]: a sentinela apontada por log/v.jsonl foi sobrescrita"; return 0; }
  [ "$rc" -ne 0 ] || { falha "[A6]: push com log/v.jsonl symlink foi ACEITO"; return 0; }
  grep -qF 'é um link simbólico — recusado (SEC-001)' <<<"$out" \
    || { falha "[A6]: recusou sem a causa da guarda. Saída: $(head -3 <<<"$out")"; return 0; }
  neutralizado; echo "OK [A6] — push recusado citando SEC-001, sentinela intacta"
}
c_A6

echo "[A7] blobs/<nome> do hub é symlink — push RECUSADO com rc≠0"
c_A7() {
  ataque
  prepara A7 fs
  printf 'anexo legítimo\n' > "$T/A7/anexo.md"
  LG "$R" send "$CH" --thread t1 --kind note --subject anexo --body-file "$T/A7/anexo.md" >/dev/null
  local x; x="$(ls "$LOC/blobs")"
  local alvo="$T/A7/fora/alvo"; sentinela "$alvo"
  mkdir -p "$HC/blobs"; ln -s "$alvo" "$HC/blobs/$x"
  local out rc
  set +e; out="$(LG "$R" sync "$CH" --push-only 2>&1)"; rc=$?; set -e
  intacta "$alvo" || { falha "[A7]: a sentinela apontada por blobs/<nome> foi sobrescrita"; return 0; }
  [ "$rc" -ne 0 ] || { falha "[A7]: push com blobs/<nome> symlink terminou rc=0 — a recusa foi engolida"; return 0; }
  grep -qF 'é um link simbólico — recusado (SEC-001)' <<<"$out" \
    || { falha "[A7]: recusou sem a causa da guarda. Saída: $(head -3 <<<"$out")"; return 0; }
  neutralizado; echo "OK [A7] — push recusado com rc≠0 citando SEC-001"
}
c_A7

# ───────────────────────────────────────────────────────────────────────────────────────────────
echo "[M2] mutação — publicação volta a usar temporário previsível sem O_EXCL: [A1] contamina"
c_M2() {
  prepara M2 fs
  local common="$T/M2/v/.forge/scripts/lib/transports/_common.sh"
  cp "$common" "$T/M2/common.orig"
  # Âncora única: a linha que cria o temporário de publicação (nome aleatório + noclobber).
  perl -0pi -e 's/tmp="\.liaison-publica\.\$\$\.\$RANDOM\$RANDOM\.tmp"; set -C/tmp=".\$nome.tmp"; set +C/' "$common"
  if cmp -s "$common" "$T/M2/common.orig"; then falha "[M2]: a mutação não alterou _common.sh — âncora do perl não casou"; return 0; fi
  local alvo="$T/M2/fora/.bashrc"; sentinela "$alvo"
  ln -s "$alvo" "$HC/log/.v.jsonl.tmp"
  LG "$R" send "$CH" --thread t1 --kind note --subject "mutante" --body "mutante" >/dev/null
  set +e; LG "$R" sync "$CH" --push-only >/dev/null 2>&1; set -e
  if intacta "$alvo"; then falha "[M2]: sem nome aleatório nem O_EXCL a sentinela ficou intacta — [A1] não mede o helper"; return 0; fi
  cp "$T/M2/common.orig" "$common"
  cmp -s "$common" "$T/M2/common.orig" || { falha "[M2]: restauração não bateu byte a byte"; return 0; }
  # RECONTROLE: restaurado, o mesmo ataque volta a ser neutralizado.
  sentinela "$alvo"; rm -f "$HC/log/.v.jsonl.tmp" "$HC/log/v.jsonl"
  ln -s "$alvo" "$HC/log/.v.jsonl.tmp"
  LG "$R" send "$CH" --thread t1 --kind note --subject "recontrole" --body "recontrole" >/dev/null
  set +e; LG "$R" sync "$CH" --push-only >/dev/null 2>&1; set -e
  intacta "$alvo" || { falha "[M2]: recontrole — restaurado o helper, a sentinela ainda foi sobrescrita"; return 0; }
  echo "OK [M2] — mutante contamina a sentinela; restaurado, volta a segurar"
}
c_M2

# ───────────────────────────────────────────────────────────────────────────────────────────────
echo "[5] contador de controle — ataques exercitados = ataques neutralizados, e > 0"
# shellcheck source=/dev/null
. "$WS/template/.forge/scripts/lib/gate-universe.sh"
if ! forge_universe_check "w321/ataques-neutralizados" "$NEUTRALIZADOS" "ataque(s) neutralizado(s)" \
     "cenários de ataque deste gate, medidos em execução" "$WS"; then
  falha "[5]: nenhum ataque neutralizado foi medido"
fi
[ "$ATAQUES" -gt 0 ] && [ "$NEUTRALIZADOS" -eq "$ATAQUES" ] \
  || falha "[5]: $NEUTRALIZADOS de $ATAQUES ataque(s) exercitado(s) terminaram neutralizados"
set +e
out5="$(forge_universe_check "w321/ataques-neutralizados" 0 "ataque(s)" "contrapositiva" "$WS" 2>&1)"; rc5=$?
set -e
[ "$rc5" -ne 0 ] || falha "[5]: universo vazio aprovou — $out5"

if [ "$FALHAS" -ne 0 ]; then
  echo "FAIL w321-liaison-symlink-traversal — $FALHAS falha(s); $NEUTRALIZADOS/$ATAQUES ataque(s) neutralizado(s)"
  exit 1
fi
echo "PASS w321-liaison-symlink-traversal — $NEUTRALIZADOS/$ATAQUES ataque(s) neutralizado(s)"
