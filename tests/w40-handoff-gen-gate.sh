#!/usr/bin/env bash
# Gate — handoff-gen (REQ-02/NFR-02): o gerador determinístico monta .forge/HANDOFF.md a partir
# do estado do change (manifest/progress/deferrals), degrada sem FORGE.md, é idempotente e preserva
# um delta narrativo já escrito.
#   [1] gera o artefato com as 5 seções + dados do change
#   [2] determinismo: duas execuções sem mudança de estado → diff vazio
#   [3] degradação sem FORGE.md → runtime = n/d
#   [4] preserva o delta narrativo escrito entre os marcadores
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GEN="$WS/template/.forge/scripts/handoff-gen.sh"
[ -f "$GEN" ]
T="$(mktemp -d /tmp/forge-handoff.XXXXXX)"
trap 'rm -rf "$T"' EXIT

DIR="$T/.forge/specs/active/demo-change"
mkdir -p "$DIR"
cat > "$DIR/manifest.yaml" <<'YAML'
id: demo-change
type: feature
scale: 2
status: implementing
YAML
cat > "$DIR/progress.json" <<'JSON'
{ "current_wave": 2, "done_stories": 1, "total_stories": 3, "done_tasks": 4, "total_tasks": 10 }
JSON
cat > "$DIR/deferrals.json" <<'JSON'
[ { "id": "DEFER-1", "status": "open" }, { "id": "DEFER-2", "status": "resolved" } ]
JSON

echo "[1] gera artefato com seções + dados"
FORGE_ROOT="$T" bash "$GEN" demo-change >/dev/null
H="$T/.forge/HANDOFF.md"
[ -f "$H" ]
grep -q '## 1. Header' "$H"
grep -q '## 2. Estado' "$H"
grep -q '## 3. Regras fixas da sessão' "$H"
grep -q '## 4. Delta narrativo' "$H"
grep -q '## 5. Como retomar' "$H"
grep -q 'demo-change' "$H"
grep -q 'DEFER-1' "$H"
grep -q '4/10' "$H"
echo "OK [1]"

echo "[2] determinismo: duas execuções → diff vazio"
cp "$H" "$T/first.md"
FORGE_ROOT="$T" bash "$GEN" demo-change >/dev/null
diff "$T/first.md" "$H"
echo "OK [2]"

echo "[3] degradação sem FORGE.md → runtime n/d"
grep -q 'test=`n/d`' "$H"
echo "OK [3]"

echo "[4] preserva delta narrativo escrito"
python3 - "$H" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
a = '<!-- FORGE:NARRATIVE-DELTA:START -->'
b = '<!-- FORGE:NARRATIVE-DELTA:END -->'
i = s.index(a) + len(a); j = s.index(b)
s = s[:i] + '\nFoco: terminar a wave 2. Decisão aberta: X.\n' + s[j:]
open(p, 'w').write(s)
PY
FORGE_ROOT="$T" bash "$GEN" demo-change >/dev/null
grep -q 'Foco: terminar a wave 2' "$H"
echo "OK [4]"

echo "PASS w40-handoff-gen-gate"
