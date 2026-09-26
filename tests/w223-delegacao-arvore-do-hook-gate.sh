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
#       bloqueia, nomeia o tronco (e nomeia também o heavy-mutex.sh, resolvido no mesmo push)
#   [5b] pre-push — HARNESS_SUITE com o run-all.sh REAL (não stub): worktree TEM
#       .forge/scripts/tests/ com um teste que falha e SEM run-all.sh próprio; tronco tem o
#       run-all.sh real (sem testes) → BLOQUEIA nomeando o teste da PRÓPRIA worktree. Prova que o
#       runner do tronco, quando emprestado, examina a árvore que empresta o hook (--path), nunca
#       a própria (LDG — achado do adendo de revisão do w223)
#   [5c] pre-push — HARNESS_SUITE contrafactual: worktree SEM .forge/scripts/tests/ (diretório
#       inteiro ausente — harness anterior à #73); tronco tem run-all.sh real com um teste que
#       falha → passa (rc 0), a suíte do tronco NUNCA examina o alheio quando o diretório não
#       existe na worktree
#   [6] pre-push — lint de shell (check-shell-pipeline.sh) ausente na worktree, presente no
#       tronco, com um .sh no diff do push → não bloqueia, nomeia o tronco
#   [7] pre-push — contrafactual: AI_CHECK ausente nas DUAS árvores → continua BLOQUEANDO
#   [8] lib/check-red-first.sh — os dois alvos internos (check-red-first.sh delegado,
#       gate-universe.sh) ausentes na árvore que executa e presentes na árvore de onde a lib foi
#       sourced (o tronco) → não bloqueia, nomeia o tronco nos dois
#   [9] AUTO-IRONIA: os 13 sítios (12 de L3 §0 + RUNTIME_LIB, achado do adendo de revisão)
#       chamam o mesmo resolvedor — contagem estrutural por arquivo, sem vacuidade, MAIS a
#       identidade byte a byte do corpo da função entre as 4 cópias (pre-commit, commit-msg,
#       post-merge, pre-push), porque a contagem de chamadas não pega uma correção aplicada só
#       numa cópia
#   [10] pre-push — RUNTIME_LIB (forge-runtime.sh) ausente na worktree, presente no tronco, com
#       runtime.gates declarado (forma CSV) e o gate existindo na worktree → não bloqueia, nomeia
#       o tronco, e o gate declarado roda de verdade (achado do adendo de revisão do w223)
#   [11] pre-push — a recusa de alvo ausente nas duas árvores nomeia AS DUAS árvores procuradas,
#       nunca afirma presença falsa de diretório que só existe numa delas (achado do adendo)
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
case "$out" in
  *"usando o do tronco"*"heavy-mutex.sh"*) : ;;
  *) echo "FAIL [5]: não nomeou o tronco para heavy-mutex.sh, resolvido no mesmo push (saída: '$out')"; exit 1 ;;
esac
echo "OK [5]"

