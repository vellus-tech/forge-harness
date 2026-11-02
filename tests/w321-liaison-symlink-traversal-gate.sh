#!/usr/bin/env bash
# Gate W321 — o hub do liaison recusa symlink em vez de segui-lo para fora da árvore do canal.
#
# POR QUE ESTE GATE EXISTE (SEC-001). `_dir_push`/`_dir_pull` (lib/transports/_common.sh) faziam
# `mkdir -p "$hub/log" "$hub/blobs"` seguido de `cp`/`mv` sem nunca checar se o próprio hub, `log/`
# ou `blobs/` eram links simbólicos. Um participante com push no canal (ou com acesso de escrita
# ao diretório compartilhado, no transporte `fs`/`fs-union`) podia substituir `blobs` por um
# symlink para fora da árvore do canal — por exemplo `../../../../.git/hooks` no transporte `git`,
# onde o hub é um clone local dentro do próprio repositório da vítima (`.forge/cache/liaison/`).
# `mkdir -p` sobre um symlink-para-diretório já existente é um no-op silencioso: o `cp`/`mv` que vem
# depois obedece ao link e escreve fora da árvore do canal, com o bit de execução herdado — no caso
# do git, dentro de `.git/hooks/` de quem sincroniza, executado no próximo commit da vítima.
#
# A CORREÇÃO tem duas camadas independentes: (a) `_dir_reject_symlink` em `_common.sh`, chamada
# antes de qualquer `mkdir`/`cp`/`mv` sobre hub/log/blobs — vale para TODO transporte baseado em
# diretório (fs, fs-union, e o clone local do git); (b) o transporte `git` também recusa, ANTES do
# checkout, qualquer entrada da árvore (`ls-tree -r`) com modo 120000 (symlink) ou 160000
# (submódulo) dentro do diretório do canal, e fixa `core.symlinks=false` como segunda rede — um
# symlink committed vira ARQUIVO DE TEXTO comum no checkout, nunca um link real do filesystem.
#
#   [1]  controle — push/pull normais por `fs` continuam funcionando (mensagem e blob chegam)
#   [2]  ataque `fs`/push: hub `blobs/` é um symlink para fora — push RECUSADO, sentinela intacta
#   [3]  ataque `fs`/pull: hub `log/` é um symlink para fora — pull RECUSADO, sentinela intacta
#   [4]  ataque `git`: a branch do canal remoto tem `<canal>/blobs` como symlink (modo 120000) —
#        sync RECUSADO antes do checkout, cache local nunca materializa o link
#   [5]  contador de controle: universo vazio reprova
#   [6]  mutação — remover a guarda de `_dir_push_blobs` faz [2] ser ACEITO (sentinela contaminada);
#        restaurado, [2] volta a recusar (recontrole)
set -euo pipefail
# Isolamento git (LDG-0201): GIT_DIR herdado do ambiente faria os comandos git abaixo obedecerem
# ao repositório de quem invocou o gate, e não aos repositórios sintéticos criados aqui.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d "${TMPDIR:-/tmp}/forge-w321.XXXXXX")"
T="$(cd "$T" && pwd -P)"
trap 'rm -rf "$T"' EXIT

CH="ch"
HUB="$T/hub"
HUB_CH="$HUB/$CH"

mk_repo() { # mk_repo <dir-name> — réplica sintética própria, nunca o repositório real
  local dir="$T/$1"
  mkdir -p "$dir/.forge"
  cp -R "$WS/template/.forge/scripts" "$dir/.forge/"
  cp -R "$WS/template/.forge/templates" "$dir/.forge/"
  git -C "$dir" init -q
  git -C "$dir" config user.email "$1@test"
  git -C "$dir" config user.name "$1"
  git -C "$dir" config commit.gpgsign false
  git -C "$dir" commit --allow-empty -qm init >/dev/null
}

LG() { local repo="$1"; shift; FORGE_ROOT="$T/$repo" bash "$T/$repo/.forge/scripts/liaison-ops.sh" "$@"; }

echo "[1] controle fs — push normal popula o hub, pull normal traz mensagem e blob"
mk_repo a; mk_repo b
LG a open "$CH" --self a --participants a,b >/dev/null
LG b open "$CH" --self b --participants a,b >/dev/null
LG a transport set "$CH" --kind fs --path "$HUB" >/dev/null
LG b transport set "$CH" --kind fs --path "$HUB" >/dev/null
LG a thread open "$CH" t1 --subject abertura --participants a,b --body abertura >/dev/null
printf 'corpo legitimo 1 — conteudo irrelevante\n' > "$T/corpo-1.md"
LG a send "$CH" --thread t1 --kind note --subject "c1" --body-file "$T/corpo-1.md" >/dev/null
LG a sync "$CH" --push-only >/dev/null \
  || { echo "FAIL [1]: push normal (controle) reprovou"; exit 1; }
