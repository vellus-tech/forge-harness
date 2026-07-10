#!/usr/bin/env bash
# HITL decision log (§12.1) — appends one entry to the active change's
# approvals.yaml and, on approve, flips the corresponding manifest gate to true.
# Usage:
#   approval-log.sh <change-id> --gate <gate> --decision <decision>
#                   [--reason "<text>"] [--iteration N] [--scope "<text>"]
#                   [--notes "<text>"] [--superseded-by <id>] [--autonomous]
# gates:     requirements_reviewed | design_reviewed | tasks_reviewed |
#            implementation_verified | human_archive_approval | close
# decisions: approve | review | reject | supersede | abandon | block | deliver-external
# Rules (§12.1): every decision except approve REQUIRES --reason;
#                supersede also requires --superseded-by; iteration is 1..3.
# --autonomous (§12.2, modo yolo): decisão tomada por subagente Opus, não por humano.
#                Grava autonomous:true e decided_by fixo "forge-yolo (opus, high)"; exige
#                --reason SEMPRE (inclusive approve) para a análise ficar auditável.
# Output: "OK <id>: <gate> = <decision>" or "FAIL (...)".
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${FORGE_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

ID="${1:-}"; shift || true
GATE=""; DECISION=""; REASON=""; ITERATION=""; SCOPE=""; NOTES=""; SUPERSEDED_BY=""; AUTONOMOUS=0
while [ $# -gt 0 ]; do case "$1" in
  --gate) GATE="${2:-}"; shift 2 ;;
  --decision) DECISION="${2:-}"; shift 2 ;;
  --reason) REASON="${2:-}"; shift 2 ;;
  --iteration) ITERATION="${2:-}"; shift 2 ;;
  --scope) SCOPE="${2:-}"; shift 2 ;;
  --notes) NOTES="${2:-}"; shift 2 ;;
  --superseded-by) SUPERSEDED_BY="${2:-}"; shift 2 ;;
  --autonomous) AUTONOMOUS=1; shift ;;
  *) echo "FAIL (unknown argument: $1)"; exit 2 ;;
esac; done

[ -n "$ID" ] || { echo "FAIL (usage: approval-log.sh <change-id> --gate <g> --decision <d> ...)"; exit 2; }
DIR="$ROOT/.forge/specs/active/$ID"
MAN="$DIR/manifest.yaml"
[ -f "$MAN" ] || { echo "FAIL (no active change: $ID)"; exit 1; }

case "$GATE" in requirements_reviewed|design_reviewed|tasks_reviewed|implementation_verified|human_archive_approval|close) ;; *) echo "FAIL (--gate invalid: '$GATE')"; exit 2 ;; esac
case "$DECISION" in approve|review|reject|supersede|abandon|block|deliver-external) ;; *) echo "FAIL (--decision invalid: '$DECISION')"; exit 2 ;; esac
if [ "$DECISION" != "approve" ] && [ -z "$REASON" ]; then
  echo "FAIL (every decision except approve requires --reason — §12.1)"; exit 2
fi
# Modo autônomo (--yolo): a decisão é de um subagente, não de um humano. Toda decisão
# autônoma — inclusive approve — carrega a análise como reason (auditoria: a máquina sempre
# registra o porquê, para ser distinguível e revisável). O registro marca autonomous:true.
if [ "$AUTONOMOUS" -eq 1 ] && [ -z "$REASON" ]; then
  echo "FAIL (autonomous decision requires --reason — a máquina sempre registra a análise, §12.2)"; exit 2
fi
# Hard-stop DETERMINISTA (§12.2/§13.1): --autonomous não pode decidir um gate listado em
# autonomy.human_hard_stops do forge.yaml. A fronteira de segurança é mecânica aqui — não fica
# refém do juízo do agente. Mutação de baseline em domínio regulado exige humano de verdade.
if [ "$AUTONOMOUS" -eq 1 ] && [ -f "$ROOT/.forge/forge.yaml" ]; then
  HARD_STOPS="$(awk '/^autonomy:/{a=1;next} a&&/^[^[:space:]]/{a=0} a&&/human_hard_stops:/{l=1;next} l&&/^[[:space:]]*-[[:space:]]/{sub(/^[[:space:]]*-[[:space:]]*/,"");print;next} l&&/^[[:space:]]*[a-z_]+:/{l=0}' "$ROOT/.forge/forge.yaml")"
  for hs in $HARD_STOPS; do
    [ "$hs" = "$GATE" ] && { echo "FAIL (gate '$GATE' está em autonomy.human_hard_stops — decisão autônoma proibida; exige aprovação humana, §13.1)"; exit 2; }
  done
fi
if [ "$DECISION" = "supersede" ] && [ -z "$SUPERSEDED_BY" ]; then
  echo "FAIL (supersede requires --superseded-by <change-id>)"; exit 2
fi
if [ -n "$ITERATION" ]; then
  case "$ITERATION" in 1|2|3) ;; *) echo "FAIL (--iteration must be 1..3 — loop §14.6 escalates after 3)"; exit 2 ;; esac
fi

if [ "$AUTONOMOUS" -eq 1 ]; then
  BY="forge-yolo (opus, high)"   # identidade honesta do decisor autônomo — nunca um humano
else
  BY="$(git config user.name 2>/dev/null || true)"; [ -n "$BY" ] || BY="$(id -un)"
fi
AT="$(date +%Y-%m-%dT%H:%M:%S%z | sed 's/\([0-9][0-9]\)$/:\1/')"
COMMIT="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || true)"

FILE="$DIR/approvals.yaml"
[ -f "$FILE" ] || printf 'approvals:\n' > "$FILE"

{
  printf '  - gate: %s\n' "$GATE"
  printf '    decision: %s\n' "$DECISION"
  [ "$AUTONOMOUS" -eq 1 ] && printf '    autonomous: true\n'
  [ -n "$REASON" ] && printf '    reason: "%s"\n' "$(printf '%s' "$REASON" | sed 's/"/\\"/g')"
  printf '    decided_by: "%s"\n' "$BY"
  printf '    decided_at: "%s"\n' "$AT"
  [ -n "$ITERATION" ] && printf '    iteration: %s\n' "$ITERATION"
  [ -n "$COMMIT" ] && printf '    commit: "%s"\n' "$COMMIT"
  [ -n "$SCOPE" ] && printf '    scope: "%s"\n' "$(printf '%s' "$SCOPE" | sed 's/"/\\"/g')"
  [ -n "$NOTES" ] && printf '    notes: "%s"\n' "$(printf '%s' "$NOTES" | sed 's/"/\\"/g')"
  [ -n "$SUPERSEDED_BY" ] && printf '    superseded_by: %s\n' "$SUPERSEDED_BY"
} >> "$FILE"

if [ "$DECISION" = "approve" ] && [ "$GATE" != "close" ]; then
  GATE_RE="$GATE" perl -pi -e 's/^(  \Q$ENV{GATE_RE}\E): false$/$1: true/' "$MAN"
fi

echo "OK $ID: $GATE = $DECISION"
