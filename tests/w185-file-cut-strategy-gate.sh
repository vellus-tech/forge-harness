#!/usr/bin/env bash
# Gate W185 (LDG-0063) — code-style.md § "Corte de arquivo grande": a rule parava em "é smell,
# revise" sem oferecer caminho, e agente sem estratégia inventava helpers.ts/utils.ts como
# depósito do que sobrou. Esta rule adota a coreografia do prompt 09 do vibe-coding-toolkit (MIT)
# como orientação cabeada — nunca como prompt solto.
#
#   [1] as quatro costuras existem, NA ORDEM declarada (UI/rota→serviço de domínio; bloco de UI
#       repetido→sub-componente; acesso a dados→repositório/adaptador; helpers→utilitário de
#       domínio) — ordem importa porque é sequência de tentativa, não lista solta
#   [2] escape hatch nomeado ("sem costura natural, pare e siga para o próximo") está presente —
#       preferível a inventar abstração
#   [3] preservação de interface pública via barril fino (reexporta, não edita cada import site)
#   [4] ritmo: um arquivo extraído por commit, com typecheck+teste+lint entre cada
#   [5] as duas armadilhas: arquivo de destino pode passar do próprio teto; tipo de retorno pode
#       alargar em silêncio por inferência
#   [6] atribuição preservada: vibe-coding-toolkit (MIT), prompt 09
#   [7] fiação: quality-reviewer.md aponta para o heading real de code-style.md (não é arquivo
#       órfão) e instrui a não inventar helpers.ts/utils.ts como despejo
#   [8] frontmatter dos dois arquivos tocados continua válido
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CS="$WS/template/.forge/rules/conventions/code-style.md"
QR="$WS/template/.forge/agents/review/quality-reviewer.md"

fail() { echo "FAIL $*"; exit 1; }

[ -f "$CS" ] || fail "[0]: code-style.md ausente em $CS"
[ -f "$QR" ] || fail "[0]: quality-reviewer.md ausente em $QR"

echo "[1] quatro costuras, na ordem"
l1="$(grep -n 'Lógica de negócio embutida em UI/rota' "$CS" | head -1 | cut -d: -f1)"
l2="$(grep -n 'Bloco de UI repetido' "$CS" | head -1 | cut -d: -f1)"
l3="$(grep -n 'Acesso a dados' "$CS" | head -1 | cut -d: -f1)"
l4="$(grep -n 'Aglomerado de helpers' "$CS" | head -1 | cut -d: -f1)"
[ -n "$l1" ] || fail "[1]: costura 1 (UI/rota → serviço de domínio) ausente"
[ -n "$l2" ] || fail "[1]: costura 2 (bloco de UI repetido → sub-componente) ausente"
[ -n "$l3" ] || fail "[1]: costura 3 (acesso a dados → repositório/adaptador) ausente"
[ -n "$l4" ] || fail "[1]: costura 4 (aglomerado de helpers → utilitário de domínio) ausente"
[ "$l1" -lt "$l2" ] || fail "[1]: costura 1 não vem antes da 2 ($l1 >= $l2)"
[ "$l2" -lt "$l3" ] || fail "[1]: costura 2 não vem antes da 3 ($l2 >= $l3)"
[ "$l3" -lt "$l4" ] || fail "[1]: costura 3 não vem antes da 4 ($l3 >= $l4)"
echo "OK [1]"

echo "[2] escape hatch nomeado"
grep -qF 'sem costura natural, pare e siga para o próximo' "$CS" \
  || fail "[2]: escape hatch nomeado ausente ou reformulado (frase exata esperada)"
echo "OK [2]"

echo "[3] barril fino preserva interface pública"
grep -q 'barril fino' "$CS" || fail "[3]: 'barril fino' ausente"
grep -q 'reexport' "$CS" || fail "[3]: menção a reexportar ausente"
echo "OK [3]"

echo "[4] ritmo de um arquivo por commit com typecheck+teste+lint"
grep -q 'um arquivo extraído por commit' "$CS" || fail "[4]: ritmo 'um arquivo extraído por commit' ausente"
grep -qi 'typecheck' "$CS" || fail "[4]: menção a typecheck ausente no ritmo"
echo "OK [4]"

echo "[5] as duas armadilhas"
grep -q 'acima do próprio teto' "$CS" || fail "[5]: armadilha do arquivo de destino acima do teto ausente"
grep -qi 'alargar em silêncio' "$CS" || fail "[5]: armadilha do tipo de retorno alargando em silêncio ausente"
echo "OK [5]"

echo "[6] atribuição preservada"
grep -q 'vibe-coding-toolkit' "$CS" || fail "[6]: atribuição a vibe-coding-toolkit ausente"
grep -q 'MIT' "$CS" || fail "[6]: menção à licença MIT ausente"
grep -q 'prompt 09' "$CS" || fail "[6]: referência ao prompt 09 ausente"
echo "OK [6]"

echo "[7] fiação: quality-reviewer aponta para o lugar certo"
anchor='Corte de arquivo grande'
grep -q "$anchor" "$QR" || fail "[7]: quality-reviewer.md não referencia '$anchor'"
grep -qE "^#+.*$anchor" "$CS" || fail "[7]: '$anchor' não é um heading real em code-style.md — referência apontaria para lugar errado"
grep -qi 'helpers\.ts' "$QR" || fail "[7]: quality-reviewer.md não nomeia o anti-padrão (helpers.ts como despejo)"
echo "OK [7]"

echo "[8] frontmatter válido"
bash "$WS/template/.forge/scripts/validate-frontmatter.sh" "$CS" "$QR" | tail -1 | grep -q '^OK' \
  || fail "[8]: frontmatter inválido em code-style.md ou quality-reviewer.md"
echo "OK [8]"

echo "PASS w185-file-cut-strategy-gate"