# ── [5b] pre-push — HARNESS_SUITE com run-all.sh REAL: teste da PRÓPRIA worktree ────────────
echo "[5b] pre-push — run-all.sh real no tronco, teste que falha na PRÓPRIA worktree, sem runner"
R5B="$T/r5b"; TR5B="$T/tr5b"
mktrunk "$TR5B"
cp "$HOOKS/pre-push" "$TR5B/.forge/hooks/git/pre-push"; chmod +x "$TR5B/.forge/hooks/git/pre-push"
printf '#!/usr/bin/env bash\ncheck_docs_reviewed() { return 0; }\n' > "$TR5B/.forge/hooks/git/lib/check-docs-reviewed.sh"
printf '#!/usr/bin/env bash\ncheck_red_first() { return 0; }\n' > "$TR5B/.forge/hooks/git/lib/check-red-first.sh"
# run-all.sh REAL do template no tronco (não o stub `exit 0` de mktrunk) — sem teste algum no
# diretório do tronco, para que qualquer FALHA só possa vir do que a worktree publica.
cp "$WS/template/.forge/scripts/tests/run-all.sh" "$TR5B/.forge/scripts/tests/run-all.sh"; chmod +x "$TR5B/.forge/scripts/tests/run-all.sh"
mkrepo "$R5B" "$TR5B/.forge/hooks/git"
mkdir -p "$R5B/.forge/hooks/git/lib" "$R5B/.forge/scripts/tests"   # worktree TEM o diretório de testes
cp "$TR5B/.forge/hooks/git/lib/check-docs-reviewed.sh" "$R5B/.forge/hooks/git/lib/check-docs-reviewed.sh"
cp "$TR5B/.forge/hooks/git/lib/check-red-first.sh" "$R5B/.forge/hooks/git/lib/check-red-first.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R5B/.forge/scripts/check-ai-attribution.sh"; chmod +x "$R5B/.forge/scripts/check-ai-attribution.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R5B/.forge/scripts/check-liaison-acks.sh"; chmod +x "$R5B/.forge/scripts/check-liaison-acks.sh"
printf -- '---\nforge_version: 1\n---\n\n# FORGE\n\nruntime:\n  test:\n  typecheck:\n' > "$R5B/.forge/FORGE.md"
# ...mas SEM run-all.sh próprio, e com um teste que FALHA
printf '#!/usr/bin/env bash\nexit 1\n' > "$R5B/.forge/scripts/tests/meu-gate.test.sh"; chmod +x "$R5B/.forge/scripts/tests/meu-gate.test.sh"
SHA5B="$(git -C "$R5B" rev-parse HEAD)"
out="$(cd "$R5B" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA5B" "$ZERO" | bash "$TR5B/.forge/hooks/git/pre-push" origin "file://$R5B" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [5b]: pre-push passou com um teste falhando na própria worktree (saída: '$out')"; exit 1; }
case "$out" in
  *"meu-gate.test.sh"*) : ;;
  *) echo "FAIL [5b]: bloqueou sem nomear o teste da worktree que falhou (saída: '$out')"; exit 1 ;;
esac
echo "OK [5b]"

# ── [5c] pre-push — HARNESS_SUITE contrafactual: sem o diretório de testes na worktree ──────
echo "[5c] pre-push — worktree SEM .forge/scripts/tests/, tronco com teste que falha → rc 0"
R5C="$T/r5c"; TR5C="$T/tr5c"
mktrunk "$TR5C"
cp "$HOOKS/pre-push" "$TR5C/.forge/hooks/git/pre-push"; chmod +x "$TR5C/.forge/hooks/git/pre-push"
printf '#!/usr/bin/env bash\ncheck_docs_reviewed() { return 0; }\n' > "$TR5C/.forge/hooks/git/lib/check-docs-reviewed.sh"
printf '#!/usr/bin/env bash\ncheck_red_first() { return 0; }\n' > "$TR5C/.forge/hooks/git/lib/check-red-first.sh"
cp "$WS/template/.forge/scripts/tests/run-all.sh" "$TR5C/.forge/scripts/tests/run-all.sh"; chmod +x "$TR5C/.forge/scripts/tests/run-all.sh"
# teste que falha, mas é do TRONCO — causa alheia à worktree
printf '#!/usr/bin/env bash\nexit 1\n' > "$TR5C/.forge/scripts/tests/do-tronco.test.sh"; chmod +x "$TR5C/.forge/scripts/tests/do-tronco.test.sh"
mkrepo "$R5C" "$TR5C/.forge/hooks/git"
mkdir -p "$R5C/.forge/hooks/git/lib" "$R5C/.forge/scripts"   # SEM .forge/scripts/tests/ nenhum
cp "$TR5C/.forge/hooks/git/lib/check-docs-reviewed.sh" "$R5C/.forge/hooks/git/lib/check-docs-reviewed.sh"
cp "$TR5C/.forge/hooks/git/lib/check-red-first.sh" "$R5C/.forge/hooks/git/lib/check-red-first.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R5C/.forge/scripts/check-ai-attribution.sh"; chmod +x "$R5C/.forge/scripts/check-ai-attribution.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R5C/.forge/scripts/check-liaison-acks.sh"; chmod +x "$R5C/.forge/scripts/check-liaison-acks.sh"
printf -- '---\nforge_version: 1\n---\n\n# FORGE\n\nruntime:\n  test:\n  typecheck:\n' > "$R5C/.forge/FORGE.md"
SHA5C="$(git -C "$R5C" rev-parse HEAD)"
out="$(cd "$R5C" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA5C" "$ZERO" | bash "$TR5C/.forge/hooks/git/pre-push" origin "file://$R5C" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [5c]: pre-push bloqueou por um teste que só existe no tronco, sem diretório de testes na worktree (saída: '$out')"; exit 1; }
case "$out" in
  *"do-tronco.test.sh"*) echo "FAIL [5c]: a suíte do tronco rodou (nomeou 'do-tronco.test.sh') mesmo sem o diretório de testes na worktree (saída: '$out')"; exit 1 ;;
  *) : ;;
