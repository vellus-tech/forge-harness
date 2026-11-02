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
#   [A5b] o mesmo sob `umask 000`: blob e log publicados sem escrita para grupo/outros (QUAL-203)
#   [A6] `log/<self>.jsonl` do hub é symlink — push RECUSADO citando SEC-001, sentinela intacta
#   [A7] `blobs/<nome>` do hub é symlink — push RECUSADO (rc≠0), nunca `continue` silencioso
#   [A8] temporário de publicação adivinhado e plantado como symlink para FIFO: a abertura
#        exclusiva recusa, nada atravessa (SEC-203 — `set -C` não era O_EXCL)
#   [A9] temporário de publicação órfão na réplica nunca é publicado como blob (LOG-202)
#   [A10] nome final do log ocupado por diretório: recusa, nada movido para dentro, sem órfão
#   [B1] o diretório do canal inteiro é symlink — push e pull RECUSADOS, nada criado fora
#   [B2] `path` configurado como symlink legítimo (manual e fs) continua funcionando (ARCH-004)
#   [B5] CDPATH no ambiente não desvia um `path` relativo (fs e manual — LOG-204)
#   [B3] TOCTOU tornado determinístico: `log/` vira symlink entre as guardas e a escrita (um shim
#        de `node` troca o diretório na chamada da união) — a âncora física recusa, nada sai
#   [B4] `transport probe` de fs e fs-union recusa canal symlink ANTES de criar diretório
#   [C1] git: symlink aninhado `<canal>/blobs/sub/x` — pull e push RECUSADOS, cache sem link
#   [C2] git: submódulo (gitlink 160000) dentro do canal — idem
#   [C3] git: variante de caixa `CH/blobs` (o pathspec diferencia maiúsculas; APFS/NTFS não) — idem
#   [C4] git: symlink seguido de 12000 entradas, pelo `liaison-ops.sh` que roda sob
#        `set -euo pipefail` — a varredura não é pulada por SIGPIPE
#   [C5] git: cache contaminado por versão vulnerável — (a) branch envenenada com o link já
#        materializado: recusa e limpa; (b) branch limpa com link não rastreado herdado: a árvore
#        herdada é descartada e o push publica sem link
#   [C6] git: recusa do `_dir_push` (divergência) propaga — rc≠0 e nenhuma marca d'água falsa
#   [C6b] o mesmo no caminho de corrida do `t_push` (primeiro push rejeitado por shim, divergência
#        plantada entre as tentativas) — QUAL-202
#   [F1] `fs-union` recusa, antes de publicar, um `_common.sh` do tronco sem `_dir_publish_file` ou
#        sem `_dir_reject_symlink` (tronco anterior a SEC-001)
#   [G1] pull: entrada do hub com hardlink (nlink>1) para um segredo da vítima é ignorada com aviso
#   [H1] pull: nome com `\n` + symlink para o segredo — a linha injetada não vira entrada (SEC-201)
#   [H2] pull: nome com `\n` + hardlink para o segredo — idem (SEC-202)
#   [H3] pull: entrada regular vira symlink entre a enumeração e a leitura (shim) — SEC-105
#   [H4] pull: blob com conteúdo que não confere com o sha256 do nome não é instalado (SEC-002)
#   [R1] push: log próprio do hub é FIFO — recusa sem travar (NODE-201, SEC-204)
#   [R2] push: log próprio do hub é hardlink de log confidencial — recusa, nada unido nem republicado
#   [E1] export: `log/` e `blobs/` do diretório de saída como symlink — recusa (ARCH-201)
#   [E2] controle: export legítimo publica sem bit de execução e é importável
#   [L1] corrida: nome final do log vira symlink-para-diretório entre a guarda e a instalação —
#        `rename(2)` substitui o link, nada sai do hub (LOG-201)
#   [I1] import --from: bundle externo com blob symlink (nome sem prefixo sha256, fora do alcance do
#        SEC-002) para o segredo da vítima — RECUSADO no staging seguro, segredo nunca na réplica;
#        controle: o mesmo bundle com blob regular importa com o corpo (NODE-201, LDG-0233)
#   [I2] import --from: blob do bundle é FIFO — o import termina, sem travar
#   [I3] import --from: a RAIZ do bundle é symlink para o canal privado da vítima com outro peer (com e sem barra final) — RECUSADO citando SEC-001, nada cruza de canal; controle: symlink num componente PAI de `--from` continua aceito e importa com o corpo (NODE-201)
#   [M7] mutação — guarda A (staging do import) sozinha segura; sem A e sem B o segredo vaza; restauradas, volta
#   [M8] mutação — guarda B na leitura do blob de mensagem NOVA sozinha segura; sem ela e sem A, vaza
#   [M9] mutação — guarda B na leitura do blob da RECUPERAÇÃO sozinha segura; sem ela e sem A, vaza
#   [M10] mutação — a raiz do `--from` volta ao `cd -P` que segue o último componente: o canal privado vaza para o canal atacado; restaurada, segura
#   [5]  contador de controle medido — ataques exercitados = ataques neutralizados, e > 0
#   [M1] mutação pelo canal real (transporte `manual`) — sem a guarda de topo de `_dir_push` sobre
#        `blobs/`, a causa exclusiva dela some (a camada ancorada ainda recusa); restaurada, volta
#   [M2] mutação pelo canal real — nome do temporário FIXO com a abertura exclusiva mantida: recusa e
#        sentinela intacta; sem a exclusividade, contamina; restaurado, volta a segurar (QUAL-201)
#   [M5] mutação pelo canal real — a âncora deixa de conferir `pwd -P`: a corrida de [B3] volta a
#        escrever fora da árvore; restaurada, volta a segurar
#   [M6] mutação pelo canal real — a instalação troca `rename(2)` por `mv -f`: a corrida de [L1]
#        escreve fora; restaurado, volta a segurar
#   [M3] mutação pelo canal real — varredura `ls-tree` desligada: a causa exclusiva dela some (cenário
#        igual ao [4]) e `core.symlinks=false` ainda materializa o link como arquivo regular
#   [M4] mutação — além disso `core.symlinks=true`: o link materializa e só a checagem
#        pós-checkout o recusa (causa própria), limpando o cache; restaurado, a varredura volta
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

echo "[A5b] o mesmo sob umask 000: o blob publicado não tem escrita para grupo nem para outros (QUAL-203)"
c_A5b() {
  prepara A5b fs
  printf 'anexo sob umask 000\n' > "$T/A5b/anexo.md"
  LG "$R" send "$CH" --thread t1 --kind note --subject anexo --body-file "$T/A5b/anexo.md" >/dev/null
  ( umask 000; LG "$R" sync "$CH" --push-only >/dev/null ) || { falha "[A5b]: push legítimo sob umask 000 reprovou"; return 0; }
  local x; x="$(ls "$HC/blobs")"
  [ -n "$x" ] || { falha "[A5b]: o push não publicou o blob"; return 0; }
  [ -z "$(find "$HC/blobs/$x" \( -perm -0020 -o -perm -0002 \) -print)" ] \
    || { falha "[A5b]: blob publicado sob umask 000 com escrita para grupo/outros: $(ls -l "$HC/blobs/$x")"; return 0; }
  [ -z "$(find "$HC/log/v.jsonl" \( -perm -0020 -o -perm -0002 \) -print)" ] \
    || { falha "[A5b]: log publicado sob umask 000 com escrita para grupo/outros: $(ls -l "$HC/log/v.jsonl")"; return 0; }
  echo "OK [A5b] — sob umask 000 o publicado sai sem escrita para grupo/outros"
}
c_A5b

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

# fixa_nome_tmp <_common.sh> <liaison-hub-io.mjs> — fixture: simula o atacante que ADIVINHOU o nome
# do temporário de publicação, tornando-o constante ($TMP_FIXO) na cópia da réplica, onde quer que
# ele seja gerado (no módulo node por `randomBytes`, ou no shell antigo por `_liaison_unique_suffix`).
TMP_FIXO='.liaison-publica.PREVISTO.tmp'
fixa_nome_tmp() {
  local common="$1" mod="$2"
  if [ -f "$mod" ] && grep -qF "randomBytes(16).toString('hex')" "$mod"; then
    perl -pi -e "s/randomBytes\\(16\\)\\.toString\\('hex'\\)/'PREVISTO'/" "$mod"
    grep -qF "'PREVISTO'" "$mod"; return
  fi
  if grep -q '^_liaison_unique_suffix()' "$common"; then
    perl -pi -e 's/^_liaison_unique_suffix\(\) \{.*\}$/_liaison_unique_suffix() { printf PREVISTO; }/' "$common"
    grep -qF 'printf PREVISTO' "$common"; return
  fi
  return 1
}
# destrava_fifo <fifo> — abre o FIFO para escrita sem bloquear, para que um leitor ainda à espera
# receba EOF; sem leitor (ele já terminou), a abertura falha e nada acontece.
destrava_fifo() {
  node -e 'const f=require("fs");try{f.closeSync(f.openSync(process.argv[1],f.constants.O_WRONLY|f.constants.O_NONBLOCK))}catch{}' "$1"
}

echo "[A8] temporário de publicação adivinhado e plantado como symlink para FIFO: nada atravessa"
# SEC-203: `set -C` não é O_EXCL — o noclobber do bash só recusa nome existente que seja arquivo
# REGULAR; um symlink para FIFO (ou dispositivo) é aberto e escrito. Com o nome adivinhado (o
# `$RANDOM` do bash 3.2 é quase linear), o conteúdo publicado atravessa o link.
c_A8() {
  ataque
  prepara A8 fs
  fixa_nome_tmp "$T/A8/v/.forge/scripts/lib/transports/_common.sh" "$T/A8/v/.forge/scripts/lib/liaison-hub-io.mjs" \
    || { falha "[A8]: fixture — não foi possível fixar o nome do temporário"; return 0; }
  local fifo="$T/A8/fora/fifo" cap="$T/A8/fora/capturado" leitor out rc
  mkdir -p "$T/A8/fora"; mkfifo "$fifo"; : > "$cap"
  ( cat "$fifo" > "$cap" ) & leitor=$!
  ln -s "$fifo" "$HC/log/$TMP_FIXO"
  LG "$R" send "$CH" --thread t1 --kind note --subject "segunda" --body "segunda mensagem" >/dev/null
  set +e; out="$(LG "$R" sync "$CH" --push-only 2>&1)"; rc=$?; set -e
  destrava_fifo "$fifo"; wait "$leitor" 2>/dev/null || true
  [ ! -s "$cap" ] || { falha "[A8]: a publicação atravessou o symlink plantado no temporário e escreveu no FIFO (rc=$rc)"; return 0; }
  [ ! -L "$HC/log/v.jsonl" ] || { falha "[A8]: o log do hub virou symlink depois do push"; return 0; }
  [ "$rc" -ne 0 ] || { falha "[A8]: push com o temporário ocupado por symlink terminou rc=0"; return 0; }
  grep -qF 'SEC-001' <<<"$out" || { falha "[A8]: recusou sem a causa. Saída: $(head -3 <<<"$out")"; return 0; }
  neutralizado; echo "OK [A8] — temporário ocupado por symlink é recusado pela abertura exclusiva; nada atravessa"
}
c_A8

echo "[A9] temporário de publicação órfão na réplica local nunca é publicado no hub (LOG-202)"
c_A9() {
  prepara A9 fs
  mkdir -p "$LOC/blobs"; printf 'resto de publicação interrompida\n' > "$LOC/blobs/.liaison-publica.0123abcd.tmp"
  printf 'anexo legítimo\n' > "$T/A9/anexo.md"
  LG "$R" send "$CH" --thread t1 --kind note --subject anexo --body-file "$T/A9/anexo.md" >/dev/null
  LG "$R" sync "$CH" --push-only >/dev/null || { falha "[A9]: push legítimo reprovou"; return 0; }
  [ ! -e "$HC/blobs/.liaison-publica.0123abcd.tmp" ] || { falha "[A9]: o temporário órfão foi publicado no hub como se fosse blob"; return 0; }
  [ -n "$(ls "$HC/blobs")" ] || { falha "[A9]: o blob legítimo não foi publicado"; return 0; }
  echo "OK [A9] — temporário órfão ignorado, blob legítimo publicado"
}
c_A9

