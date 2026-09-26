#!/usr/bin/env bash
# Gate W223 — issue #141: core.hooksPath absoluto para o tronco (#41/#54, LDG-0042) + delegação
# resolvida por $ROOT (a árvore que executa) faz um hook novo, vindo do tronco, encontrar
# scripts/libs antigos na worktree e bloquear por causa alheia.
#
# Desenho (L3 D14 reaproveitado): precedência de resolução do alvo delegado — primeiro a árvore
# que executa; se ausente lá e a árvore do hook (o tronco, quando hooksPath é absoluto) tiver o
# alvo, usa o do tronco com uma linha nomeando-o ("hook: <alvo> ausente em <worktree> — usando o
# do tronco (<caminho>); rode forge update na worktree"); bloqueio mantido quando falta nas duas.
#
#   [1] pre-commit — matriz exaustiva dos quatro estados (worktree x tronco, cada um com/sem):
#       [1a] sem na worktree, com no tronco  → passa e nomeia o tronco
#       [1b] sem nas duas                    → contrafactual: continua bloqueando
#       [1c] com nas duas (conteúdos diferentes) → usa o da PRÓPRIA árvore, nunca o do tronco
#       [1d] com só na worktree              → usa o próprio
#   [2] commit-msg — sem na worktree, com no tronco → passa e nomeia o tronco
#   [3] post-merge — os dois alvos (changelog-from-merge.mjs, check-liaison-log-integrity.sh)
#       ausentes na worktree e presentes no tronco → não FALHA, nomeia o tronco nos dois
#   [4] pre-push — DOCS_LIB, RED_LIB (require_hook_lib), AI_CHECK e ACKS ausentes na worktree e
#       presentes no tronco (stubs) → "pre-push OK", quatro linhas nomeando o tronco
#   [5] pre-push — HARNESS_SUITE (run-all.sh) ausente na worktree, presente no tronco → não
#       bloqueia, nomeia o tronco
#   [6] pre-push — lint de shell (check-shell-pipeline.sh) ausente na worktree, presente no
#       tronco, com um .sh no diff do push → não bloqueia, nomeia o tronco
#   [7] pre-push — contrafactual: AI_CHECK ausente nas DUAS árvores → continua BLOQUEANDO
#   [8] lib/check-red-first.sh — os dois alvos internos (check-red-first.sh delegado,
#       gate-universe.sh) ausentes na árvore que executa e presentes na árvore de onde a lib foi
#       sourced (o tronco) → não bloqueia, nomeia o tronco nos dois
#   [9] AUTO-IRONIA: os 12 sítios medidos em L3 §0 (pre-push 6, pre-commit 1, commit-msg 1,
#       post-merge 2, lib/check-red-first.sh 2) têm todos a mesma resolução — contagem estrutural
#       de chamadas ao resolvedor compartilhado, por arquivo, sem vacuidade
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS="$WS/template/.forge/hooks/git"

T="$(mktemp -d "${TMPDIR:-/tmp}/forge-w223.XXXXXX")"
trap 'rm -rf "$T"' EXIT
# Canônico (resolve symlinks, ex.: /var -> /private/var no macOS): `git rev-parse --show-toplevel`
# e `cd && pwd` dentro dos hooks devolvem o caminho REAL, e os casts abaixo comparam string.
T="$(cd "$T" && pwd -P)"

ZERO=0000000000000000000000000000000000000000

# mktrunk <dir> — .forge de "tronco": só o que cada cenário precisa, populado pelo chamador.
# heavy-mutex.sh sempre presente (stub): heavy_mutex fica desligado por padrão nestes cenários
# (sem forge.yaml com enabled:true), então só a PRESENÇA do alvo importa — evita que o Bloco
# HEAVY_LIB (issue #141, sítio 5/6) bloqueie cenários que não são sobre ele.
mktrunk() {
  mkdir -p "$1/.forge/hooks/git/lib" "$1/.forge/scripts/lib" "$1/.forge/scripts/tests"
  printf '#!/usr/bin/env bash\nforge_heavy_mutex_acquire() { return 0; }\nforge_heavy_mutex_arm_trap() { :; }\n' \
    > "$1/.forge/scripts/lib/heavy-mutex.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$1/.forge/scripts/tests/run-all.sh"
  chmod +x "$1/.forge/scripts/tests/run-all.sh"
}