[ -d "$HUB_CH/blobs" ] && [ -n "$(ls -A "$HUB_CH/blobs" 2>/dev/null)" ] \
  || { echo "FAIL [1]: hub sem blob após push legítimo"; exit 1; }
LG b sync "$CH" --pull-only >/dev/null \
  || { echo "FAIL [1]: pull normal (controle) reprovou"; exit 1; }
B_BLOBS="$T/b/.forge/liaison/$CH/blobs"
[ -n "$(ls -A "$B_BLOBS" 2>/dev/null)" ] \
  || { echo "FAIL [1]: b não recebeu o blob após pull legítimo"; exit 1; }
echo "OK [1] — push/pull legítimos continuam funcionando"

echo "[2] ataque fs/push — hub blobs/ é symlink para fora: push RECUSADO, sentinela intacta"
SENTINEL_BLOBS="$T/sentinel-blobs"
mkdir -p "$SENTINEL_BLOBS"
rm -rf "$HUB_CH/blobs"
ln -s "$SENTINEL_BLOBS" "$HUB_CH/blobs"
printf 'corpo malicioso — nao deveria sair da arvore do canal\n' > "$T/corpo-2.md"
LG a send "$CH" --thread t1 --kind note --subject "c2" --body-file "$T/corpo-2.md" >/dev/null
set +e
out2="$(LG a sync "$CH" --push-only 2>&1)"; rc2=$?
set -e
[ "$rc2" -ne 0 ] || { echo "FAIL [2]: push com hub/blobs symlink foi ACEITO (rc=0)"; exit 1; }
grep -qi 'symlink' <<<"$out2" \
  || { echo "FAIL [2]: recusou sem nomear a causa (symlink). Saída: $(head -3 <<<"$out2")"; exit 1; }
[ -z "$(ls -A "$SENTINEL_BLOBS" 2>/dev/null)" ] \
  || { echo "FAIL [2]: a sentinela fora da árvore recebeu arquivo — traversal aconteceu de verdade"; exit 1; }
[ -L "$HUB_CH/blobs" ] || { echo "FAIL [2]: o symlink do hub foi alterado pelo push recusado"; exit 1; }
echo "OK [2] — push recusado citando symlink, sentinela e link do hub intactos"

echo "[3] ataque fs/pull — hub log/ é symlink para fora: pull RECUSADO"
rm -f "$HUB_CH/blobs"
mkdir -p "$HUB_CH/blobs"
SENTINEL_LOG="$T/sentinel-log"
mkdir -p "$SENTINEL_LOG"
mv "$HUB_CH/log" "$T/log-real-backup"
ln -s "$SENTINEL_LOG" "$HUB_CH/log"
set +e
out3="$(LG b sync "$CH" --pull-only 2>&1)"; rc3=$?
set -e
[ "$rc3" -ne 0 ] || { echo "FAIL [3]: pull com hub/log symlink foi ACEITO (rc=0)"; exit 1; }
grep -qi 'symlink' <<<"$out3" \
  || { echo "FAIL [3]: recusou sem nomear a causa (symlink). Saída: $(head -3 <<<"$out3")"; exit 1; }
rm -f "$HUB_CH/log"
mv "$T/log-real-backup" "$HUB_CH/log"
echo "OK [3] — pull recusado citando symlink"

echo "[4] ataque git — branch do canal com <canal>/blobs symlink: sync recusado antes do checkout"
git init -q --bare "$T/hub.git"
git -C "$T/hub.git" symbolic-ref HEAD refs/heads/main 2>/dev/null || true
mkdir -p "$T/attacker-clone"
git -C "$T/attacker-clone" init -q
git -C "$T/attacker-clone" remote add origin "$T/hub.git"
git -C "$T/attacker-clone" config user.email "attacker@test"
git -C "$T/attacker-clone" config user.name "attacker"
git -C "$T/attacker-clone" config commit.gpgsign false
git -C "$T/attacker-clone" checkout -q --orphan "liaison/$CH"
mkdir -p "$T/attacker-clone/$CH/log"
: > "$T/attacker-clone/$CH/log/.keep"
git -C "$T/attacker-clone" add "$CH/log/.keep"
# symlink committed como modo 120000 — não precisa resolver de verdade, a defesa age sobre o modo
# da entrada na árvore, antes de qualquer checkout.
ln -s "../../../../../../sentinel-git-attack" "$T/attacker-clone/$CH/blobs"
git -C "$T/attacker-clone" add "$CH/blobs"
git -C "$T/attacker-clone" commit -qm "liaison($CH): attacker" >/dev/null
git -C "$T/attacker-clone" push -q origin "liaison/$CH"