echo "[A10] nome final do log ocupado por diretório: push RECUSADO e nenhum temporário fica no hub"
c_A10() {
  ataque
  prepara A10 fs
  rm -f "$HC/log/v.jsonl"; mkdir "$HC/log/v.jsonl"; : > "$HC/log/v.jsonl/x"
  LG "$R" send "$CH" --thread t1 --kind note --subject "segunda" --body "segunda" >/dev/null
  local out rc
  set +e; out="$(LG "$R" sync "$CH" --push-only 2>&1)"; rc=$?; set -e
  [ "$rc" -ne 0 ] || { falha "[A10]: push com o nome final ocupado por diretório terminou rc=0"; return 0; }
  [ -z "$(find "$HC/log" -maxdepth 2 -name '.liaison-publica.*' -print)" ] \
    || { falha "[A10]: o caminho de erro deixou temporário no hub: $(find "$HC/log" -maxdepth 2 -name '.liaison-publica.*' -print | tr '\n' ' ')"; return 0; }
  [ -z "$(find "$HC/log/v.jsonl" -mindepth 1 ! -name x -print)" ] || { falha "[A10]: algo foi movido para DENTRO do diretório plantado"; return 0; }
  neutralizado; echo "OK [A10] — recusado, nada movido para dentro do diretório, nenhum temporário órfão"
}
c_A10


# ───────────────────────────────────────────────────────────────────────────────────────────────
# Cluster B — caminho físico fixado uma vez (SEC-103, ARCH-004) e guardas do probe (SEC-108).

echo "[B1] diretório do canal inteiro é symlink — push e pull RECUSADOS"
c_B1() {
  ataque
  prepara B1 fs
  local fora="$T/B1/fora-canal"; mkdir -p "$fora"
  mv "$HC" "$T/B1/canal-real"; ln -s "$fora" "$HC"
  LG "$R" send "$CH" --thread t1 --kind note --subject "segunda" --body "segunda" >/dev/null
  local out rc
  set +e; out="$(LG "$R" sync "$CH" --push-only 2>&1)"; rc=$?; set -e
  [ "$rc" -ne 0 ] || { falha "[B1]: push com o diretório do canal symlink foi ACEITO"; return 0; }
  grep -qF 'é um link simbólico — recusado (SEC-001)' <<<"$out" \
    || { falha "[B1]: push recusado sem a causa da guarda. Saída: $(head -3 <<<"$out")"; return 0; }
  set +e; out="$(LG "$R" sync "$CH" --pull-only 2>&1)"; rc=$?; set -e
  [ "$rc" -ne 0 ] || { falha "[B1]: pull com o diretório do canal symlink foi ACEITO"; return 0; }
  grep -qF 'é um link simbólico — recusado (SEC-001)' <<<"$out" \
    || { falha "[B1]: pull recusado sem a causa da guarda. Saída: $(head -3 <<<"$out")"; return 0; }
  [ -z "$(ls -A "$fora")" ] || { falha "[B1]: algo foi criado fora da árvore: $(ls -A "$fora" | tr '\n' ' ')"; return 0; }
  neutralizado; echo "OK [B1] — push e pull recusados, nada criado fora"
}
c_B1

echo "[B2] path configurado como symlink legítimo continua funcionando (manual e fs — ARCH-004)"
c_B2() {
  local kind
  for kind in manual fs; do
    local base="$T/B2-$kind" real atalho
    real="$base/real"; atalho="$base/atalho"
    mk_repo "B2-$kind/v"; mkdir -p "$real"; ln -s "$real" "$atalho"
    LG "B2-$kind/v" open "$CH" --self v --participants v,x >/dev/null
    LG "B2-$kind/v" transport set "$CH" --kind "$kind" --path "$atalho" >/dev/null
    LG "B2-$kind/v" thread open "$CH" t1 --subject abertura --participants v,x --body abertura >/dev/null
    local out rc dest
    set +e; out="$(LG "B2-$kind/v" sync "$CH" 2>&1)"; rc=$?; set -e
    [ "$rc" -eq 0 ] || { falha "[B2]: $kind com path symlink legítimo reprovou (rc=$rc): $(head -3 <<<"$out")"; return 0; }
    if [ "$kind" = manual ]; then dest="$real/log/v.jsonl"; else dest="$real/$CH/log/v.jsonl"; fi
    [ -f "$dest" ] || { falha "[B2]: $kind não publicou no destino real do symlink ($dest)"; return 0; }
  done
  echo "OK [B2] — manual e fs com path symlink (configuração confiável) publicam e puxam"
}
c_B2

echo "[B5] CDPATH no ambiente não desvia a resolução de um path relativo (fs e manual — LOG-204)"
# Com CDPATH definido, `cd -P -- hubrel` procura `hubrel` primeiro nos diretórios do CDPATH (e
# imprime o destino no stdout, poluindo o `$(cd … && pwd -P)`): o sync publicaria onde o operador
# nunca configurou. Toda resolução de caminho do liaison roda com `CDPATH=''`.
c_B5() {
  local kind ok=1
  for kind in fs manual; do
    ataque
    local base="B5-$kind"; mk_repo "$base/v"; mkdir -p "$T/$base/outro/hubrel"
    [ "$kind" = manual ] && mkdir -p "$T/$base/v/hubrel"
    local out rc dest
    set +e
    out="$(cd "$T/$base/v" \
      && LG "$base/v" open "$CH" --self v --participants v,x >/dev/null \
      && LG "$base/v" transport set "$CH" --kind "$kind" --path hubrel >/dev/null \
      && LG "$base/v" thread open "$CH" t1 --subject abertura --participants v,x --body abertura >/dev/null \
      && CDPATH="$T/$base/outro" LG "$base/v" sync "$CH" --push-only 2>&1)"; rc=$?
    set -e
    if [ "$kind" = manual ]; then dest="$T/$base/v/hubrel/log/v.jsonl"; else dest="$T/$base/v/hubrel/$CH/log/v.jsonl"; fi
    [ -z "$(find "$T/$base/outro" -type f -print)" ] || { falha "[B5]: $kind com CDPATH publicou no diretório do CDPATH: $(find "$T/$base/outro" -type f -print | tr '\n' ' ')"; ok=0; continue; }
    [ "$rc" -eq 0 ] || { falha "[B5]: $kind com CDPATH reprovou (rc=$rc): $(head -3 <<<"$out")"; ok=0; continue; }
    [ -f "$dest" ] || { falha "[B5]: $kind com CDPATH não publicou no path relativo configurado ($dest)"; ok=0; continue; }
    neutralizado
  done
  [ "$ok" -eq 0 ] || echo "OK [B5] — CDPATH não desvia fs nem manual"
}
c_B5

echo "[B3] TOCTOU — log/ vira symlink entre a guarda e a escrita: nada sai da árvore"
c_B3() {
  ataque
  prepara B3 fs
  local fora="$T/B3/fora-toctou"; mkdir -p "$fora"
  local realnode; realnode="$(command -v node)"
  mkdir -p "$T/B3/bin"
  # Interpõe-se ao `node` só na chamada da união: troca `log/` do hub por um symlink para fora no
  # instante seguinte às guardas e anterior a qualquer escrita — a corrida, tornada determinística.
  cat > "$T/B3/bin/node" <<EOF
#!/bin/sh
case "\$1" in
  */liaison-push-union.mjs)
    if [ -d "$HC/log" ] && [ ! -L "$HC/log" ]; then
      mv "$HC/log" "$HC/log.real" && ln -s "$fora" "$HC/log"
    fi ;;
esac
exec "$realnode" "\$@"
EOF
  chmod +x "$T/B3/bin/node"
  LG "$R" send "$CH" --thread t1 --kind note --subject "segunda" --body "segunda" >/dev/null
  local out rc
  set +e; out="$(PATH="$T/B3/bin:$PATH" LG "$R" sync "$CH" --push-only 2>&1)"; rc=$?; set -e
  [ -L "$HC/log" ] || { falha "[B3]: pré-condição — a troca do log/ não aconteceu (o shim não rodou)"; return 0; }
  [ -z "$(ls -A "$fora")" ] || { falha "[B3]: escrita fora da árvore pela corrida: $(ls -A "$fora" | tr '\n' ' ')"; return 0; }
  [ "$rc" -ne 0 ] || { falha "[B3]: push terminou rc=0 com o log/ trocado no meio"; return 0; }
  grep -qF 'não é o diretório físico esperado (SEC-001)' <<<"$out" \
    || { falha "[B3]: recusou sem a causa da âncora física. Saída: $(head -3 <<<"$out")"; return 0; }
  neutralizado; echo "OK [B3] — a âncora física recusa a troca no meio do sync, nada sai da árvore"
}
c_B3

echo "[B4] transport probe (fs e fs-union) recusa canal symlink antes de criar diretório"
c_B4() {
  local kind ok=1
  for kind in fs fs-union; do
    ataque
    prepara "B4-$kind" "$kind"
    local fora="$T/B4-$kind/fora-probe"; mkdir -p "$fora"
    rm -rf "$HC"; ln -s "$fora" "$HC"
    local out rc
    set +e; out="$(LG "$R" transport probe "$CH" 2>&1)"; rc=$?; set -e
    [ -z "$(ls -A "$fora")" ] || { falha "[B4]: $kind probe criou diretório fora da árvore: $(ls -A "$fora" | tr '\n' ' ')"; ok=0; continue; }
    [ "$rc" -ne 0 ] || { falha "[B4]: $kind probe aprovou um canal que é symlink"; ok=0; continue; }
    grep -qF 'é um link simbólico — recusado (SEC-001)' <<<"$out" \
      || { falha "[B4]: $kind probe recusou sem a causa. Saída: $(head -3 <<<"$out")"; ok=0; continue; }
    neutralizado
  done
  [ "$ok" -eq 0 ] || echo "OK [B4] — probe recusa antes do mkdir (fs e fs-union)"
}
c_B4


# ───────────────────────────────────────────────────────────────────────────────────────────────
# Cluster C — transporte git (SEC-104, PLAT-001/002/003, LOG-002/003).

# git_atacante <id> — remoto nu em $T/<id>/hub.git e índice do atacante em $T/<id>/att, numa branch
# órfã. As entradas entram por `update-index --cacheinfo`, sem depender do filesystem do atacante
# (é assim que se commita `CH/blobs` ao lado de `ch/` mesmo num disco que não diferencia caixa).
git_atacante() {
  local att="$T/$1/att"
  git init -q --bare "$T/$1/hub.git"
  git init -q "$att"
  git -C "$att" config user.email a@test; git -C "$att" config user.name a
  git -C "$att" config commit.gpgsign false
  git -C "$att" checkout -q --orphan "liaison/$CH"
}
entrada() { # entrada <id> <modo> <conteúdo-ou-sha> <caminho>
  local att="$T/$1/att" h
  if [ "$2" = 160000 ]; then h="$3"; else h="$(printf '%s' "$3" | git -C "$att" hash-object -w --stdin)"; fi
  git -C "$att" update-index --add --cacheinfo "$2,$h,$4"
}
publica() { # publica <id> — commit do índice atual do atacante, forçado na branch do canal
  local att="$T/$1/att" tree c
  tree="$(git -C "$att" write-tree)"
  c="$(git -C "$att" commit-tree -m "chore: ataque" "$tree")"
  git -C "$att" push -q -f "$T/$1/hub.git" "$c:refs/heads/liaison/$CH"
}
vitima_git() { # vitima_git <id> — réplica "v" com transporte git apontando para o remoto do cenário
  R="$1/v"; LOC="$T/$1/v/.forge/liaison/$CH"; VC="$T/$1/v/.forge/cache/liaison/$CH"
  mk_repo "$R"
  LG "$R" open "$CH" --self v --participants v,a >/dev/null
  LG "$R" transport set "$CH" --kind git --remote "$T/$1/hub.git" --branch "liaison/$CH" >/dev/null
}
links_no_cache() { # lista links simbólicos na árvore de trabalho do cache (fora de .git)
  [ -d "$1" ] || return 0
  find "$1" -path "$1/.git" -prune -o -type l -print
}

