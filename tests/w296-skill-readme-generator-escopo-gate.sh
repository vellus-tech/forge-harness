#!/usr/bin/env bash
# Gate W296 — SKILL.md de readme-generator não promete README nem comparação de branches irmãs
# sem a ressalva de escopo (TASK-17, add-unify-changelog-skill).
#
# Distinção por PROXIMIDADE DE FRASE, não por presença da palavra: "readme.md"/"branches irmãs"
# só é permitido dentro de uma frase que também contém uma ressalva de "fora de escopo nesta
# versão" (ou equivalente). Um grep solto por "readme" reprovaria o próprio nome da skill
# (readme-generator) e o título do documento.
#
#   [1] SKILL.md real do template → passa
#   [2] SKILL.md mutado com instrução executável de gerar README sem ressalva → FAIL
#   [3] SKILL.md mutado com instrução de comparar branches irmãs sem ressalva → FAIL
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$WS/template/.forge/skills/readme-generator/SKILL.md"
[ -f "$SKILL" ] || { echo "FAIL: $SKILL não existe"; exit 1; }

T="$(mktemp -d /tmp/forge-w296.XXXXXX)"
trap 'rm -rf "$T"' EXIT

checker() { # checker <arquivo> -> rc 0 se nenhuma frase viola, rc 1 com FAIL citando a frase
  python3 -I - "$1" <<'PYEOF'
import re, sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()
# frases: quebra em '.', '!', '?' seguidos de espaço/fim, preservando contexto dentro de um
# parágrafo (não quebra em vírgula nem em quebra de linha simples).
sentences = re.split(r'(?<=[.!?])\s+', text.replace('\n', ' '))
alvo_re = re.compile(r'readme\.md|branches? irm[aã]', re.IGNORECASE)
ressalva_re = re.compile(r'fora de escopo|não foram portadas|nao foram portadas', re.IGNORECASE)
violacoes = []
for s in sentences:
    if alvo_re.search(s) and not ressalva_re.search(s):
        violacoes.append(s.strip())
if violacoes:
    for v in violacoes:
        print(f"FAIL: SKILL.md promete README ou comparação de branches irmãs sem a ressalva de escopo: {v}")
    sys.exit(1)
print("OK: nenhuma frase viola o escopo")
sys.exit(0)
PYEOF
}

# ── [1] ──────────────────────────────────────────────────────────────────────────────────────
echo "[1] SKILL.md real do template → passa"
out="$(checker "$SKILL" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [1]: SKILL.md real reprovou ($out)"; exit 1; }
echo "OK [1]"

# ── [2] ──────────────────────────────────────────────────────────────────────────────────────
echo "[2] SKILL.md mutado com instrução executável de gerar README sem ressalva → FAIL"
cp "$SKILL" "$T/dirty2.md"
printf '\nGere o README.md automaticamente lendo o repositório e atualize as secoes de setup.\n' >> "$T/dirty2.md"
out="$(checker "$T/dirty2.md" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [2]: checker aprovou instrução executável de README sem ressalva"; exit 1; }
case "$out" in
  *"FAIL: SKILL.md promete"*) : ;;
  *) echo "FAIL [2]: reprovou sem a mensagem esperada (saida: $out)"; exit 1 ;;
esac
echo "OK [2]"

# ── [3] ──────────────────────────────────────────────────────────────────────────────────────
echo "[3] SKILL.md mutado com instrução de comparar branches irmãs sem ressalva → FAIL"
cp "$SKILL" "$T/dirty3.md"
printf '\nCompare as branches irmas develop e master para recuperar conteudo perdido antes de publicar.\n' >> "$T/dirty3.md"
out="$(checker "$T/dirty3.md" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [3]: checker aprovou instrução executável de comparação de branches irmãs sem ressalva"; exit 1; }
case "$out" in
  *"FAIL: SKILL.md promete"*) : ;;
  *) echo "FAIL [3]: reprovou sem a mensagem esperada (saida: $out)"; exit 1 ;;
esac
echo "OK [3]"

echo "PASS w296-skill-readme-generator-escopo"
