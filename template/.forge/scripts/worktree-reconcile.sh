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
# AHEAD/BEHIND (LDG-0056): resolvido por `git ls-remote`, nunca por `refs/remotes/<remote>/*`.
# `refs/remotes/*` é réplica LOCAL e pode estar desatualizada NAS DUAS DIREÇÕES: sem `fetch`
# recente ela ignora o que o servidor já tem (ahead superestimado), e depois de um `fetch` de
# OUTRO processo ela pode registrar mais do que este processo ainda sabia (ahead subestimado). É o
# MESMO defeito que o `check-push-ahead.sh` corrigiu para o `pre-push` (issue #67) — a técnica é a
# mesma; o desenho aqui é diferente porque `git worktree` COMPARTILHA `refs/remotes/*` e o banco de
# objetos entre TODOS os worktrees do mesmo repositório (só HEAD/index são por worktree), então uma
# leitura de rede POR REMOTO — nunca por worktree — já cobre todos eles. Ver `worktree_reconcile.
# timeout_s` no forge.yaml.
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

# ── leitura de rede, uma vez por REMOTO, nunca por worktree ─────────────────────────────────────
CACHE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/forge-wtreconcile.XXXXXX")" || {
  echo "FAIL: não foi possível criar diretório temporário" >&2
  exit 1
}
trap 'rm -rf "$CACHE_DIR"' EXIT INT TERM HUP