# mkrepo <dir> <hooksPath-dir> — repositório git mínimo com hooksPath apontando para
# <hooksPath-dir> (o "tronco"); $ROOT deste repo é a "worktree" que executa o hook.
mkrepo() {
  local d="$1" hp="$2"
  mkdir -p "$d"
  git -C "$d" init -q -b main
  git -C "$d" config user.email t@t; git -C "$d" config user.name t; git -C "$d" config commit.gpgsign false
  git -C "$d" config core.hooksPath "$hp"
  printf 'x\n' > "$d/a.txt"
  git -C "$d" add -A >/dev/null 2>&1
  git -C "$d" commit -qm "chore: init" >/dev/null 2>&1
}

pass=0

# ── [1] pre-commit — matriz exaustiva ────────────────────────────────────────────────────────
echo "[1] pre-commit — matriz exaustiva dos quatro estados"

# [1a] sem na worktree, com no tronco
R1A="$T/r1a"; TR1A="$T/tr1a"
mktrunk "$TR1A"
cp "$HOOKS/pre-commit" "$TR1A/.forge/hooks/git/pre-commit"; chmod +x "$TR1A/.forge/hooks/git/pre-commit"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TR1A/.forge/scripts/check-secrets.sh"; chmod +x "$TR1A/.forge/scripts/check-secrets.sh"
mkrepo "$R1A" "$TR1A/.forge/hooks/git"
mkdir -p "$R1A/.forge/scripts"   # worktree TEM o diretório, mas SEM check-secrets.sh
printf 'y\n' > "$R1A/b.txt"; git -C "$R1A" add b.txt >/dev/null 2>&1
out="$(cd "$R1A" && git commit -q -m teste 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [1a]: pre-commit bloqueou com o alvo presente no tronco (saída: '$out')"; exit 1; }
case "$out" in
  *"usando o do tronco"*"$TR1A/.forge/scripts/check-secrets.sh"*) : ;;
  *) echo "FAIL [1a]: passou sem nomear o tronco (saída: '$out')"; exit 1 ;;
esac
echo "OK [1a]"

# [1b] sem nas duas — contrafactual
R1B="$T/r1b"; TR1B="$T/tr1b"
mktrunk "$TR1B"
cp "$HOOKS/pre-commit" "$TR1B/.forge/hooks/git/pre-commit"; chmod +x "$TR1B/.forge/hooks/git/pre-commit"
mkrepo "$R1B" "$TR1B/.forge/hooks/git"
mkdir -p "$R1B/.forge/scripts"
printf 'y\n' > "$R1B/b.txt"; git -C "$R1B" add b.txt >/dev/null 2>&1
out="$(cd "$R1B" && git commit -q -m teste 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [1b]: pre-commit passou com o alvo ausente nas duas árvores (saída: '$out')"; exit 1; }
case "$out" in
  *"check-secrets.sh"*"alvo ausente"*) : ;;
  *) echo "FAIL [1b]: bloqueou sem nomear o alvo ausente (saída: '$out')"; exit 1 ;;
esac
echo "OK [1b]"

# [1c] com nas duas, conteúdos diferentes — usa o da PRÓPRIA árvore
R1C="$T/r1c"; TR1C="$T/tr1c"
mktrunk "$TR1C"
cp "$HOOKS/pre-commit" "$TR1C/.forge/hooks/git/pre-commit"; chmod +x "$TR1C/.forge/hooks/git/pre-commit"
printf '#!/usr/bin/env bash\nexit 1\n' > "$TR1C/.forge/scripts/check-secrets.sh"; chmod +x "$TR1C/.forge/scripts/check-secrets.sh"
mkrepo "$R1C" "$TR1C/.forge/hooks/git"
mkdir -p "$R1C/.forge/scripts"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R1C/.forge/scripts/check-secrets.sh"; chmod +x "$R1C/.forge/scripts/check-secrets.sh"
printf 'y\n' > "$R1C/b.txt"; git -C "$R1C" add b.txt >/dev/null 2>&1
out="$(cd "$R1C" && git commit -q -m teste 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [1c]: pre-commit não usou a própria versão (sucesso esperado; saída: '$out')"; exit 1; }
case "$out" in
  *"usando o do tronco"*) echo "FAIL [1c]: usou o do tronco em vez do da própria árvore (saída: '$out')"; exit 1 ;;
  *) : ;;