# c_git_recusa <id> <rótulo> — a branch já publicada pelo cenário tem de ser recusada pela
# varredura da árvore, tanto no pull quanto no push, sem nada fora e sem link no cache.
c_git_recusa() {
  local id="$1" rot="$2" fora="$T/$1/fora"
  local out rc
  set +e; out="$(LG "$R" sync "$CH" --pull-only 2>&1)"; rc=$?; set -e
  [ "$rc" -ne 0 ] || { falha "[$id]: pull aceitou a branch com $rot"; return 0; }
  grep -qF 'contém symlink ou submódulo' <<<"$out" \
    || { falha "[$id]: pull recusou sem a causa da varredura ($rot). Saída: $(head -3 <<<"$out")"; return 0; }
  LG "$R" thread open "$CH" t1 --subject abertura --participants v,a --body abertura >/dev/null
  set +e; out="$(LG "$R" sync "$CH" --push-only 2>&1)"; rc=$?; set -e
  [ "$rc" -ne 0 ] || { falha "[$id]: push aceitou a branch com $rot"; return 0; }
  grep -qF 'contém symlink ou submódulo' <<<"$out" \
    || { falha "[$id]: push recusou sem a causa da varredura ($rot). Saída: $(head -3 <<<"$out")"; return 0; }
  [ -z "$(links_no_cache "$VC")" ] || { falha "[$id]: link simbólico no cache: $(links_no_cache "$VC" | tr '\n' ' ')"; return 0; }
  [ -z "$(ls -A "$fora" 2>/dev/null)" ] || { falha "[$id]: algo foi escrito fora do cache"; return 0; }
  neutralizado; echo "OK [$id] — $rot recusado no pull e no push, cache sem link"
}

echo "[C1] git — symlink aninhado ch/blobs/sub/x"
c_C1() {
  ataque; git_atacante C1; mkdir -p "$T/C1/fora"
  entrada C1 100644 "" "$CH/log/.keep"
  entrada C1 120000 "$T/C1/fora/x" "$CH/blobs/sub/x"
  publica C1
  vitima_git C1
  c_git_recusa C1 "symlink aninhado"
}
c_C1

echo "[C2] git — submódulo (gitlink 160000) dentro do canal"
c_C2() {
  ataque; git_atacante C2
  entrada C2 100644 "" "$CH/log/.keep"
  entrada C2 160000 "$(printf '%040d' 7)" "$CH/sub"
  publica C2
  vitima_git C2
  c_git_recusa C2 "gitlink 160000"
}
c_C2

echo "[C3] git — variante de caixa CH/blobs (o pathspec diferencia maiúsculas; APFS/NTFS não)"
c_C3() {
  ataque; git_atacante C3; mkdir -p "$T/C3/fora"
  entrada C3 100644 "" "$CH/log/.keep"
  entrada C3 120000 "$T/C3/fora" "CH/blobs"
  publica C3
  vitima_git C3
  c_git_recusa C3 "variante de caixa CH/blobs"
}
c_C3

echo "[C4] git — árvore grande (≥ 10k entradas depois do symlink) sob set -euo pipefail"
c_C4() {
  ataque; git_atacante C4; mkdir -p "$T/C4/fora"
  entrada C4 100644 "" "$CH/log/.keep"
  entrada C4 120000 "$T/C4/fora" "$CH/blobs"
  local h; h="$(printf '' | git -C "$T/C4/att" hash-object -w --stdin)"
  awk -v h="$h" -v ch="$CH" 'BEGIN { for (i = 0; i < 12000; i++) printf "100644 %s\t%s/zz/%05d\n", h, ch, i }' \
    > "$T/C4/index-info"
  git -C "$T/C4/att" update-index --index-info < "$T/C4/index-info"
  publica C4
  vitima_git C4
  c_git_recusa C4 "symlink seguido de 12000 entradas"
}
c_C4

echo "[C5] git — cache pré-existente contaminado por versão vulnerável"
c_C5() {
  # (a) a branch continua envenenada e o cache já tem o link materializado (core.symlinks=true,
  #     como a versão sem a correção fazia): recusa E limpa — nada pode sobrar no cache.
  ataque; git_atacante C5a; mkdir -p "$T/C5a/fora"
  entrada C5a 100644 "" "$CH/log/.keep"
  entrada C5a 120000 "$T/C5a/fora" "$CH/blobs"
  publica C5a
  vitima_git C5a
  mkdir -p "$VC"; git -C "$VC" init -q; git -C "$VC" remote add origin "$T/C5a/hub.git"
  git -C "$VC" config core.symlinks true; git -C "$VC" fetch -q origin "liaison/$CH"
  git -C "$VC" checkout -q -B "liaison/$CH" FETCH_HEAD
  [ -L "$VC/$CH/blobs" ] || { falha "[C5a]: pré-condição — o cache não materializou o link"; return 0; }
  c_git_recusa C5a "cache contaminado"

  # (b) a branch está LIMPA, mas o cache traz um link não rastreado deixado pela versão antiga:
  #     o checkout não o remove; o sync tem de descartar a árvore herdada e seguir publicando.
  ataque; git_atacante C5b; mkdir -p "$T/C5b/fora"
  entrada C5b 100644 "" "$CH/log/.keep"
  publica C5b
  vitima_git C5b
  mkdir -p "$VC"; git -C "$VC" init -q; git -C "$VC" remote add origin "$T/C5b/hub.git"
  git -C "$VC" fetch -q origin "liaison/$CH"; git -C "$VC" checkout -q -B "liaison/$CH" FETCH_HEAD
  ln -s "$T/C5b/fora" "$VC/$CH/blobs"
  LG "$R" thread open "$CH" t1 --subject abertura --participants v,a --body abertura >/dev/null
  printf 'anexo legítimo\n' > "$T/C5b/anexo.md"
  LG "$R" send "$CH" --thread t1 --kind note --subject anexo --body-file "$T/C5b/anexo.md" >/dev/null
  local out rc
  set +e; out="$(LG "$R" sync "$CH" --push-only 2>&1)"; rc=$?; set -e
  [ -z "$(ls -A "$T/C5b/fora")" ] || { falha "[C5b]: o blob saiu do cache pelo link herdado"; return 0; }
  [ "$rc" -eq 0 ] || { falha "[C5b]: push contra branch limpa reprovou por causa do link herdado (rc=$rc): $(head -3 <<<"$out")"; return 0; }
  local modos; modos="$(git -C "$T/C5b/hub.git" ls-tree -r "liaison/$CH")"
  case "$modos" in *120000*|*160000*) falha "[C5b]: o push publicou um link na branch do canal"; return 0 ;; esac
  case "$modos" in *"$CH/blobs/"*) : ;; *) falha "[C5b]: o blob não chegou à branch"; return 0 ;; esac
  neutralizado; echo "OK [C5b] — árvore herdada descartada, push publica sem link"
}
c_C5

echo "[C6] git — recusa do _dir_push propaga: rc≠0 e nenhuma marca d'água de publicação"
c_C6() {
  ataque
  vitima_git C6
  git init -q --bare "$T/C6/hub.git"
  LG "$R" thread open "$CH" t1 --subject abertura --participants v,a --body abertura >/dev/null
  LG "$R" sync "$CH" --push-only >/dev/null || { falha "[C6]: pré-condição — primeiro push reprovou"; return 0; }
  # Um terceiro reescreve a história da vítima na branch: content_sha divergente no msg_id v-0001.
  local att="$T/C6/att"
  git clone -q -b "liaison/$CH" "$T/C6/hub.git" "$att"
  git -C "$att" config user.email a@test; git -C "$att" config user.name a; git -C "$att" config commit.gpgsign false
  perl -pi -e 's/("content_sha":")[0-9a-f]/${1}z/ if $. == 1' "$att/$CH/log/v.jsonl"
  git -C "$att" commit -qam "chore: reescrita" >/dev/null; git -C "$att" push -q origin "liaison/$CH"
  LG "$R" send "$CH" --thread t1 --kind note --subject "segunda" --body "segunda" >/dev/null
  local out rc
  set +e; out="$(LG "$R" sync "$CH" --push-only 2>&1)"; rc=$?; set -e
  [ "$rc" -ne 0 ] || { falha "[C6]: push com divergência no hub git terminou rc=0 — a recusa foi engolida"; return 0; }
  grep -qF 'DIVERGÊNCIA' <<<"$out" || { falha "[C6]: recusou sem a causa. Saída: $(head -3 <<<"$out")"; return 0; }
  case "$(cat "$LOC/state.json" 2>/dev/null)" in
    *'"v": "v-0002"'*) falha "[C6]: marca d'água de publicação gravada para uma mensagem que não foi publicada"; return 0 ;;
  esac
  neutralizado; echo "OK [C6] — recusa propagada, sem marca d'água falsa"
}
c_C6

echo "[C6b] git — corrida: o primeiro push é rejeitado e a divergência chega entre as tentativas (QUAL-202)"
# O t_push do git tem um SEGUNDO `_dir_push`, no caminho de corrida (push rejeitado → refaz o clone →
# republica). Um shim de `git` rejeita o primeiro push UMA vez e, nesse instante, um terceiro
# reescreve a história da vítima na branch: a recusa por divergência do segundo `_dir_push` tem de
# propagar — rc≠0, causa DIVERGÊNCIA e nenhuma marca d'água de publicação.
c_C6b() {
  ataque
  vitima_git C6b
  git init -q --bare "$T/C6b/hub.git"
  LG "$R" thread open "$CH" t1 --subject abertura --participants v,a --body abertura >/dev/null
  LG "$R" sync "$CH" --push-only >/dev/null || { falha "[C6b]: pré-condição — primeiro push reprovou"; return 0; }
  local realgit marca="$T/C6b/rejeitou" bin="$T/C6b/bin" att="$T/C6b/att"
  realgit="$(command -v git)"; mkdir -p "$bin"
  cat > "$bin/git" <<SHIM
#!/bin/sh
case " \$* " in
  *" push "*)
    if [ ! -e "$marca" ]; then
      : > "$marca"
      "$realgit" clone -q -b "liaison/$CH" "$T/C6b/hub.git" "$att" >/dev/null 2>&1
      "$realgit" -C "$att" config user.email a@test; "$realgit" -C "$att" config user.name a
      "$realgit" -C "$att" config commit.gpgsign false
      perl -pi -e 's/("content_sha":")[0-9a-f]/\${1}z/ if \$. == 1' "$att/$CH/log/v.jsonl"
      "$realgit" -C "$att" commit -qam "chore: reescrita" >/dev/null
      "$realgit" -C "$att" push -q origin "liaison/$CH" >/dev/null 2>&1
      echo "shim: push rejeitado uma vez (corrida simulada)" >&2
      exit 1
    fi ;;
