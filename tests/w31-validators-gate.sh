#!/usr/bin/env bash
# Gate W3.1 — runs the deterministic validators suite (§19.1–§19.4):
# every rule family has at least one PASS and one FAIL case (tests/validators.bats).
set -euo pipefail
WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bats "$WS/tests/validators.bats"
echo "OK"
