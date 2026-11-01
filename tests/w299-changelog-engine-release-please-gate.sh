#!/usr/bin/env bash
# Gate W299 — changelog-engine.mjs, deteccao de release-please-config.json (TASK-04).
#
# Cenários:
#   [1] componente com release-please-config.json + modo explicito -> CHANGELOG intocado, saida
#       aponta "titulo do PR"
#   [2] raiz com release-please-config.json + --merge-range -> CHANGELOG intocado, sem erro
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="$WS/template/.forge/skills/readme-generator/scripts/changelog-engine.mjs"

T="$(mktemp -d /tmp/forge-w299.XXXXXX)"
trap 'rm -rf "$T"' EXIT

# ── [1] ──────────────────────────────────────────────────────────────────────────────────────
echo "[1] componente com release-please-config.json + modo explicito -> CHANGELOG intocado"
R1="$T/r1"; mkdir -p "$R1"
printf '{}\n' > "$R1/release-please-config.json"
printf '# Changelog\n\n## [Unreleased]\n' > "$R1/CHANGELOG.md"
before="$(cat "$R1/CHANGELOG.md")"
out="$(node "$ENGINE" --root "$R1" --type added --description "nao deveria entrar" 2>&1)"
after="$(cat "$R1/CHANGELOG.md")"
[ "$before" = "$after" ] || { echo "FAIL [1]: CHANGELOG.md alterado com release-please-config.json presente"; exit 1; }
case "$out" in
  *"titulo do PR"*|*"título do PR"*) : ;;
  *) echo "FAIL [1]: saida nao aponta para o titulo do PR como fonte (saida: $out)"; exit 1 ;;
esac
echo "OK [1]"

# ── [2] ──────────────────────────────────────────────────────────────────────────────────────
echo "[2] raiz com release-please-config.json + --merge-range -> CHANGELOG intocado, sem erro"
R2="$T/r2"; mkdir -p "$R2"
printf '{}\n' > "$R2/release-please-config.json"
git -C "$R2" init -q -b main
git -C "$R2" config user.email t@t; git -C "$R2" config user.name t; git -C "$R2" config commit.gpgsign false
printf '# Changelog\n\n## [Unreleased]\n' > "$R2/CHANGELOG.md"
git -C "$R2" add -A >/dev/null 2>&1; git -C "$R2" commit -qm 'chore: init' >/dev/null 2>&1
git -C "$R2" checkout -qb feature >/dev/null 2>&1
printf 'x\n' > "$R2/x.txt"; git -C "$R2" add -A >/dev/null 2>&1
git -C "$R2" commit -qm 'feat(x): adicionar x' >/dev/null 2>&1
git -C "$R2" checkout -q main >/dev/null 2>&1
git -C "$R2" merge -q --no-ff feature -m 'merge feature' >/dev/null 2>&1
before2="$(cat "$R2/CHANGELOG.md")"
out2="$(node "$ENGINE" --root "$R2" --merge-range 2>&1)"; rc2=$?
after2="$(cat "$R2/CHANGELOG.md")"
[ "$rc2" -eq 0 ] || { echo "FAIL [2]: rc=$rc2 (deveria ser no-op sem erro) saida: $out2"; exit 1; }
[ "$before2" = "$after2" ] || { echo "FAIL [2]: CHANGELOG.md alterado com release-please-config.json presente na raiz"; exit 1; }
echo "OK [2]"

echo "PASS w299-changelog-engine-release-please"
