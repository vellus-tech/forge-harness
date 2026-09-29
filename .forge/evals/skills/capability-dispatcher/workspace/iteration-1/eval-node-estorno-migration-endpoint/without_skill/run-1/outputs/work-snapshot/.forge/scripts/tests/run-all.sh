#!/usr/bin/env bash
# Runner da suíte de guarda do CONSUMIDOR (issue #73).
#
# Existe porque o `pre-push` do harness trata "o diretório existe e o runner não" como ERRO que
# bloqueia — e isso é deliberado, é o fecho da issue #49: um gate entregue e nunca chamado conta
# como cobertura nos relatórios e não cobre nada, então a ausência do invocador não pode terminar
# no mesmo desfecho de uma execução bem-sucedida.
#
# O que estava errado é que o template NÃO entregava este arquivo. Todo consumidor que tivesse
# `.forge/scripts/tests/` — porque escreveu testes de gate próprios ali, que é exatamente o que o
# harness incentiva — recebia no upgrade um hook que bloqueia o push e não recebia o arquivo que o
# desbloquearia. Medido: dois de quatro repositórios de um ecossistema caíam nisso, e num deles o
# mesmo `update` migrava `core.hooksPath` de relativo para absoluto, de modo que o tronco e as
# quatro worktrees passavam a executar o hook do tronco no mesmo instante — cinco checkouts com
# push bloqueado simultaneamente, no primeiro `git push` depois do upgrade.
#
# E nenhum `--dry-run` revelava: a lista de mudanças enumera o que o overlay ESCREVE, e a ausência
# de um arquivo no template não é uma mudança.
#
# Diretório sem teste algum sai ZERO — mas dizendo em voz alta que examinou zero. "Não rodei" e
# "rodei e passou" não podem terminar no mesmo silêncio: é o defeito canônico que a suíte deste
# harness existe para eliminar, e ele seria reintroduzido aqui por um runner mudo.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
while [ $# -gt 0 ]; do
  case "$1" in
    --path) DIR="$2"; shift 2 ;;
    -h|--help) echo "uso: run-all.sh [--path <dir>]"; exit 0 ;;
    *) echo "run-all.sh: argumento desconhecido '$1'" >&2; exit 64 ;;
  esac
done
[ -d "$DIR" ] || { echo "run-all.sh: '$DIR' não é um diretório" >&2; exit 66; }

# Sentinela da árvore RASTREADA (LDG-0179). Um teste que muta arquivo rastreado do repositório e
# restaura no trap não sobrevive a `SIGKILL`, e quando restaura com `git checkout --` apaga trabalho
# não commitado com o teste saindo verde. Aqui a guarda mede o EFEITO: retrato da árvore rastreada
# antes e depois de cada alvo, e a divergência vira veredito próprio, distinto de "reprovou".
#
# Repositório ausente ou `git` ausente NÃO viram verde silencioso, e a promessa é CUMPRIDA em código,
# não só em comentário: a primeira redação deste bloco guardava tudo por `if [ -n "$REPO" ]`, de modo
# que sem repositório não havia snapshot, o ramo do aviso ficava inalcançável e um teste que sujava a
# árvore saía com `✓` e o runner com rc 0 — medido. Agora a impossibilidade de medir é ela própria um
# estado: aviso explícito na cabeça, marcação por alvo e rc 3 no fecho, o MESMO contrato de rc 3 do
# runner da suíte. Duas implementações do mesmo contrato divergindo em silêncio é o LDG-0014.
LIB_ARVORE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" 2>/dev/null && pwd)/arvore-rastreada.sh"
SENTINELA=0
REPO=""
if [ -f "$LIB_ARVORE" ]; then
  # shellcheck source=/dev/null
  . "$LIB_ARVORE"
  SENTINELA=1
  REPO="$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null)" || REPO=""
  if [ -z "$REPO" ]; then
    SENTINELA=0
    echo "run-all.sh: aviso — '$DIR' não está em repositório git (ou 'git' está ausente); a sentinela da árvore rastreada NÃO pôde medir nada, e um teste que sujar a árvore passará sem ser visto" >&2
  fi
else
  echo "run-all.sh: aviso — sentinela da árvore rastreada ausente ($LIB_ARVORE); os testes rodam SEM ela" >&2
