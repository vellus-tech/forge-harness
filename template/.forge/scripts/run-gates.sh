#!/usr/bin/env bash
# run-gates.sh — executa os gates declarados em `runtime.gates` do FORGE.md para um change.
#
# Este script já era INVOCADO pela documentação e não existia. `commands/waves/wave.md` manda:
#
#     gate_result="$(bash .forge/scripts/run-gates.sh <change-id> <wave-id> 2>&1 | tail -1)"
#     bash .forge/scripts/wave-ops.sh close <change-id> <wave-id> --gate "$gate_result"
#
# e o arquivo não estava no repositório. O efeito prático é o que se espera de uma referência morta:
# o veredito da wave passou a vir do chamador. A skill `wave-advance` chegava a passar `--gate OK`
# literal, e o `wave-ops.sh close` assumia `OK` quando ninguém passava nada. Ninguém mentiu — só
# não havia como não mentir.
#
# Uso:
#   run-gates.sh <change-id> [wave-id]
# Saída: uma linha por gate, e a ÚLTIMA linha é o veredito agregado — `OK`, `FAIL` ou
# `NO-GATES` (nenhum gate declarado no FORGE.md). O `| tail -1` da doc depende disso.
# Exit: 0 quando todos passam ou não há gate declarado; 1 quando algum reprova.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${FORGE_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
export FORGE_ROOT="$ROOT"
# shellcheck source=lib/forge-runtime.sh
. "$SCRIPT_DIR/lib/forge-runtime.sh"

ID="${1:-}"
WAVE="${2:-}"
[ -n "$ID" ] || { echo "FAIL (usage: run-gates.sh <change-id> [wave-id])" >&2; echo "FAIL"; exit 1; }

label="$ID"
[ -n "$WAVE" ] && label="$ID/$WAVE"

gates=()
while IFS= read -r g; do [ -n "$g" ] && gates+=("$g"); done < <(forge_runtime_gates "$ROOT")

if [ "${#gates[@]}" -eq 0 ]; then
  # Nenhum gate declarado é estado legítimo (projeto que ainda não adotou), mas tem de ser DITO:
  # "NO-GATES" é auditável, e quem lê o waves.json depois consegue distinguir "passou nos gates" de
  # "não havia gate". `OK` aqui apagaria essa diferença — é a ambiguidade que este script remove.
  echo "  (nenhum gate declarado em runtime.gates do FORGE.md — nada a executar)"
  echo "NO-GATES"
  exit 0
fi

# Diretório de log por EXECUÇÃO, não por nome. Um path fixo `/tmp/forge-gates-<id>-<gate>.log`
# colide entre duas execuções simultâneas do mesmo change — dois processos escrevendo o mesmo
# arquivo produzem veredito cruzado, e o gate que reprova pode não ser o que o log mostra.
LOGDIR="$(mktemp -d /tmp/forge-gates.XXXXXX)"
fail=0
for gate in "${gates[@]}"; do
  script="$SCRIPT_DIR/${gate}.sh"
  log="$LOGDIR/$gate.log"
  if [ ! -f "$script" ]; then
    # Pré-requisito ausente REPROVA. Antes isto era WARN + skip no spec-verify, o que faz um gate
    # declarado e inexistente virar silêncio verde — a forma exata do risco que o harness proíbe.
    echo "  $gate: MISSING ($script não existe)"
    fail=1
    continue
  fi
  if forge_run_gate "$gate" "bash '$script' '$ID'" "$log" "$ROOT"; then
    echo "  $gate: passed (log: $log)"
  else
    echo "  $gate: failed (log: $log)"
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then echo "FAIL"; exit 1; fi
echo "OK"