esac
echo "OK [1c]"

# [1d] com só na worktree
R1D="$T/r1d"; TR1D="$T/tr1d"
mktrunk "$TR1D"
cp "$HOOKS/pre-commit" "$TR1D/.forge/hooks/git/pre-commit"; chmod +x "$TR1D/.forge/hooks/git/pre-commit"
mkrepo "$R1D" "$TR1D/.forge/hooks/git"
mkdir -p "$R1D/.forge/scripts"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R1D/.forge/scripts/check-secrets.sh"; chmod +x "$R1D/.forge/scripts/check-secrets.sh"
printf 'y\n' > "$R1D/b.txt"; git -C "$R1D" add b.txt >/dev/null 2>&1
out="$(cd "$R1D" && git commit -q -m teste 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [1d]: pre-commit bloqueou com o alvo presente na própria árvore (saída: '$out')"; exit 1; }
case "$out" in
  *"usando o do tronco"*) echo "FAIL [1d]: nomeou o tronco quando a própria árvore já tinha o alvo (saída: '$out')"; exit 1 ;;
  *) : ;;
esac
echo "OK [1d] — os quatro estados da matriz cobertos"

# ── [2] commit-msg ────────────────────────────────────────────────────────────────────────────
echo "[2] commit-msg — ausente na worktree, presente no tronco"
R2="$T/r2"; TR2="$T/tr2"
mktrunk "$TR2"
cp "$HOOKS/commit-msg" "$TR2/.forge/hooks/git/commit-msg"; chmod +x "$TR2/.forge/hooks/git/commit-msg"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TR2/.forge/scripts/check-ai-attribution.sh"; chmod +x "$TR2/.forge/scripts/check-ai-attribution.sh"
mkrepo "$R2" "$TR2/.forge/hooks/git"
mkdir -p "$R2/.forge/scripts"
printf 'chore: mensagem\n' > "$T/msg2.txt"
out="$(cd "$R2" && bash "$TR2/.forge/hooks/git/commit-msg" "$T/msg2.txt" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [2]: commit-msg bloqueou com o alvo presente no tronco (saída: '$out')"; exit 1; }
case "$out" in
  *"usando o do tronco"*"$TR2/.forge/scripts/check-ai-attribution.sh"*) : ;;
  *) echo "FAIL [2]: passou sem nomear o tronco (saída: '$out')"; exit 1 ;;
esac
echo "OK [2]"

# ── [3] post-merge — os dois alvos ───────────────────────────────────────────────────────────
echo "[3] post-merge — changelog-from-merge.mjs e check-liaison-log-integrity.sh via tronco"
R3="$T/r3"; TR3="$T/tr3"
mktrunk "$TR3"
cp "$HOOKS/post-merge" "$TR3/.forge/hooks/git/post-merge"; chmod +x "$TR3/.forge/hooks/git/post-merge"
printf 'process.exit(0);\n' > "$TR3/.forge/scripts/lib/changelog-from-merge.mjs"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TR3/.forge/scripts/check-liaison-log-integrity.sh"; chmod +x "$TR3/.forge/scripts/check-liaison-log-integrity.sh"
mkrepo "$R3" "$TR3/.forge/hooks/git"
mkdir -p "$R3/.forge/scripts/lib"
out="$(cd "$R3" && bash "$TR3/.forge/hooks/git/post-merge" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [3]: post-merge falhou com os alvos presentes no tronco (saída: '$out')"; exit 1; }
case "$out" in
  *"usando o do tronco"*"changelog-from-merge.mjs"*) : ;;
  *) echo "FAIL [3]: não nomeou o tronco para changelog-from-merge.mjs (saída: '$out')"; exit 1 ;;
esac
case "$out" in
  *"usando o do tronco"*"check-liaison-log-integrity.sh"*) : ;;
  *) echo "FAIL [3]: não nomeou o tronco para check-liaison-log-integrity.sh (saída: '$out')"; exit 1 ;;
esac
echo "OK [3]"

