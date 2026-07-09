#!/usr/bin/env bash
# Gate W9.2 — benchmark registry:
#   [1] todos os casos canônicos validam contra benchmark-case.schema.json
#   [2] runner stub gera grading, aggregate e run-manifest
#   [3] suite roda todos os casos pequenos
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w92.XXXXXX)"
trap 'rm -rf "$T"' EXIT
cp -R "$WS/template/.forge" "$T/.forge"
S="$T/.forge/scripts"

echo "[1] benchmark cases validam contra schema"
for c in greenfield-small brownfield-bugfix refactor-invariant docs-only multi-module-scale3; do
  f="$T/.forge/evals/benchmarks/$c/case.json"
  [ -f "$f" ]
  node "$WS/tools/validate-yaml.mjs" "$WS/template/.forge/schemas/benchmark-case.schema.json" "$f" >/dev/null
done
echo "OK [1]"

echo "[2] caso mínimo gera aggregate + run-manifest"
FORGE_ROOT="$T" bash "$S/benchmark-eval.sh" greenfield-small --runner stub --runs 1 >/tmp/forge-w92-one.log
ITER="$T/.forge/evals/benchmarks/greenfield-small/runs/latest/iteration-1"
[ -f "$ITER/eval-1/grading.json" ]
[ -f "$ITER/aggregate.json" ]
RM="$(find "$ITER/evidence/runs" -name run-manifest.json | head -1)"
[ -f "$RM" ]
node "$WS/tools/validate-yaml.mjs" "$WS/template/.forge/schemas/run-manifest.schema.json" "$RM" >/dev/null
grep -q '^BUDGET stage=eval' /tmp/forge-w92-one.log
echo "OK [2]"

echo "[3] suite roda todos os casos pequenos"
FORGE_ROOT="$T" bash "$S/benchmark-eval.sh" suite --runner stub --runs 1 >/tmp/forge-w92-suite.log
grep -q 'OK benchmark suite (5 cases)' /tmp/forge-w92-suite.log
for c in greenfield-small brownfield-bugfix refactor-invariant docs-only multi-module-scale3; do
  [ -f "$T/.forge/evals/benchmarks/$c/runs/latest/iteration-1/aggregate.json" ]
done
echo "OK [3]"

echo "OK"