esac
exec "$realgit" "\$@"
SHIM
  chmod +x "$bin/git"
  LG "$R" send "$CH" --thread t1 --kind note --subject "segunda" --body "segunda" >/dev/null
  local out rc
  set +e; out="$(PATH="$bin:$PATH" LG "$R" sync "$CH" --push-only 2>&1)"; rc=$?; set -e
  [ -e "$marca" ] || { falha "[C6b]: pré-condição — o shim não rejeitou o primeiro push"; return 0; }
  "$realgit" -C "$T/C6b/hub.git" show "liaison/$CH:$CH/log/v.jsonl" | grep -q '"content_sha":"z' \
    || { falha "[C6b]: pré-condição — a reescrita do terceiro não chegou ao remoto"; return 0; }
  [ "$rc" -ne 0 ] || { falha "[C6b]: push no caminho de corrida terminou rc=0 — a recusa do segundo _dir_push foi engolida"; return 0; }
  grep -qF 'DIVERGÊNCIA' <<<"$out" || { falha "[C6b]: recusou sem a causa. Saída: $(head -3 <<<"$out")"; return 0; }
  case "$(cat "$LOC/state.json" 2>/dev/null)" in
    *'"v": "v-0002"'*) falha "[C6b]: marca d'água de publicação gravada no caminho de corrida"; return 0 ;;
  esac
  neutralizado; echo "OK [C6b] — no caminho de corrida a divergência propaga: rc≠0, sem marca d'água"
}
c_C6b

echo "[M3] mutação — varredura da árvore desligada: [4] perde a causa; [M4] + core.symlinks=true: o link materializa"
c_M34() {
  git_atacante M3; mkdir -p "$T/M3/fora"
  entrada M3 100644 "" "$CH/log/.keep"
  entrada M3 120000 "$T/M3/fora" "$CH/blobs"
  publica M3
  vitima_git M3
  local gitsh="$T/M3/v/.forge/scripts/lib/transports/git.sh" out
  cp "$gitsh" "$T/M3/git.orig"
  # CONTROLE: a varredura recusa com a causa própria dela.
  set +e; out="$(LG "$R" sync "$CH" --pull-only 2>&1)"; set -e
  grep -qF 'contém symlink ou submódulo' <<<"$out" || { falha "[M3]: controle — a varredura não recusou"; return 0; }
  # MUTANTE (iii): a varredura nunca acha nada.
  perl -0pi -e 's/END\{exit !f\}/END{exit 1}/' "$gitsh"
  if cmp -s "$gitsh" "$T/M3/git.orig"; then falha "[M3]: a mutação (iii) não alterou git.sh — âncora do perl não casou"; return 0; fi
  set +e; out="$(LG "$R" sync "$CH" --pull-only 2>&1)"; set -e
  if grep -qF 'contém symlink ou submódulo' <<<"$out"; then falha "[M3]: sem a varredura a causa dela continuou aparecendo — a âncora não distingue a camada"; return 0; fi
  # Com a varredura desligada, `core.symlinks=false` ainda segura: o link vira arquivo de texto.
  [ -f "$VC/$CH/blobs" ] && [ ! -L "$VC/$CH/blobs" ] \
    || { falha "[M3]: sem a varredura, core.symlinks=false não materializou o link como arquivo regular"; return 0; }
  [ -z "$(ls -A "$T/M3/fora")" ] || { falha "[M3]: algo saiu do cache sob o mutante (iii)"; return 0; }
  echo "OK [M3] — sem a varredura a causa some; core.symlinks=false ainda segura (arquivo regular)"
  # MUTANTE (iv): além disso, core.symlinks=true — a checagem pós-checkout é a última camada.
  perl -0pi -e 's/config core\.symlinks false/config core.symlinks true/' "$gitsh"
  set +e; out="$(LG "$R" sync "$CH" --pull-only 2>&1)"; set -e
  if [ -f "$VC/$CH/blobs" ] && [ ! -L "$VC/$CH/blobs" ]; then falha "[M4]: com core.symlinks=true o checkout ainda deu arquivo regular — [M3] não mede core.symlinks"; return 0; fi
  grep -qF 'materializou link simbólico no cache' <<<"$out" \
    || { falha "[M4]: o link materializado não foi recusado pela checagem pós-checkout. Saída: $(head -3 <<<"$out")"; return 0; }
  [ -z "$(links_no_cache "$VC")" ] || { falha "[M4]: a checagem pós-checkout recusou mas deixou o link no cache"; return 0; }
  [ -z "$(ls -A "$T/M3/fora")" ] || { falha "[M4]: algo saiu do cache sob o mutante (iv)"; return 0; }
  # RECONTROLE: restaurado, a varredura volta a recusar com a causa própria.
  cp "$T/M3/git.orig" "$gitsh"
  cmp -s "$gitsh" "$T/M3/git.orig" || { falha "[M4]: restauração não bateu byte a byte"; return 0; }
  set +e; out="$(LG "$R" sync "$CH" --pull-only 2>&1)"; set -e
  grep -qF 'contém symlink ou submódulo' <<<"$out" || { falha "[M4]: recontrole — restaurado, a varredura não recusou"; return 0; }
  echo "OK [M4] — com core.symlinks=true o link materializa e só a checagem pós-checkout o pega; restaurado, a varredura volta"
}
c_M34


# ───────────────────────────────────────────────────────────────────────────────────────────────
# Cluster F — fs-union recusa um _common.sh do tronco sem as guardas de SEC-001 (SEC-106, ARCH-005).

echo "[F1] fs-union — _common.sh do tronco sem o helper de publicação ou sem a guarda de symlink: RECUSA"
c_F1() {
  local falta
  for falta in _dir_publish_file _dir_reject_symlink; do
    ataque
    prepara "F1$falta" fs-union
    local common="$T/F1$falta/v/.forge/scripts/lib/transports/_common.sh"
    # Fixture: o tronco perde a DEFINIÇÃO da função (renomeada), como um tronco anterior à correção.
    perl -pi -e "s/^${falta}\\(\\) \\{/${falta}_ausente() {/" "$common"
    if grep -q "^${falta}() {" "$common"; then falha "[F1]: fixture — $falta continua definida no tronco"; continue; fi
    LG "$R" send "$CH" --thread t1 --kind note --subject "segunda" --body "segunda" >/dev/null
    local out rc
    set +e; out="$(LG "$R" sync "$CH" --push-only 2>&1)"; rc=$?; set -e
    [ "$rc" -ne 0 ] || { falha "[F1]: fs-union publicou com um tronco sem $falta"; continue; }
    grep -qF 'FAIL fs-union: o _common.sh do checkout principal não tem as guardas de SEC-001' <<<"$out" \
      || { falha "[F1]: recusou sem a causa ($falta). Saída: $(head -3 <<<"$out")"; continue; }
    neutralizado; echo "OK [F1] — tronco sem $falta recusado"
  done
}
c_F1

# ───────────────────────────────────────────────────────────────────────────────────────────────
# Cluster G — hardlink no hub é ignorado no pull (SEC-105, parcial).

echo "[G1] pull — entrada do hub com hardlink (nlink>1) é ignorada com aviso"
c_G1() {
  ataque
  mk_repo G1/v; mk_repo G1/x
  local H="$T/G1/hub" r
  for r in v x; do
    LG "G1/$r" open "$CH" --self "$r" --participants v,x >/dev/null
    LG "G1/$r" transport set "$CH" --kind fs --path "$H" >/dev/null
  done
  LG G1/x thread open "$CH" t1 --subject abertura --participants v,x --body abertura >/dev/null
  printf 'isca\n' > "$T/G1/isca.md"
  LG G1/x send "$CH" --thread t1 --kind note --subject anexo --body-file "$T/G1/isca.md" >/dev/null
  LG G1/x sync "$CH" --push-only >/dev/null
  local x; x="$(ls "$H/$CH/blobs")"
  local segredo="$T/G1/fora/.ssh/id_ed25519"; mkdir -p "$(dirname "$segredo")"
  printf 'SEGREDO-DA-VÍTIMA\n' > "$segredo"; chmod 600 "$segredo"
  rm -f "$H/$CH/blobs/$x"; ln "$segredo" "$H/$CH/blobs/$x"
  local out rc
  set +e; out="$(LG G1/v sync "$CH" --pull-only 2>&1)"; rc=$?; set -e
  local copia="$T/G1/v/.forge/liaison/$CH/blobs/$x"
  if [ -f "$copia" ] && grep -q 'SEGREDO' "$copia"; then falha "[G1]: o conteúdo hardlinkado entrou na réplica da vítima"; return 0; fi
  grep -qF 'mais de um vínculo (hardlink)' <<<"$out" \
    || { falha "[G1]: a entrada hardlinkada foi ignorada sem aviso. Saída: $(head -3 <<<"$out")"; return 0; }
  [ "$(find "$segredo" -perm 0600 -print)" = "$segredo" ] || { falha "[G1]: o modo do segredo mudou"; return 0; }
  neutralizado; echo "OK [G1] — hardlink ignorado com aviso, nada entra na réplica (rc=$rc)"
}
c_G1

# ───────────────────────────────────────────────────────────────────────────────────────────────
# Cluster H — a LEITURA do hub no pull (SEC-201, SEC-202, SEC-105, defesa do SEC-002).
#
# O pull enumerava com `find … | while read` e copiava com `cp` por caminho: um nome com `\n`
# injetava uma segunda linha que nunca passou pelos filtros (`-type f`, `-links 1`), e a troca entre
# a enumeração e a leitura seguia o link. O segredo da vítima entrava na réplica, de onde o push
# seguinte o publicava no hub.

# par_fs <id> — participantes v (vítima) e x (atacante) num hub `fs`; x abre a thread, manda um anexo
# e publica. Define HB (blobs/ do hub), X (nome do blob publicado), SEG (segredo da vítima, fora do
# hub e do repositório) e COPIA (onde o blob chegaria na réplica de v).
par_fs() {
  local id="$1" r
  mk_repo "$id/v"; mk_repo "$id/x"
  for r in v x; do
    LG "$id/$r" open "$CH" --self "$r" --participants v,x >/dev/null
    LG "$id/$r" transport set "$CH" --kind fs --path "$T/$id/hub" >/dev/null
  done
  LG "$id/x" thread open "$CH" t1 --subject abertura --participants v,x --body abertura >/dev/null
  printf 'isca legítima do anexo\n' > "$T/$id/isca.md"
  LG "$id/x" send "$CH" --thread t1 --kind note --subject anexo --body-file "$T/$id/isca.md" >/dev/null
  LG "$id/x" sync "$CH" --push-only >/dev/null
  HB="$T/$id/hub/$CH/blobs"; X="$(ls "$HB")"
  SEG="$T/$id/fora/.ssh/id_ed25519"; mkdir -p "$(dirname "$SEG")"
  printf 'SEGREDO-DA-VÍTIMA\n' > "$SEG"; chmod 600 "$SEG"
  COPIA="$T/$id/v/.forge/liaison/$CH/blobs/$X"
}

# c_nl <id> <symlink|hardlink> — o atacante troca o blob por um link para o segredo e planta um
# arquivo REGULAR cujo nome é `a\n<blob>`: a linha injetada aponta para o link.
c_nl() {
  local id="$1" modo="$2"
  ataque
  par_fs "$id"
  rm -f "$HB/$X"
  if [ "$modo" = symlink ]; then ln -s "$SEG" "$HB/$X"; else ln "$SEG" "$HB/$X"; fi
  : > "$HB/a
$X"
  local out rc
  set +e; out="$(LG "$id/v" sync "$CH" --pull-only 2>&1)"; rc=$?; set -e
  if [ -f "$COPIA" ] && grep -q 'SEGREDO' "$COPIA"; then
    falha "[$id]: o nome com \\n injetou o $modo e o segredo entrou na réplica da vítima (rc=$rc)"; return 0
  fi
  local causa='link simbólico no hub (SEC-001)'; [ "$modo" = hardlink ] && causa='mais de um vínculo (hardlink)'
  grep -qF "$causa" <<<"$out" || { falha "[$id]: o $modo foi ignorado sem aviso. Saída: $(head -3 <<<"$out")"; return 0; }
  grep -qF 'nome fora do padrão' <<<"$out" || { falha "[$id]: o nome com \\n foi ignorado sem aviso. Saída: $(head -3 <<<"$out")"; return 0; }
  neutralizado; echo "OK [$id] — nome com \\n não injeta entrada; o $modo é recusado com aviso"
}
echo "[H1] pull — nome com \\n + symlink para o segredo da vítima: nada entra na réplica"
c_nl H1 symlink
echo "[H2] pull — nome com \\n + hardlink para o segredo da vítima: idem"
c_nl H2 hardlink

