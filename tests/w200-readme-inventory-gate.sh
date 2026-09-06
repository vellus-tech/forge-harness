#!/usr/bin/env bash
# Gate W200 — inventário de contagem do README ("## 📁 Estrutura") contra a árvore real (LDG-0165/LDG-0166).
#
# POR QUE ESTE GATE EXISTE. A tabela `<dir>/ (N)` da seção `## 📁 Estrutura` do README.md é mantida
# à mão, e ninguém a reconferia: medido em 2026-09-06, 6 das 7 linhas com contagem declarada
# estavam erradas, e `scripts/ (63)` não batia com critério nenhum (61 arquivos no topo do
# diretório, 136 recursivo). A correção pontual dos números envelheceria de novo em dois meses —
# a durável é este gate, que reconfere a cada push.
#
# CRITÉRIO, único e explícito: `find "<root>/<dir>" -type f ! -name 'README.md'`, recursivo,
# descontando o README do próprio diretório contado (o número casa com o substantivo do
# comentário ao lado: "agents/ (47) # subagentes" conta 47 subagentes, não 48 com a documentação
# sobre eles). Critério fixado em `find` sobre a ÁRVORE DE TRABALHO, e não `git ls-files`, porque a
# função `confere` também roda sobre uma árvore-fixture fora de repositório git (cenários [2]-[5]).
# LIMITAÇÃO DECLARADA: hoje `find` e `git ls-files` coincidem nos sete diretórios (sem symlink, sem
# oculto, sem ignorado) — mas um arquivo não rastreado sob `template/.forge/<dir>` deixaria este
# gate vermelho localmente e verde no CI, e é um risco aceito, não um risco despercebido.
#
# O QUE ESTE GATE NÃO FAZ: confere para BAIXO (número declarado que não bate com a árvore), nunca
# para os LADOS — um diretório novo em `template/.forge/` que ninguém declare no README não é
# acusado. Ampliar isso exigiria decidir uma política de "todo diretório precisa de número", que
# não é o problema medido aqui.
#
#   [1] positivo com contador, sobre o README.md e a árvore REAIS deste repositório — único
#       cenário vermelho no estado defeituoso, e o único que não é hermético.
#   [2] anti-vacuidade — README-fixture sem nenhuma linha de contagem reprova pela guarda de piso;
#       sem este cenário, apagar os números "consertaria" o drift e o gate aprovaria por não ter
#       olhado nada.
#   [3] diretório fantasma — linha declarando contagem para um diretório que não existe reprova,
#       por mensagem que nomeia o caminho, distinta de "real (0)" (que confundiria "não existe"
#       com "existe e está vazio").
#   [4] mutação de TEXTO — contagem declarada rebaixada reprova por mensagem que nomeia o
#       diretório, declarado e real; controle e recontrole com o fixture íntegro.
#   [5] mutação de ÁRVORE — arquivo a mais num diretório da fixture reprova por mensagem; removido,
#       volta a aprovar. Sem este cenário um gate que só comparasse texto contra texto passaria.
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$WS" || { echo "FAIL: não foi possível entrar em '$WS'"; exit 2; }
README_REAL="README.md"
FORGE_REAL="template/.forge"