# ── [4] pre-push — DOCS_LIB, RED_LIB, AI_CHECK, ACKS ────────────────────────────────────────
echo "[4] pre-push — DOCS_LIB, RED_LIB, AI_CHECK, ACKS ausentes na worktree, presentes no tronco"
R4="$T/r4"; TR4="$T/tr4"
mktrunk "$TR4"
cp "$HOOKS/pre-push" "$TR4/.forge/hooks/git/pre-push"; chmod +x "$TR4/.forge/hooks/git/pre-push"
printf '#!/usr/bin/env bash\ncheck_docs_reviewed() { return 0; }\n' > "$TR4/.forge/hooks/git/lib/check-docs-reviewed.sh"
printf '#!/usr/bin/env bash\ncheck_red_first() { return 0; }\n' > "$TR4/.forge/hooks/git/lib/check-red-first.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TR4/.forge/scripts/check-ai-attribution.sh"; chmod +x "$TR4/.forge/scripts/check-ai-attribution.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TR4/.forge/scripts/check-liaison-acks.sh"; chmod +x "$TR4/.forge/scripts/check-liaison-acks.sh"
mkrepo "$R4" "$TR4/.forge/hooks/git"
mkdir -p "$R4/.forge/hooks/git/lib" "$R4/.forge/scripts"   # os diretórios existem; os 4 alvos, não
SHA4="$(git -C "$R4" rev-parse HEAD)"
out="$(cd "$R4" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA4" "$ZERO" | bash "$TR4/.forge/hooks/git/pre-push" origin "file://$R4" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [4]: pre-push bloqueou com os quatro alvos presentes no tronco (saída: '$out')"; exit 1; }
case "$out" in *"pre-push OK"*) : ;; *) echo "FAIL [4]: não terminou 'pre-push OK' (saída: '$out')"; exit 1 ;; esac
n_warn="$(grep -c "usando o do tronco" <<<"$out")"
[ "$n_warn" -eq 4 ] || { echo "FAIL [4]: esperava 4 linhas nomeando o tronco (DOCS_LIB, RED_LIB, AI_CHECK, ACKS), veio $n_warn (saída: '$out')"; exit 1; }
echo "OK [4] — 4 alvos resolvidos via tronco"

# ── [5] pre-push — HARNESS_SUITE ─────────────────────────────────────────────────────────────
echo "[5] pre-push — run-all.sh ausente na worktree, presente no tronco"
R5="$T/r5"; TR5="$T/tr5"
mktrunk "$TR5"
cp "$HOOKS/pre-push" "$TR5/.forge/hooks/git/pre-push"; chmod +x "$TR5/.forge/hooks/git/pre-push"
printf '#!/usr/bin/env bash\ncheck_docs_reviewed() { return 0; }\n' > "$TR5/.forge/hooks/git/lib/check-docs-reviewed.sh"
printf '#!/usr/bin/env bash\ncheck_red_first() { return 0; }\n' > "$TR5/.forge/hooks/git/lib/check-red-first.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TR5/.forge/scripts/tests/run-all.sh"
mkrepo "$R5" "$TR5/.forge/hooks/git"
mkdir -p "$R5/.forge/hooks/git/lib" "$R5/.forge/scripts/tests"
cp "$TR5/.forge/hooks/git/lib/check-docs-reviewed.sh" "$R5/.forge/hooks/git/lib/check-docs-reviewed.sh"
cp "$TR5/.forge/hooks/git/lib/check-red-first.sh" "$R5/.forge/hooks/git/lib/check-red-first.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R5/.forge/scripts/check-ai-attribution.sh"; chmod +x "$R5/.forge/scripts/check-ai-attribution.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R5/.forge/scripts/check-liaison-acks.sh"; chmod +x "$R5/.forge/scripts/check-liaison-acks.sh"
printf -- '---\nforge_version: 1\n---\n\n# FORGE\n\nruntime:\n  test:\n  typecheck:\n' > "$R5/.forge/FORGE.md"
SHA5="$(git -C "$R5" rev-parse HEAD)"
out="$(cd "$R5" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA5" "$ZERO" | bash "$TR5/.forge/hooks/git/pre-push" origin "file://$R5" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [5]: pre-push bloqueou com run-all.sh presente no tronco (saída: '$out')"; exit 1; }
case "$out" in
  *"usando o do tronco"*"run-all.sh"*) : ;;
  *) echo "FAIL [5]: não nomeou o tronco para run-all.sh (saída: '$out')"; exit 1 ;;
