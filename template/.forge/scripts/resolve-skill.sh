#!/usr/bin/env bash
# resolve-skill.sh — resolve o diretório de uma skill projetada, SÓ PARA USO DO COMANDO
# (nunca do hook `post-merge`, que usa `resolve_delegated()` restrito a `.forge/skills/` do
# projeto — ver REQ-07/REQ-12/REQ-13 do change add-unify-changelog-skill).
#
# Ordem de precedência:
#   1. $FORGE_SKILL_DIR_<NOME> (env var, NOME em UPPERCASE com qualquer caractere não
#      alfanumérico trocado por "_") — override explícito, maior precedência.
#   2. $FORGE_ROOT/.forge/skills/<nome>/ (ou $PWD se FORGE_ROOT ausente) — cópia do projeto,
#      projetada em .claude/skills/<nome> pelo sync-adapters. Resolvida PRIMEIRO entre as fontes
#      não-override para não colidir com uma skill de mesmo nome de outro consumidor instalada
#      no escopo de usuário (ex.: "readme-generator" em Python no Payments).
#   3. $HOME/.claude/skills/<nome>/ — skill de usuário do adapter ativo (hoje só Claude).
#
# Ausência nas três fontes: "FAIL skill <nome> ausente", rc 1.
#
# Uso: resolve-skill.sh <nome> [<arquivo-obrigatorio>...]
#   <arquivo-obrigatorio> é relativo ao diretório resolvido; se informado, cada um precisa
#   existir dentro do diretório resolvido, senão a resolução falha mesmo com o diretório presente.
#
# Saída (stdout, em sucesso): o caminho absoluto do diretório resolvido.
set -uo pipefail

nome="${1:-}"
shift || true
[ -n "$nome" ] || { echo "Uso: resolve-skill.sh <nome> [<arquivo-obrigatorio>...]" >&2; exit 2; }

# NOME em UPPERCASE, não alfanumerico -> "_" (ex.: "design-system" -> "DESIGN_SYSTEM").
var_suffix="$(printf '%s' "$nome" | tr '[:lower:]' '[:upper:]' | sed 's/[^A-Z0-9]/_/g')"
env_var="FORGE_SKILL_DIR_${var_suffix}"

ROOT="${FORGE_ROOT:-$PWD}"

_check_required_files() { # _check_required_files <dir> <arquivo...> -> rc 0 se todos existem
  local dir="$1"; shift
  local f
  for f in "$@"; do
    [ -f "$dir/$f" ] || return 1
  done
  return 0
}

candidatos=()
# shellcheck disable=SC2154
env_val="$(eval "printf '%s' \"\${$env_var:-}\"")"
[ -n "$env_val" ] && candidatos+=("$env_val")
candidatos+=("$ROOT/.forge/skills/$nome")
[ -n "${HOME:-}" ] && candidatos+=("$HOME/.claude/skills/$nome")

for dir in "${candidatos[@]}"; do
  [ -d "$dir" ] || continue
  if [ "$#" -gt 0 ]; then
    _check_required_files "$dir" "$@" || continue
  fi
  printf '%s\n' "$dir"
  exit 0
done

echo "FAIL skill $nome ausente" >&2
echo "  (procurado em: ${candidatos[*]:-<nenhuma fonte configurada>})" >&2
exit 1
