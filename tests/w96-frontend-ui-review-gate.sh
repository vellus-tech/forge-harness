#!/usr/bin/env bash
# Gate W-frontend — skill frontend-ui-review: o scanner de token fantasma (A1, o gate mais
# importante) é o núcleo executável. Exercita o comportamento real, não só a presença.
#   [1] fixture COM token fantasma → exit 1 e reporta o token não definido
#   [2] fixture SEM fantasma (tudo definido) → exit 0
#   [3] allowlist suprime token injetado em runtime → exit 0
#   [4] artefatos presentes: SKILL.md (name correto), scanner, convenções 10-12 na rule, fiação no agent
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN="$WS/template/.forge/skills/frontend-ui-review/scripts/scan-phantom-tokens.py"
T="$(mktemp -d /tmp/forge-fe.XXXXXX)"
trap 'rm -rf "$T"' EXIT

command -v python3 >/dev/null 2>&1 || { echo "SKIP (python3 ausente)"; echo "PASS w96-frontend-ui-review-gate"; exit 0; }
[ -f "$SCAN" ] || { echo "FAIL (scanner ausente: $SCAN)"; exit 1; }

# tokens definidos
printf ':root {\n  --surface-0: #fff;\n  --color-primary-500: #0051E6;\n}\n' > "$T/tokens.css"
mkdir -p "$T/src"

echo "[1] fixture com token fantasma → FAIL"
# --surface-0 definido (ok), --surface-1 NUNCA definido (fantasma)
printf '.card { background: var(--surface-0); color: var(--surface-1); }\n' > "$T/src/Card.module.css"
set +e
out="$(python3 "$SCAN" "$T/tokens.css" "$T/src")"; rc=$?
set -e
[ "$rc" -eq 1 ] || { echo "FAIL [1] (esperava exit 1, veio $rc)"; exit 1; }
echo "$out" | grep -q 'PHANTOM --surface-1' || { echo "FAIL [1] (não reportou --surface-1)"; exit 1; }
echo "$out" | grep -q 'PHANTOM --surface-0' && { echo "FAIL [1] (marcou token DEFINIDO como fantasma)"; exit 1; }
echo "OK [1]"

echo "[2] fixture sem fantasma → OK"
printf '.card { background: var(--surface-0); color: var(--color-primary-500); }\n' > "$T/src/Card.module.css"
set +e
python3 "$SCAN" "$T/tokens.css" "$T/src" >/dev/null; rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "FAIL [2] (esperava exit 0, veio $rc)"; exit 1; }
echo "OK [2]"

echo "[2b] token com maiúscula/underscore definido+referenciado → NÃO é fantasma"
# custom properties são case-sensitive; a regex precisa aceitar [A-Za-z0-9_-]. src isolado.
mkdir -p "$T/src2"
printf ':root { --gap-Large: 24px; --fontSize_base: 16px; }\n' > "$T/tokens2.css"
printf '.box { gap: var(--gap-Large); font-size: var(--fontSize_base); }\n' > "$T/src2/Box.module.css"
set +e
out2="$(python3 "$SCAN" "$T/tokens2.css" "$T/src2")"; rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "FAIL [2b] (token maiúsculo definido virou falso-positivo, exit $rc): $out2"; exit 1; }
echo "OK [2b]"

echo "[3] allowlist suprime token injetado em runtime → OK"
printf '.bar { width: var(--progress); background: var(--surface-0); }\n' > "$T/src/Bar.module.css"
set +e
python3 "$SCAN" "$T/tokens.css" "$T/src" "--progress" >/dev/null; rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "FAIL [3] (allowlist não suprimiu --progress, exit $rc)"; exit 1; }
# sem allowlist, --progress é fantasma → exit 1 (prova que a allowlist é que suprimiu)
set +e
python3 "$SCAN" "$T/tokens.css" "$T/src" >/dev/null; rc=$?
set -e
[ "$rc" -eq 1 ] || { echo "FAIL [3] (--progress deveria ser fantasma sem allowlist)"; exit 1; }
echo "OK [3]"

echo "[4] artefatos + fiação presentes"
SK="$WS/template/.forge/skills/frontend-ui-review/SKILL.md"
[ -f "$SK" ] || { echo "FAIL [4] (SKILL.md ausente)"; exit 1; }
grep -qE '^name: frontend-ui-review$' "$SK" || { echo "FAIL [4] (name errado no frontmatter)"; exit 1; }
DS="$WS/template/.forge/rules/frontend/design-system.md"
grep -q 'Token fantasma é proibido' "$DS" || { echo "FAIL [4] (regra 10 ausente na DS rule)"; exit 1; }
grep -q 'Sem fallback literal' "$DS" || { echo "FAIL [4] (regra 11 ausente)"; exit 1; }
grep -q 'Controle nativo do browser é domado' "$DS" || { echo "FAIL [4] (regra 12 ausente)"; exit 1; }
grep -q 'frontend-ui-review' "$WS/template/.forge/agents/engineering/frontend-engineer.md" || { echo "FAIL [4] (agent não referencia a skill)"; exit 1; }
echo "OK [4]"

echo "PASS w96-frontend-ui-review-gate"
