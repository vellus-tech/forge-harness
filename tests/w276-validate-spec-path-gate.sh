#!/usr/bin/env bash
# Gate W276 — issue #189: `validate-spec.sh --path <dir>` sobre um change type:bugfix em
# `verified` executava `red-evidence.sh ensure <man.id>`, que resolve o change PELO ID em
# .forge/specs/active/ do repositório — não pelo diretório informado. Validar uma CÓPIA do change
# regravava, em silêncio (stdio ignorado, catch best-effort), o red-evidence.json do change REAL.
#   [a] validar a cópia deixa o red-evidence.json do change real byte a byte igual
#   [b] validar a cópia não grava nada fora da cópia (árvore do repositório, worktrees, status)
#   [c] a cópia é avaliada como está: evidência pending reprova (rc != 0) e a saída diz que o
#       replay não foi executado
#   [d] não regride: validar o change ATIVO (por id, por --path absoluto e por --path relativo)
#       continua executando o replay e gravando a evidência
set -euo pipefail
# Isolamento git (LDG-0201): GIT_DIR herdado faria os comandos abaixo obedecerem ao repositório
# de quem invocou o gate, e não ao repositório sintético criado aqui.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w276.XXXXXX)"
C="$(mktemp -d /tmp/forge-w276-copia.XXXXXX)"
trap 'rm -rf "$T" "$C"' EXIT

cp -R "$WS/template/.forge" "$T/.forge"
git -C "$T" init -q -b main
git -C "$T" config user.email t@t
git -C "$T" config user.name t
git -C "$T" config commit.gpgsign false
git -C "$T" add -A
git -C "$T" commit -qm "chore: init harness" >/dev/null

SN="$T/.forge/scripts/spec-new.sh"
RE="$T/.forge/scripts/red-evidence.sh"
VS="$T/.forge/scripts/validate-spec.sh"
field() { node -e "const v=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))[process.argv[2]];console.log(v===null?'null':v)" "$1" "$2"; }

# Defeito real com Red reproduzível (bug, teste, correção em commits separados): o `ensure`
# tem o que replayar e GRAVA quando roda — sem isso o gate não distinguiria "não rodou" de
# "rodou e não escreveu nada".
mkdir -p "$T/src" "$T/tests"
printf 'export function sum(a, b) { return a - b; }\n' > "$T/src/sum.mjs"
git -C "$T" add src/sum.mjs && git -C "$T" commit -qm "feat: sum (com bug)" >/dev/null
cat > "$T/tests/sum.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { sum } from '../src/sum.mjs';
test('bug-189-regression', () => { assert.strictEqual(sum(2, 3), 5); });
JS
git -C "$T" add tests/sum.test.mjs && git -C "$T" commit -qm "test: regressão bug-189" >/dev/null
printf 'export function sum(a, b) { return a + b; }\n' > "$T/src/sum.mjs"
git -C "$T" add src/sum.mjs && git -C "$T" commit -qm "fix: bug-189 — sum soma errado" >/dev/null

FORGE_ROOT="$T" bash "$SN" bug-189 --type bugfix --scale 1 >/dev/null
REAL="$T/.forge/specs/active/bug-189"
EV="$REAL/evidence/red/red-evidence.json"
out="$(FORGE_ROOT="$T" bash "$RE" record bug-189 --test-path tests/sum.test.mjs --test-id bug-189-regression --command "node --test tests/sum.test.mjs" --fix-files src/sum.mjs --failure-pattern AssertionError 2>&1)"
grep -q "OK record" <<<"$out" || { echo "FAIL: record não confirmou ($out)"; exit 1; }
[ "$(field "$EV" status)" = "pending" ] || { echo "FAIL: fixture — evidência do change real deveria estar pending"; exit 1; }
[ "$(field "$EV" replayed_at)" = "null" ] || { echo "FAIL: fixture — replayed_at deveria ser null antes de qualquer replay"; exit 1; }
git -C "$T" add -A && git -C "$T" commit -qm "chore: change bug-189 (tasks-ready, evidência pending)" >/dev/null
cp "$EV" "$C/red-evidence.before.json"

