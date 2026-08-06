#!/usr/bin/env bash
# check-red-first.sh (hook) — Forge pre-push: bloqueia o push de uma faixa que contenha commit
# `fix(...)` quando algum change ATIVO type:bugfix não tiver evidência de Red resolvida
# (observed|waived). Chama SÓ o check ESTÁTICO já existente (.forge/scripts/check-red-first.sh
# check — Onda B, nunca roda teste algum, só lê evidence/red/*.json). O replay real (Onda C,
# lib/red-replay.mjs) é caro — worktree git + execução de teste — e NUNCA roda aqui: o pre-push
# tem que continuar rápido e viável. Replay é responsabilidade de `/forge:red replay` e do
# checkpoint de `/forge:verify` (spec-verify.sh). Sourced por pre-push (mesmo padrão de
# check-docs-reviewed.sh), também executável standalone para teste.
set -u

REPO="${REPO:-}"
[ -n "$REPO" ] || REPO="$(git rev-parse --show-toplevel 2>/dev/null)"
ZERO_SHA="0000000000000000000000000000000000000000"

_redfirst_resolve_base() {  # espelha _docs_resolve_base (check-docs-reviewed.sh)
  local local_sha="$1" remote_sha="$2" default_ref base
  if [ "$remote_sha" != "$ZERO_SHA" ]; then
    printf '%s\n' "$remote_sha"
    return 0
  fi
  default_ref="$(git -C "$REPO" symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null || true)"
  default_ref="${default_ref#refs/remotes/}"
  for candidate in "origin/develop" "$default_ref" "origin/main"; do
    [ -n "$candidate" ] || continue
    if base="$(git -C "$REPO" merge-base "$local_sha" "$candidate" 2>/dev/null)" && [ -n "$base" ]; then
      printf '%s\n' "$base"
      return 0
    fi
  done
  git -C "$REPO" rev-list --max-parents=0 "$local_sha" 2>/dev/null | tail -1
}

_redfirst_has_fix_commit() {  # _redfirst_has_fix_commit <base> <local_sha>
  local base="$1" local_sha="$2"
  git -C "$REPO" log --format=%s "$base..$local_sha" 2>/dev/null | grep -Eq '^fix(\([^)]*\))?!?:'
}

# Nota de escopo (auditoria Onda C, corrigida na Onda D item 5) — bloquear por QUALQUER change
# bugfix ativo pendente, independente de relação com o que está sendo empurrado, torna o
# bloqueio inegociável um convite ao --no-verify. O filtro por interseção de fix_files serve
# para ESCOLHER quais changes cobrar quando há vários — nunca para ISENTAR quem não declarou
# fix_files algum. A versão anterior invertia isso: `[ -f "$ev" ] || return 1` (sem evidência,
# pula) e `[ -n "$ff" ] || return 1` (sem fix_files declarados, pula) faziam exatamente o caso
# mais comum de brownfield — bugfix ativo criado, evidência ainda com fix_files:[] (o próprio
# scaffold de spec-new) — escapar do bloqueio inteiro, em vez de ser pego pelo item 1 do check
# estático ("ausência de evidência de Red num change type:bugfix" — a rule é explícita: quem NÃO
# declara nada não pode estar em posição melhor do que quem declara e não intersecta). Agora:
# ausência de evidência OU fix_files vazio/ausente ⇒ SEMPRE checa (não há como estabelecer
# não-relação); só um change com fix_files DECLARADOS e comprovadamente sem interseção é pulado.
_redfirst_touched_files() {  # _redfirst_touched_files <base> <local_sha> -> um path por linha
  git -C "$REPO" diff --name-only "$1" "$2" 2>/dev/null
}

_redfirst_should_check() {  # _redfirst_should_check <chdir> <touched-tmpfile> — 0 = checar, 1 = pular
  local chdir="$1" touched="$2" ev="$chdir/evidence/red/red-evidence.json" ff
  [ -f "$ev" ] || return 0
  ff="$(node -e "
    try {
      const d = JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));
      const arr = Array.isArray(d.fix_files) ? d.fix_files : [];
      for (const f of arr) process.stdout.write(f + '\n');
    } catch {}
  " "$ev" 2>/dev/null)"
  [ -n "$ff" ] || return 0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    grep -Fxq "$f" "$touched" 2>/dev/null && return 0
    grep -qF "$f/" "$touched" 2>/dev/null && return 0
  done <<< "$ff"
  return 1
}

check_red_first() {
  local line local_ref local_sha remote_ref remote_sha base failed=0
  local check_script="$REPO/.forge/scripts/check-red-first.sh"
  local active_dir="$REPO/.forge/specs/active"
  # harness sem red-first (versão antiga do template) ou sem changes ativos — no-op, não trava.
  [ -f "$check_script" ] || return 0
  [ -d "$active_dir" ] || return 0

  while IFS=' ' read -r local_ref local_sha remote_ref remote_sha; do
    [ -n "${local_ref:-}" ] || continue
    [ "${local_sha:-}" != "$ZERO_SHA" ] || continue

    base="$(_redfirst_resolve_base "$local_sha" "${remote_sha:-$ZERO_SHA}")"
    [ -n "$base" ] || continue
    _redfirst_has_fix_commit "$base" "$local_sha" || continue

    local touched_file
    touched_file="$(mktemp "${TMPDIR:-/tmp}/forge-redfirst-touched-XXXXXX")"
    _redfirst_touched_files "$base" "$local_sha" > "$touched_file"

    for chdir in "$active_dir"/*/; do
      [ -d "$chdir" ] || continue
      local chid manifest type out rc
      chid="$(basename "$chdir")"
      manifest="$chdir/manifest.yaml"
      [ -f "$manifest" ] || continue
      type="$(awk -F': ' '$1=="type"{print $2; exit}' "$manifest")"
      [ "$type" = "bugfix" ] || continue
      _redfirst_should_check "$chdir" "$touched_file" || continue

      out="$(FORGE_ROOT="$REPO" bash "$check_script" check "$chid" 2>&1)"; rc=$?
      if [ "$rc" -ne 0 ]; then
        {
          echo "pre-push BLOQUEADO: red-first pendente em '$chid' (commit fix(...) detectado em '$local_ref')."
          echo "$out" | sed 's/^/  /'
          echo "  grave a observação com /forge:red record + /forge:red replay, ou dispense com /forge:red waive --reason <motivo>."
        } >&2
        failed=1
      fi
    done
    rm -f "$touched_file"
  done

  [ "$failed" -eq 0 ]
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  check_red_first
  exit $?
fi
