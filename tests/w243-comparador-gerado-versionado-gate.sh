#!/usr/bin/env bash
# Gate W243 — issue #158: `template/.forge/rules/testing/quality-gates.md` só mencionava
# "versionado" na seção de Regressão Visual (contexto de fixtures), e
# `template/.forge/rules/architecture/api-and-contracts.md` declarava o contrato como fonte da
# verdade sem dizer o que um teste de COMPARAÇÃO pode prescrever quando diverge do gerado. Medido
# na issue: um comparador de contrato OpenAPI bloqueou pushes por três semanas mandando
# "regenerar por cima" de edições deliberadas, uma delas a correção de uma exposição de
# superfície interna real.
#
# Este gate confere a seção nova "Comparação gerado × versionado" em quality-gates.md com os três
# itens do desenho aprovado, e a referência cruzada em api-and-contracts.md.
#
#   [1] a seção "Comparação gerado × versionado" existe como heading real em quality-gates.md
#   [2] item (1): asserções de propriedade do artefato, independentes da comparação byte-a-byte
#   [3] item (2), POSITIVA: a mensagem-modelo nomeia as duas causas possíveis (gerador mudou
#       legitimamente OU versionado editado deliberadamente) e aponta `git log -p -- <arquivo>`
#   [4] item (2), NEGATIVA PAREADA: a seção NÃO contém instrução de "regenerar e commitar" (ou
#       equivalente) como remediação — a positiva sozinha não bastaria, pois um texto podia
#       nomear as duas causas E ainda concluir mandando regenerar por cima
#   [5] item (3) + referência cruzada: api-and-contracts.md tem a regra de que, onde o contrato
#       versionado é fonte da verdade, nenhum teste tem como remediação sobrescrevê-lo com o
#       gerado, com referência de volta a quality-gates.md
#   [6] frontmatter dos dois arquivos tocados continua válido
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QG="$WS/template/.forge/rules/testing/quality-gates.md"
AC="$WS/template/.forge/rules/architecture/api-and-contracts.md"

fail() { echo "FAIL $*"; exit 1; }

[ -f "$QG" ] || fail "[0]: quality-gates.md ausente em $QG"
[ -f "$AC" ] || fail "[0]: api-and-contracts.md ausente em $AC"

echo "[1] heading 'Comparação gerado × versionado' existe em quality-gates.md"
grep -qE '^#+[[:space:]]*Comparação gerado × versionado' "$QG" \
  || fail "[1]: heading 'Comparação gerado × versionado' ausente ou não é heading real"
echo "OK [1]"

# extrai o corpo da seção nova (da heading até a próxima heading de mesmo nível ou superior)
secao="$(awk '/^## Comparação gerado × versionado/{s=1; next} s && /^## /{exit} s' "$QG")"
[ -n "$secao" ] || fail "[1b]: seção 'Comparação gerado × versionado' vazia"

echo "[2] item (1): asserções de propriedade do artefato"
printf '%s\n' "$secao" | grep -qi 'asserç.*propriedade' \
  || fail "[2]: item de asserções de PROPRIEDADE do artefato ausente"
printf '%s\n' "$secao" | grep -qi 'independente.*comparação\|independente.*byte' \
  || fail "[2]: propriedade não está marcada como independente da comparação byte-a-byte"
echo "OK [2]"

echo "[3] item (2) POSITIVA: mensagem nomeia as duas causas + git log -p"
printf '%s\n' "$secao" | grep -qi 'gerador mudou legitimamente' \
  || fail "[3]: causa 'gerador mudou legitimamente' ausente"
printf '%s\n' "$secao" | grep -qi 'versionado.*edita.*deliberad\|edita.*deliberad.*versionado' \
  || fail "[3]: causa 'versionado editado deliberadamente' ausente"
printf '%s\n' "$secao" | grep -qF 'git log -p -- <arquivo>' \
  || fail "[3]: próximo passo 'git log -p -- <arquivo>' ausente"
echo "OK [3]"

echo "[4] item (2) NEGATIVA PAREADA: seção não prescreve 'regenerar e commitar'"
# Uma SENTENÇA que MENCIONA a proibição ("... NUNCA prescreve 'regenerar e commitar' ...") é o
# texto esperado da regra; uma SENTENÇA que casa o padrão SEM a negação 'nunca' na própria
# sentença é a instrução proibida de fato (o cenário que a mutação do desenho precisa pegar:
# trocar a cláusula final por uma instrução real do tipo "rode a geração e commite"). A quebra é
# por sentença, não por linha — a seção é markdown em parágrafo único e uma linha inteira pode
# conter tanto o "NUNCA prescreve" quanto, numa cláusula seguinte da MESMA linha, a instrução
# proibida de fato; checar a linha toda mascararia essa segunda cláusula atrás do 'nunca' da
# primeira.
padrao='regener[ae].{0,25}(e |&).{0,4}commit|rode a geração e commite|regenere e commite'
sentencas="$(printf '%s\n' "$secao" | sed -E 's/\. /.\n/g')"
while IFS= read -r sentenca; do
  [ -z "$sentenca" ] && continue
  if printf '%s' "$sentenca" | grep -qiE "$padrao"; then
    if ! printf '%s' "$sentenca" | grep -qi 'nunca'; then
      fail "[4]: sentença prescreve regenerar-e-commitar sem negação — instrução proibida pelo desenho: $sentenca"
    fi
  fi
done <<<"$sentencas"
echo "OK [4]"

echo "[5] item (3) + referência cruzada em api-and-contracts.md"
grep -qi 'nenhum teste.*remediação.*sobrescrev\|sobrescrev.*gerado' "$AC" \
  || fail "[5]: api-and-contracts.md não declara que nenhum teste remedia sobrescrevendo com o gerado"
grep -qE 'testing/quality-gates\.md|Comparação gerado × versionado' "$AC" \
  || fail "[5]: api-and-contracts.md não referencia quality-gates.md (referência cruzada ausente)"
grep -qi 'api-and-contracts\.md' "$QG" \
  || fail "[5]: quality-gates.md não referencia api-and-contracts.md (referência cruzada ausente do outro lado)"
echo "OK [5]"

echo "[6] frontmatter válido"
bash "$WS/template/.forge/scripts/validate-frontmatter.sh" "$QG" "$AC" | tail -1 | grep -q '^OK' \
  || fail "[6]: frontmatter inválido em quality-gates.md ou api-and-contracts.md"
echo "OK [6]"

echo "PASS w243-comparador-gerado-versionado-gate"