# confere <readme> <forge-root>
#
# Extrai o bloco fenceado da seção "## ... Estrutura" (o awk é o mesmo idioma usado para
# extrair blocos fenceados em todo o harness: entra em modo de coleta na heading, alterna com
# cada ``` vista, sai ao fechar o SEGUNDO fence). Para cada linha do bloco que casar
# `<dir>/ (N)`, confere `[ -d "<root>/<dir>" ]` explicitamente (nunca silenciando o find com
# 2>/dev/null) e compara N com `find "<root>/<dir>" -type f ! -name 'README.md' | wc -l`.
# Imprime uma linha "FAIL: ..." por divergência (diretório fantasma OU contagem errada), SEMPRE
# imprime o contador de universo ao final, e reprova por guarda de piso quando há menos de 7
# linhas com contagem declarada — universo raso (ou vazio) não pode aprovar por vacuidade.
confere() {
  local readme="$1" root="$2"
  local bloco pares=0 bad=0 rc_local=0
  bloco="$(awk '/^## .*Estrutura/{s=1} s&&/^```/{f++; if(f==2) exit; next} s&&f==1' "$readme")"
  while IFS= read -r linha; do
    if [[ "$linha" =~ ([A-Za-z0-9_.-]+)/[[:space:]]+\(([0-9]+)\) ]]; then
      local dir="${BASH_REMATCH[1]}" declarado="${BASH_REMATCH[2]}"
      pares=$((pares + 1))
      if [ ! -d "$root/$dir" ]; then
        echo "FAIL: README declara contagem para '$root/$dir/', que NÃO existe na árvore"
        bad=$((bad + 1)); rc_local=1
        continue
      fi
      local real
      real="$(find "$root/$dir" -type f ! -name 'README.md' | wc -l | tr -d ' ')"
      if [ "$declarado" != "$real" ]; then
        echo "FAIL: inventário do README defasado em '$root/$dir/' — declarado ($declarado), real ($real)"
        bad=$((bad + 1)); rc_local=1
      fi
    fi
  done <<<"$bloco"
  echo "-- universo: $pares linha(s) com contagem declarada no bloco de estrutura; $bad divergente(s)"
  if [ "$pares" -ge 7 ]; then
    :
  else
    echo "FAIL: guarda de piso — apenas $pares linha(s) com contagem declarada (esperado >= 7); README sem números não pode aprovar por vacuidade"
    rc_local=1
  fi
  return "$rc_local"
}

overall_rc=0

# ── fixtures (hermético, para [2]-[5]) ──────────────────────────────────────────────────────
T="$(mktemp -d /tmp/forge-w200.XXXXXX)"
trap 'rm -rf "$T"' EXIT
FX="$T/forge"

# mk_tree — árvore-fixture com os sete nomes e contagens pequenas e conhecidas; cada diretório
# recebe também um README.md, que a cláusula `! -name 'README.md'` precisa descontar — provado,
# não assumido, porque a intacta só passa se a exclusão funcionar nos sete diretórios de uma vez.
mk_tree() {
  rm -rf "$FX"
  local par d n i
  for par in agents:3 commands:4 contracts:5 skills:2 rules:6 schemas:1 scripts:7; do
    d="${par%%:*}"; n="${par##*:}"
    mkdir -p "$FX/$d"
    i=1
    while [ "$i" -le "$n" ]; do : >"$FX/$d/file$i.txt"; i=$((i + 1)); done
    : >"$FX/$d/README.md"
  done
}

# mk_readme_intact <out> — bloco com as sete contagens corretas da fixture.
mk_readme_intact() {
  {
    echo "# fixture"
    echo
    echo "## 📁 Estrutura"
    echo
    echo '```text'
    echo "├── agents/  (3)"
    echo "├── commands/ (4)"
    echo "├── contracts/ (5)"
    echo "├── skills/   (2)"
    echo "├── rules/   (6)"
    echo "├── schemas/ (1)"
    echo "└── scripts/ (7)"
    echo '```'
  } >"$1"
}

# mk_readme_sem_numeros <out> — mesmos sete nomes, sem nenhuma contagem: a "correção" por
# apagar os números, que a guarda de piso precisa reprovar.
mk_readme_sem_numeros() {
  {
    echo "# fixture"
    echo
    echo "## 📁 Estrutura"
    echo
    echo '```text'
    echo "├── agents/            # sem contagem"
    echo "├── commands/           # sem contagem"
    echo "├── contracts/          # sem contagem"
    echo "├── skills/             # sem contagem"
    echo "├── rules/              # sem contagem"
    echo "├── schemas/            # sem contagem"
    echo "└── scripts/            # sem contagem"
    echo '```'
  } >"$1"
}

mk_tree

# ── [1] positivo com contador, sobre o repositório REAL ──────────────────────────────────────
echo "[1] positivo com contador, sobre o repositório real."
out1="$(confere "$README_REAL" "$FORGE_REAL")"; rc1=$?
if [ "$rc1" -ne 0 ]; then
  echo "$out1" | sed -n '/^FAIL:/s/^FAIL: /FAIL [1]: /p'
  overall_rc=1
fi
echo "$out1" | grep -- '-- universo:'
if [ "$rc1" -eq 0 ]; then
  pares1="$(echo "$out1" | sed -n 's/^-- universo: \([0-9]*\).*/\1/p')"
  echo "OK [1] — $pares1 de $pares1 contagens conferidas (0 divergente)"
