#!/usr/bin/env bash
# Gate W240 — #157: /forge:upgrade verifica o resultado do overlay rodando a suíte do consumidor
# e triando cada reprovação, em vez de declarar concluído com base só no `doctor` e na lista de
# arquivos escritos.
#
# ESTÁTICO, por texto e por POSIÇÃO DE LINHA sobre `template/.forge/commands/harness/upgrade.md` —
# não há comportamento a exercitar (o comando é um protocolo em prosa para um agente seguir, não
# código); a prova é que o texto certo existe na ordem certa. Propriedade PBT: não se aplica.
#
#   [1] o passo que roda `run-all.sh` existe ENTRE o passo "Aplique" e o passo do `core.hooksPath`
#       (posição de linha, não só presença — um passo pode existir e estar no lugar errado)
#   [2] as três classes de reprovação estão nomeadas: regressão, evolução legítima do template,
#       fixture desatualizada
#   [3] o critério de desempate por `git grep` aparece ANTES de "fixture desatualizada" ser
#       nomeada como classe (ordem de leitura no arquivo, não só presença)
#   [4] a reexecução isolada de alvo NÃO VERIFICADO (rc 3 / LDG-0181) está descrita, e o texto
#       proíbe classificá-lo como regressão direto
#   [5] o passo de resumo lista cada reprovação com a classe atribuída
#   [6] espelho do plugin (`plugin/forge/commands/upgrade.md`) idêntico — build:plugin foi rodado
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$WS" || { echo "FAIL: não foi possível entrar em '$WS'"; exit 2; }

SRC="template/.forge/commands/harness/upgrade.md"
[ -f "$SRC" ] || { echo "FAIL: '$SRC' não existe"; exit 1; }

overall_rc=0

# ── [1] posição de linha: passo do run-all.sh entre "Aplique" e "core.hooksPath" ────────────
echo "[1] o passo que roda run-all.sh fica entre 'Aplique' e o passo do core.hooksPath."
linha_aplique="$(grep -nE '^[0-9]+\. \*\*Aplique\*\*' "$SRC" | head -1 | cut -d: -f1)"
linha_hookspath="$(grep -nE 'Garanta o .core\.hooksPath' "$SRC" | head -1 | cut -d: -f1)"
linha_runall="$(grep -nF 'run-all.sh' "$SRC" | head -1 | cut -d: -f1)"
if [ -z "$linha_aplique" ]; then
  echo "FAIL [1]: não achei o passo 'Aplique' em $SRC"; overall_rc=1
elif [ -z "$linha_hookspath" ]; then
  echo "FAIL [1]: não achei o passo do core.hooksPath em $SRC"; overall_rc=1
elif [ -z "$linha_runall" ]; then
  echo "FAIL [1]: não achei nenhuma menção a run-all.sh em $SRC"; overall_rc=1
elif [ "$linha_runall" -le "$linha_aplique" ] || [ "$linha_runall" -ge "$linha_hookspath" ]; then
  echo "FAIL [1]: run-all.sh está na linha $linha_runall, fora do intervalo (Aplique=$linha_aplique, core.hooksPath=$linha_hookspath)"
  overall_rc=1
else
  echo "OK [1] — run-all.sh na linha $linha_runall, entre Aplique ($linha_aplique) e core.hooksPath ($linha_hookspath)"
fi

# ── [2] as três classes nomeadas ─────────────────────────────────────────────────────────────
echo "[2] as três classes de reprovação estão nomeadas."
for classe in 'Regressão' 'Evolução legítima do template' 'Fixture desatualizada'; do
  if ! grep -qiF "$classe" "$SRC"; then
    echo "FAIL [2]: classe '$classe' não encontrada em $SRC"; overall_rc=1
  fi
done
[ "$overall_rc" -eq 0 ] && echo "OK [2] — as três classes presentes"

# ── [3] critério de desempate (git grep) vem ANTES de "fixture desatualizada" ser nomeada classe
echo "[3] o critério de desempate com git grep vem antes de nomear 'fixture desatualizada'."
linha_fixture_classe="$(grep -niF 'Fixture desatualizada**' "$SRC" | head -1 | cut -d: -f1)"
linha_desempate="$(grep -nF 'git grep' "$SRC" | head -1 | cut -d: -f1)"
if [ -z "$linha_fixture_classe" ]; then
  echo "FAIL [3]: não achei 'Fixture desatualizada' como item de classe (negrito) em $SRC"; overall_rc=1
