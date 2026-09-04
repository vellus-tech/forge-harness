#!/usr/bin/env bash
# Gate W161 — `forge update` distingue ".forge/ ausente" de ".forge/ presente sem forge.yaml"
# (LDG-0028). bin/forge.mjs testava só `existsSync(.forge/forge.yaml)` e, ao falhar, emitia
# ".forge não encontrado em <target> — use `npx forge-harness init`" mesmo quando .forge/ EXISTE
# e só o forge.yaml sumiu (instalação parcial, arquivo apagado, ou o dogfood do próprio harness).
# `init` num .forge/ com specs/baseline exige --force e faz backup+sobrescrita — a ação errada e
# potencialmente destrutiva para quem só precisa restaurar um arquivo. O exit 3 e o não-escrever
# em disco (REQ-FHT-037) estão corretos nos dois casos; só a mensagem muda.
#
#   [1] .forge/ AUSENTE por completo -> mensagem original, sugere init (continua correto)
#   [2] .forge/ existe (com conteúdo) mas forge.yaml ausente -> mensagem nomeia forge.yaml, NÃO
#       sugere init, e o conteúdo existente não é tocado
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w161.XXXXXX)"
trap 'rm -rf "$T"' EXIT

git -C "$T" init -q
git -C "$T" config user.email "fixture@test"
git -C "$T" config user.name "fixture"

echo "[1] .forge/ AUSENTE por completo -> mensagem original, sugere init"
out1="$(node "$WS/bin/forge.mjs" update --target "$T" --no-plugin 2>&1)"; rc1=$?
if [ "$rc1" -ne 3 ]; then
  echo "FAIL [1]: esperado exit 3, veio $rc1 — saída: '$out1'"
  exit 1
fi
case "$out1" in
  *"npx forge-harness init"*) : ;;
  *) echo "FAIL [1]: .forge ausente deveria sugerir init — saída: '$out1'"; exit 1 ;;
esac
echo "OK [1]"

echo "[2] .forge/ existe (com conteúdo) mas forge.yaml ausente -> nomeia forge.yaml, não sugere init"
mkdir -p "$T/.forge/specs/active"
printf 'marcador de harness parcialmente instalado\n' > "$T/.forge/README.md"
out2="$(node "$WS/bin/forge.mjs" update --target "$T" --no-plugin 2>&1)"; rc2=$?
if [ "$rc2" -ne 3 ]; then
  echo "FAIL [2]: esperado exit 3 (REQ-FHT-037 — não escreve, mas ainda reprova), veio $rc2 — saída: '$out2'"
  exit 1
fi
case "$out2" in
  *forge.yaml*) : ;;
  *) echo "FAIL [2]: mensagem não nomeia forge.yaml como o artefato realmente ausente — saída: '$out2'"; exit 1 ;;
esac
case "$out2" in
  *"npx forge-harness init"*)
    echo "FAIL [2]: mensagem ainda manda rodar init com .forge/ existente — ação destrutiva/errada (LDG-0028) — saída: '$out2'"
    exit 1 ;;
esac
[ -f "$T/.forge/README.md" ] || { echo "FAIL [2]: update tocou/apagou conteúdo existente de .forge/ — nunca deveria escrever neste caminho"; exit 1; }
echo "OK [2] — saída: $out2"

echo "PASS w161-update-missing-forgeyaml-message"
