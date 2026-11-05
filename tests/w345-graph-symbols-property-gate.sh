#!/usr/bin/env bash
# Gate — TASK-14 de fix-graph-query-symbols-fusion (STORY-07): gate formal de FECHAMENTO que
# consolida as seis propriedades (P1-P6) já provadas Red→Verde ao longo das stories anteriores
# (P2/P4-herança/P5 na TASK-03/w344, P6 na TASK-05/w344 [5a]/[6c], P1/P3/P4-desempate na
# TASK-09/w344) num único gate dedicado, com seed fixa reprodutível e o "teste do teste" (padrão
# w121 [2] / w344 [6a]: mutação deliberada precisa reprovar com contraexemplo minimizado).
#
# DD-08 (design.md §5 item 2): esta task NÃO tem par vermelho/verde de comportamento próprio.
# graph-query.mjs e graph-symbols-extract.mjs já implementam P1-P6 desde TASK-03/TASK-05/TASK-09
# — um import() que resolvesse e passasse de cara não seria Red válido (o comportamento já existe
# e já foi provado Red→Verde na task correspondente). Mesmo padrão de TASK-02/TASK-13.
#
# Lógica real no driver `tests/w345-graph-symbols-property-gate.driver.mjs` (ESM, convenção já
# usada por w289/w290/w291/w286) — evita heredoc de node com conteúdo Unicode/template-literal
# extenso, que neste repositório truncou silenciosamente a entrada do processo filho.
#
#   P1  completude       — rankSymbols não omite nem inventa matches
#   P2  sem duplicata    — extractSymbols nunca repete a chave (file,name,type,line)
#   P3  metamórfica      — t' substring de t  =>  results(t) ⊆ results(t'), sem corte de 20
#   P4a invariância (herança)   — resolveInheritance independe da ORDEM de entrada
#   P4b invariância (desempate) — rankSymbols independe da ORDEM de entrada
#   P5  invariância cosmética   — comentário/linha em branco só muda `line`
#   P6  equivalência      — symbols.idx.tsv é projeção EXATA de symbols.json
#   tt-p2/tt-p4 teste do teste — mutação deliberada reprova com contraexemplo minimizado
#
# Seed: FORGE_PBT_SEED (env), se definida e numérica, substitui a seed-base fixa no driver —
# reprodutibilidade obrigatória (rule testing/property-based-testing.md), nunca Math.random.
set -uo pipefail
unset CLAUDE_CODE_SESSION_ID
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if node "$WS/tests/w345-graph-symbols-property-gate.driver.mjs"; then
  echo "PASS — w345: P1-P6 consolidadas em gate formal, seed fixa (FORGE_PBT_SEED), teste do teste com controle/recontrole (STORY-07/TASK-14)"
  exit 0
else
  echo "FAIL — w345-graph-symbols-property-gate.driver.mjs reprovou (ver saída acima)"
  exit 1
fi
