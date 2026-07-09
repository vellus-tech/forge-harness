#!/usr/bin/env bash
# Gate — hookspath-respect-custom: init/update/install.sh nunca sobrescrevem um core.hooksPath
# customizado pré-existente. core.hooksPath vive em .git/config (compartilhado entre worktrees
# quando extensions.worktreeConfig não está ligado) — sobrescrever silenciosamente desativaria os
# hooks do projeto sem aviso. Achado real: 2x em axis-go-cloud (.githooks apagado por forge update).
#   [1] init em repo COM hooksPath customizado → preserva (não sobrescreve)
#   [2] init em repo SEM hooksPath → segue setando .forge/hooks/git (caminho feliz preservado)
#   [3] update em repo COM hooksPath customizado → preserva
#   [4] install.sh (bash) segue a mesma regra, para paridade com bin/forge.mjs
#   [5] idempotência: hooksPath já .forge/hooks/git → no-op silencioso (sem nota de "customizado")
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$WS/bin/forge.mjs"
T="$(mktemp -d /tmp/forge-hookspath.XXXXXX)"
trap 'rm -rf "$T"' EXIT

echo "[1] init em repo com hooksPath customizado → preserva"
D1="$T/case1"; mkdir -p "$D1"; git -C "$D1" init -q
node "$BIN" init --target "$D1" --slug c1 --name C1 --desc t --yes --no-plugin >/dev/null 2>&1
git -C "$D1" config core.hooksPath .githooks
out="$(node "$BIN" init --target "$D1" --slug c1 --name C1 --desc t --yes --no-plugin --force 2>&1)"
[ "$(git -C "$D1" config --get core.hooksPath)" = ".githooks" ] || { echo "FAIL [1] (hooksPath sobrescrito)"; exit 1; }
echo "$out" | grep -qi 'customizado' || { echo "FAIL [1] (nota informativa ausente)"; exit 1; }
echo "OK [1]"

echo "[2] init em repo sem hooksPath → segue setando .forge/hooks/git"
D2="$T/case2"; mkdir -p "$D2"; git -C "$D2" init -q
node "$BIN" init --target "$D2" --slug c2 --name C2 --desc t --yes --no-plugin >/dev/null 2>&1
[ "$(git -C "$D2" config --get core.hooksPath)" = ".forge/hooks/git" ] || { echo "FAIL [2] (não setou o default)"; exit 1; }
echo "OK [2]"

echo "[3] update em repo com hooksPath customizado → preserva"
D3="$T/case3"; mkdir -p "$D3"; git -C "$D3" init -q
node "$BIN" init --target "$D3" --slug c3 --name C3 --desc t --yes --no-plugin >/dev/null 2>&1
git -C "$D3" config core.hooksPath .githooks
node "$BIN" update --target "$D3" --no-plugin >/dev/null 2>&1
[ "$(git -C "$D3" config --get core.hooksPath)" = ".githooks" ] || { echo "FAIL [3] (update sobrescreveu hooksPath)"; exit 1; }
echo "OK [3]"

echo "[4] install.sh preserva hooksPath customizado (paridade)"
D4="$T/case4"; mkdir -p "$D4"; git -C "$D4" init -q
bash "$WS/installer/install.sh" --target "$D4" --slug c4 --name C4 --desc t >/dev/null 2>&1
git -C "$D4" config core.hooksPath .githooks
bash "$WS/installer/install.sh" --target "$D4" --slug c4 --name C4 --desc t --force >/dev/null 2>&1
[ "$(git -C "$D4" config --get core.hooksPath)" = ".githooks" ] || { echo "FAIL [4] (install.sh sobrescreveu hooksPath)"; exit 1; }
echo "OK [4]"

echo "[5] idempotência: já .forge/hooks/git → no-op silencioso"
D5="$T/case5"; mkdir -p "$D5"; git -C "$D5" init -q
node "$BIN" init --target "$D5" --slug c5 --name C5 --desc t --yes --no-plugin >/dev/null 2>&1
out5="$(node "$BIN" update --target "$D5" --no-plugin 2>&1)"
[ "$(git -C "$D5" config --get core.hooksPath)" = ".forge/hooks/git" ] || { echo "FAIL [5]"; exit 1; }
echo "$out5" | grep -qi 'customizado' && { echo "FAIL [5] (nota de customizado indevida)"; exit 1; }
echo "OK [5]"

echo "PASS w94-hookspath-preserve-gate"
