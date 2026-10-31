#!/usr/bin/env bash
# ORDINAL: wNNN atribuído na hora do merge
# Gate de desempenho — gancho de saída `guard-cross-session-send.sh` (NFR-01, TASK-16/TASK-17,
# STORY-09): p95 ≤ 300 ms em 50 execuções por caso do REQ-05, sobre um registro de fixture com
# 20 sessões e um workspace com repositório aninhado e worktree. A lógica mora no driver
# `tests/native-send-guard-perf-gate.driver.mjs` (node:perf_hooks sobre o processo real do
# gancho, via node:child_process) — este .sh só isola o ambiente git e repassa o resultado.
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

node "$WS/tests/native-send-guard-perf-gate.driver.mjs"
echo "PASS native-send-guard-perf-gate"
