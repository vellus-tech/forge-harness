#!/usr/bin/env bash
# Gate W1.4 (revised in W1.4b) — adapter SELECTION + reconcile/prune:
#   [1] default install (claude only) → no .agents/.cursor/.kiro, no QWEN/GEMINI.md
#   [2] multi-select install (claude,cursor,qwen) → only those targets; QWEN.md present
#   [3] smoke-adapters.sh green for the active set + no foreign paths
#   [4] idempotency: sync --adapter all twice → byte-identical tree
#   [5] add an adapter via --set claude,cursor,qwen,kiro → kiro appears
#   [6] remove via --set claude → .cursor/.kiro/.agents pruned, QWEN.md gone, lockfiles gone
#   [7] compatibility contract (generated mode) stays green
#   [8] doctor exits 0
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w14.XXXXXX)"
trap 'rm -rf "$T"' EXIT

tree_hash() {
  (cd "$1" && find . -type f ! -name '.DS_Store' -print0 | LC_ALL=C sort -z \
    | xargs -0 shasum -a 256 | shasum -a 256 | cut -d' ' -f1)
}
sync() { (cd "$T" && bash .forge/scripts/sync-adapters.sh "$@" >/dev/null); }

echo "[1] install default (claude only)"
"$WS/installer/install.sh" --target "$T" --slug fixture-app --name "Fixture App" --desc "Gate W1.4" >/dev/null
# LDG-0034: cada condição reprova com a SUA mensagem — agrupar arquivos/dirs numa asserção só
# não diz qual deles falhou.
[ -f "$T/AGENTS.md" ] || { echo "FAIL [1]: AGENTS.md ausente"; exit 1; }
[ -L "$T/CLAUDE.md" ] || { echo "FAIL [1]: CLAUDE.md não é symlink"; exit 1; }
[ ! -d "$T/.agents" ] || { echo "FAIL [1]: .agents presente num install default (claude-only)"; exit 1; }
[ ! -d "$T/.cursor" ] || { echo "FAIL [1]: .cursor presente num install default (claude-only)"; exit 1; }
[ ! -d "$T/.kiro" ] || { echo "FAIL [1]: .kiro presente num install default (claude-only)"; exit 1; }
[ ! -e "$T/QWEN.md" ] || { echo "FAIL [1]: QWEN.md presente num install default (claude-only)"; exit 1; }
[ ! -e "$T/GEMINI.md" ] || { echo "FAIL [1]: GEMINI.md presente num install default (claude-only)"; exit 1; }
[ "$(find "$T/.forge/adapters" -name '*.lock.yaml' | wc -l | tr -d ' ')" -eq 2 ] # core + claude
echo "OK [1]"

echo "[2] reconcile para claude,cursor,qwen"
sync --set claude,cursor,qwen
[ -f "$T/.cursor/rules/forge.mdc" ] || { echo "FAIL [2]: .cursor/rules/forge.mdc ausente"; exit 1; }
grep -q 'alwaysApply: true' "$T/.cursor/rules/forge.mdc" \
  || { echo "FAIL [2]: .cursor/rules/forge.mdc sem alwaysApply: true"; exit 1; }
[ -d "$T/.agents/commands/forge" ] || { echo "FAIL [2]: .agents/commands/forge ausente"; exit 1; }
ls "$T"/.agents/commands/forge/*.md >/dev/null \
  || { echo "FAIL [2]: .agents/commands/forge sem *.md"; exit 1; }
[ -L "$T/QWEN.md" ]
[ ! -d "$T/.kiro" ]
grep -q '    - cursor' "$T/.forge/forge.yaml" \
  || { echo "FAIL [2]: forge.yaml não lista cursor ativo"; exit 1; }
grep -q '    - qwen' "$T/.forge/forge.yaml" \
  || { echo "FAIL [2]: forge.yaml não lista qwen ativo"; exit 1; }
echo "OK [2]"

echo "[3] smokes do conjunto ativo + foreign paths"
(cd "$T" && bash .forge/scripts/smoke-adapters.sh) | tail -1 | grep -q '^OK$'
echo "OK [3]"

echo "[4] idempotencia (sync --adapter all 2x)"
sync --adapter all
H1="$(tree_hash "$T")"
sync --adapter all
H2="$(tree_hash "$T")"
[ "$H1" = "$H2" ]
echo "OK [4] (${H1:0:12})"

echo "[5] adicionar kiro via --set"
sync --set claude,cursor,qwen,kiro
[ -f "$T/.kiro/steering/forge.md" ] || { echo "FAIL [5]: .kiro/steering/forge.md ausente"; exit 1; }
[ ! -d "$T/.kiro/specs" ] || { echo "FAIL [5]: .kiro/specs presente indevidamente"; exit 1; }
echo "OK [5]"

echo "[6] reduzir para claude → poda cursor/qwen/kiro"
sync --set claude
[ ! -d "$T/.cursor" ] || { echo "FAIL [6]: .cursor deveria ter sido podado"; exit 1; }
[ ! -d "$T/.kiro" ] || { echo "FAIL [6]: .kiro deveria ter sido podado"; exit 1; }
[ ! -d "$T/.agents" ] || { echo "FAIL [6]: .agents deveria ter sido podado"; exit 1; }
[ ! -e "$T/QWEN.md" ]
[ ! -f "$T/.forge/adapters/cursor.lock.yaml" ] || { echo "FAIL [6]: cursor.lock.yaml deveria ter sido removido"; exit 1; }
[ ! -f "$T/.forge/adapters/qwen.lock.yaml" ] || { echo "FAIL [6]: qwen.lock.yaml deveria ter sido removido"; exit 1; }
[ ! -f "$T/.forge/adapters/kiro.lock.yaml" ] || { echo "FAIL [6]: kiro.lock.yaml deveria ter sido removido"; exit 1; }
[ -f "$T/.forge/adapters/claude.lock.yaml" ] || { echo "FAIL [6]: claude.lock.yaml deveria sobreviver à poda"; exit 1; }
[ -f "$T/.forge/adapters/core.lock.yaml" ] || { echo "FAIL [6]: core.lock.yaml deveria sobreviver à poda"; exit 1; }
[ -f "$T/AGENTS.md" ] || { echo "FAIL [6]: AGENTS.md deveria sobreviver à poda (core)"; exit 1; }
[ -L "$T/CLAUDE.md" ] || { echo "FAIL [6]: CLAUDE.md deveria sobreviver à poda (claude)"; exit 1; }
echo "OK [6] (poda completa, claude intacto)"

echo "[7] contrato (generated mode)"
CLAUDE_CONTRACT_MODE=generated CLAUDE_CONTRACT_TARGET="$T" \
  bats "$WS/tests/snapshot/claude-contract.bats" >/dev/null
echo "OK [7]"

echo "[8] doctor"
(cd "$T" && bash .forge/scripts/doctor.sh --report >/dev/null)
echo "OK [8]"

echo "OK"
