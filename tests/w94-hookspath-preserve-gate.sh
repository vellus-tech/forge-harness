#!/usr/bin/env bash
# Gate — hookspath-respect-custom: init/update/install.sh nunca sobrescrevem um core.hooksPath
# customizado pré-existente. core.hooksPath vive em .git/config (compartilhado entre worktrees
# quando extensions.worktreeConfig não está ligado) — sobrescrever silenciosamente desativaria os
# hooks do projeto sem aviso. Achado real: 2x em axis-go-cloud (.githooks apagado por forge update).
#   [1] init em repo COM hooksPath customizado → preserva (não sobrescreve)
#   [2] init em repo SEM hooksPath → seta o caminho ABSOLUTO dos hooks do tronco. Era relativo
#       (`.forge/hooks/git`) até a issue #41: relativo é resolvido por cada worktree contra a
#       PRÓPRIA árvore, que carrega a cópia antiga dos hooks daquela branch, e o hook novo então
#       não bloqueia nada onde o trabalho acontece (gate w137).
#   [3] update em repo COM hooksPath customizado → preserva
#   [4] install.sh (bash) segue a mesma regra, para paridade com bin/forge.mjs
#   [5] idempotência: hooksPath já no valor absoluto correto → no-op silencioso (sem nota de "customizado")
#   [6] migração: o valor legado relativo `.forge/hooks/git` NÃO conta como customizado — é nosso,
#       e é o defeito. Tem de ser migrado para absoluto, com a razão impressa.
set -uo pipefail

# `set -e` foi retirado de propósito (LDG-0012): com ele, uma invocação de `node bin/forge.mjs`
# que falhasse dentro de um cenário matava o gate na hora, sem imprimir FAIL nenhum — o log
# terminava no título do cenário e ninguém sabia o que aconteceu. Aconteceu de verdade ao
# desenvolver a issue #41. Cada comando que pode falhar declara o motivo abaixo.
run_or_fail() {  # run_or_fail <rótulo> <cmd...>
  local label="$1"; shift
  "$@" >/dev/null 2>&1 || { echo "FAIL $label (comando falhou: $*)"; exit 1; }
}

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$WS/bin/forge.mjs"
T="$(mktemp -d /tmp/forge-hookspath.XXXXXX)"
trap 'rm -rf "$T"' EXIT

echo "[1] init em repo com hooksPath customizado → preserva"
D1="$T/case1"; mkdir -p "$D1"; git -C "$D1" init -q
run_or_fail "[1]" node "$BIN" init --target "$D1" --slug c1 --name C1 --desc t --yes --no-plugin
git -C "$D1" config core.hooksPath .githooks
out="$(node "$BIN" init --target "$D1" --slug c1 --name C1 --desc t --yes --no-plugin --force 2>&1)"
[ "$(git -C "$D1" config --get core.hooksPath)" = ".githooks" ] || { echo "FAIL [1] (hooksPath sobrescrito)"; exit 1; }
grep -qi 'customizado' <<<"$out" || { echo "FAIL [1] (nota informativa ausente)"; exit 1; }
echo "OK [1]"

echo "[2] init em repo sem hooksPath → seta o caminho absoluto dos hooks do tronco"
D2="$T/case2"; mkdir -p "$D2"; git -C "$D2" init -q
D2R="$(cd "$D2" && pwd -P)"   # macOS: /tmp é symlink para /private/tmp e o git devolve o caminho real
run_or_fail "[2]" node "$BIN" init --target "$D2" --slug c2 --name C2 --desc t --yes --no-plugin
hp2="$(git -C "$D2" config --get core.hooksPath)"
case "$hp2" in
  /*) : ;;
  *)  echo "FAIL [2] (hooksPath relativo '$hp2' — worktrees resolveriam na própria árvore)"; exit 1 ;;
esac
[ "$hp2" = "$D2R/.forge/hooks/git" ] || { echo "FAIL [2] (esperava '$D2R/.forge/hooks/git', veio '$hp2')"; exit 1; }
echo "OK [2]"

echo "[3] update em repo com hooksPath customizado → preserva"
D3="$T/case3"; mkdir -p "$D3"; git -C "$D3" init -q
run_or_fail "[3]" node "$BIN" init --target "$D3" --slug c3 --name C3 --desc t --yes --no-plugin
git -C "$D3" config core.hooksPath .githooks
run_or_fail "[3]" node "$BIN" update --target "$D3" --no-plugin
[ "$(git -C "$D3" config --get core.hooksPath)" = ".githooks" ] || { echo "FAIL [3] (update sobrescreveu hooksPath)"; exit 1; }
echo "OK [3]"

echo "[4] install.sh preserva hooksPath customizado (paridade)"
D4="$T/case4"; mkdir -p "$D4"; git -C "$D4" init -q
run_or_fail "[4]" bash "$WS/installer/install.sh" --target "$D4" --slug c4 --name C4 --desc t
git -C "$D4" config core.hooksPath .githooks
run_or_fail "[4]" bash "$WS/installer/install.sh" --target "$D4" --slug c4 --name C4 --desc t --force
[ "$(git -C "$D4" config --get core.hooksPath)" = ".githooks" ] || { echo "FAIL [4] (install.sh sobrescreveu hooksPath)"; exit 1; }
echo "OK [4]"

echo "[5] idempotência: já no valor absoluto correto → no-op silencioso"
D5="$T/case5"; mkdir -p "$D5"; git -C "$D5" init -q
D5R="$(cd "$D5" && pwd -P)"
run_or_fail "[5]" node "$BIN" init --target "$D5" --slug c5 --name C5 --desc t --yes --no-plugin
out5="$(node "$BIN" update --target "$D5" --no-plugin 2>&1)"
[ "$(git -C "$D5" config --get core.hooksPath)" = "$D5R/.forge/hooks/git" ] || { echo "FAIL [5] (valor mudou num update idempotente)"; exit 1; }
grep -qi 'customizado' <<<"$out5" && { echo "FAIL [5] (nota de customizado indevida)"; exit 1; }
# `git: core.hooksPath` é a linha que o wireHooksPath imprime ao ESCREVER. O doctor, que o update
# roda no fim, também menciona hooksPath — mas com o prefixo dele. Ancorar na linha do wire.
grep -q '^git: core.hooksPath' <<<"$out5" && { echo "FAIL [5] (reescreveu hooksPath num no-op)"; exit 1; }
echo "OK [5]"

echo "[6] valor legado relativo é MIGRADO para absoluto, não tratado como customizado"
D6="$T/case6"; mkdir -p "$D6"; git -C "$D6" init -q
D6R="$(cd "$D6" && pwd -P)"
run_or_fail "[6]" node "$BIN" init --target "$D6" --slug c6 --name C6 --desc t --yes --no-plugin
git -C "$D6" config core.hooksPath .forge/hooks/git    # estado de quem instalou antes da issue #41
out6="$(node "$BIN" update --target "$D6" --no-plugin 2>&1)"
[ "$(git -C "$D6" config --get core.hooksPath)" = "$D6R/.forge/hooks/git" ] || { echo "FAIL [6] (legado relativo não foi migrado: '$(git -C "$D6" config --get core.hooksPath)')"; exit 1; }
grep -qi 'customizado' <<<"$out6" && { echo "FAIL [6] (tratou o valor legado como customização do projeto)"; exit 1; }
grep -qi 'absoluto' <<<"$out6" || { echo "FAIL [6] (migrou em silêncio, sem dizer o porquê)"; exit 1; }
echo "OK [6]"

echo "PASS w94-hookspath-preserve-gate"