esac
echo "OK [5]"

# ── [6] pre-push — lint de shell, com .sh no diff ───────────────────────────────────────────
echo "[6] pre-push — check-shell-pipeline.sh ausente na worktree, presente no tronco, .sh no diff"
R6="$T/r6"; TR6="$T/tr6"
mktrunk "$TR6"
cp "$HOOKS/pre-push" "$TR6/.forge/hooks/git/pre-push"; chmod +x "$TR6/.forge/hooks/git/pre-push"
printf '#!/usr/bin/env bash\ncheck_docs_reviewed() { return 0; }\n' > "$TR6/.forge/hooks/git/lib/check-docs-reviewed.sh"
printf '#!/usr/bin/env bash\ncheck_red_first() { return 0; }\n' > "$TR6/.forge/hooks/git/lib/check-red-first.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TR6/.forge/scripts/check-shell-pipeline.sh"; chmod +x "$TR6/.forge/scripts/check-shell-pipeline.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TR6/.forge/scripts/check-heredoc-hash.sh"; chmod +x "$TR6/.forge/scripts/check-heredoc-hash.sh"
mkrepo "$R6" "$TR6/.forge/hooks/git"
mkdir -p "$R6/.forge/hooks/git/lib" "$R6/.forge/scripts"
cp "$TR6/.forge/hooks/git/lib/check-docs-reviewed.sh" "$R6/.forge/hooks/git/lib/check-docs-reviewed.sh"
cp "$TR6/.forge/hooks/git/lib/check-red-first.sh" "$R6/.forge/hooks/git/lib/check-red-first.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R6/.forge/scripts/check-ai-attribution.sh"; chmod +x "$R6/.forge/scripts/check-ai-attribution.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R6/.forge/scripts/check-liaison-acks.sh"; chmod +x "$R6/.forge/scripts/check-liaison-acks.sh"
printf -- '---\nforge_version: 1\n---\n\n# FORGE\n\nruntime:\n  test:\n  typecheck:\n' > "$R6/.forge/FORGE.md"
printf 'echo hi\n' > "$R6/tool.sh"; git -C "$R6" add tool.sh >/dev/null 2>&1
git -C "$R6" commit -qm "chore: add tool.sh" >/dev/null 2>&1
SHA6="$(git -C "$R6" rev-parse HEAD)"
out="$(cd "$R6" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA6" "$ZERO" | bash "$TR6/.forge/hooks/git/pre-push" origin "file://$R6" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [6]: pre-push bloqueou com os lints presentes no tronco (saída: '$out')"; exit 1; }
case "$out" in
  *"usando o do tronco"*"check-shell-pipeline.sh"*) : ;;
  *) echo "FAIL [6]: não nomeou o tronco para check-shell-pipeline.sh (saída: '$out')"; exit 1 ;;
esac
echo "OK [6]"

# ── [7] pre-push — contrafactual: ausente nas duas árvores ──────────────────────────────────
echo "[7] pre-push — AI_CHECK ausente nas duas árvores → continua bloqueando"
R7="$T/r7"; TR7="$T/tr7"
mktrunk "$TR7"
cp "$HOOKS/pre-push" "$TR7/.forge/hooks/git/pre-push"; chmod +x "$TR7/.forge/hooks/git/pre-push"
printf '#!/usr/bin/env bash\ncheck_docs_reviewed() { return 0; }\n' > "$TR7/.forge/hooks/git/lib/check-docs-reviewed.sh"
printf '#!/usr/bin/env bash\ncheck_red_first() { return 0; }\n' > "$TR7/.forge/hooks/git/lib/check-red-first.sh"
mkrepo "$R7" "$TR7/.forge/hooks/git"
mkdir -p "$R7/.forge/hooks/git/lib" "$R7/.forge/scripts"   # check-ai-attribution.sh ausente nas duas
SHA7="$(git -C "$R7" rev-parse HEAD)"
out="$(cd "$R7" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA7" "$ZERO" | bash "$TR7/.forge/hooks/git/pre-push" origin "file://$R7" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [7]: pre-push passou com o alvo ausente nas duas árvores (saída: '$out')"; exit 1; }
case "$out" in
  *"check-ai-attribution.sh"*"alvo ausente"*) : ;;
  *) echo "FAIL [7]: bloqueou sem nomear o alvo ausente (saída: '$out')"; exit 1 ;;