mk_repo victim
LG victim open "$CH" --self victim --participants victim,a >/dev/null
LG victim transport set "$CH" --kind git --remote "$T/hub.git" --branch "liaison/$CH" >/dev/null
set +e
out4="$(LG victim sync "$CH" --pull-only 2>&1)"; rc4=$?
set -e
[ "$rc4" -ne 0 ] || { echo "FAIL [4]: sync via git com symlink na branch foi ACEITO (rc=0)"; exit 1; }
grep -qiE 'symlink|submódulo|sec-001' <<<"$out4" \
  || { echo "FAIL [4]: recusou sem nomear a causa. Saída: $(head -4 <<<"$out4")"; exit 1; }
VCACHE_CH="$T/victim/.forge/cache/liaison/$CH/$CH"
[ -L "$VCACHE_CH/blobs" ] \
  && { echo "FAIL [4]: o cache local materializou o symlink de verdade"; exit 1; }
echo "OK [4] — sync via git recusado antes do checkout, cache local nunca materializou o link"

echo "[5] contador de controle — universo vazio reprova"
# shellcheck source=/dev/null
. "$WS/template/.forge/scripts/lib/gate-universe.sh"
forge_universe_check "w321/ataques-recusados" 4 "ataque(s) recusado(s)" "[2]+[3]+[4]+controle" "$WS" \
  || { echo "FAIL [5]"; exit 1; }
set +e
out5="$(forge_universe_check "w321/ataques-recusados" 0 "ataque(s)" "contrapositiva" "$WS" 2>&1)"; rc5=$?
set -e
[ "$rc5" -ne 0 ] || { echo "FAIL [5]: universo vazio aprovou — $out5"; exit 1; }
echo "OK [5]"

echo "[6] mutação — remover a guarda de _dir_push_blobs aceita o ataque; restaurada, volta a recusar"
MCOMMON="$T/a/.forge/scripts/lib/transports/_common.sh"
cp "$MCOMMON" "$T/common.orig"
perl -0pi -e 's/_dir_reject_symlink "\$hub\/blobs" \|\| return 1\n(\s*local b name)/\1/' "$MCOMMON"
cmp -s "$MCOMMON" "$T/common.orig" && { echo "FAIL [6]: a mutação não alterou _common.sh — o alvo do perl não casou"; exit 1; }

MHUB="$T/mut-hub"; rm -rf "$MHUB"; mkdir -p "$MHUB/log"
SENTINEL_MUT="$T/sentinel-mut"; rm -rf "$SENTINEL_MUT"; mkdir -p "$SENTINEL_MUT"
ln -s "$SENTINEL_MUT" "$MHUB/blobs"
MREP="$T/mut-rep"; rm -rf "$MREP"; mkdir -p "$MREP/blobs"
printf 'payload da mutacao\n' > "$MREP/blobs/payload.txt"
set +e
( LIAISON_CHANNEL_DIR="$MREP" LIAISON_SELF="a" \
    bash -c ". \"$MCOMMON\"; _dir_push_blobs \"$MHUB\" \"$MREP\"" ) >/dev/null 2>&1
set -e
[ -f "$SENTINEL_MUT/payload.txt" ] \
  || { echo "FAIL [6]: sem a guarda, o ataque NÃO contaminou a sentinela — [2] não mede a guarda certa"; exit 1; }
cp "$T/common.orig" "$MCOMMON"
cmp -s "$MCOMMON" "$T/common.orig" || { echo "FAIL [6]: restauração não bateu byte a byte"; exit 1; }

# RECONTROLE: restaurado, o mesmo ataque volta a ser recusado.
rm -rf "$SENTINEL_MUT"; mkdir -p "$SENTINEL_MUT"
set +e
( LIAISON_CHANNEL_DIR="$MREP" LIAISON_SELF="a" \
    bash -c ". \"$MCOMMON\"; _dir_push_blobs \"$MHUB\" \"$MREP\"" ) >/dev/null 2>&1
set -e
[ -z "$(ls -A "$SENTINEL_MUT" 2>/dev/null)" ] \
  || { echo "FAIL [6]: recontrole — restaurada a guarda, a sentinela ainda foi contaminada"; exit 1; }
echo "OK [6] — sem a guarda o ataque passa; restaurada, volta a ser recusado"

echo "PASS w321-liaison-symlink-traversal"
