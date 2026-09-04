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

pass=0; fail=0; failed=""
run_one() {  # run_one <arquivo> <comando...>
  local nome="$1"; shift
  if "$@" >/dev/null 2>&1; then
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
echo "harness-tests: $total arquivo(s) examinado(s) — PASS=$pass FAIL=$fail"
if [ "$fail" -ne 0 ]; then
  printf 'FALHARAM:\n'; printf '  - %s\n' $failed
  exit 1
fi
echo "OK harness-tests"
