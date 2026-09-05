#!/usr/bin/env bash
# Gate W186 (LDG-0064) — quality-gates.md § "Portão de decisão para burndown de lint": sem esse
# portão, afrouxar uma regra de lint chega disfarçado de "código mais limpo". Adota o portão A/B/C
# do prompt 02 do vibe-coding-toolkit (MIT) como texto de processo, válido para qualquer stack.
#
#   [1] as três opções (A corrigir tudo / B dívida visível rastreada / C reescopar como mudança
#       de config) existem, com (A) marcado como padrão na ausência de resposta
#   [2] dívida da opção B é declarada VISÍVEL (comentário + referência de issue), nunca supressão
#       silenciosa
#   [3] opção C é marcada explicitamente como mudança de config, nunca como código mais limpo
#   [4] severidade derivada de contagem medida: regra sem violação nasce error; com violação nasce
#       warn com a contagem como linha de base; critério de parada é a contagem voltar a zero
#   [5] ignore curto e nomeado, nunca rebaixamento da regra inteira
#   [6] atribuição preservada: vibe-coding-toolkit (MIT), prompt 02
#   [7] fiação: quality-reviewer.md aponta para o heading real de quality-gates.md (não é arquivo
#       órfão) e eleva rebaixamento de regra sem decisão a achado
#   [8] frontmatter dos dois arquivos tocados continua válido
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QG="$WS/template/.forge/rules/testing/quality-gates.md"
QR="$WS/template/.forge/agents/review/quality-reviewer.md"

fail() { echo "FAIL $*"; exit 1; }

[ -f "$QG" ] || fail "[0]: quality-gates.md ausente em $QG"
[ -f "$QR" ] || fail "[0]: quality-reviewer.md ausente em $QR"

echo "[1] três opções, (A) como padrão"
grep -qE '\(A\).*Corrigir tudo' "$QG" || fail "[1]: opção (A) 'corrigir tudo' ausente"
grep -qE '\(B\)' "$QG" || fail "[1]: opção (B) ausente"
grep -qE '\(C\)' "$QG" || fail "[1]: opção (C) ausente"
grep -qi 'padrão na ausência de resposta' "$QG" || fail "[1]: (A) não é marcado como padrão na ausência de resposta"
echo "OK [1]"

echo "[2] dívida da opção B é visível, nunca silenciosa"
grep -qi 'dívida.*VISÍVEL\|VISÍVEL.*dívida' "$QG" || fail "[2]: dívida da opção (B) não é marcada VISÍVEL"
grep -qi 'issue' "$QG" || fail "[2]: referência de issue ausente na opção (B)"
grep -qi 'supressão silenciosa\|silenciosa' "$QG" || fail "[2]: veto a supressão silenciosa ausente"
echo "OK [2]"

echo "[3] opção C é mudança de config, nunca código mais limpo"
grep -qi 'MUDANÇA DE CONFIG' "$QG" || fail "[3]: opção (C) não é marcada como MUDANÇA DE CONFIG"
grep -qi 'nunca apresentad[oa].*código mais limpo\|nunca.*mais limpo' "$QG" \
  || fail "[3]: veto a apresentar afrouxamento como código mais limpo ausente"
echo "OK [3]"

echo "[4] severidade derivada de contagem medida"
grep -q 'nasce `error`' "$QG" || fail "[4]: regra sem violação nascendo error ausente"
grep -q 'nasce `warn`' "$QG" || fail "[4]: regra com violação nascendo warn ausente"
grep -qi 'linha de base' "$QG" || fail "[4]: contagem como linha de base ausente"
grep -qi 'voltar a zero' "$QG" || fail "[4]: critério de parada (contagem voltar a zero) ausente"
echo "OK [4]"

echo "[5] ignore curto e nomeado"
grep -q '`ignore`' "$QG" || fail "[5]: menção a 'ignore' ausente"
grep -qi 'curto e nomeado' "$QG" || fail "[5]: 'curto e nomeado' ausente"
grep -qi 'nunca.*regra inteira\|regra inteira.*nunca' "$QG" || fail "[5]: veto a rebaixar a regra inteira ausente"
echo "OK [5]"

echo "[6] atribuição preservada"
grep -q 'vibe-coding-toolkit' "$QG" || fail "[6]: atribuição a vibe-coding-toolkit ausente"
grep -q 'MIT' "$QG" || fail "[6]: menção à licença MIT ausente"
grep -q 'prompt 02' "$QG" || fail "[6]: referência ao prompt 02 ausente"
echo "OK [6]"

echo "[7] fiação: quality-reviewer aponta para o lugar certo"
anchor='Portão de decisão para burndown de lint'
grep -qF "$anchor" "$QR" || fail "[7]: quality-reviewer.md não referencia '$anchor'"
grep -qE "^#+.*$anchor" "$QG" || fail "[7]: '$anchor' não é um heading real em quality-gates.md — referência apontaria para lugar errado"
grep -qi 'rebaixa\|rebaixar' "$QR" || fail "[7]: quality-reviewer.md não eleva rebaixamento de regra sem decisão"
echo "OK [7]"

echo "[8] frontmatter válido"
bash "$WS/template/.forge/scripts/validate-frontmatter.sh" "$QG" "$QR" | tail -1 | grep -q '^OK' \
  || fail "[8]: frontmatter inválido em quality-gates.md ou quality-reviewer.md"
echo "OK [8]"

echo "PASS w186-lint-burndown-gate"