esac
echo "OK [5c]"

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
echo "[9] os 13 sítios (12 de L3 §0 + RUNTIME_LIB) chamam o mesmo resolvedor — contagem + corpo"
total=0
for par in "pre-commit:1" "commit-msg:1" "post-merge:2" "pre-push:7"; do
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
[ "$total" -eq 13 ] || { echo "FAIL [9]/vacuidade — total de sítios contados foi $total, esperado 13 (L3 §0: pre-push 7 [6 + RUNTIME_LIB], pre-commit 1, commit-msg 1, post-merge 2, check-red-first.sh 2)"; exit 1; }
echo "OK [9] — 13 sítios cobertos ($total)"

# Identidade byte a byte do CORPO da função entre as 4 cópias (pre-commit, commit-msg, post-merge,
# pre-push): a contagem acima só prova que cada arquivo CHAMA o resolvedor o número certo de vezes,
# nunca que as 4 definições continuam a MESMA função — uma correção aplicada numa cópia só (ex.:
# a mensagem "(procurado em ...)" do achado LOW do adendo) passaria verde no laço acima.
echo "[9b] as 4 cópias de resolve_delegated() têm o corpo byte a byte idêntico"
body_pc="$(awk '/^resolve_delegated\(\) \{/{f=1} f{print} f&&/^\}/{exit}' "$HOOKS/pre-commit")"
for h in commit-msg post-merge pre-push; do
  body_h="$(awk '/^resolve_delegated\(\) \{/{f=1} f{print} f&&/^\}/{exit}' "$HOOKS/$h")"
  [ "$body_pc" = "$body_h" ] || { echo "FAIL [9b]: resolve_delegated() em $h diverge de pre-commit — correção aplicada só numa cópia"; exit 1; }
done
echo "OK [9b] — 4 cópias idênticas"

