#!/usr/bin/env bash
# Gate W10.5 — ship exige avaliação canônica por SHA e não oferece bypass de review.
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
S="$WS/template/.forge/commands/git/ship.md"

grep -q 'code-evaluator.*diff_sha' "$S"
grep -q 'reviewers transversais e de stack' "$S"
grep -q 'APPROVED_WITH_COMMENTS' "$S"
grep -q 'Não há flag para pular o `code-evaluator`' "$S"
if grep -q -- '--no-review' "$S"; then
  echo 'FAIL ship ainda oferece --no-review' >&2
  exit 1
fi
echo "PASS w105-ship-review-gate"