# Cópia do change em OUTRO diretório (fora do repositório), marcada verified — o cenário da issue.
mkdir -p "$C/copia"
cp -R "$REAL" "$C/copia/bug-189"
COPY="$C/copia/bug-189"
rm -f "$COPY/spec-delta.yaml"
printf 'verification:\n  commit: "abc1234"\n  checks: []\n' > "$COPY/verification.yaml"
perl -pi -e 's/^status: .*/status: verified/' "$COPY/manifest.yaml"

snapshot() {
  ( cd "$1" && find . -path ./.git -prune -o -type f -print | LC_ALL=C sort | xargs shasum -a 256 )
  git -C "$1" worktree list --porcelain | grep -c '^worktree ' || true
  git -C "$1" status --porcelain
  git -C "$1" rev-parse HEAD
}
snapshot "$T" > "$C/tree.before"

echo "[a] validate-spec --path <cópia verified> não toca o red-evidence.json do change real"
set +e
out="$(FORGE_ROOT="$T" bash "$VS" --path "$COPY" 2>&1)"; rc=$?
set -e
echo "  saída (rc=$rc): $out"
cmp -s "$C/red-evidence.before.json" "$EV" || {
  echo "FAIL [a]: o red-evidence.json do change REAL mudou ao validar a cópia (status: $(field "$EV" status), replayed_at: $(field "$EV" replayed_at))"
  diff "$C/red-evidence.before.json" "$EV" | head -20 || true
  exit 1
}
echo "OK [a]"

echo "[b] a validação da cópia não grava nada fora da cópia"
snapshot "$T" > "$C/tree.after"
cmp -s "$C/tree.before" "$C/tree.after" || { echo "FAIL [b]: a árvore do repositório mudou ao validar a cópia"; diff "$C/tree.before" "$C/tree.after" | head -20 || true; exit 1; }
echo "OK [b]"

echo "[c] a cópia é avaliada como está, com a recusa do replay dita na saída"
[ "$rc" -ne 0 ] || { echo "FAIL [c]: evidência pending numa cópia verified deveria reprovar ($out)"; exit 1; }
grep -q "^FAIL (" <<<"$out" || { echo "FAIL [c]: sem linha de veredito FAIL ($out)"; exit 1; }
grep -q "replay não executado" <<<"$out" || { echo "FAIL [c]: a saída não diz que o replay foi recusado para o --path fora do change ativo ($out)"; exit 1; }
[ "$(field "$COPY/evidence/red/red-evidence.json" status)" = "pending" ] || { echo "FAIL [c]: a evidência da cópia não deveria ter sido regravada"; exit 1; }
echo "OK [c]"

echo "[d] não regride: validar o change ATIVO continua executando o replay e gravando a evidência"
rm -f "$REAL/spec-delta.yaml"
printf 'verification:\n  commit: "abc1234"\n  checks: []\n' > "$REAL/verification.yaml"
perl -pi -e 's/^status: .*/status: verified/' "$REAL/manifest.yaml"
n=0
for how in id abs rel; do
  cp "$C/red-evidence.before.json" "$EV"
  set +e
  case "$how" in
    id)  out="$(FORGE_ROOT="$T" bash "$VS" bug-189 2>&1)"; rc=$? ;;
    abs) out="$(FORGE_ROOT="$T" bash "$VS" --path "$REAL" 2>&1)"; rc=$? ;;
    rel) out="$(cd "$T" && FORGE_ROOT="$T" bash "$VS" --path ./.forge/specs/active/bug-189 2>&1)"; rc=$? ;;
  esac
  set -e
  [ "$rc" -eq 0 ] || { echo "FAIL [d/$how]: validação do change ativo com Red real deveria aprovar ($out)"; exit 1; }
  [ "$(field "$EV" status)" = "observed" ] || { echo "FAIL [d/$how]: o replay não gravou observed no change ativo ($out)"; exit 1; }
  [ "$(field "$EV" replayed_at)" != "null" ] || { echo "FAIL [d/$how]: replayed_at não gravado"; exit 1; }
  grep -q "replay não executado" <<<"$out" && { echo "FAIL [d/$how]: aviso de recusa emitido para o change ativo ($out)"; exit 1; }
  echo "  OK [d/$how] — $out"
  n=$((n + 1))
done
[ "$n" -eq 3 ] || { echo "FAIL [d]: contador de controle — esperava 3 formas de invocação examinadas, examinou $n"; exit 1; }
echo "OK [d] — $n formas de invocação do change ativo gravaram evidência"

echo "W276 PASS"
