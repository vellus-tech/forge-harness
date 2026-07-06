#!/usr/bin/env bash
# worktree-reconcile.sh — reconciliação determinista de worktrees (sem LLM).
# Para cada worktree de `git worktree list --porcelain`, imprime branch, ahead/behind do
# upstream, status curto (staged/dirty/untracked) e último commit — 1 bloco de 3-4 linhas por
# worktree. Usa `git -C` sempre (nunca `cd`) para não perder o cwd entre chamadas.
#
# Motivação: após um subagente ser interrompido/morto no meio de uma onda, o tracker
# (PROGRESS-TRACKING.md) pode não refletir o estado REAL do worktree — este script dá a foto
# real antes de redistribuir tasks (ver /forge:coding-loop).
#
# Uso:
#   worktree-reconcile.sh                # lista todos os worktrees do repo atual
#   worktree-reconcile.sh --root <path>  # repo alternativo (default: cwd)
set -u

ROOT="."
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    *) echo "Uso: worktree-reconcile.sh [--root <path>]" >&2; exit 1 ;;
  esac
done

ROOT="$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null)" || {
  echo "FAIL: não é um repositório git ($ROOT)" >&2
  exit 1
}

porcelain="$(git -C "$ROOT" worktree list --porcelain 2>/dev/null)"
[ -n "$porcelain" ] || { echo "Nenhum worktree encontrado."; exit 0; }

wt=""
count=0
print_block() {
  local path="$1"
  [ -n "$path" ] || return 0
  [ -d "$path" ] || { echo "$path :: MISSING (path não existe mais no disco)"; echo; return 0; }

  local branch upstream ahead behind status staged dirty untracked last
  branch="$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")"
  upstream="$(git -C "$path" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo "")"

  ahead=0; behind=0
  if [ -n "$upstream" ]; then
    ahead="$(git -C "$path" rev-list --count "${upstream}..HEAD" 2>/dev/null || echo 0)"
    behind="$(git -C "$path" rev-list --count "HEAD..${upstream}" 2>/dev/null || echo 0)"
  fi

  status="$(git -C "$path" status --porcelain 2>/dev/null || echo "")"
  staged="$(printf '%s\n' "$status" | grep -c '^[MADRC]' || true)"
  dirty="$(printf '%s\n' "$status" | grep -c '^.[MD]' || true)"
  untracked="$(printf '%s\n' "$status" | grep -c '^??' || true)"

  last="$(git -C "$path" log -1 --format='%h %ci %s' 2>/dev/null || echo "sem commits")"

  echo "$path"
  echo "  branch=$branch upstream=${upstream:-<none>} ahead=$ahead behind=$behind"
  echo "  staged=$staged dirty=$dirty untracked=$untracked"
  echo "  last: $last"
  echo
}

while IFS= read -r line; do
  case "$line" in
    "worktree "*)
      print_block "$wt"
      wt="${line#worktree }"
      count=$((count + 1))
      ;;
  esac
done <<EOF_PORCELAIN
$porcelain
EOF_PORCELAIN
print_block "$wt"

echo "Total: $count worktree(s)."