fi

# ── [2] anti-vacuidade — zero declarações reprova pela guarda de piso ────────────────────────
echo "[2] anti-vacuidade — README-fixture sem contagem alguma."
mk_readme_sem_numeros "$T/readme_vazio.md"
out2="$(confere "$T/readme_vazio.md" "$FX")"; rc2=$?
if [ "$rc2" -eq 0 ]; then
  echo "FAIL [2]: guarda de piso NÃO reprovou README sem contagem alguma — universo vazio aprovaria por vacuidade ('$out2')"
  overall_rc=1
else
  case "$out2" in
    *"guarda de piso"*) echo "OK [2] — guarda de piso reprovou universo vazio" ;;
    *) echo "FAIL [2]: reprovou, mas sem a mensagem de guarda de piso ('$out2')"; overall_rc=1 ;;
  esac
fi

# ── [3] diretório fantasma ────────────────────────────────────────────────────────────────────
echo "[3] diretório fantasma — linha declara contagem para diretório inexistente."
{
  echo "# fixture"
  echo
  echo "## 📁 Estrutura"
  echo
  echo '```text'
  echo "├── agents/  (3)"
  echo "├── commands/ (4)"
  echo "├── contracts/ (5)"
  echo "├── skills/   (2)"
  echo "├── rules/   (6)"
  echo "├── schemas/ (1)"
  echo "├── scripts/ (7)"
  echo "└── fantasma/  (9)"
  echo '```'
} >"$T/readme_fantasma.md"
out3="$(confere "$T/readme_fantasma.md" "$FX")"; rc3=$?
esperado3="README declara contagem para '$FX/fantasma/', que NÃO existe na árvore"
if [ "$rc3" -eq 0 ]; then
  echo "FAIL [3]: confere aprovou com diretório fantasma declarado ('$out3')"
  overall_rc=1
elif ! printf '%s\n' "$out3" | grep -qF -- "$esperado3"; then
  echo "FAIL [3]: reprovou, mas sem a mensagem esperada — esperado conter '$esperado3', obtido '$out3'"
  overall_rc=1
else
  echo "OK [3] — diretório fantasma acusado por mensagem"
fi

# ── [4] mutação de TEXTO — contagem declarada rebaixada, com controle e recontrole ──────────
echo "[4] mutação de texto — agents/ (3) rebaixado para (2)."
mk_readme_intact "$T/readme_ok.md"
out4ctrl="$(confere "$T/readme_ok.md" "$FX")"; rc4ctrl=$?
if [ "$rc4ctrl" -ne 0 ]; then
  echo "FAIL [4]: controle — README-fixture ÍNTEGRO reprovou antes da mutação ('$out4ctrl')"
  overall_rc=1
fi
mk_readme_intact "$T/readme_mut.md"
perl -0pi -e 's/agents\/  \(3\)/agents\/  (2)/' "$T/readme_mut.md"
out4="$(confere "$T/readme_mut.md" "$FX")"; rc4=$?
esperado4="inventário do README defasado em '$FX/agents/' — declarado (2), real (3)"
if [ "$rc4" -eq 0 ]; then
  echo "FAIL [4]: confere aprovou com agents/ mutado para (2) ('$out4')"
  overall_rc=1
elif ! printf '%s\n' "$out4" | grep -qF -- "$esperado4"; then
  echo "FAIL [4]: reprovou, mas sem a mensagem esperada — esperado conter '$esperado4', obtido '$out4'"
  overall_rc=1
else
  echo "OK [4] — agents/ mutado acusado por mensagem (declarado 2, real 3); controle íntegro aprovou antes"
fi

# ── [5] mutação de ÁRVORE — arquivo a mais em contracts/, com controle e recontrole ─────────
echo "[5] mutação de árvore — arquivo extra em contracts/."
mk_readme_intact "$T/readme_arvore.md"
out5ctrl="$(confere "$T/readme_arvore.md" "$FX")"; rc5ctrl=$?
if [ "$rc5ctrl" -ne 0 ]; then
  echo "FAIL [5]: controle — README-fixture ÍNTEGRO reprovou antes da mutação de árvore ('$out5ctrl')"
  overall_rc=1
