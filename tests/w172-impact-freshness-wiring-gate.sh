#!/usr/bin/env bash
# Gate W172 — G5 (frescor de grafo/impacto) vira gate EXECUTÁVEL na transição a `implementing`,
# não instrução para o agente lembrar de rodar durante /forge:analyze (LDG-0036).
#
# Antes deste fix, `impact-freshness.mjs` só era chamado por archive-spec.sh (pré-flight do
# archive — tarde demais: o código já foi implementado contra um impacto que ninguém conferiu) e
# pelo texto de analyze.md (que manda o AGENTE rodar o node manualmente). Nada em
# spec-transition.sh/validate-spec.mjs chamava o script na hora que importa — antes de começar a
# implementar. Este gate prova a fiação directa: spec-transition.sh CHAMA impact-freshness.mjs
# na transição a implementing, com o mesmo julgamento (missing/stale bloqueia; not-applicable
# nunca bloqueia) já usado pelo archive.
#
#   [0] CONTROLE: affected_paths tocando código + grafo construído + impact.json FRESCO →
#       transição a implementing sucede (não regride o caminho feliz).
#   [1] impact.json AUSENTE (grafo construído, affected_paths não vazio) → REPROVA a transição,
#       mensagem nomeia o gate (G5) e a saída (/forge:impact --change <id>).
#   [2] impact.json DESATUALIZADO (grafo mudou depois do último /forge:impact) → REPROVA.
#   [3] not-applicable — change SEM affected_paths (default, a imensa maioria) → transição
#       sucede mesmo com grafo construído (nunca bloqueia quem não toca código).
#   [4] FIAÇÃO: spec-transition.sh chama impact-freshness.mjs de verdade — não é um
#       re-julgamento paralelo que só parece testar a mesma coisa.
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w172.XXXXXX)"
trap 'rm -rf "$T"' EXIT
cp -R "$WS/template/.forge" "$T/.forge"
S="$T/.forge/scripts"

mkdir -p "$T/src"
printf 'const b = require("./b.js");\nmodule.exports = { b };\n' > "$T/src/a.js"
printf 'module.exports = 1;\n' > "$T/src/b.js"
FORGE_ROOT="$T" bash "$S/graph.sh" build >/dev/null

echo "[4] FIAÇÃO: spec-transition.sh chama lib/impact-freshness.mjs"
grep -q 'impact-freshness\.mjs' "$S/spec-transition.sh" \
  || { echo "FAIL [4]: spec-transition.sh não referencia impact-freshness.mjs (G5 continua instrução, não gate)"; exit 1; }
echo "OK [4]"

echo "[0] CONTROLE: affected_paths + grafo + impact.json fresco -> implementing sucede"
FORGE_ROOT="$T" bash "$S/spec-new.sh" chg-fresh --type feature --scale 0 >/dev/null
perl -0pi -e 's/^affected_paths: \[\]$/affected_paths:\n  - src\/a.js/m' "$T/.forge/specs/active/chg-fresh/manifest.yaml"
FORGE_ROOT="$T" bash "$S/spec-transition.sh" chg-fresh tasks-ready >/dev/null
FORGE_ROOT="$T" bash "$S/impact.sh" --change chg-fresh >/dev/null
OUT0="$(FORGE_ROOT="$T" bash "$S/spec-transition.sh" chg-fresh implementing)"
grep -q '^OK chg-fresh: tasks-ready -> implementing$' <<< "$OUT0" || { echo "FAIL [0]: transição não sucedeu: $OUT0"; exit 1; }
echo "OK [0]"

echo "[1] impact.json AUSENTE -> REPROVA a transição a implementing"
FORGE_ROOT="$T" bash "$S/spec-new.sh" chg-missing --type feature --scale 0 >/dev/null
perl -0pi -e 's/^affected_paths: \[\]$/affected_paths:\n  - src\/a.js/m' "$T/.forge/specs/active/chg-missing/manifest.yaml"
FORGE_ROOT="$T" bash "$S/spec-transition.sh" chg-missing tasks-ready >/dev/null
set +e
OUT1="$(FORGE_ROOT="$T" bash "$S/spec-transition.sh" chg-missing implementing 2>&1)"
RC1=$?
set -e
[ "$RC1" -ne 0 ] || { echo "FAIL [1]: transição passou (rc=0) sem impact.json: $OUT1"; exit 1; }
grep -q 'FAIL' <<< "$OUT1" || { echo "FAIL [1]: saída sem FAIL: $OUT1"; exit 1; }
grep -qi 'impact.json' <<< "$OUT1" || { echo "FAIL [1]: mensagem não nomeia impact.json: $OUT1"; exit 1; }
grep -qi 'missing' <<< "$OUT1" || { echo "FAIL [1]: mensagem não indica o status missing: $OUT1"; exit 1; }
grep -q '/forge:impact' <<< "$OUT1" || { echo "FAIL [1]: mensagem não indica a saída (/forge:impact): $OUT1"; exit 1; }
grep -q 'G5' <<< "$OUT1" || { echo "FAIL [1]: mensagem não nomeia o guardrail G5: $OUT1"; exit 1; }
CURSTATUS="$(awk -F': ' '$1=="status"{print $2; exit}' "$T/.forge/specs/active/chg-missing/manifest.yaml")"
[ "$CURSTATUS" = "tasks-ready" ] || { echo "FAIL [1]: manifest avançou apesar da reprovação (status: $CURSTATUS)"; exit 1; }
echo "OK [1]"

echo "[2] impact.json DESATUALIZADO (grafo mudou depois do último /forge:impact) -> REPROVA"
FORGE_ROOT="$T" bash "$S/spec-new.sh" chg-stale --type feature --scale 0 >/dev/null
perl -0pi -e 's/^affected_paths: \[\]$/affected_paths:\n  - src\/a.js/m' "$T/.forge/specs/active/chg-stale/manifest.yaml"
FORGE_ROOT="$T" bash "$S/spec-transition.sh" chg-stale tasks-ready >/dev/null
FORGE_ROOT="$T" bash "$S/impact.sh" --change chg-stale >/dev/null
printf 'const c = require("./c.js");\nmodule.exports = { c };\n' > "$T/src/a.js"
printf 'module.exports = 2;\n' > "$T/src/c.js"
FORGE_ROOT="$T" bash "$S/graph.sh" build >/dev/null
set +e
OUT2="$(FORGE_ROOT="$T" bash "$S/spec-transition.sh" chg-stale implementing 2>&1)"
RC2=$?
set -e
[ "$RC2" -ne 0 ] || { echo "FAIL [2]: transição passou (rc=0) com impact.json desatualizado: $OUT2"; exit 1; }
grep -qi 'stale' <<< "$OUT2" || { echo "FAIL [2]: mensagem não indica o status stale: $OUT2"; exit 1; }
echo "OK [2]"
# devolve o grafo para não contaminar o caso [3]
FORGE_ROOT="$T" bash "$S/graph.sh" build >/dev/null

echo "[3] not-applicable — change SEM affected_paths sucede mesmo com grafo construído"
FORGE_ROOT="$T" bash "$S/spec-new.sh" chg-na --type feature --scale 0 >/dev/null
FORGE_ROOT="$T" bash "$S/spec-transition.sh" chg-na tasks-ready >/dev/null
OUT3="$(FORGE_ROOT="$T" bash "$S/spec-transition.sh" chg-na implementing)"
grep -q '^OK chg-na: tasks-ready -> implementing$' <<< "$OUT3" || { echo "FAIL [3]: not-applicable bloqueou indevidamente: $OUT3"; exit 1; }
echo "OK [3]"

echo "OK"
