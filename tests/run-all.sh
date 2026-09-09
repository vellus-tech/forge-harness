#!/usr/bin/env bash
# run-all.sh — suíte consolidada do harness Forge (Fase 8, W8.0).
# Roda, em ordem determinista, todos os gates *-gate.sh + as suítes bats
# (validators.bats e o contrato Claude em source mode). Saída agregada com contagem.
# Gate da W8.0: esta suíte 100% verde.
#
# Uso:
#   tests/run-all.sh            # roda tudo; exit 0 só se 100% verde
#   tests/run-all.sh --list     # apenas lista o que seria executado, em ordem
#   tests/run-all.sh -v         # ecoa a saída de cada gate (default: só PASS/FAIL + tail no erro)
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$WS"

VERBOSE=0
LIST=0
for a in "$@"; do
  case "$a" in
    -v|--verbose) VERBOSE=1 ;;
    --list) LIST=1 ;;
    *) echo "arg desconhecido: $a" >&2; exit 2 ;;
  esac
done

# Desliga a manutenção automática do git em TODO fixture da suíte.
#
# `git commit` dispara `git gc --auto` em BACKGROUND. Onze gates criam repositório git em /tmp, e
# quando o fixture é removido logo depois do último commit, o gc ainda está escrevendo em `.git` —
# o `rm -rf` então falha com "Directory not empty", e sob `set -e` o gate morre DEPOIS de ter
# passado nas suas asserções. Não reproduz no macOS (APFS + timing), reproduz no CI Linux
# (overlayfs). Foi o que reprovou o w106 no CI com todas as asserções verdes no log.
#
# Via GIT_CONFIG_COUNT em vez de `git config` por fixture: uma única declaração cobre os onze
# gates e qualquer gate futuro, sem depender de cada autor lembrar. É também a razão de estar
# AQUI e não em cada gate — o esquecimento é a falha que se quer eliminar.
export GIT_CONFIG_COUNT=3
export GIT_CONFIG_KEY_0=gc.auto           GIT_CONFIG_VALUE_0=0
export GIT_CONFIG_KEY_1=maintenance.auto  GIT_CONFIG_VALUE_1=0
export GIT_CONFIG_KEY_2=gc.autoDetach     GIT_CONFIG_VALUE_2=false

# Ordem: guardrails (gw*) primeiro, depois waves (w*) em ordem numérica natural.
# `run-all.sh` se exclui; o w80 (gate da própria suíte) NÃO chama run-all (sem recursão).
# Build do array sem mapfile (portável p/ bash 3.2 do macOS).
GATES=()
while IFS= read -r _g; do
  [ -n "$_g" ] && GATES+=("$_g")