echo "[H3] pull — a entrada vira symlink entre a enumeração e a leitura: o link nunca é seguido"
# Determinístico como o [B3]: um shim de `cp` E de `node` troca o blob regular por um link para o
# segredo na primeira chamada feita DE DENTRO de `blobs/` do hub. Na leitura por `find | cp` isso
# cai entre a enumeração e a cópia; na leitura pelo módulo node a enumeração e a abertura sem
# seguir link são o mesmo processo, então a troca mais tardia possível é antes dele — e o
# resultado exigido é o mesmo: o link nunca é seguido.
c_H3() {
  ataque
  par_fs H3
  local bin="$T/H3/bin" marca="$T/H3/trocou" prog real; mkdir -p "$bin"
  for prog in cp node; do
    real="$(command -v "$prog")"
    cat > "$bin/$prog" <<SHIM
#!/bin/sh
if [ "\$(pwd -P)" = "$HB" ] && [ ! -e "$marca" ]; then
  : > "$marca"; rm -f "$HB/$X"; ln -s "$SEG" "$HB/$X"
fi
exec "$real" "\$@"
SHIM
    chmod +x "$bin/$prog"
  done
  local out rc
  set +e; out="$(PATH="$bin:$PATH" LG H3/v sync "$CH" --pull-only 2>&1)"; rc=$?; set -e
  [ -e "$marca" ] || { falha "[H3]: pré-condição — a troca não aconteceu (o shim não rodou em blobs/)"; return 0; }
  if [ -f "$COPIA" ] && grep -q 'SEGREDO' "$COPIA"; then
    falha "[H3]: a troca entre a enumeração e a leitura levou o segredo para a réplica (rc=$rc)"; return 0
  fi
  neutralizado; echo "OK [H3] — a troca regular→symlink no meio do pull não é seguida"
}
c_H3

echo "[H4] pull — blob do hub com conteúdo que não confere com o sha256 do nome: não é instalado"
c_H4() {
  ataque
  par_fs H4
  printf 'conteúdo ADULTERADO no hub\n' > "$T/H4/adulterado"
  mv -f "$T/H4/adulterado" "$HB/$X"
  local out rc
  set +e; out="$(LG H4/v sync "$CH" --pull-only 2>&1)"; rc=$?; set -e
  if [ -f "$COPIA" ] && grep -q 'ADULTERADO' "$COPIA"; then
    falha "[H4]: o blob adulterado (sha256 do nome não confere) foi instalado na réplica (rc=$rc)"; return 0
  fi
  grep -qF 'não confere' <<<"$out" || { falha "[H4]: o blob adulterado foi descartado sem aviso. Saída: $(head -3 <<<"$out")"; return 0; }
  neutralizado; echo "OK [H4] — blob com sha divergente recusado com aviso, nada instalado"
}
c_H4

# ───────────────────────────────────────────────────────────────────────────────────────────────
# Cluster R — o push lê `hub/log/<self>.jsonl` UMA vez, pelo leitor seguro (NODE-201, SEC-204).
# Antes, a classificação e a união o liam por CAMINHO: um FIFO plantado travava o push para sempre,
# e um hardlink para um log confidencial (outro canal, mesmo filesystem) era unido à réplica e
# republicado no hub.

echo "[R1] push — log próprio do hub é FIFO: o push termina RECUSADO, sem travar"
c_R1() {
  ataque
  prepara R1 fs
  rm -f "$HC/log/v.jsonl"; mkfifo "$HC/log/v.jsonl"
  LG "$R" send "$CH" --thread t1 --kind note --subject "segunda" --body "segunda" >/dev/null
  local saida="$T/R1/push.out" rcf="$T/R1/push.rc" pid
  ( set +e; LG "$R" sync "$CH" --push-only >"$saida" 2>&1; echo $? > "$rcf" ) & pid=$!
  for _ in $(seq 1 40); do kill -0 "$pid" 2>/dev/null || break; perl -e 'select(undef,undef,undef,0.5)'; done
  if kill -0 "$pid" 2>/dev/null; then
    pkill -f "$T/R1/" 2>/dev/null || true; destrava_fifo "$HC/log/v.jsonl"; wait "$pid" 2>/dev/null || true
    falha "[R1]: o push TRAVOU por 20 s lendo o FIFO plantado no log próprio do hub"; return 0
  fi
  wait "$pid" 2>/dev/null || true
  local rc; rc="$(cat "$rcf" 2>/dev/null || echo '?')"
  [ "$rc" != 0 ] || { falha "[R1]: push com FIFO no log próprio do hub terminou rc=0"; return 0; }
  grep -qF 'SEC-001' "$saida" || { falha "[R1]: recusou sem a causa. Saída: $(head -3 "$saida")"; return 0; }
  neutralizado; echo "OK [R1] — FIFO no log próprio do hub é recusado sem travar (rc=$rc)"
}
c_R1

echo "[R2] push — log próprio do hub é hardlink de um log confidencial: RECUSADO, nada é unido nem republicado"
c_R2() {
  ataque
  prepara R2 fs
  local segredo="$T/R2/fora/confidencial.jsonl"; mkdir -p "$(dirname "$segredo")"
  printf '{"sender":"v","seq":7,"msg_id":"v-0007","content_sha":"s7","subject":"SEGREDO do canal confidencial"}\n' > "$segredo"
  rm -f "$HC/log/v.jsonl"; ln "$segredo" "$HC/log/v.jsonl"
  LG "$R" send "$CH" --thread t1 --kind note --subject "segunda" --body "segunda" >/dev/null
  local out rc
  set +e; out="$(LG "$R" sync "$CH" --push-only 2>&1)"; rc=$?; set -e
  if grep -q 'SEGREDO' "$LOC/log/v.jsonl"; then falha "[R2]: o conteúdo hardlinkado foi unido à réplica local (rc=$rc)"; return 0; fi
  if [ ! -L "$HC/log/v.jsonl" ] && [ "$(find "$HC/log/v.jsonl" -links 1 -print)" ] && grep -q 'SEGREDO' "$HC/log/v.jsonl"; then
    falha "[R2]: o conteúdo hardlinkado foi republicado no hub como arquivo novo (rc=$rc)"; return 0
  fi
  [ "$rc" -ne 0 ] || { falha "[R2]: push com o log próprio do hub hardlinkado terminou rc=0"; return 0; }
  grep -qF 'mais de um vínculo (hardlink)' <<<"$out" || { falha "[R2]: recusou sem a causa. Saída: $(head -3 <<<"$out")"; return 0; }
  neutralizado; echo "OK [R2] — hardlink no log próprio do hub recusado, nada unido nem republicado"
}
c_R2

# ───────────────────────────────────────────────────────────────────────────────────────────────
# Cluster E —`export` publica no diretório de saída pelos mesmos helpers do push (ARCH-201).
# O diretório de `--out` tem o mesmo layout do transporte `manual` e costuma ser compartilhado
# (pendrive, diretório de VPN); o `export` fazia `mkdir -p` + `cp` em `log/` e `blobs/` seguindo link.

echo "[E1] export — blobs/ e log/ do diretório de saída plantados como symlink: RECUSADO, nada sai"
c_E1() {
  local sub ok=1
  for sub in blobs log; do
    ataque
    local id="E1-$sub"; mk_repo "$id/a"
    LG "$id/a" open "$CH" --self a --participants a,b >/dev/null
    LG "$id/a" thread open "$CH" t1 --subject x --participants a,b --body x >/dev/null
    printf 'corpo\n' > "$T/$id/corpo.md"
    LG "$id/a" send "$CH" --thread t1 --kind note --subject s --body-file "$T/$id/corpo.md" >/dev/null
    local out_dir="$T/$id/compartilhado" fora="$T/$id/fora" out rc
    mkdir -p "$out_dir" "$fora"; ln -s "$fora" "$out_dir/$sub"
    set +e; out="$(LG "$id/a" export "$CH" --out "$out_dir" 2>&1)"; rc=$?; set -e
    [ -z "$(ls -A "$fora")" ] || { falha "[E1]: export seguiu o symlink em $sub/ e escreveu fora: $(ls -A "$fora" | tr '\n' ' ')"; ok=0; continue; }
    [ "$rc" -ne 0 ] || { falha "[E1]: export com $sub/ symlink terminou rc=0"; ok=0; continue; }
    grep -qF 'é um link simbólico — recusado (SEC-001)' <<<"$out" || { falha "[E1]: export recusou sem a causa ($sub). Saída: $(head -3 <<<"$out")"; ok=0; continue; }
    neutralizado
  done
  [ "$ok" -eq 0 ] || echo "OK [E1] — export recusa log/ e blobs/ symlink sem escrever fora"
}
c_E1