fi
# Contador por ALVO, não por condição global: com a sentinela desligada cada alvo já entra em
# `rc_sentinela=3` e se conta sozinho, e semear o contador aqui somaria um ponto que não existe.
nao_medidos=0

pass=0; fail=0; failed=""
run_one() {  # run_one <arquivo> <comando...>
  local nome="$1"; shift
  local antes="" rc_sentinela=0 alvo_ok=0
  # `antes="$(arvore_snapshot ...)"` herdaria o rc 3 da biblioteca; `arvore_retrato` devolve sempre
  # rc 0 e carrega o estado no VALOR, que é o que impede a morte muda sob `set -e` no adotante.
  if [ "$SENTINELA" -eq 1 ]; then antes="$(arvore_retrato "$REPO")"; else rc_sentinela=3; fi
  if "$@" >/dev/null 2>&1; then alvo_ok=1; fi
  if [ "$SENTINELA" -eq 1 ]; then
    arvore_confere "$REPO" "$antes" "$nome" >/dev/null 2>&1
    rc_sentinela=$?
  fi
  if [ "$rc_sentinela" -eq 1 ]; then
    fail=$((fail + 1)); failed="$failed $nome"
    printf '  ✗ %s — o teste sujou a árvore rastreada do repositório\n' "$nome"
    arvore_confere "$REPO" "$antes" "$nome" 2>&1 | sed 's/^/      /' | tail -20
    return 0
  fi
  if [ "$rc_sentinela" -eq 3 ]; then
    nao_medidos=$((nao_medidos + 1))
    printf '  ⚠ %s — árvore rastreada NÃO MEDIDA (sem git ou fora de repositório); o ✓ abaixo vale pelas asserções do teste, não pelo efeito dele na árvore\n' "$nome"
  fi
  if [ "$alvo_ok" -eq 1 ]; then
    pass=$((pass + 1)); printf '  ✓ %s\n' "$nome"
  else
    fail=$((fail + 1)); failed="$failed $nome"; printf '  ✗ %s\n' "$nome"
    "$@" 2>&1 | sed 's/^/      /' | tail -20
  fi
}

# `find` em vez de glob: glob que não casa nada devolve o próprio padrão como literal em bash, e
# isso vira "arquivo inexistente" contado como teste. O `-print0`/`read -d ''` cobre caminho com
# espaço; `mapfile -d` não existe no bash 3.2 do macOS.
total=0
while IFS= read -r -d '' f; do
  total=$((total + 1))
  case "$f" in
    *.test.mjs|*.mjs) run_one "$(basename "$f")" node "$f" ;;
    *.test.sh|*-test.sh|*.bats) run_one "$(basename "$f")" bash "$f" ;;
    *) total=$((total - 1)) ;;
  esac
done < <(find "$DIR" -type f \( -name '*.test.mjs' -o -name '*.test.sh' -o -name '*-test.sh' -o -name '*.bats' \) -print0 2>/dev/null | sort -z)

# O contador é a asserção, não o enfeite: sem ele, um diretório vazio e uma suíte inteira que não
# foi encontrada por erro de padrão produzem a mesma linha verde.
if [ "$total" -eq 0 ]; then
  echo "OK harness-tests — 0 arquivo(s) de teste examinado(s) em $DIR (nada a rodar)"
  exit 0
fi
echo "harness-tests: $total arquivo(s) examinado(s) — PASS=$pass FAIL=$fail NÃO-MEDIDOS=$nao_medidos"
if [ "$fail" -ne 0 ]; then
  printf 'FALHARAM:\n'; printf '  - %s\n' $failed
  exit 1
fi
# Reprovação tem precedência; o terceiro estado sai 3, como no runner da suíte deste harness. Não sai
# 0 porque "rodei e não pude medir se sujaram a árvore" não é "rodei e nada sujou" — é o falso-verde
# que esta guarda existe para eliminar — e não sai 1 porque não houve reprovação de asserção alguma.
if [ "$nao_medidos" -ne 0 ]; then
  echo "NÃO VERIFICADO harness-tests — os testes passaram, mas a árvore rastreada não pôde ser medida em $nao_medidos ponto(s)"
  exit 3
fi
echo "OK harness-tests"
