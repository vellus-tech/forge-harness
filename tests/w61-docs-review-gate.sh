#!/usr/bin/env bash
# Gate — docs-review (WAVE 4, §20.4): pre-push hard-require — mudança user-facing sem
# README.md + CHANGELOG.md revisados bloqueia o push. Sem válvula de escape.
#   [1] range user-facing (feat tocando src.js) sem README/CHANGELOG → exit 1
#   [2] range user-facing com README.md e CHANGELOG.md tocados → exit 0
#   [3] range docs-only (só docs/x.md ou só README) → exit 0
#   [4] range chore-only sem fonte → exit 0
#   [5] range só .forge/** (ex.: `forge update` sincronizando maquinaria) → exit 0, mesmo
#       tocando .sh/.mjs — não é código do projeto, é maquinaria sincronizada do harness
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/hooks/git/lib/check-docs-reviewed.sh"
[ -f "$LIB" ]
[ -x "$LIB" ]

T="$(mktemp -d /tmp/forge-docsgate.XXXXXX)"
trap 'rm -rf "$T"' EXIT

git init -q "$T"
git -C "$T" config user.email "t@t"
git -C "$T" config user.name "t"
git -C "$T" config commit.gpgsign false

# base commit so every scenario branch has a common root
echo "base" > "$T/base.txt"
git -C "$T" add -A
git -C "$T" commit -qm "chore: base"

run_gate() {  # run_gate <local_sha>
  local sha="$1"
  printf 'refs/heads/x %s refs/heads/x 0000000000000000000000000000000000000000\n' "$sha" \
    | REPO="$T" bash "$LIB"
}

echo "[1] user-facing sem README/CHANGELOG → exit 1"
git -C "$T" checkout -q -b case1
echo "console.log(1);" > "$T/src.js"
git -C "$T" add -A
git -C "$T" commit -qm "feat(app): adiciona feature nova"
sha1="$(git -C "$T" rev-parse HEAD)"
set +e
run_gate "$sha1"
rc=$?
set -e
[ "$rc" -eq 1 ]
echo "OK [1]"

echo "[2] user-facing com README.md e CHANGELOG.md → exit 0"
git -C "$T" checkout -q main 2>/dev/null || git -C "$T" checkout -q master
git -C "$T" checkout -q -b case2
echo "console.log(2);" > "$T/src2.js"
echo "# README" > "$T/README.md"
echo "# CHANGELOG" > "$T/CHANGELOG.md"
git -C "$T" add -A
git -C "$T" commit -qm "feat(app): adiciona feature nova documentada"
sha2="$(git -C "$T" rev-parse HEAD)"
run_gate "$sha2"
echo "OK [2]"

echo "[3] docs-only → exit 0"
git -C "$T" checkout -q main 2>/dev/null || git -C "$T" checkout -q master
git -C "$T" checkout -q -b case3
mkdir -p "$T/docs"
echo "doc" > "$T/docs/x.md"
git -C "$T" add -A
git -C "$T" commit -qm "docs: atualiza documentação"
sha3="$(git -C "$T" rev-parse HEAD)"
run_gate "$sha3"
echo "OK [3]"

echo "[4] chore-only sem fonte → exit 0"
git -C "$T" checkout -q main 2>/dev/null || git -C "$T" checkout -q master
git -C "$T" checkout -q -b case4
echo "ignore-me" > "$T/.gitignore"
git -C "$T" add -A
git -C "$T" commit -qm "chore: adiciona gitignore"
sha4="$(git -C "$T" rev-parse HEAD)"
run_gate "$sha4"
echo "OK [4]"

echo "[5] só .forge/** (chore de harness update) → exit 0 mesmo tocando .sh/.mjs"
git -C "$T" checkout -q main 2>/dev/null || git -C "$T" checkout -q master
git -C "$T" checkout -q -b case5
mkdir -p "$T/.forge/scripts/lib" "$T/.forge/hooks/git"
echo "#!/usr/bin/env bash" > "$T/.forge/scripts/doctor.sh"
echo "export const x = 1;" > "$T/.forge/scripts/lib/foo.mjs"
echo "#!/usr/bin/env bash" > "$T/.forge/hooks/git/pre-push"
git -C "$T" add -A
git -C "$T" commit -qm "chore(forge): atualiza harness para 0.1.0-rcN"
sha5="$(git -C "$T" rev-parse HEAD)"
run_gate "$sha5"
echo "OK [5]"

echo "OK"
