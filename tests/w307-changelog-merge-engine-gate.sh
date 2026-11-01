#!/usr/bin/env bash
# Gate W307 — paridade com o `tests/changelog-merge-gate.sh` antigo (TASK-14,
# add-unify-changelog-skill), agora contra o motor único `changelog-engine.mjs` em modo
# --merge-range. O arquivo antigo é removido na TASK-16 (tombstone); este é o substituto.
#   [1] no-op sem CHANGELOG.md raiz
#   [2] merge com feat/fix/chore → Adicionado(feat)+Corrigido(fix), em pt-BR; chore ignorado
#   [3] idempotência: re-rodar não duplica
#   [4] no-op quando HEAD não é merge
#   [5] refactor ignorado (DIV-02)
#   [6] revert ignorado (DIV-02)
#   [7] perf → Corrigido, nunca Alterado (DIV-01)
#   [8] no-op com release-please-config.json na raiz (REQ-10b)
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="$WS/template/.forge/skills/readme-generator/scripts/changelog-engine.mjs"
[ -f "$ENGINE" ]

mkbase() { # mkbase <dir> — repo git mínimo com CHANGELOG.md inicial
  mkdir -p "$1"
  (
    cd "$1"
    git init -q
    git config user.email "t@t"; git config user.name "t"
    git config commit.gpgsign false
    printf '# Changelog\n\nFormato Keep a Changelog.\n' > CHANGELOG.md
    git add -A; git commit -qm "docs: changelog inicial" >/dev/null
  )
}

# ── [1] ──────────────────────────────────────────────────────────────────────────────────────
echo "[1] no-op sem CHANGELOG.md raiz"
T1="$(mktemp -d /tmp/forge-w307-1.XXXXXX)"
(
  cd "$T1"
  git init -q
  git config user.email "t@t"; git config user.name "t"; git config commit.gpgsign false
  printf 'x\n' > a.txt; git add -A; git commit -qm "chore: base" >/dev/null
)
node "$ENGINE" --root "$T1" --merge-range >/dev/null 2>&1 || true
[ ! -f "$T1/CHANGELOG.md" ] || { echo "FAIL [1]: CHANGELOG.md criado indevidamente"; exit 1; }
rm -rf "$T1"
echo "OK [1]"

# ── [2] ──────────────────────────────────────────────────────────────────────────────────────
echo "[2] merge feat/fix/chore → Adicionado+Corrigido pt-BR; chore ignorado"
T2="$(mktemp -d /tmp/forge-w307-2.XXXXXX)"
mkbase "$T2"
(
  cd "$T2"
  git checkout -q -b feature/x
  echo "1" > f1.txt; git add -A; git commit -qm "feat(auth): adiciona login por OTP" >/dev/null
  echo "2" > f2.txt; git add -A; git commit -qm "fix(billing): corrige arredondamento de centavos" >/dev/null
  echo "3" > f3.txt; git add -A; git commit -qm "chore: bump deps" >/dev/null
  git checkout -q main 2>/dev/null || git checkout -q master
  git merge --no-ff --no-edit feature/x -q
)
node "$ENGINE" --root "$T2" --merge-range
grep -q '## \[Unreleased\]' "$T2/CHANGELOG.md"
grep -q '### Adicionado' "$T2/CHANGELOG.md" && grep -q 'login por OTP' "$T2/CHANGELOG.md" \
  || { echo "FAIL [2]: sem '### Adicionado' com 'login por OTP'"; exit 1; }
grep -q '### Corrigido' "$T2/CHANGELOG.md" && grep -q 'arredondamento de centavos' "$T2/CHANGELOG.md" \
  || { echo "FAIL [2]: sem '### Corrigido' com 'arredondamento de centavos'"; exit 1; }
! grep -q 'bump deps' "$T2/CHANGELOG.md" || { echo "FAIL [2]: chore gerou entrada"; exit 1; }
echo "OK [2]"

# ── [3] ──────────────────────────────────────────────────────────────────────────────────────
echo "[3] idempotência: re-rodar não duplica"
before="$(grep -c 'login por OTP' "$T2/CHANGELOG.md")"
node "$ENGINE" --root "$T2" --merge-range
after="$(grep -c 'login por OTP' "$T2/CHANGELOG.md")"
[ "$before" -eq 1 ] && [ "$after" -eq 1 ] \
  || { echo "FAIL [3]: contagem mudou entre execucoes (before=$before after=$after)"; exit 1; }
echo "OK [3]"

