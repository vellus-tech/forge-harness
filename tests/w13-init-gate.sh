#!/usr/bin/env bash
# Gate W1.3 (E2E) — exercises the deterministic installer end to end:
#   [1] greenfield install (empty dir, no git) → full structure, no orphan placeholders
#   [2] doctor --report exits 0 on the fresh install
#   [3] re-init without --force → exit 3, tree untouched (overwrite guard)
#   [4] re-init with --force → previous tree backed up as .forge.bak-1
#   [5] compatibility contract (generated mode) stays green
#   [6] git repo install → hooksPath configured, staging.yml present, pre-commit hook runs OK
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T1="$(mktemp -d /tmp/forge-w13a.XXXXXX)"
T2="$(mktemp -d /tmp/forge-w13b.XXXXXX)"
trap 'rm -rf "$T1" "$T2"' EXIT

tree_hash() {
  (cd "$1" && find . -type f ! -name '.DS_Store' -print0 | LC_ALL=C sort -z \
    | xargs -0 shasum -a 256 | shasum -a 256 | cut -d' ' -f1)
}

echo "[1] greenfield install (sem git)"
"$WS/installer/install.sh" --target "$T1" --slug fixture-app --name "Fixture App" --desc "Fixture do gate W1.3" >/dev/null
[ -f "$T1/.forge/FORGE.md" ]
# .forge/templates/ keeps placeholders by design (they are templates for future artifacts)
[ "$(grep -rl '<PROJECT_[A-Z_]*>' "$T1/.forge" | grep -v '/templates/' | wc -l | tr -d ' ')" -eq 0 ]
grep -q '<PROJECT_SLUG>' "$T1/.forge/templates/FORGE.md"
# default install = claude only: AGENTS.md (core) + CLAUDE.md; NO QWEN/GEMINI/.agents/.cursor/.kiro
[ -f "$T1/AGENTS.md" ] && [ -L "$T1/CLAUDE.md" ]
[ ! -e "$T1/QWEN.md" ] && [ ! -e "$T1/GEMINI.md" ]
[ ! -d "$T1/.agents" ] && [ ! -d "$T1/.cursor" ] && [ ! -d "$T1/.kiro" ]
[ -f "$T1/.claude/settings.json" ] && [ -f "$T1/.forge/adapters/claude.lock.yaml" ] && [ -f "$T1/.forge/adapters/core.lock.yaml" ]
grep -q '>>> forge (managed) >>>' "$T1/.gitignore"
echo "OK [1] (claude-only, sem poluicao de adapters nao escolhidos)"

echo "[2] doctor exit 0"
(cd "$T1" && bash .forge/scripts/doctor.sh --report >/dev/null)
echo "OK [2]"

echo "[3] guarda contra sobrescrita (sem --force)"
H1="$(tree_hash "$T1")"
set +e
"$WS/installer/install.sh" --target "$T1" --slug other >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 3 ]
[ "$(tree_hash "$T1")" = "$H1" ]
echo "OK [3] (exit 3, arvore intacta)"

echo "[4] --force cria backup"
"$WS/installer/install.sh" --target "$T1" --slug fixture-app --name "Fixture App" --desc "Fixture do gate W1.3" --force >/dev/null
[ -d "$T1/.forge.bak-1" ]
echo "OK [4]"

echo "[5] contrato (generated mode)"
CLAUDE_CONTRACT_MODE=generated CLAUDE_CONTRACT_TARGET="$T1" \
  bats "$WS/tests/snapshot/claude-contract.bats" >/dev/null
echo "OK [5] (bats verde)"

echo "[6] repo git: hooksPath + staging.yml + pre-commit"
git -C "$T2" init -q -b main
"$WS/installer/install.sh" --target "$T2" --slug fixture-git --name "Fixture Git" --desc "Fixture git do gate W1.3" >/dev/null
[ "$(git -C "$T2" config core.hooksPath)" = ".forge/hooks/git" ]
[ -f "$T2/.github/workflows/staging.yml" ]
git -C "$T2" add -A
out="$(git -C "$T2" -c user.name=fixture -c user.email=fixture@test commit -q -m "chore: fixture inicial" 2>&1 || { echo "COMMIT_FAILED"; exit 1; })"
git -C "$T2" log --oneline -1 >/dev/null
echo "OK [6] (hooks ativos, commit passou pelo pre-commit)"

echo "OK"