esac
echo "OK [7]"

# ── [8] lib/check-red-first.sh — os dois alvos internos ─────────────────────────────────────
echo "[8] lib/check-red-first.sh — check-red-first.sh delegado e gate-universe.sh via tronco"
R8="$T/r8"; TR8="$T/tr8"
mkdir -p "$TR8/.forge/scripts/lib"
cp "$HOOKS/lib/check-red-first.sh" "$TR8/.forge/hooks-lib-check-red-first.sh" 2>/dev/null || true
mkdir -p "$TR8/.forge/hooks/git/lib"
cp "$HOOKS/lib/check-red-first.sh" "$TR8/.forge/hooks/git/lib/check-red-first.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TR8/.forge/scripts/check-red-first.sh"; chmod +x "$TR8/.forge/scripts/check-red-first.sh"
cat > "$TR8/.forge/scripts/lib/gate-universe.sh" <<'EOF'
#!/usr/bin/env bash
EOF
mkdir -p "$R8/.forge/scripts" "$R8/.forge/scripts/lib"   # dirs existem; os dois alvos, não
out="$(REPO="$R8" bash -c '
  set -u
  . "'"$TR8"'/.forge/hooks/git/lib/check-red-first.sh"
  check_red_first < /dev/null
' 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [8]: check_red_first bloqueou com os dois alvos presentes no tronco (saída: '$out')"; exit 1; }
case "$out" in
  *"usando o do tronco"*"check-red-first.sh"*) : ;;
  *) echo "FAIL [8]: não nomeou o tronco para check-red-first.sh (saída: '$out')"; exit 1 ;;
esac
case "$out" in
  *"usando o do tronco"*"gate-universe.sh"*) : ;;
  *) echo "FAIL [8]: não nomeou o tronco para gate-universe.sh (saída: '$out')"; exit 1 ;;
esac
echo "OK [8]"

# ── [9] AUTO-IRONIA ──────────────────────────────────────────────────────────────────────────
# Sem `declare -A`: o bash 3.2 do macOS (issue de portabilidade irmã do w97) não tem array
# associativo. Pares "hook:esperado" numa lista simples, um por linha.
echo "[9] os 12 sítios (L3 §0) chamam o mesmo resolvedor — contagem estrutural por arquivo"
total=0
for par in "pre-commit:1" "commit-msg:1" "post-merge:2" "pre-push:6"; do
  h="${par%%:*}"; esperado="${par##*:}"
  # `\$\(resolve_delegated ` — só a INVOCAÇÃO real (substituição de comando), nunca a linha da
  # definição nem o comentário que a documenta (que também contém o nome da função de propósito).
  n="$(grep -cE '\$\(resolve_delegated ' "$HOOKS/$h" 2>/dev/null || true)"
  n="${n:-0}"
  total=$((total + n))
  [ "$n" -eq "$esperado" ] || { echo "FAIL [9]: $h — esperava $esperado chamada(s) a resolve_delegated, achei $n"; exit 1; }
done
n_rf="$(grep -cE '\$\(_redfirst_resolve_delegated ' "$HOOKS/lib/check-red-first.sh" 2>/dev/null || true)"
n_rf="${n_rf:-0}"
total=$((total + n_rf))
[ "$n_rf" -eq 2 ] || { echo "FAIL [9]: lib/check-red-first.sh — esperava 2 chamadas ao resolvedor interno, achei $n_rf"; exit 1; }
[ "$total" -eq 12 ] || { echo "FAIL [9]/vacuidade — total de sítios contados foi $total, esperado 12 (L3 §0: pre-push 6, pre-commit 1, commit-msg 1, post-merge 2, check-red-first.sh 2)"; exit 1; }
echo "OK [9] — 12 sítios cobertos ($total)"

echo "PASS w223-delegacao-arvore-do-hook"
