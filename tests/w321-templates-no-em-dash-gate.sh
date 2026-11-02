#!/usr/bin/env bash
# Gate W321 — LDG-1592: templates de .forge/templates/spec/ e .forge/templates/refactor/
# nasciam com travessão (—, U+2014) em headers e placeholders de proposal.md, design.md,
# tasks.md, spec-delta.yaml e refactor.md — gerados por spec-new.sh, antes de qualquer sessão
# escrever conteúdo próprio. Viola a regra de tolerância zero a travessão. Usa python3 (não
# grep -P) porque grep -P de bytes dá zero falso no Mac (feedback medido no histórico do
# projeto) — a varredura por codepoint U+2014 é a prova real, independente de locale/encoding
# do shell.
#   [1] nenhum dos cinco arquivos-fonte afetados contém U+2014
#   [2] MUTAÇÃO (sandbox) — reinserir um travessão num dos arquivos faz [1] falhar, nomeando
#       o arquivo e a linha
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

FILES=(
  "template/.forge/templates/spec/proposal.md"
  "template/.forge/templates/spec/design.md"
  "template/.forge/templates/spec/tasks.md"
  "template/.forge/templates/spec/spec-delta.yaml"
  "template/.forge/templates/refactor/refactor.md"
)

scan() { # scan <root>
  local root="$1"
  python3 - "$root" "${FILES[@]}" <<'PYEOF'
import sys
root = sys.argv[1]
files = sys.argv[2:]
bad = []
for rel in files:
    path = root + "/" + rel
    with open(path, encoding="utf-8") as fh:
        for lineno, line in enumerate(fh, 1):
            if "—" in line:
                bad.append(f"{rel}:{lineno}")
if bad:
    print("\n".join(bad))
    sys.exit(1)
sys.exit(0)
PYEOF
}

echo "[1] nenhum dos cinco arquivos-fonte contém travessão (U+2014)"
if ! out="$(scan "$WS")"; then
  echo "FAIL [1]: travessão encontrado — $out"
  exit 1
fi
echo "OK [1]"

echo "[2] MUTAÇÃO (sandbox) — reinserir travessão em proposal.md faz [1] falhar"
MT="$(mktemp -d /tmp/forge-w321-mut.XXXXXX)"
trap 'rm -rf "$MT"' EXIT
cp -R "$WS/template" "$MT/template"
PT="$MT/template/.forge/templates/spec/proposal.md"
perl -CSD -pi -e 's/^# Proposal: <CHANGE_ID>/# Proposal \x{2014} <CHANGE_ID>/' "$PT"
grep -q $'—' "$PT" || { echo "FAIL [2]: mutação não inseriu o travessão (perl não casou)"; exit 1; }
if out2="$(scan "$MT")"; then
  echo "FAIL [2]: mutação deveria fazer o scan falhar, mas passou"
  exit 1
fi
grep -q "proposal.md:1" <<<"$out2" || { echo "FAIL [2]: saída não nomeia proposal.md:1 ($out2)"; exit 1; }
echo "OK [2] — mutação detectada: $out2"

echo "OK"