done < <(ls tests/*-gate.sh 2>/dev/null | LC_ALL=C sort)

# Suítes bats: contrato em source mode + validadores. O contrato em generated mode é
# exercitado dentro de w14-adapters-gate.sh (precisa de um alvo instalado).
BATS_SUITES=()
[ -f tests/validators.bats ] && BATS_SUITES+=("tests/validators.bats")
[ -f tests/snapshot/claude-contract.bats ] && BATS_SUITES+=("tests/snapshot/claude-contract.bats")

if [ "$LIST" -eq 1 ]; then
  # Guarda de contagem antes de CADA expansão: sob `set -u` no bash 3.2, `"${arr[@]}"` com o array
  # vazio aborta com "unbound variable". Ver a nota longa junto ao laço dos gates, abaixo.
  echo "# gates (${#GATES[@]}):"
  [ "${#GATES[@]}" -gt 0 ] && printf '  %s\n' "${GATES[@]}"
  echo "# bats (${#BATS_SUITES[@]}):"
  [ "${#BATS_SUITES[@]}" -gt 0 ] && printf '  %s\n' "${BATS_SUITES[@]}"
  exit 0
fi

# Sentinela da árvore RASTREADA (LDG-0179).
#
# Seis gates desta suíte usavam arquivo rastreado da árvore de trabalho como fixture: mutavam o
# arquivo real e restauravam no trap. Nenhuma restauração sobrevive a `SIGKILL` — o modo de morte
# desta máquina sob pressão de memória — e três deles restauravam com `git checkout --`, que apaga
# trabalho não commitado com o gate saindo VERDE. Os seis foram convertidos para operar sobre cópia;
# esta sentinela fecha a classe por fora, medindo o EFEITO: o retrato da árvore rastreada antes e
# depois de CADA alvo, com a divergência virando um veredito próprio, distinto de "reprovou".
#
# Ela é cega para o gate que muta e restaura corretamente no fluxo feliz — essa metade é da trava de
# forma do w213 — e não cobre morte por sinal, porque o runner morre junto. As duas peças convivem.
#
# A ausência da biblioteca é ERRO, e não silêncio: um guardião entregue e nunca invocado conta como
# cobertura em relatório e não cobre nada, que é a issue #49 deste próprio harness.
LIB_ARVORE="$WS/template/.forge/scripts/lib/arvore-rastreada.sh"
if [ ! -f "$LIB_ARVORE" ]; then
  echo "run-all.sh: sentinela ausente — '$LIB_ARVORE' não existe; a suíte não roda sem ela" >&2
  exit 4
fi
# shellcheck source=/dev/null
. "$LIB_ARVORE"

have_bats=1
command -v bats >/dev/null 2>&1 || have_bats=0

pass=0; fail=0; skip=0; unverified=0
failed_names=()
unverified_names=()
start_epoch="$(date +%s 2>/dev/null || echo 0)"

# Três estados, nunca dois (LDG-0180).
#
# Até aqui `run_one` tinha dois desfechos, e todo rc diferente de zero virava a mesma parcela, o
# mesmo marcador e a mesma linha em FALHARAM:. Um gate reprovado por asserção, um gate que o kernel
# matou por pressão de memória, um gate que estourou o teto de tempo e um gate sem dependência
# terminavam com o mesmo veredito. Isso é falso-VERMELHO: manda procurar defeito onde não há, e no
# limite faz alguém "consertar" código correto. Foi medido — dois gates apareceram vermelhos numa
# execução sob pressão de memória e passaram limpos isolados; os dois tinham sido MORTOS.
#
# O discriminador primário é a FORMA DO RC, e o log só agrava, nunca abranda:
#   rc 0                 passagem
#   rc em [129, 192]     morto por sinal — 128+N, com folga sobre os 31 sinais do macOS e os 64 do
#                        Linux. MAS se o log já contém uma LINHA DE REPROVAÇÃO, a violação chegou a
#                        ser observada e o desfecho é reprovação: esconder um achado real atrás de
#                        "não verificado" seria falso-verde, estritamente pior que o falso-vermelho.
#   rc 126 ou 127        dependência ausente ou alvo não executável — não é veredito do alvo
#   rc 128               REPROVAÇÃO, não sinal: o produtor esmagadoramente mais provável de 128 aqui
#                        é o git, que o usa para erro fatal (`git diff HEAD` em repo sem commit).
#   qualquer outro       reprovação por asserção
#
# A ausência do token FAIL NÃO é usada para abrandar: dezesseis dos gates desta suíte não contêm o
# token em lugar nenhum e reprovam por comando nu morrendo sob `set -e`, e asserções nuas existem
# dentro de gates que têm o token. Exigir o marcador rebaixaria essa família inteira para "não
# verificado" — trocaria o falso-vermelho por falso-verde.
#
# "LINHA de reprovação" é literal, e a precisão custou o defeito que esta onda existe para eliminar.
# A primeira implementação procurava o TOKEN em qualquer posição do log — `(^|[^A-Za-z])FAIL` — e com
# isso classificava como reprovação a morte por sinal de um gate cujo caminho VERDE apenas NARRA o
# token. Medido em três gates de produção deste repositório, todos com rc 0:
#   w131-surface-declaration-gate.sh   [9] WAV-01 — '--gate FAIL' continua reprovando …
#   w51-waves-progress-gate.sh         [4] wave-ops close: OK fecha; FAIL recusa
#   req13-affects-surfaces-gate.sh     [1] affects_surfaces: … → FAIL   (duas ocorrências)
# Qualquer um dos três morto por SIGKILL depois dessa linha — o cenário exato do incidente que
# originou este item — voltava a ser falso-VERMELHO. A forma que os gates usam para reprovar de
# verdade é o token no INÍCIO da linha (`FAIL [n]: …`, `FAIL: …`, `fail() { echo "FAIL $*"; }`,
# `console.error('FAIL …')`, `print("FAIL …")`): medido sobre os 137 gates, as 2.843 aberturas
# `echo "FAIL` e as demais formas abrem a LINHA com o token, e nenhuma emissão de reprovação o
# coloca no meio. O `[[:space:]]*` inicial existe porque quatro gates indentam a saída de sub-alvos
# com `sed 's/^/      /'` — a reprovação de um sub-gate chega indentada ao log e tem de agravar.
#
# Para bats a regra é outra, porque o bats ABSORVE o sinal do worker e devolve rc 1 — a faixa nunca
# dispararia no caso que mais importa. Lá o discriminador é o contrato TAP, que o bats emite sempre:
# plano `1..0` (ou plano ausente) com rc 0 é vacuidade, e rc não-zero sem nenhuma linha `^not ok` é
# morte, não reprovação. Ao contrário de FAIL, `^not ok` é contrato do formato, não convenção.
classificar() { # classificar <tipo> <rc> <arquivo-de-log> -> PASS | FAIL | UNV:<motivo>
  local tipo="$1" rc="$2" lf="$3"
  local n
  if [ "$tipo" = "bats" ]; then
    if [ "$rc" -ge 129 ] && [ "$rc" -le 192 ]; then echo "UNV:sinal-$((rc - 128))"; return 0; fi
    if [ "$rc" -eq 0 ]; then
      # atribuição direta, sem `|| echo 0`: `grep -c` já imprime 0 quando não casa, e o `|| echo`
      # anexaria uma segunda linha que quebra o teste numérico seguinte (família do LDG-0177).
      n="$(grep -cE '^1\.\.[1-9]' "$lf" 2>/dev/null)"
      [ "${n:-0}" -ge 1 ] || { echo "UNV:plano-vazio"; return 0; }
      echo "PASS"; return 0
    fi
    n="$(grep -cE '^not ok' "$lf" 2>/dev/null)"
    [ "${n:-0}" -ge 1 ] && { echo "FAIL"; return 0; }
    echo "UNV:sem-not-ok"; return 0
  fi
  [ "$rc" -eq 0 ] && { echo "PASS"; return 0; }
  if [ "$rc" -ge 129 ] && [ "$rc" -le 192 ]; then
    n="$(grep -cE '^[[:space:]]*FAIL([^A-Za-z0-9_]|$)' "$lf" 2>/dev/null)"
    [ "${n:-0}" -ge 1 ] && { echo "FAIL"; return 0; }
    echo "UNV:sinal-$((rc - 128))"; return 0
  fi
  if [ "$rc" -eq 126 ] || [ "$rc" -eq 127 ]; then echo "UNV:dependencia-ausente"; return 0; fi
  echo "FAIL"
}

run_one() {
  local name="$1" tipo="$2"; shift 2
  local log rc veredito motivo
  # `mktemp` sem checagem classificava como REPROVAÇÃO um alvo que passa: com o caminho vazio o
  # redirecionamento morre e o rc que chega é 1, sem o alvo ter sido sequer executado. Disco cheio
  # e TMPDIR sem escrita são vizinhos de porta da pressão de memória que originou este item.
  log="$(mktemp 2>/dev/null || true)"
  if [ -z "$log" ] || [ ! -f "$log" ]; then
    unverified=$((unverified + 1)); unverified_names+=("$name (sem-log)")
    printf '  \033[35m⚠\033[0m %s\n' "$name"
    printf '      não verificado (sem-log) — o arquivo de log não pôde ser criado\n'
    return 0
  fi
  local antes rc_sentinela
  # `arvore_retrato`, e não `arvore_snapshot`: a atribuição por substituição de comando HERDA o rc 3
  # da biblioteca, e sob `set -e` isso mata o chamador antes de qualquer saída. Aqui o runner não usa
  # `set -e`, mas o idioma é o mesmo dos dez sítios de adoção e não pode divergir por acaso.
  antes="$(arvore_retrato "$WS")"
  "$@" >"$log" 2>&1; rc=$?
  veredito="$(classificar "$tipo" "$rc" "$log")"
  # A sentinela agrava, nunca abranda: ela promove PASS e "não verificado" a SUJOU, e jamais rebaixa
  # uma reprovação já observada — esconder um achado real atrás de outro rótulo seria falso-verde.
  arvore_confere "$WS" "$antes" "$name" >>"$log" 2>&1
  rc_sentinela=$?
  if [ "$rc_sentinela" -eq 1 ] && [ "$veredito" != "FAIL" ]; then
    veredito="SUJOU"
  elif [ "$rc_sentinela" -eq 3 ] && [ "$veredito" = "PASS" ]; then
    veredito="UNV:arvore-nao-medida"
  fi
  case "$veredito" in
    PASS)
      pass=$((pass + 1))
      printf '  \033[32m✓\033[0m %s\n' "$name"
      [ "$VERBOSE" -eq 1 ] && sed 's/^/      /' "$log"
      ;;
    FAIL)
      fail=$((fail + 1)); failed_names+=("$name")
      printf '  \033[31m✗\033[0m %s\n' "$name"
      sed 's/^/      /' "$log" | tail -8
      ;;
    SUJOU)
      fail=$((fail + 1)); failed_names+=("$name (sujou a árvore rastreada)")
      printf '  \033[31m✗\033[0m %s\n' "$name"
      printf '      o alvo sujou a árvore rastreada do repositório — não é reprovação de asserção\n'
      sed 's/^/      /' "$log" | tail -8
      ;;
    *)
      motivo="${veredito#UNV:}"
      unverified=$((unverified + 1)); unverified_names+=("$name ($motivo)")
      printf '  \033[35m⚠\033[0m %s\n' "$name"
      printf '      não verificado (%s, rc=%s) — o desfecho não é veredito do alvo\n' "$motivo" "$rc"
      sed 's/^/      /' "$log" | tail -4
      ;;
  esac
  rm -f "$log"
}

echo "== Forge — suíte consolidada (run-all) =="
# GUARDA DE VACUIDADE ANTES DA EXPANSÃO — sob `set -u` no bash 3.2, `"${arr[@]}"` com o array vazio
# aborta com "unbound variable". Era defeito PRÉ-EXISTENTE nos três sítios (as duas listagens do
# `--list`, este laço e o dos bats), e é o mesmo colapso de dois estados que esta onda combate: uma
# árvore sem `tests/validators.bats` fazia o runner morrer AQUI, depois de já ter executado todos os
# gates, sem imprimir `== Resultado ==` e devolvendo rc 1 — indistinguível de "algum gate reprovou",
# com toda a classificação já apurada perdida. Medido nesta bancada, contra o runner de produção:
#   run-all.sh: line 220: BATS_SUITES[@]: unbound variable ; rc=1 ; zero linhas '^PASS='.
# `${#arr[@]}` é seguro no bash 3.2 com array vazio (medido); só a expansão dos elementos não é.
echo "-- gates deterministas (${#GATES[@]}) --"
if [ "${#GATES[@]}" -gt 0 ]; then
  for g in "${GATES[@]}"; do
    run_one "$(basename "$g")" gate bash "$g"
  done
fi

echo "-- suítes bats (${#BATS_SUITES[@]}) --"
if [ "${#BATS_SUITES[@]}" -eq 0 ]; then
  :
elif [ "$have_bats" -eq 0 ]; then
  skip=$((skip + ${#BATS_SUITES[@]}))
  printf '  \033[33m○\033[0m bats indisponível — %d suíte(s) puladas\n' "${#BATS_SUITES[@]}"
else
  for b in "${BATS_SUITES[@]}"; do
    run_one "$(basename "$b")" bats bats "$b"
  done
fi

end_epoch="$(date +%s 2>/dev/null || echo 0)"
elapsed=$((end_epoch - start_epoch))

echo
echo "== Resultado =="
echo "PASS=$pass  FAIL=$fail  SKIP=$skip  UNVERIFIED=$unverified  (${elapsed}s)"
# Expansão de array só DEPOIS da guarda de contagem: sob `set -u` no bash 3.2, `"${arr[@]}"` com o
# array vazio aborta com "unbound variable".
if [ "$fail" -ne 0 ]; then
  printf 'FALHARAM:\n'; printf '  - %s\n' "${failed_names[@]}"
fi
if [ "$unverified" -ne 0 ]; then
  printf 'NÃO VERIFICADOS:\n'; printf '  - %s\n' "${unverified_names[@]}"
fi
# Reprovação tem precedência: é o achado acionável. O terceiro estado sai 3, e não 0, porque uma
# suíte em que quarenta gates morreram por falta de memória reportando verde é o falso-verde que
# este harness existe para eliminar; e não sai 1 porque isso reintroduziria o defeito no único canal
# que o CI lê. Os consumidores medidos (npm test, o passo do CI) testam zero contra não-zero, e
# continuam bloqueando em 3 exatamente como em 1. O código 2 segue sendo argumento desconhecido.
if [ "$fail" -ne 0 ]; then exit 1; fi
if [ "$unverified" -ne 0 ]; then exit 3; fi
echo "OK — suíte 100% verde"