elif [ -z "$linha_desempate" ]; then
  echo "FAIL [3]: não achei 'git grep' (critério de desempate) em $SRC"; overall_rc=1
elif [ "$linha_desempate" -le "$linha_fixture_classe" ]; then
  echo "FAIL [3]: 'git grep' esperado DEPOIS da classe (é onde o desempate se aplica antes de rotular), mas está na linha $linha_desempate <= $linha_fixture_classe — confira se o texto do desempate cita a classe corretamente"
  overall_rc=1
else
  echo "OK [3] — critério de desempate (linha $linha_desempate) referencia e vem depois da classe nomeada (linha $linha_fixture_classe), como exigido pelo texto 'antes de chamar algo de fixture desatualizada'"
fi
# reforço textual: a frase-chave do desempate precisa citar explicitamente a ordem "antes de chamar"
if ! grep -qiF 'antes de chamar algo de' "$SRC"; then
  echo "FAIL [3]: não achei a frase que ordena o desempate antes da classificação ('antes de chamar algo de ...')"
  overall_rc=1
fi

# ── [4] reexecução isolada de alvo não verificado (rc 3 / LDG-0181) ─────────────────────────
echo "[4] reexecução isolada de alvo não verificado, nunca classificado como regressão direto."
if ! grep -qiF 'NÃO VERIFICADO' "$SRC"; then
  echo "FAIL [4]: não achei menção a alvo com desfecho NÃO VERIFICADO"; overall_rc=1
fi
if ! grep -qF 'rc 3' "$SRC"; then
  echo "FAIL [4]: não achei referência ao rc 3 (LDG-0181)"; overall_rc=1
fi
if ! grep -qiF 'isoladamente' "$SRC"; then
  echo "FAIL [4]: não achei a reexecução isolada do alvo não verificado"; overall_rc=1
fi
if ! grep -qiF 'Nunca classifique um alvo não verificado como regressão' "$SRC"; then
  echo "FAIL [4]: não achei a proibição explícita de classificar alvo não verificado como regressão direto"; overall_rc=1
fi
[ "$overall_rc" -eq 0 ] && echo "OK [4] — NÃO VERIFICADO / rc 3 / reexecução isolada / proibição de classificar como regressão, todos presentes"

# ── [5] o resumo lista cada reprovação com a classe atribuída ───────────────────────────────
echo "[5] o passo de resumo lista cada reprovação com a classe atribuída."
linha_resuma="$(grep -nE '^[0-9]+\. \*\*Resuma\*\*' "$SRC" | head -1 | cut -d: -f1)"
if [ -z "$linha_resuma" ]; then
  echo "FAIL [5]: não achei o passo 'Resuma'"; overall_rc=1
else
  bloco_resuma="$(sed -n "${linha_resuma},\$p" "$SRC" | sed -n '1,3p')"
  if ! printf '%s\n' "$bloco_resuma" | grep -qiF 'classe atribuída'; then
    echo "FAIL [5]: o passo 'Resuma' não menciona listar as reprovações com a classe atribuída"
    overall_rc=1
  else
    echo "OK [5] — passo 'Resuma' (linha $linha_resuma) referencia a listagem por classe"
  fi
fi

# ── [6] espelho do plugin idêntico ───────────────────────────────────────────────────────────
echo "[6] espelho do plugin (plugin/forge/commands/upgrade.md) idêntico à fonte."
PLUGIN="plugin/forge/commands/upgrade.md"
if [ ! -f "$PLUGIN" ]; then
  echo "FAIL [6]: '$PLUGIN' não existe"; overall_rc=1
elif ! diff -q "$SRC" "$PLUGIN" >/dev/null 2>&1; then
  echo "FAIL [6]: '$PLUGIN' diverge de '$SRC' — rode: npm run build:plugin"
  diff "$SRC" "$PLUGIN" | head -20 || true
  overall_rc=1
else
  echo "OK [6] — plugin/forge/commands/upgrade.md idêntico à fonte"
fi

exit "$overall_rc"