fi
: >"$FX/contracts/extra.txt"
out5="$(confere "$T/readme_arvore.md" "$FX")"; rc5=$?
esperado5="inventário do README defasado em '$FX/contracts/' — declarado (5), real (6)"
if [ "$rc5" -eq 0 ]; then
  echo "FAIL [5]: confere aprovou com arquivo extra em contracts/ ('$out5')"
  overall_rc=1
elif ! printf '%s\n' "$out5" | grep -qF -- "$esperado5"; then
  echo "FAIL [5]: reprovou, mas sem a mensagem esperada — esperado conter '$esperado5', obtido '$out5'"
  overall_rc=1
else
  echo "OK [5] — arquivo extra em contracts/ acusado por mensagem (declarado 5, real 6)"
fi
rm -f "$FX/contracts/extra.txt"
out5rec="$(confere "$T/readme_arvore.md" "$FX")"; rc5rec=$?
if [ "$rc5rec" -ne 0 ]; then
  echo "FAIL [5]: recontrole — removido o arquivo extra, confere continuou reprovando ('$out5rec')"
  overall_rc=1
fi

# ── [6] o badge de gates do README casa com a árvore ────────────────────────────────────────
# O inventário de Estrutura não era a única contagem mantida à mão neste README: o badge do topo
# dizia 66 quando a árvore tinha 124 gates — defasagem de 58, encontrada pela revisão adversarial
# DEPOIS que esta entrega já corrigia as outras sete. Corrigir a contagem e deixar o badge de fora
# seria consertar o sintoma e preservar a causa, que é contagem sem quem a reconfira.
echo "[6] o badge de gates do README casa com a contagem de tests/*-gate.sh"
badge_n="$(grep -oE 'gates-[0-9]+' "$WS/README.md" | head -1 | cut -d- -f2)"
arvore_n="$(find "$WS/tests" -maxdepth 1 -name '*-gate.sh' | wc -l | tr -d ' ')"
if [ -z "$badge_n" ]; then
  echo "FAIL [6]: não achei o badge de gates no README — o predicado ficou sem universo, e universo vazio não aprova"
  overall_rc=1
elif [ "$arvore_n" -eq 0 ]; then
  echo "FAIL [6]: zero gate encontrado em tests/ — universo vazio, o cenário aprovaria por vacuidade"
  overall_rc=1
elif [ "$badge_n" != "$arvore_n" ]; then
  echo "FAIL [6]: o badge do README diz $badge_n gate(s) e a árvore tem $arvore_n — a mesma contagem à mão que este gate existe para impedir"
  overall_rc=1
else
  echo "OK [6] — badge e árvore concordam em $arvore_n gate(s)"
fi

# mutação do [6]: rebaixar o badge tem de reprovar, e restaurar tem de voltar a passar.
cp "$WS/README.md" "$T/readme.orig"
sed -i.bak "s/gates-${arvore_n}%20passing/gates-1%20passing/" "$WS/README.md" && rm -f "$WS/README.md.bak"
mut_badge="$(grep -oE 'gates-[0-9]+' "$WS/README.md" | head -1 | cut -d- -f2)"
if [ "$mut_badge" = "$arvore_n" ]; then
  echo "FAIL [6]: a mutação não alterou o badge — o alvo do sed não casou, e a prova mediria o próprio engano"
  overall_rc=1
elif [ "$mut_badge" = "$arvore_n" ] || [ "$mut_badge" != "1" ]; then
  echo "FAIL [6]: a mutação produziu badge inesperado ('$mut_badge')"
  overall_rc=1
fi
cp "$T/readme.orig" "$WS/README.md"
if ! cmp -s "$WS/README.md" "$T/readme.orig"; then
  echo "FAIL [6]: restauração do README não bateu byte a byte"
  overall_rc=1
fi
rec_badge="$(grep -oE 'gates-[0-9]+' "$WS/README.md" | head -1 | cut -d- -f2)"
if [ "$rec_badge" != "$arvore_n" ]; then
  echo "FAIL [6]: recontrole — depois da restauração o badge não voltou a $arvore_n (ficou '$rec_badge')"
  overall_rc=1
else
  echo "OK [6] mutação — rebaixar o badge é detectável; restauração e recontrole verificados"
fi

exit "$overall_rc"