echo "[E2] controle — export legítimo publica log e blob, sem bit de execução, e import do bundle funciona"
c_E2() {
  mk_repo E2/a; mk_repo E2/b
  LG E2/a open "$CH" --self a --participants a,b >/dev/null
  LG E2/b open "$CH" --self b --participants a,b >/dev/null
  LG E2/a thread open "$CH" t1 --subject x --participants a,b --body x >/dev/null
  printf '#!/bin/sh\necho corpo\n' > "$T/E2/corpo.sh"
  LG E2/a send "$CH" --thread t1 --kind note --subject s --body-file "$T/E2/corpo.sh" >/dev/null
  chmod 0755 "$T/E2/a/.forge/liaison/$CH/blobs/"*
  LG E2/a export "$CH" --out "$T/E2/bundle" >/dev/null || { falha "[E2]: export legítimo reprovou"; return 0; }
  [ -f "$T/E2/bundle/log/a.jsonl" ] && [ -n "$(ls "$T/E2/bundle/blobs")" ] || { falha "[E2]: bundle sem log ou blob"; return 0; }
  if tem_bit_x "$T/E2/bundle/blobs"/*; then falha "[E2]: blob exportado com bit de execução"; return 0; fi
  LG E2/b import "$CH" --from "$T/E2/bundle" >/dev/null || { falha "[E2]: import do bundle exportado reprovou"; return 0; }
  [ -n "$(ls "$T/E2/b/.forge/liaison/$CH/blobs")" ] || { falha "[E2]: o import não trouxe o blob"; return 0; }
  echo "OK [E2] — export legítimo publica e o bundle é importável"
}
c_E2

# ───────────────────────────────────────────────────────────────────────────────────────────────
echo "[M1] mutação — sem a guarda de topo de _dir_push sobre blobs/, a recusa perde a causa dela"
# Pelo transporte `manual`, cujo probe não confere o hub: a primeira camada a ver o `blobs/` symlink
# é a guarda de topo de `_dir_push`, e a causa dela traz o caminho do hub por extenso. Sem ela, a
# camada ancorada (`_dir_ensure_subdir`) ainda recusa — defesa em profundidade —, mas com causa
# própria; é essa diferença que prova que a guarda de topo está viva.
c_M1() {
  prepara M1 manual
  local fora="$T/M1/fora-blobs"; mkdir -p "$fora"
  rm -rf "$HC/blobs"; ln -s "$fora" "$HC/blobs"
  printf 'anexo legítimo\n' > "$T/M1/anexo.md"
  LG "$R" send "$CH" --thread t1 --kind note --subject anexo --body-file "$T/M1/anexo.md" >/dev/null
  local common="$T/M1/v/.forge/scripts/lib/transports/_common.sh" ancora="'$HC/blobs' é um link simbólico — recusado (SEC-001)" out rc
  cp "$common" "$T/M1/common.orig"
  set +e; out="$(LG "$R" sync "$CH" --push-only 2>&1)"; rc=$?; set -e
  [ "$rc" -ne 0 ] && grep -qF "$ancora" <<<"$out" || { falha "[M1]: controle — a guarda de topo não recusou com a causa dela. Saída: $(head -3 <<<"$out")"; return 0; }
  perl -0pi -e 's/  _dir_reject_symlink "\$hub\/blobs" \|\| return 1\n(  hub="\$\(_dir_phys_expected "\$hub"\)" \|\| return 1\n  _dir_ensure_subdir )/$1/' "$common"
  if cmp -s "$common" "$T/M1/common.orig"; then falha "[M1]: a mutação não alterou _common.sh — âncora do perl não casou"; return 0; fi
  set +e; out="$(LG "$R" sync "$CH" --push-only 2>&1)"; rc=$?; set -e
  if grep -qF "$ancora" <<<"$out"; then falha "[M1]: sem a guarda de topo a causa dela continuou aparecendo — [2] não mede a guarda"; return 0; fi
  [ "$rc" -ne 0 ] && [ -z "$(ls -A "$fora")" ] \
    || { falha "[M1]: sem a guarda de topo a camada ancorada não segurou (rc=$rc)"; return 0; }
  cp "$T/M1/common.orig" "$common"
  cmp -s "$common" "$T/M1/common.orig" || { falha "[M1]: restauração não bateu byte a byte"; return 0; }
  set +e; out="$(LG "$R" sync "$CH" --push-only 2>&1)"; rc=$?; set -e
  [ "$rc" -ne 0 ] && grep -qF "$ancora" <<<"$out" || { falha "[M1]: recontrole — restaurada, a guarda de topo não recusou com a causa dela"; return 0; }
  echo "OK [M1] — sem a guarda de topo a causa some (a camada ancorada ainda segura); restaurada, volta"
}
c_M1

echo "[M2] mutação — nome do temporário fixo: com abertura exclusiva recusa; sem ela, contamina"
# QUAL-201: separa as duas camadas da publicação. Fixar o nome do temporário (o atacante "adivinhou")
# MANTENDO a abertura exclusiva tem de continuar seguro — recusa, sentinela intacta: é a prova de que
# a garantia é a exclusividade, não a imprevisibilidade. Tirar também a exclusividade contamina. O
# recontrole restaura o módulo e o mesmo nome plantado volta a ser inerte.
c_M2() {
  prepara M2 fs
  local mod="$T/M2/v/.forge/scripts/lib/liaison-hub-io.mjs" common="$T/M2/v/.forge/scripts/lib/transports/_common.sh"
  [ -f "$mod" ] || { falha "[M2]: módulo de publicação ausente ($mod) — a publicação não passa pelo módulo node"; return 0; }
  cp "$mod" "$T/M2/mod.orig"
  local alvo="$T/M2/fora/.bashrc" out rc
  # MUTANTE (i): nome fixo, abertura exclusiva mantida.
  fixa_nome_tmp "$common" "$mod" || { falha "[M2]: a fixação do nome não casou no módulo"; return 0; }
  sentinela "$alvo"; ln -s "$alvo" "$HC/log/$TMP_FIXO"
  LG "$R" send "$CH" --thread t1 --kind note --subject "mutante-i" --body "mutante-i" >/dev/null
  set +e; out="$(LG "$R" sync "$CH" --push-only 2>&1)"; rc=$?; set -e
  intacta "$alvo" || { falha "[M2]: com o nome fixo e a abertura exclusiva a sentinela foi sobrescrita — a exclusividade não segura"; return 0; }
  [ "$rc" -ne 0 ] || { falha "[M2]: com o nome fixo ocupado por symlink o push terminou rc=0"; return 0; }
  # MUTANTE (ii): além disso, a abertura deixa de ser exclusiva.
  perl -0pi -e "s/openSync\\(candidato, 'wx', 0o644\\)/openSync(candidato, 'w', 0o644)/" "$mod"
  grep -qF "openSync(candidato, 'w', 0o644)" "$mod" || { falha "[M2]: a mutação (ii) não casou no módulo"; return 0; }
  set +e; LG "$R" sync "$CH" --push-only >/dev/null 2>&1; set -e
  if intacta "$alvo"; then falha "[M2]: sem a abertura exclusiva a sentinela ficou intacta — [M2](i) não mede a exclusividade"; return 0; fi
  # RECONTROLE
  cp "$T/M2/mod.orig" "$mod"
  cmp -s "$mod" "$T/M2/mod.orig" || { falha "[M2]: restauração não bateu byte a byte"; return 0; }
  sentinela "$alvo"; rm -f "$HC/log/$TMP_FIXO" "$HC/log/v.jsonl"; ln -s "$alvo" "$HC/log/$TMP_FIXO"
  LG "$R" send "$CH" --thread t1 --kind note --subject "recontrole" --body "recontrole" >/dev/null
  set +e; out="$(LG "$R" sync "$CH" --push-only 2>&1)"; rc=$?; set -e
  intacta "$alvo" || { falha "[M2]: recontrole — restaurado o módulo, a sentinela ainda foi sobrescrita"; return 0; }
  [ "$rc" -eq 0 ] || { falha "[M2]: recontrole — push legítimo reprovou (rc=$rc): $(head -3 <<<"$out")"; return 0; }
  echo "OK [M2] — nome fixo + exclusividade recusa; sem exclusividade contamina; restaurado, volta a segurar"
}
c_M2


echo "[M5] mutação — a âncora física deixa de conferir pwd -P: [B3] volta a escrever fora"
# toctou_push <id> — prepara a réplica, instala o shim que troca log/ na chamada da união e roda o
# push pelo canal real. Deixa em $FORA o diretório-alvo da troca.
toctou_push() {
  local id="$1" realnode; realnode="$(command -v node)"
  FORA="$T/$id/fora-toctou"; mkdir -p "$FORA" "$T/$id/bin"
  cat > "$T/$id/bin/node" <<SHIM
#!/bin/sh
case "\$1" in
  */liaison-push-union.mjs)
    if [ -d "$HC/log" ] && [ ! -L "$HC/log" ]; then
      mv "$HC/log" "$HC/log.real.\$\$" && ln -s "$FORA" "$HC/log"
    fi ;;
esac
exec "$realnode" "\$@"
SHIM
  chmod +x "$T/$id/bin/node"
  LG "$R" send "$CH" --thread t1 --kind note --subject "toctou" --body "toctou" >/dev/null
  set +e; PATH="$T/$id/bin:$PATH" LG "$R" sync "$CH" --push-only >/dev/null 2>&1; set -e
}
restaura_log() { rm -f "$HC/log"; local d; for d in "$HC"/log.real.*; do mv "$d" "$HC/log"; break; done; rm -rf "${FORA:?}"/* "${FORA:?}"/.[!.]* 2>/dev/null || true; }
c_M5() {
  prepara M5 fs
  local common="$T/M5/v/.forge/scripts/lib/transports/_common.sh"
  cp "$common" "$T/M5/common.orig"
  # CONTROLE: com a âncora, a troca no meio do sync não escreve fora.
  toctou_push M5
  [ -z "$(ls -A "$FORA")" ] || { falha "[M5]: controle — escrita fora mesmo com a âncora"; return 0; }
  restaura_log
  perl -0pi -e 's/if \[ "\$\(pwd -P\)" != "\$1" \]; then/if false; then/' "$common"
  if cmp -s "$common" "$T/M5/common.orig"; then falha "[M5]: a mutação não alterou _common.sh — âncora do perl não casou"; return 0; fi
  toctou_push M5
  [ -n "$(ls -A "$FORA")" ] || { falha "[M5]: sem a conferência de pwd -P nada saiu da árvore — [B3] não mede a âncora"; return 0; }
  restaura_log
  cp "$T/M5/common.orig" "$common"
  cmp -s "$common" "$T/M5/common.orig" || { falha "[M5]: restauração não bateu byte a byte"; return 0; }
  # RECONTROLE
  toctou_push M5
  [ -z "$(ls -A "$FORA")" ] || { falha "[M5]: recontrole — restaurada a âncora, ainda escreveu fora"; return 0; }
  echo "OK [M5] — sem a conferência de pwd -P a corrida escreve fora; restaurada, segura"
}
c_M5

echo "[L1] corrida — o nome FINAL do log vira symlink-para-diretório entre a guarda e a instalação"
# LOG-201: a instalação por `rename(2)` é load-bearing? Um shim de `node` planta, na chamada da
# união (depois de toda guarda sobre `log/<self>.jsonl` e antes da publicação), um symlink para um
# diretório de fora no nome final. `rename` substitui o link sem segui-lo; `mv -f` moveria o
# arquivo para DENTRO do diretório apontado, isto é, para fora do hub.
# rename_push <id> — roda o push com o shim e deixa em $FORA o diretório-alvo do link.
rename_push() {
  local id="$1" realnode; realnode="$(command -v node)"
  FORA="$T/$id/fora-rename"; mkdir -p "$FORA" "$T/$id/bin"
  cat > "$T/$id/bin/node" <<SHIM
#!/bin/sh
case "\$1" in
  */liaison-push-union.mjs) rm -f "$HC/log/v.jsonl"; ln -s "$FORA" "$HC/log/v.jsonl" ;;
esac
exec "$realnode" "\$@"
SHIM
  chmod +x "$T/$id/bin/node"
  LG "$R" send "$CH" --thread t1 --kind note --subject "rename" --body "rename" >/dev/null
  set +e; RENAME_OUT="$(PATH="$T/$id/bin:$PATH" LG "$R" sync "$CH" --push-only 2>&1)"; RENAME_RC=$?; set -e
}
c_L1() {
  ataque
  prepara L1 fs
  rename_push L1
  [ -z "$(ls -A "$FORA")" ] || { falha "[L1]: a instalação seguiu o symlink-para-diretório plantado no nome final: $(ls -A "$FORA" | tr '\n' ' ')"; return 0; }
  [ -f "$HC/log/v.jsonl" ] && [ ! -L "$HC/log/v.jsonl" ] || { falha "[L1]: o nome final não ficou arquivo regular (o link plantado sobreviveu)"; return 0; }
  [ "$RENAME_RC" -eq 0 ] || { falha "[L1]: push reprovou (rc=$RENAME_RC): $(head -3 <<<"$RENAME_OUT")"; return 0; }
  neutralizado; echo "OK [L1] — rename(2) substitui o link plantado no nome final, nada sai do hub"
}
c_L1