# ── [4] ──────────────────────────────────────────────────────────────────────────────────────
echo "[4] no-op quando HEAD não é merge"
snap="$(cat "$T2/CHANGELOG.md")"
(
  cd "$T2"
  echo "4" > f4.txt; git add -A; git commit -qm "feat: muda algo sem merge" >/dev/null
)
node "$ENGINE" --root "$T2" --merge-range
[ "$(cat "$T2/CHANGELOG.md")" = "$snap" ] || { echo "FAIL [4]: CHANGELOG.md mudou sem merge"; exit 1; }
rm -rf "$T2"
echo "OK [4]"

# ── [5] ──────────────────────────────────────────────────────────────────────────────────────
echo "[5] refactor ignorado (DIV-02)"
T5="$(mktemp -d /tmp/forge-w307-5.XXXXXX)"
mkbase "$T5"
(
  cd "$T5"
  git checkout -q -b feature/r
  echo "1" > f1.txt; git add -A; git commit -qm "refactor(core): reorganiza modulos" >/dev/null
  git checkout -q main 2>/dev/null || git checkout -q master
  git merge --no-ff --no-edit feature/r -q
)
node "$ENGINE" --root "$T5" --merge-range >/dev/null 2>&1 || true
! grep -q 'reorganiza modulos' "$T5/CHANGELOG.md" || { echo "FAIL [5]: refactor gerou entrada"; exit 1; }
rm -rf "$T5"
echo "OK [5]"

# ── [6] ──────────────────────────────────────────────────────────────────────────────────────
echo "[6] revert ignorado (DIV-02)"
T6="$(mktemp -d /tmp/forge-w307-6.XXXXXX)"
mkbase "$T6"
(
  cd "$T6"
  git checkout -q -b feature/v
  echo "1" > f1.txt; git add -A; git commit -qm 'revert: desfaz mudanca anterior' >/dev/null
  git checkout -q main 2>/dev/null || git checkout -q master
  git merge --no-ff --no-edit feature/v -q
)
node "$ENGINE" --root "$T6" --merge-range >/dev/null 2>&1 || true
! grep -q 'desfaz mudanca anterior' "$T6/CHANGELOG.md" || { echo "FAIL [6]: revert gerou entrada"; exit 1; }
rm -rf "$T6"
echo "OK [6]"

# ── [7] ──────────────────────────────────────────────────────────────────────────────────────
echo "[7] perf → Corrigido, nunca Alterado (DIV-01)"
T7="$(mktemp -d /tmp/forge-w307-7.XXXXXX)"
mkbase "$T7"
(
  cd "$T7"
  git checkout -q -b feature/p
  echo "1" > f1.txt; git add -A; git commit -qm "perf(api): reduz latencia de consulta" >/dev/null
  git checkout -q main 2>/dev/null || git checkout -q master
  git merge --no-ff --no-edit feature/p -q
)
node "$ENGINE" --root "$T7" --merge-range
grep -q '### Corrigido' "$T7/CHANGELOG.md" && grep -q 'reduz latencia de consulta' "$T7/CHANGELOG.md" \
  || { echo "FAIL [7]: perf não gerou entrada em ### Corrigido"; cat "$T7/CHANGELOG.md"; exit 1; }
! grep -q '### Alterado' "$T7/CHANGELOG.md" || { echo "FAIL [7]: perf gerou ### Alterado (proibido por DIV-01)"; exit 1; }
rm -rf "$T7"
echo "OK [7]"

# ── [8] ──────────────────────────────────────────────────────────────────────────────────────
echo "[8] no-op com release-please-config.json na raiz (REQ-10b)"
T8="$(mktemp -d /tmp/forge-w307-8.XXXXXX)"
mkbase "$T8"
printf '{}\n' > "$T8/release-please-config.json"
(
  cd "$T8"
  git add -A; git commit -qm "chore: release-please" >/dev/null
  git checkout -q -b feature/rp
  echo "1" > f1.txt; git add -A; git commit -qm "feat(x): algo novo" >/dev/null
  git checkout -q main 2>/dev/null || git checkout -q master
  git merge --no-ff --no-edit feature/rp -q
)
snap8="$(cat "$T8/CHANGELOG.md")"
out="$(node "$ENGINE" --root "$T8" --merge-range 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [8]: motor saiu rc=$rc com release-please presente (saida: $out)"; exit 1; }
[ "$(cat "$T8/CHANGELOG.md")" = "$snap8" ] || { echo "FAIL [8]: CHANGELOG.md alterado com release-please-config.json presente"; exit 1; }
rm -rf "$T8"
echo "OK [8]"

echo "PASS w307-changelog-merge-engine"
