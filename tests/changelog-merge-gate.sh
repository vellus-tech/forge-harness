#!/usr/bin/env bash
# Gate — changelog-from-merge (§20.4): o post-merge acumula commits convencionais
# do branch mergeado no CHANGELOG.md raiz (Keep a Changelog, [Unreleased]).
#   [1] no-op sem CHANGELOG.md raiz
#   [2] merge com feat/fix/chore → Added(feat)+Fixed(fix); chore ignorado
#   [3] idempotência: re-rodar não duplica
#   [4] no-op quando HEAD não é merge
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib/changelog-from-merge.mjs"
[ -f "$LIB" ]
T="$(mktemp -d /tmp/forge-chlog.XXXXXX)"
trap 'rm -rf "$T"' EXIT

cd "$T"
git init -q
git config user.email "t@t"; git config user.name "t"
git config commit.gpgsign false
mkdir -p .forge/scripts/lib
cp "$LIB" .forge/scripts/lib/changelog-from-merge.mjs

echo "[1] no-op sem CHANGELOG.md raiz"
echo "x" > a.txt; git add -A; git commit -qm "chore: base"
node .forge/scripts/lib/changelog-from-merge.mjs "$T" || true
[ ! -f CHANGELOG.md ]
echo "OK [1]"

echo "[2] merge feat/fix/chore → Added+Fixed; chore ignorado"
printf '# Changelog\n\nFormato Keep a Changelog.\n' > CHANGELOG.md
git add -A; git commit -qm "docs: changelog inicial"
git checkout -q -b feature/x
echo "1" > f1.txt; git add -A; git commit -qm "feat(auth): adiciona login por OTP"
echo "2" > f2.txt; git add -A; git commit -qm "fix(billing): corrige arredondamento de centavos"
echo "3" > f3.txt; git add -A; git commit -qm "chore: bump deps"
git checkout -q main 2>/dev/null || git checkout -q master
git merge --no-ff --no-edit feature/x -q
node .forge/scripts/lib/changelog-from-merge.mjs "$T"
grep -q '## \[Unreleased\]' CHANGELOG.md
grep -q '### Added' CHANGELOG.md && grep -q 'login por OTP' CHANGELOG.md
grep -q '### Fixed' CHANGELOG.md && grep -q 'arredondamento de centavos' CHANGELOG.md
! grep -q 'bump deps' CHANGELOG.md
echo "OK [2]"

echo "[3] idempotência: re-rodar não duplica"
before="$(grep -c 'login por OTP' CHANGELOG.md)"
node .forge/scripts/lib/changelog-from-merge.mjs "$T"
after="$(grep -c 'login por OTP' CHANGELOG.md)"
[ "$before" -eq 1 ] && [ "$after" -eq 1 ]
echo "OK [3]"

echo "[4] no-op quando HEAD não é merge"
cp CHANGELOG.md /tmp/chlog-snap.$$
echo "4" > f4.txt; git add -A; git commit -qm "feat: muda algo sem merge"
node .forge/scripts/lib/changelog-from-merge.mjs "$T"
diff -q CHANGELOG.md /tmp/chlog-snap.$$ >/dev/null
rm -f /tmp/chlog-snap.$$
echo "OK [4]"

echo "OK"