echo "[M6] mutação — a instalação troca rename(2) por mv -f: [L1] passa a escrever fora"
c_M6() {
  prepara M6 fs
  local mod="$T/M6/v/.forge/scripts/lib/liaison-hub-io.mjs"
  cp "$mod" "$T/M6/mod.orig"
  # CONTROLE
  rename_push M6
  [ -z "$(ls -A "$FORA")" ] || { falha "[M6]: controle — escrita fora mesmo com rename(2)"; return 0; }
  rm -f "$HC/log/v.jsonl"; rm -rf "$FORA"
  # MUTANTE: `mv -f` no lugar do rename.
  perl -0pi -e "s/import \\{ randomBytes \\} from 'node:crypto';/import { randomBytes } from 'node:crypto';\\nimport { execFileSync } from 'node:child_process';/; s/renameSync\\(tmp, nome\\);/execFileSync('mv', ['-f', tmp, nome]);/" "$mod"
  grep -qF "execFileSync('mv', ['-f', tmp, nome]);" "$mod" || { falha "[M6]: a mutação não casou no módulo"; return 0; }
  rename_push M6
  [ -n "$(ls -A "$FORA")" ] || { falha "[M6]: com mv -f nada saiu do hub — [L1] não mede o rename(2)"; return 0; }
  rm -f "$HC/log/v.jsonl"; rm -rf "$FORA"
  # RECONTROLE
  cp "$T/M6/mod.orig" "$mod"
  cmp -s "$mod" "$T/M6/mod.orig" || { falha "[M6]: restauração não bateu byte a byte"; return 0; }
  rename_push M6
  [ -z "$(ls -A "$FORA")" ] || { falha "[M6]: recontrole — restaurado o rename, ainda escreveu fora"; return 0; }
  echo "OK [M6] — com mv -f a corrida escreve fora; restaurado o rename(2), segura"
}
c_M6

# ───────────────────────────────────────────────────────────────────────────────────────────────
# Cluster I — `import --from <bundle>` (NODE-201, achado da revisão do PR #254; LDG-0233).
#
# O `import` chamava `applyBundle` direto sobre o diretório que o operador aponta, sem o staging
# seguro que o `sync` usa: um bundle recebido por fora do canal (pendrive, diretório compartilhado,
# anexo de outro participante) com um symlink em `blobs/` para um arquivo da vítima fazia o
# `readFileSync`/`copyFileSync` de `liaison-import.mjs` seguir o link — o segredo entrava na réplica
# local e o próximo `sync` o publicava no hub. Um FIFO no lugar do blob travava o comando.
#
# O nome do blob é `anexo.md`, SEM o prefixo sha256: `BODY_REF_RE` o aceita, e por isso a
# conferência do SEC-002 (sha256 do nome contra os bytes) não se aplica — é o caminho que o atacante,
# dono do envelope, escolhe. O envelope é refeito com `content_sha` recalculado, como ele faria.

# bundle_hostil <id> — x (atacante) exporta um bundle com um anexo renomeado para `anexo.md` e o
# envelope recalculado; v (vítima) tem o canal aberto e nunca sincronizou. Define BUN (bundle),
# BB (blobs/ do bundle) e SEG (segredo da vítima, fora do bundle e do repositório).
bundle_hostil() {
  local id="$1" orig
  mk_repo "$id/x"; mk_repo "$id/v"
  LG "$id/x" open "$CH" --self x --participants v,x >/dev/null
  LG "$id/v" open "$CH" --self v --participants v,x >/dev/null
  LG "$id/x" thread open "$CH" t1 --subject abertura --participants v,x --body abertura >/dev/null
  printf 'isca legítima do anexo\n' > "$T/$id/isca.md"
  LG "$id/x" send "$CH" --thread t1 --kind note --subject anexo --body-file "$T/$id/isca.md" >/dev/null
  BUN="$T/$id/bundle"; BB="$BUN/blobs"
  LG "$id/x" export "$CH" --out "$BUN" >/dev/null
  orig="$(ls "$BB")"; mv "$BB/$orig" "$BB/anexo.md"
  node - "$T/$id/x/.forge/scripts/lib" "$BUN/log/x.jsonl" <<'NODEEOF'
const { readFileSync, writeFileSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, f] = process.argv;
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const out = readFileSync(f, 'utf8').split('\n').filter(Boolean).map((l) => {
    const m = JSON.parse(l);
    if (m.body_ref) { m.body_ref = 'blobs/anexo.md'; m.content_sha = M.computeContentSha(m); }
    return JSON.stringify(m);
  });
  writeFileSync(f, out.join('\n') + '\n');
})();
NODEEOF
  SEG="$T/$id/fora/.ssh/id_ed25519"; mkdir -p "$(dirname "$SEG")"
  printf 'SEGREDO-DA-VÍTIMA\n' > "$SEG"; chmod 600 "$SEG"
}
planta_link_blob() { rm -f "$BB/anexo.md"; ln -s "$SEG" "$BB/anexo.md"; }
vazou() { grep -rqF 'SEGREDO-DA-VÍTIMA' "$T/$1/.forge/liaison"; }        # vazou <repo-relativo>
reabre_vitima() { rm -rf "$T/$1/.forge/liaison"; LG "$1" open "$CH" --self v --participants v,x >/dev/null; }

# Causas por extenso de cada guarda — é a causa que distingue QUAL camada recusou:
#   guarda A (staging seguro do import, pelo leitor do `liaison-hub-io.mjs`)
#   guarda B (leitura do blob em `applyBundle` sem seguir link, fstat no descritor)
CAUSA_A='link simbólico no hub (SEC-001)'
CAUSA_B='não é(são) arquivo regular de um vínculo'

# Mutações: A volta a aplicar o bundle cru (o comportamento anterior à correção); B devolve cada
# leitura de blob ao `readFileSync` por caminho. Cada uma tem de ALTERAR o arquivo (cmp), senão a
# âncora do perl não casou e a prova não prova nada.
muta_A() { perl -pi -e 's/_apply_bundle "\$channel" "\$staging" "import"/_apply_bundle "\$channel" "\$from_dir" "import"/' "$1"; }
muta_B_novo() { perl -pi -e 's/buf = leBlobSeguro\(join\(fromBlobs, blobName\)\);/buf = readFileSync(join(fromBlobs, blobName));/' "$1"; }
muta_B_rec() { perl -pi -e 's/buf = leBlobSeguro\(src\);/buf = readFileSync(src);/' "$1"; }
muta() { # muta <função> <arquivo> <rótulo> — aplica e confere que o arquivo mudou
  local f="$2" antes="$2.antes-da-mutacao"
  cp "$f" "$antes"; "$1" "$f"
  if cmp -s "$f" "$antes"; then rm -f "$antes"; falha "$3: a mutação $1 não alterou $(basename "$f") — âncora do perl não casou (guarda ausente?)"; return 1; fi
  rm -f "$antes"
}

echo "[I1] import --from — bundle externo com blob symlink para o segredo da vítima: RECUSADO, nada entra na réplica"
c_I1() {
  ataque
  bundle_hostil I1
  local out rc
  # CONTROLE (b): o mesmo bundle com o blob REGULAR é importado — mensagem e corpo chegam. Prova que
  # o envelope refeito é aceito, e que a recusa abaixo é pelo link, não pelo envelope.
  mk_repo I1/c; LG I1/c open "$CH" --self c --participants c,x >/dev/null
  set +e; out="$(LG I1/c import "$CH" --from "$BUN" 2>&1)"; rc=$?; set -e
  [ "$rc" -eq 0 ] && grep -qF 'isca legítima do anexo' "$T/I1/c/.forge/liaison/$CH/blobs/anexo.md" 2>/dev/null \
    || { falha "[I1]: controle — o bundle legítimo não foi importado com o corpo (rc=$rc). Saída: $(head -3 <<<"$out")"; return 0; }
  # ATAQUE (a)
  planta_link_blob
  set +e; out="$(LG I1/v import "$CH" --from "$BUN" 2>&1)"; rc=$?; set -e
  if vazou I1/v; then falha "[I1]: o conteúdo do segredo da vítima entrou na réplica pelo import --from (rc=$rc)"; return 0; fi
  grep -qF "$CAUSA_A" <<<"$out" || { falha "[I1]: o blob symlink foi descartado sem a causa do staging seguro. Saída: $(head -3 <<<"$out")"; return 0; }
  [ "$(find "$SEG" -perm 0600 -print)" = "$SEG" ] || { falha "[I1]: o modo do segredo mudou"; return 0; }
  neutralizado; echo "OK [I1] — bundle legítimo importa; blob symlink recusado no staging, segredo fora da réplica (rc=$rc)"
}
c_I1

echo "[I2] import --from — blob do bundle é FIFO: o import termina, sem travar"
c_I2() {
  ataque
  bundle_hostil I2
  rm -f "$BB/anexo.md"; mkfifo "$BB/anexo.md"
  local saida="$T/I2/import.out" rcf="$T/I2/import.rc" pid
  ( set +e; LG I2/v import "$CH" --from "$BUN" >"$saida" 2>&1; echo $? > "$rcf" ) & pid=$!
  for _ in $(seq 1 40); do kill -0 "$pid" 2>/dev/null || break; perl -e 'select(undef,undef,undef,0.5)'; done
  if kill -0 "$pid" 2>/dev/null; then
    pkill -f "$T/I2/" 2>/dev/null || true; destrava_fifo "$BB/anexo.md"; wait "$pid" 2>/dev/null || true
    falha "[I2]: o import TRAVOU por 20 s lendo o FIFO plantado no bundle"; return 0
  fi
  wait "$pid" 2>/dev/null || true
  grep -qF 'SEC-001' "$saida" || { falha "[I2]: o FIFO foi descartado sem a causa. Saída: $(head -3 "$saida")"; return 0; }
  neutralizado; echo "OK [I2] — FIFO no bundle é recusado sem travar (rc=$(cat "$rcf" 2>/dev/null || echo '?'))"
}
c_I2

echo "[M7] mutação — guarda A (staging do import): sozinha segura; sem ela e sem B, o segredo vaza"
# B desligada nos dois pontos de leitura: só o staging está entre o bundle e a réplica. Ele tem de
# recusar com a causa dele. Desligado também o staging, o mesmo bundle vaza — prova de que o cenário
# está armado. Restaurados os dois, segura de novo.
c_M7() {
  bundle_hostil M7; planta_link_blob
  local ops="$T/M7/v/.forge/scripts/liaison-ops.sh" imp="$T/M7/v/.forge/scripts/lib/liaison-import.mjs" out
  cp "$ops" "$T/M7/ops.orig"; cp "$imp" "$T/M7/imp.orig"
  muta muta_B_novo "$imp" "[M7]" || return 0
  muta muta_B_rec "$imp" "[M7]" || return 0
  set +e; out="$(LG M7/v import "$CH" --from "$BUN" 2>&1)"; set -e
  if vazou M7/v; then falha "[M7]: só com o staging (B desligada) o segredo vazou — a guarda A não segura sozinha"; return 0; fi
  grep -qF "$CAUSA_A" <<<"$out" || { falha "[M7]: só com o staging a recusa saiu sem a causa dele. Saída: $(head -3 <<<"$out")"; return 0; }
  muta muta_A "$ops" "[M7]" || return 0
  reabre_vitima M7/v
  set +e; LG M7/v import "$CH" --from "$BUN" >/dev/null 2>&1; set -e
  vazou M7/v || { falha "[M7]: sem A e sem B o segredo NÃO vazou — o cenário não exercita o ataque"; return 0; }
  cp "$T/M7/ops.orig" "$ops"; cp "$T/M7/imp.orig" "$imp"
  cmp -s "$ops" "$T/M7/ops.orig" && cmp -s "$imp" "$T/M7/imp.orig" || { falha "[M7]: restauração não bateu byte a byte"; return 0; }
  reabre_vitima M7/v
  set +e; out="$(LG M7/v import "$CH" --from "$BUN" 2>&1)"; set -e
  if vazou M7/v; then falha "[M7]: recontrole — restauradas as guardas, o segredo ainda vazou"; return 0; fi
  echo "OK [M7] — o staging segura sozinho; sem ele e sem B o segredo vaza; restaurados, segura"
}
c_M7