# ── [10] pre-push — RUNTIME_LIB (forge-runtime.sh) via tronco ───────────────────────────────
echo "[10] pre-push — forge-runtime.sh ausente na worktree, presente no tronco, gates: declarado"
R10="$T/r10"; TR10="$T/tr10"
mktrunk "$TR10"
cp "$HOOKS/pre-push" "$TR10/.forge/hooks/git/pre-push"; chmod +x "$TR10/.forge/hooks/git/pre-push"
printf '#!/usr/bin/env bash\ncheck_docs_reviewed() { return 0; }\n' > "$TR10/.forge/hooks/git/lib/check-docs-reviewed.sh"
printf '#!/usr/bin/env bash\ncheck_red_first() { return 0; }\n' > "$TR10/.forge/hooks/git/lib/check-red-first.sh"
# forge-runtime.sh REAL do template no tronco — só ele existe, nunca na worktree.
cp "$WS/template/.forge/scripts/lib/forge-runtime.sh" "$TR10/.forge/scripts/lib/forge-runtime.sh"
mkrepo "$R10" "$TR10/.forge/hooks/git"
mkdir -p "$R10/.forge/hooks/git/lib" "$R10/.forge/scripts/lib"   # o diretório existe; o arquivo, não
cp "$TR10/.forge/hooks/git/lib/check-docs-reviewed.sh" "$R10/.forge/hooks/git/lib/check-docs-reviewed.sh"
cp "$TR10/.forge/hooks/git/lib/check-red-first.sh" "$R10/.forge/hooks/git/lib/check-red-first.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R10/.forge/scripts/check-ai-attribution.sh"; chmod +x "$R10/.forge/scripts/check-ai-attribution.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R10/.forge/scripts/check-liaison-acks.sh"; chmod +x "$R10/.forge/scripts/check-liaison-acks.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R10/.forge/scripts/meu-gate.sh"; chmod +x "$R10/.forge/scripts/meu-gate.sh"
printf -- '---\nforge_version: 1\n---\n\n# FORGE\n\nruntime:\n  test:\n  typecheck:\n  gates: meu-gate\n' > "$R10/.forge/FORGE.md"
SHA10="$(git -C "$R10" rev-parse HEAD)"
out="$(cd "$R10" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA10" "$ZERO" | bash "$TR10/.forge/hooks/git/pre-push" origin "file://$R10" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [10]: pre-push bloqueou com forge-runtime.sh presente no tronco (saída: '$out')"; exit 1; }
case "$out" in
  *"usando o do tronco"*"forge-runtime.sh"*) : ;;
  *) echo "FAIL [10]: não nomeou o tronco para forge-runtime.sh (saída: '$out')"; exit 1 ;;
esac
case "$out" in
  *"meu-gate OK"*) : ;;
  *) echo "FAIL [10]: o leitor emprestado do tronco não rodou o gate declarado (saída: '$out')"; exit 1 ;;
esac
echo "OK [10]"

# ── [11] pre-push — recusa nomeia AS DUAS árvores procuradas ────────────────────────────────
echo "[11] pre-push — alvo ausente nas duas árvores: a recusa nomeia onde procurou, nunca afirma"
echo "     presença falsa de diretório que só existe numa delas"
R11="$T/r11"; TR11="$T/tr11"
mkdir -p "$TR11/.forge/hooks/git/lib" "$TR11/.forge/scripts/lib" "$TR11/.forge/scripts/tests"
printf '#!/usr/bin/env bash\nforge_heavy_mutex_acquire() { return 0; }\nforge_heavy_mutex_arm_trap() { :; }\n' \
  > "$TR11/.forge/scripts/lib/heavy-mutex.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TR11/.forge/scripts/tests/run-all.sh"; chmod +x "$TR11/.forge/scripts/tests/run-all.sh"
cp "$HOOKS/pre-push" "$TR11/.forge/hooks/git/pre-push"; chmod +x "$TR11/.forge/hooks/git/pre-push"
# check-docs-reviewed.sh AUSENTE no tronco também — só o DIRETÓRIO hooks/git/lib existe lá.
mkrepo "$R11" "$TR11/.forge/hooks/git"
mkdir -p "$R11/.forge/scripts"   # worktree SEM .forge/hooks/git/lib nenhum (diretório não existe)
SHA11="$(git -C "$R11" rev-parse HEAD)"
out="$(cd "$R11" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA11" "$ZERO" | bash "$TR11/.forge/hooks/git/pre-push" origin "file://$R11" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [11]: pre-push passou com check-docs-reviewed.sh ausente nas duas árvores (saída: '$out')"; exit 1; }
case "$out" in
  *"alvo ausente"*) : ;;
  *) echo "FAIL [11]: bloqueou sem o texto literal de alvo ausente (saída: '$out')"; exit 1 ;;
esac
case "$out" in
  *"(procurado em $R11/.forge/hooks/git/lib"*"$TR11/.forge/hooks/git/lib"*")"*) : ;;
  *) echo "FAIL [11]: a recusa não nomeia as DUAS árvores procuradas, ou nomeia caminho errado (saída: '$out')"; exit 1 ;;
esac
[ ! -d "$R11/.forge/hooks/git/lib" ] || { echo "FAIL [11]/setup: o diretório da worktree não deveria existir neste cenário"; exit 1; }
echo "OK [11]"

echo "PASS w223-delegacao-arvore-do-hook"
