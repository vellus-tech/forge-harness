#!/usr/bin/env bash
# Gate W25.4 — run-manifest.sh não descarta o --root do chamador (#128):
#   [1] chamador passa --root B: head_sha gravado é o HEAD de B, não do wrapper
#   [2] --root repetido com valores DIFERENTES recusa (rc != 0, mensagem nomeia a flag)
#   [3] --root repetido com o MESMO valor é aceito (inofensivo)
#   [4] sem --root do chamador: grava o HEAD da árvore do próprio wrapper (contrafactual)
#   [5] PBT: para permutações da posição do --root do chamador entre outros argumentos,
#       o head_sha gravado é sempre o HEAD do --root do chamador
set -euo pipefail
# Isolamento git (LDG-0201): GIT_DIR herdado do ambiente faria os comandos git abaixo
# obedecerem ao repositório de quem invocou o gate, e não aos repositórios sintéticos criados aqui.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w254.XXXXXX)"
trap 'rm -rf "$T"' EXIT

# A (wrapper tree): tem o .forge/scripts que serão invocados.
A="$T/A"
mkdir -p "$A"
cp -R "$WS/template/.forge" "$A/.forge"
git -C "$A" init >/dev/null
git -C "$A" config user.email forge@example.test
git -C "$A" config user.name Forge
git -C "$A" add -A >/dev/null
git -C "$A" commit -m "A init" >/dev/null
A_HEAD="$(git -C "$A" rev-parse HEAD)"

# B (chamador --root): repositório git distinto, com HEAD diferente de A.
B="$T/B"
mkdir -p "$B"
git -C "$B" init >/dev/null
git -C "$B" config user.email forge@example.test
git -C "$B" config user.name Forge
printf 'b\n' > "$B/b.txt"
git -C "$B" add b.txt >/dev/null
git -C "$B" commit -m "B init" >/dev/null
B_HEAD="$(git -C "$B" rev-parse HEAD)"
[ "$A_HEAD" != "$B_HEAD" ]

S="$A/.forge/scripts"

echo "[1] chamador passa --root B: head_sha gravado é o HEAD de B"
OUT_DIR="$T/out1"
mkdir -p "$OUT_DIR"
bash "$S/run-manifest.sh" write --root "$B" --stage verify --dir "$OUT_DIR" --status passed >/dev/null
RM1="$(find "$OUT_DIR/evidence/runs" -name run-manifest.json | head -1)"
[ -n "$RM1" ] && [ -f "$RM1" ]
HS1="$(node -e "console.log(require('$RM1').git.head_sha)")"
[ "$HS1" = "$B_HEAD" ] || { echo "FAIL [1]: head_sha gravado=$HS1 A=$A_HEAD B=$B_HEAD"; exit 1; }
echo "OK [1]"

echo "[2] --root repetido com valores diferentes recusa"
set +e
OUT2="$(FORGE_ROOT="$A" bash "$S/run-manifest.sh" write --root "$B" --root "$A" --stage verify --dir "$T/out2" --status passed 2>&1)"
RC2=$?
set -e
[ "$RC2" -ne 0 ] || { echo "FAIL [2]: rc=0, esperado != 0"; exit 1; }
grep -qi -- '--root' <<<"$OUT2" || { echo "FAIL [2]: mensagem não cita --root: $OUT2"; exit 1; }
echo "OK [2]"

echo "[3] --root repetido com o mesmo valor é aceito"
OUT_DIR3="$T/out3"
mkdir -p "$OUT_DIR3"
node "$S/lib/run-manifest.mjs" write --root "$B" --root "$B" --stage verify --dir "$OUT_DIR3" --status passed >/dev/null
RM3="$(find "$OUT_DIR3/evidence/runs" -name run-manifest.json | head -1)"
[ -n "$RM3" ] && [ -f "$RM3" ]
HS3="$(node -e "console.log(require('$RM3').git.head_sha)")"
[ "$HS3" = "$B_HEAD" ] || { echo "FAIL [3]: head_sha gravado=$HS3 esperado=$B_HEAD"; exit 1; }
echo "OK [3]"

echo "[4] sem --root do chamador: grava o HEAD da árvore do próprio wrapper"
OUT_DIR4="$T/out4"
mkdir -p "$OUT_DIR4"
bash "$S/run-manifest.sh" write --stage verify --dir "$OUT_DIR4" --status passed >/dev/null
RM4="$(find "$OUT_DIR4/evidence/runs" -name run-manifest.json | head -1)"
[ -n "$RM4" ] && [ -f "$RM4" ]
HS4="$(node -e "console.log(require('$RM4').git.head_sha)")"
[ "$HS4" = "$A_HEAD" ] || { echo "FAIL [4]: head_sha gravado=$HS4 esperado=$A_HEAD (HEAD do wrapper)"; exit 1; }
echo "OK [4]"

echo "[5] PBT: --root do chamador em posição aleatória sempre vence"
for perm in \
  "--root|$B|--stage|verify|--status|passed" \
  "--stage|verify|--root|$B|--status|passed" \
  "--stage|verify|--status|passed|--root|$B"
do
  IFS='|' read -r -a args <<<"$perm"
  OUT_DIR_P="$T/out-perm-$RANDOM"
  mkdir -p "$OUT_DIR_P"
  bash "$S/run-manifest.sh" write "${args[@]}" --dir "$OUT_DIR_P" >/dev/null
  RMP="$(find "$OUT_DIR_P/evidence/runs" -name run-manifest.json | head -1)"
  [ -n "$RMP" ] && [ -f "$RMP" ]
  HSP="$(node -e "console.log(require('$RMP').git.head_sha)")"
  [ "$HSP" = "$B_HEAD" ] || { echo "FAIL [5]: permutação '$perm' gravou head_sha=$HSP esperado=$B_HEAD"; exit 1; }
done
echo "OK [5]"

echo "OK"