FORGE_YAML="$ROOT/.forge/forge.yaml"
_wtr_yaml_field() {  # _wtr_yaml_field <bloco> <chave>
  [ -f "$FORGE_YAML" ] || { echo ""; return; }
  awk -v blk="$1" -v key="$2" '
    $0 ~ "^"blk":" { inblk=1; next }
    inblk && /^[a-z_]+:/ { exit }
    inblk && $0 ~ "^[ ]+"key":" { sub("^[ ]+"key":[ ]*",""); sub(/[ ]*#.*$/,""); sub(/[ ]+$/,""); print; exit }
  ' "$FORGE_YAML"
}
WTR_TIMEOUT_S="$(_wtr_yaml_field worktree_reconcile timeout_s)"
case "${WTR_TIMEOUT_S:-}" in
  '') WTR_TIMEOUT_S=5 ;;
  *[!0-9]*) WTR_TIMEOUT_S=5 ;;
  *) WTR_TIMEOUT_S=$((10#$WTR_TIMEOUT_S)); [ "$WTR_TIMEOUT_S" -ge 1 ] || WTR_TIMEOUT_S=5 ;;
esac

# `git ls-remote --heads <remote>` sem filtro de ref: UMA leitura de rede devolve TODAS as branches
# do remoto de uma vez, então N worktrees com upstreams diferentes no MESMO remote pagam uma leitura
# só. Nunca por PIPE: a captura por `$( )` esperaria o descritor fechar, e um neto de transporte
# (`git-remote-https`) pode sobreviver ao sinal e segurá-lo aberto bem depois do teto — a mesma
# armadilha medida no check-push-ahead.sh. Escreve em ARQUIVO e mata pelo grupo isolado do filho.
_wtr_ls_remote_once() {  # _wtr_ls_remote_once <remote> <arquivo-de-saída> -> rc 0 se mediu
  local remote="$1" out="$2" netpid child_pgid self_pgid isolated=0 i=0 maxi done_net=0
  set -m
  ( GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/echo SSH_ASKPASS_REQUIRE=never \
      git -C "$ROOT" ls-remote --heads "$remote" > "$out" 2>/dev/null
  ) </dev/null >/dev/null 2>&1 &
  netpid=$!
  set +m
  child_pgid="$(ps -o pgid= -p "$netpid" 2>/dev/null | tr -d ' ')"
  self_pgid="$(ps -o pgid= -p $$ 2>/dev/null | tr -d ' ')"
  [ -n "$child_pgid" ] && [ -n "$self_pgid" ] && [ "$child_pgid" != "$self_pgid" ] && isolated=1
  maxi=$(( WTR_TIMEOUT_S * 10 + 5 ))
  while [ "$i" -lt "$maxi" ]; do
    kill -0 "$netpid" 2>/dev/null || { done_net=1; break; }
    sleep 0.1; i=$((i + 1))
  done
  if [ "$done_net" -eq 0 ]; then
    if [ "$isolated" -eq 1 ]; then
      disown "$netpid" 2>/dev/null || true
      kill -TERM -- "-$child_pgid" 2>/dev/null
      sleep 0.3
      kill -KILL -- "-$child_pgid" 2>/dev/null
    fi
    return 1
  fi
  wait "$netpid" 2>/dev/null
  [ -s "$out" ]
}

# Cache POR REMOTO (nunca por worktree): a primeira chamada mede; as seguintes leem o arquivo. Sem
# array associativo (bash 3.2/macOS) — o nome do arquivo de cache é derivado do nome do remoto.
_wtr_remote_cache_file() {  # _wtr_remote_cache_file <remote> -> ecoa <arquivo>; rc 1 se não mediu
  local remote="$1" safe f status
  safe="$(printf '%s' "$remote" | tr -c 'A-Za-z0-9_.-' '_')"
  f="$CACHE_DIR/$safe.lsremote"
  status="$CACHE_DIR/$safe.status"
  if [ -f "$status" ]; then
    printf '%s' "$f"
    [ "$(cat "$status" 2>/dev/null)" = "ok" ]
    return $?
  fi
  if _wtr_ls_remote_once "$remote" "$f"; then
    echo ok > "$status"
    printf '%s' "$f"
    return 0
  fi
  : > "$f"
  echo fail > "$status"
  printf '%s' "$f"
  return 1
}

# sha remoto REAL de <remote>/<branch>, ou vazio se a leitura de rede não mediu.
_wtr_remote_sha() {  # _wtr_remote_sha <remote> <branch>
  local remote="$1" branch="$2" f
  f="$(_wtr_remote_cache_file "$remote")" || return 1
  [ -s "$f" ] || return 1
  awk -v b="refs/heads/$branch" '$2==b{print $1; exit}' "$f"
}

wt=""
count=0
print_block() {
  local path="$1"
  [ -n "$path" ] || return 0
  [ -d "$path" ] || { echo "$path :: MISSING (path não existe mais no disco)"; echo; return 0; }

  local branch upstream ahead behind status staged dirty untracked last
  local remote_name remote_branch rsha measured
  branch="$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")"
  upstream="$(git -C "$path" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo "")"

  ahead=0; behind=0; measured="sem upstream"
  if [ -n "$upstream" ]; then
    remote_name="${upstream%%/*}"
    remote_branch="${upstream#*/}"
    rsha="$(_wtr_remote_sha "$remote_name" "$remote_branch" 2>/dev/null)"
    case "$rsha" in
      [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*)
        if git -C "$path" cat-file -e "${rsha}^{commit}" 2>/dev/null; then
          # Medido pelo REMOTO REAL, não pela réplica: fecha o LDG-0056.
          ahead="$(git -C "$path" rev-list --count "${rsha}..HEAD" 2>/dev/null || echo 0)"
          behind="$(git -C "$path" rev-list --count "HEAD..${rsha}" 2>/dev/null || echo 0)"
          measured="medido via ls-remote"
        else
          # sha remoto existe mas o objeto não está localmente (clone raso, sem fetch). A réplica
          # local é o único dado disponível — mas dizemos isso, nunca fingimos que é o remoto real.
          ahead="$(git -C "$path" rev-list --count "${upstream}..HEAD" 2>/dev/null || echo 0)"
          behind="$(git -C "$path" rev-list --count "HEAD..${upstream}" 2>/dev/null || echo 0)"
          measured="NÃO MEDIDO — commit remoto $(printf '%s' "$rsha" | cut -c1-7) desconhecido localmente; réplica local pode estar desatualizada (git fetch $remote_name)"
        fi
        ;;
      *)
        ahead="$(git -C "$path" rev-list --count "${upstream}..HEAD" 2>/dev/null || echo 0)"
        behind="$(git -C "$path" rev-list --count "HEAD..${upstream}" 2>/dev/null || echo 0)"
        measured="NÃO MEDIDO — ls-remote de '$remote_name' falhou ou expirou; réplica local pode estar desatualizada"
        ;;
    esac
  fi

  status="$(git -C "$path" status --porcelain 2>/dev/null || echo "")"
  staged="$(printf '%s\n' "$status" | grep -c '^[MADRC]' || true)"
  dirty="$(printf '%s\n' "$status" | grep -c '^.[MD]' || true)"
  untracked="$(printf '%s\n' "$status" | grep -c '^??' || true)"

  last="$(git -C "$path" log -1 --format='%h %ci %s' 2>/dev/null || echo "sem commits")"

  echo "$path"
  echo "  branch=$branch upstream=${upstream:-<none>} ahead=$ahead behind=$behind ($measured)"
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
