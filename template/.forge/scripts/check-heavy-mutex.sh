#!/usr/bin/env bash
# check-heavy-mutex.sh — gate ESTÁTICO de consumo do mutex de carga pesada (issue #52).
#
# Composição em runtime não basta: o defeito real do `ci-local.sh` foi um `trap … EXIT` instalado
# DEPOIS do nosso, e nenhuma composição defende disso. Este gate cobre o que está versionado.
#
# O que ele NÃO alcança está declarado: um `dotnet test` digitado à mão continua fora da fila.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${FORGE_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
# shellcheck disable=SC1090
. "$SCRIPT_DIR/lib/gate-universe.sh"

TARGET="$ROOT"
while [ $# -gt 0 ]; do
  case "$1" in
    --path|--root) TARGET="$2"; shift 2 ;;
    *) echo "FAIL: argumento desconhecido '$1'" >&2; exit 2 ;;
  esac
done

# A lista é capturada ANTES, numa variável: `$(find …)` dentro de heredoc mistura duas camadas de
# expansão e o resultado chegou vazio — e um universo vazio aqui é indistinguível de "varri tudo e
# estava limpo" se ninguém contar. Quem conta é o contador de controle logo abaixo.
# `cd` e caminhos RELATIVOS de propósito: um filtro `-not -path '*/worktrees/*'` sobre caminho
# absoluto exclui o repositório INTEIRO quando ele mesmo vive dentro de um worktree — medido, o
# universo chegou a zero e só o contador de controle denunciou.
FILES="$(cd "$TARGET" 2>/dev/null && find . -type f -name '*.sh' -not -path './.git/*' -not -path '*/node_modules/*' -not -path './.forge/worktrees/*' 2>/dev/null | sort)
$(cd "$TARGET" 2>/dev/null && find . -type f \( -name 'pre-push' -o -name 'pre-commit' -o -name 'post-merge' -o -name 'commit-msg' \) -not -path './.git/*' -not -path './.forge/worktrees/*' 2>/dev/null | sort)"
n=0
for _f in $FILES; do [ -n "$_f" ] && n=$((n + 1)); done

# Contador de controle (issue #49): universo vazio não pode terminar no mesmo verde de "varri tudo
# e estava limpo".
if ! forge_universe_check "heavy-mutex" "$n" "arquivo(s)" "$TARGET" "$ROOT"; then
  exit 1
fi

viol=0
report() { echo "FAIL heavy-mutex: $1" >&2; viol=$((viol + 1)); }

while IFS= read -r f; do
  [ -n "$f" ] || continue
  f="$TARGET/${f#./}"
  # Os arquivos que IMPLEMENTAM o primitivo são isentos por construção: o wrapper cita TMPDIR
  # porque PROCURA caminhos legados no `sweep --legacy`, e instala trap próprio porque é dono do
  # processo. Isentar quem implementa não é abrir exceção — é não confundir o mecanismo com o uso.
  case "$f" in
    */check-heavy-mutex.sh|*/heavy-mutex.sh|*/heavy-run.sh|*/w151-heavy-mutex-gate.sh) continue ;;
  esac

  # 1. Caminho de lock derivado de variável do chamador — o defeito 1 codificado.
  if grep -nE '\$\{?(TMPDIR|HOME|PWD)[:}-]' "$f" 2>/dev/null | grep -qi 'lock'; then
    report "$f: caminho de lock derivado de variável do chamador — no macOS TMPDIR é por usuário E por contexto, e o lock deixa de ser por máquina. Use lib/heavy-mutex.sh."
  fi
  # 2. Protocolo paralelo: mkdir/ln -s direto sobre nome de lock. Dois mecanismos diferentes sobre
  #    o mesmo recurso não se excluem — e PARECEM protegidos, que é pior que não ter lock.
  if grep -nE '^[^#]*\b(mkdir|ln -s)\b[^|]*\.lock' "$f" 2>/dev/null | grep -q .; then
    report "$f: adquire lock por conta própria em vez de passar pela biblioteca — protocolo paralelo sobre o mesmo recurso não exclui nada."
  fi
  # 3. `trap … EXIT` cru DEPOIS do acquire — o defeito medido no ci-local.sh.
  if grep -q 'forge_heavy_mutex_acquire' "$f" 2>/dev/null; then
    aq="$(grep -n 'forge_heavy_mutex_acquire' "$f" | head -1 | cut -d: -f1)"
    tr="$(grep -nE "^[^#]*trap [^-].*(EXIT|INT|TERM)" "$f" | tail -1 | cut -d: -f1)"
    if [ -n "$tr" ] && [ -n "$aq" ] && [ "$tr" -gt "$aq" ]; then
      report "$f:$tr: 'trap' cru depois do acquire SUBSTITUI o handler de liberação — trap não acumula. Registre a limpeza numa função única."
    fi
    # 4. `exit` dentro de trap em arquivo que adquire: normaliza o rc e um push que falhou reporta
    #    sucesso (classe da issue #49). Aqui só reprova; a biblioteca preserva a semântica.
    if grep -qE "trap '[^']*exit [0-9]" "$f" 2>/dev/null; then
      report "$f: 'exit' dentro de trap em arquivo que adquire o mutex — um push que falhou reportaria sucesso."
    fi
    # 8. acquire dentro de pipeline: o trap morreria com a subshell.
    if grep -qE 'forge_heavy_mutex_acquire[^|]*\|[^|]' "$f" 2>/dev/null; then
      report "$f: acquire dentro de pipeline — BASH_SUBSHELL != 0 e o trap morreria com a subshell."
    fi
  fi
  # 5. `rm -rf "$var/"` com barra final: sobre symlink destrói o conteúdo do ALVO e preserva o link.
  if grep -nE 'rm -rf +"\$[A-Za-z_][A-Za-z0-9_]*/"' "$f" 2>/dev/null | grep -q .; then
    report "$f: 'rm -rf \"\$var/\"' com barra final — sobre symlink isso destrói o conteúdo do alvo e preserva o link."
  fi
  # 6. Laço sobre a fila sem o guarda `[ -d ]`: glob sem correspondência devolve o LITERAL.
  if grep -qE 'for [a-z]+ in "[^"]*\.q"/\*' "$f" 2>/dev/null && ! grep -q '\[ -d "\$' "$f" 2>/dev/null; then
    report "$f: laço sobre a fila sem '[ -d ... ] || continue' — glob sem correspondência devolve o literal."
  fi
  # 7. Aritmética sobre ticket zero-padded sem `10#`: bash lê como octal e morre.
  if grep -nE '\$\(\( *\$[A-Za-z_]*(ticket|stamp|us20)[A-Za-z_]* *\)\)' "$f" 2>/dev/null | grep -qv '10#'; then
    report "$f: aritmética sobre ticket sem '10#' — bash lê zeros à esquerda como octal e morre com 'value too great for base'."
  fi
  # 9. `mkdir -p` para materializar a âncora: aceita symlink pré-existente.
  if grep -nE 'mkdir -p[^|]*(HEAVY_MUTEX_ROOT|\.q)\b' "$f" 2>/dev/null | grep -q .; then
    report "$f: 'mkdir -p' sobre a âncora — aceita symlink plantado por terceiro e o pwd -P segue o link."
  fi
done <<EOF
$FILES
EOF

[ "$viol" -eq 0 ] || {
  echo "FAIL heavy-mutex — $viol ocorrência(s) em $n arquivo(s) examinado(s)" >&2
  exit 1
}
echo "OK heavy-mutex — nenhuma ocorrência em $n arquivo(s) examinado(s)"