echo "[M8] mutação — guarda B (leitura do blob de mensagem NOVA): sozinha segura; sem ela e sem A, vaza"
c_M8() {
  bundle_hostil M8; planta_link_blob
  local ops="$T/M8/v/.forge/scripts/liaison-ops.sh" imp="$T/M8/v/.forge/scripts/lib/liaison-import.mjs" out
  cp "$ops" "$T/M8/ops.orig"; cp "$imp" "$T/M8/imp.orig"
  muta muta_A "$ops" "[M8]" || return 0
  set +e; out="$(LG M8/v import "$CH" --from "$BUN" 2>&1)"; set -e
  if vazou M8/v; then falha "[M8]: só com B (staging desligado) o segredo vazou pela mensagem nova"; return 0; fi
  grep -qF "$CAUSA_B" <<<"$out" || { falha "[M8]: só com B a recusa saiu sem a causa dela. Saída: $(head -3 <<<"$out")"; return 0; }
  muta muta_B_novo "$imp" "[M8]" || return 0
  reabre_vitima M8/v
  set +e; LG M8/v import "$CH" --from "$BUN" >/dev/null 2>&1; set -e
  vazou M8/v || { falha "[M8]: sem A e sem B (mensagem nova) o segredo NÃO vazou — o cenário não exercita o ponto"; return 0; }
  cp "$T/M8/ops.orig" "$ops"; cp "$T/M8/imp.orig" "$imp"
  cmp -s "$ops" "$T/M8/ops.orig" && cmp -s "$imp" "$T/M8/imp.orig" || { falha "[M8]: restauração não bateu byte a byte"; return 0; }
  reabre_vitima M8/v
  set +e; LG M8/v import "$CH" --from "$BUN" >/dev/null 2>&1; set -e
  if vazou M8/v; then falha "[M8]: recontrole — restauradas as guardas, o segredo ainda vazou"; return 0; fi
  echo "OK [M8] — a leitura segura da mensagem nova segura sozinha; sem ela e sem A vaza; restauradas, segura"
}
c_M8

echo "[M9] mutação — guarda B (leitura do blob na RECUPERAÇÃO): sozinha segura; sem ela e sem A, vaza"
# A recuperação (issue #107) só alcança mensagem JÁ CONHECIDA cujo corpo local sumiu. A vítima
# importa o bundle legítimo, perde o blob local, e o atacante troca o blob do bundle por um link.
c_M9() {
  bundle_hostil M9
  local ops="$T/M9/v/.forge/scripts/liaison-ops.sh" imp="$T/M9/v/.forge/scripts/lib/liaison-import.mjs" out
  local local_blob="$T/M9/v/.forge/liaison/$CH/blobs/anexo.md"
  LG M9/v import "$CH" --from "$BUN" >/dev/null 2>&1 || true
  [ -f "$local_blob" ] || { falha "[M9]: preparação — o import legítimo não trouxe o corpo"; return 0; }
  rm -f "$local_blob"; planta_link_blob
  cp "$ops" "$T/M9/ops.orig"; cp "$imp" "$T/M9/imp.orig"
  muta muta_A "$ops" "[M9]" || return 0
  set +e; out="$(LG M9/v import "$CH" --from "$BUN" 2>&1)"; set -e
  if vazou M9/v; then falha "[M9]: só com B (staging desligado) o segredo vazou pela recuperação"; return 0; fi
  grep -qF "$CAUSA_B" <<<"$out" || { falha "[M9]: só com B a recusa na recuperação saiu sem a causa dela. Saída: $(head -3 <<<"$out")"; return 0; }
  muta muta_B_rec "$imp" "[M9]" || return 0
  set +e; LG M9/v import "$CH" --from "$BUN" >/dev/null 2>&1; set -e
  vazou M9/v || { falha "[M9]: sem A e sem B (recuperação) o segredo NÃO vazou — o cenário não exercita o ponto"; return 0; }
  rm -f "$local_blob"
  cp "$T/M9/ops.orig" "$ops"; cp "$T/M9/imp.orig" "$imp"
  cmp -s "$ops" "$T/M9/ops.orig" && cmp -s "$imp" "$T/M9/imp.orig" || { falha "[M9]: restauração não bateu byte a byte"; return 0; }
  set +e; LG M9/v import "$CH" --from "$BUN" >/dev/null 2>&1; set -e
  if vazou M9/v; then falha "[M9]: recontrole — restauradas as guardas, o segredo ainda vazou"; return 0; fi
  echo "OK [M9] — a leitura segura da recuperação segura sozinha; sem ela e sem A vaza; restauradas, segura"
}
c_M9

# ───────────────────────────────────────────────────────────────────────────────────────────────
# NODE-201 um nível acima: a RAIZ do `--from`. O PR #261 passou o bundle pelo `_dir_pull` seguro, mas resolvia a raiz antes com `cd -P` inteiro, que SEGUE um link no último componente — justamente a entrada que o autor do bundle controla (pasta extraída de anexo, pendrive, diretório compartilhado) — e anula a guarda `_dir_reject_symlink` que o `_dir_pull` aplica na raiz. O atacante x entrega como "bundle" um link para o canal PRIVADO da vítima com outro peer; o import copiava o anexo confidencial desse canal para o canal atacado, e o próximo `sync --push-only` o publicava no hub que x lê (o push publica todos os blobs locais; `applyBundle` não confere canal nem participantes). Exfiltração entre canais.

# vitima_dois_canais <id> — v tem o canal `$CH` com o atacante x e o canal privado `$CH2` com y, onde o anexo confidencial de y já foi importado legitimamente. Define V (repo de v, relativo a $T), PRIV (canal privado de v) e LNK (o "bundle" entregue por x: link para PRIV, ainda não plantado).
CH2="ch2"
vitima_dois_canais() {
  local id="$1"
  mk_repo "$id/y"; mk_repo "$id/v"; V="$id/v"
  LG "$id/y" open "$CH2" --self y --participants v,y >/dev/null
  LG "$V" open "$CH2" --self v --participants v,y >/dev/null
  LG "$V" open "$CH" --self v --participants v,x >/dev/null
  LG "$id/y" thread open "$CH2" t1 --subject privado --participants v,y --body abertura >/dev/null
  printf 'CONFIDENCIAL-CH2 — só v e y podem ler\n' > "$T/$id/confidencial.md"
  LG "$id/y" send "$CH2" --thread t1 --kind note --subject anexo --body-file "$T/$id/confidencial.md" >/dev/null
  LG "$id/y" export "$CH2" --out "$T/$id/ybun" >/dev/null
  LG "$V" import "$CH2" --from "$T/$id/ybun" >/dev/null
  PRIV="$T/$V/.forge/liaison/$CH2"
  mkdir -p "$T/$id/shared"; LNK="$T/$id/shared/bundle"
}
vazou_ch2() { grep -rqF 'CONFIDENCIAL-CH2' "$T/$1/.forge/liaison/$CH"; }   # vazou_ch2 <repo-relativo>
reabre_canal_atacado() { rm -rf "$T/$1/.forge/liaison/$CH"; LG "$1" open "$CH" --self v --participants v,x >/dev/null; }

echo "[I3] import --from — a raiz do bundle é symlink para o canal privado da vítima: RECUSADO, nada cruza de canal"
c_I3() {
  ataque
  vitima_dois_canais I3
  local out rc
  grep -rqF 'CONFIDENCIAL-CH2' "$PRIV/blobs" 2>/dev/null \
    || { falha "[I3]: preparação — o anexo confidencial de y não chegou ao canal privado de v"; return 0; }
  # CONTROLE (a): symlink num componente PAI de `--from` é escolha do operador e continua aceito — x exporta um bundle legítimo de `$CH`, alcançado por `alias -> real`.
  mk_repo I3/x; LG I3/x open "$CH" --self x --participants v,x >/dev/null
  LG I3/x thread open "$CH" t1 --subject abertura --participants v,x --body abertura >/dev/null
  printf 'isca legítima do canal atacado\n' > "$T/I3/isca.md"
  LG I3/x send "$CH" --thread t1 --kind note --subject anexo --body-file "$T/I3/isca.md" >/dev/null
  mkdir -p "$T/I3/real"; LG I3/x export "$CH" --out "$T/I3/real/bundle" >/dev/null
  ln -s "$T/I3/real" "$T/I3/alias"
  set +e; out="$(LG "$V" import "$CH" --from "$T/I3/alias/bundle" 2>&1)"; rc=$?; set -e
  [ "$rc" -eq 0 ] && grep -rqF 'isca legítima do canal atacado' "$T/$V/.forge/liaison/$CH/blobs" 2>/dev/null \
    || { falha "[I3]: controle — bundle legítimo por pai symlink não foi importado com o corpo (rc=$rc). Saída: $(head -3 <<<"$out")"; return 0; }
  # ATAQUE (b): o próprio `--from` é link para o canal privado da vítima — com e sem barra final.
  ln -s "$PRIV" "$LNK"
  local variante
  for variante in "$LNK" "$LNK/" "$LNK//"; do
    set +e; out="$(LG "$V" import "$CH" --from "$variante" 2>&1)"; rc=$?; set -e
    if vazou_ch2 "$V"; then falha "[I3]: o anexo confidencial de $CH2 entrou em $CH pelo import --from '$variante' (rc=$rc)"; return 0; fi
    [ "$rc" -ne 0 ] || { falha "[I3]: import --from '$variante' (raiz symlink) saiu com rc=0. Saída: $(head -3 <<<"$out")"; return 0; }
    grep -qF 'link simbólico' <<<"$out" && grep -qF 'SEC-001' <<<"$out" \
      || { falha "[I3]: '$variante' recusado sem a causa (link simbólico, SEC-001). Saída: $(head -3 <<<"$out")"; return 0; }
  done
  grep -rqF 'CONFIDENCIAL-CH2' "$PRIV/blobs" || { falha "[I3]: o canal privado da vítima foi alterado"; return 0; }
  neutralizado; echo "OK [I3] — pai symlink importa; raiz symlink para o canal privado RECUSADA (rc=$rc), nada cruza de canal"
}
c_I3

echo "[M10] mutação — a raiz do --from volta a ser resolvida por cd -P inteiro: o canal privado vaza; restaurada, segura"
# A mutação devolve a resolução da raiz ao `cd -P` que segue o último componente (o código anterior à correção). Com ela, o link entregue por x passa a ser a raiz física e a guarda do `_dir_pull` não vê link nenhum.
muta_raiz() { perl -pi -e 's/from_phys="\$\(_dir_phys_expected "\$from_trim"\)"/from_phys="\$(cd -P -- "\$from_trim" && pwd -P)"/' "$1"; }
c_M10() {
  vitima_dois_canais M10; ln -s "$PRIV" "$LNK"
  local ops="$T/M10/v/.forge/scripts/liaison-ops.sh" out
  cp "$ops" "$T/M10/ops.orig"
  set +e; out="$(LG "$V" import "$CH" --from "$LNK" 2>&1)"; set -e
  if vazou_ch2 "$V"; then falha "[M10]: controle — com a guarda o canal privado vazou"; return 0; fi
  muta muta_raiz "$ops" "[M10]" || return 0
  reabre_canal_atacado "$V"
  set +e; LG "$V" import "$CH" --from "$LNK" >/dev/null 2>&1; set -e
  vazou_ch2 "$V" || { falha "[M10]: com a raiz seguida o canal privado NÃO vazou — o cenário não exercita o ataque"; return 0; }
  cp "$T/M10/ops.orig" "$ops"
  cmp -s "$ops" "$T/M10/ops.orig" || { falha "[M10]: restauração não bateu byte a byte"; return 0; }
  reabre_canal_atacado "$V"
  set +e; out="$(LG "$V" import "$CH" --from "$LNK" 2>&1)"; set -e
  if vazou_ch2 "$V"; then falha "[M10]: recontrole — restaurada a guarda, o canal privado ainda vazou"; return 0; fi
  grep -qF 'SEC-001' <<<"$out" || { falha "[M10]: recontrole sem a causa SEC-001. Saída: $(head -3 <<<"$out")"; return 0; }
  echo "OK [M10] — com a raiz seguida o canal privado vaza; restaurada a guarda, segura"
}
c_M10

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
