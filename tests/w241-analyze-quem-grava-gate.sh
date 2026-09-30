#!/usr/bin/env bash
# Gate W241 — #155: /forge:analyze precisa dizer quem julga e quem grava analysis.md quando a
# análise é delegada a um subagente revisor sem permissão de escrita.
#
# ESTÁTICO, por texto e por POSIÇÃO DE LINHA sobre `template/.forge/commands/specs/analyze.md` —
# não há comportamento a exercitar (o comando é um protocolo em prosa para um agente seguir, não
# código); a prova é que a regra existe, no lugar certo do arquivo. Propriedade PBT: não se aplica.
#
#   [1] a regra de "quem julga e quem grava" (mecanismo de transcrição) está DENTRO da seção
#       `## Saída` — por POSIÇÃO DE LINHA: depois do heading `## Saída` e antes do heading
#       `## Conflito é bloqueante` (a próxima seção do arquivo real)
#   [2] os dois campos de registro exigidos pelo desenho estão presentes: quem revisou (subagente
#       + modelo) e quem transcreveu (sessão orquestradora)
#   [3] a regra nomeia explicitamente que o subagente revisor NUNCA escreve analysis.md
#       diretamente — é a sessão orquestradora quem grava
#   [4] espelho do plugin (`plugin/forge/commands/analyze.md`) idêntico à fonte — build:plugin
#       foi rodado
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$WS" || { echo "FAIL: não foi possível entrar em '$WS'"; exit 2; }

SRC="template/.forge/commands/specs/analyze.md"
[ -f "$SRC" ] || { echo "FAIL: '$SRC' não existe"; exit 1; }

overall_rc=0

# ── [1] posição de linha: regra de transcrição entre '## Saída' e '## Conflito é bloqueante' ──
echo "[1] a regra de quem julga e quem grava fica dentro de '## Saída', antes de '## Conflito é bloqueante'."
linha_saida="$(grep -nE '^## Saída$' "$SRC" | head -1 | cut -d: -f1)"
linha_conflito="$(grep -nE '^## Conflito é bloqueante' "$SRC" | head -1 | cut -d: -f1)"
if [ -z "$linha_saida" ]; then
  echo "FAIL [1]: não achei o heading '## Saída' em $SRC"; overall_rc=1
elif [ -z "$linha_conflito" ]; then
  echo "FAIL [1]: não achei o heading '## Conflito é bloqueante' (ou a seção seguinte mudou de nome) em $SRC"; overall_rc=1
else
  bloco_saida="$(sed -n "${linha_saida},${linha_conflito}p" "$SRC")"
  if [ -z "$bloco_saida" ]; then
    echo "FAIL [1]: bloco extraído de '## Saída' está vazio — confira os headings"
    overall_rc=1
  # o critério é a FRASE-CHAVE da regra ("Quem julga e quem grava"), não a palavra solta
  # 'transcrev/transcri' — essa palavra também aparece no template de saída (campo "Transcrito
  # por:"), que continuaria dentro de '## Saída' mesmo se o PARÁGRAFO da regra fosse movido para
  # '## Regras'; um grep pela palavra solta não reprovaria essa mutação. A frase-chave só existe
  # uma vez no arquivo inteiro (é o título do parágrafo da regra), então achá-la dentro do bloco
  # é evidência direta de POSIÇÃO, não só de presença.
  elif ! printf '%s\n' "$bloco_saida" | grep -qiF 'Quem julga e quem grava'; then
    echo "FAIL [1]: a frase-chave 'Quem julga e quem grava' não está dentro de '## Saída' (linhas ${linha_saida}–${linha_conflito}) de $SRC — a regra foi movida para outra seção?"
    overall_rc=1
  else
    echo "OK [1] — regra 'Quem julga e quem grava' presente dentro de '## Saída' (linhas ${linha_saida}–${linha_conflito})"
  fi
fi

# ── [2] os dois campos de registro (revisor+modelo, transcritor) presentes ──────────────────
echo "[2] os dois campos de registro (revisor+modelo, transcritor) estão presentes."
if ! grep -qiE 'revisor' "$SRC"; then
  echo "FAIL [2]: não achei referência a 'revisor' (quem revisou) em $SRC"; overall_rc=1
fi
if ! grep -qiE 'modelo' "$SRC"; then
  echo "FAIL [2]: não achei referência a 'modelo' (qual modelo o revisor usou) em $SRC"; overall_rc=1
fi
if ! grep -qiE 'transcrito por|transcritor|quem transcreveu' "$SRC"; then
  echo "FAIL [2]: não achei o campo de registro de quem transcreveu em $SRC"; overall_rc=1
fi
if ! grep -qiE 'sessão orquestradora' "$SRC"; then
  echo "FAIL [2]: não achei 'sessão orquestradora' como quem grava/transcreve em $SRC"; overall_rc=1
fi
[ "$overall_rc" -eq 0 ] && echo "OK [2] — revisor+modelo e transcritor (sessão orquestradora) presentes"

# ── [3] o subagente revisor NUNCA escreve analysis.md diretamente ──────────────────────────
echo "[3] a regra proíbe explicitamente o subagente revisor de escrever analysis.md diretamente."
if ! grep -qiE 'nunca.*(escreve|tenta escrever)|não.*(escreve|tenta escrever).*analysis\.md' "$SRC"; then
  echo "FAIL [3]: não achei a proibição explícita de o subagente revisor escrever analysis.md diretamente"
  overall_rc=1
else
  echo "OK [3] — proibição explícita presente"
fi
if ! grep -qiE 'texto' "$SRC"; then
  echo "FAIL [3]: não achei que o revisor devolve a tabela/síntese como TEXTO (não como escrita de arquivo)"
  overall_rc=1
fi

# ── [4] espelho do plugin idêntico ──────────────────────────────────────────────────────────
echo "[4] espelho do plugin (plugin/forge/commands/analyze.md) idêntico à fonte."
PLUGIN="plugin/forge/commands/analyze.md"
if [ ! -f "$PLUGIN" ]; then
  echo "FAIL [4]: '$PLUGIN' não existe"; overall_rc=1
elif ! diff -q "$SRC" "$PLUGIN" >/dev/null 2>&1; then
  echo "FAIL [4]: '$PLUGIN' diverge de '$SRC' — rode: npm run build:plugin"
  diff "$SRC" "$PLUGIN" | head -20 || true
  overall_rc=1
else
  echo "OK [4] — plugin/forge/commands/analyze.md idêntico à fonte"
fi

exit "$overall_rc"
