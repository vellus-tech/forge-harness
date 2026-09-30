#!/usr/bin/env bash
# Gate W256 — issue #138: red-first sem caminho em change `type: feature` que corrige defeito.
# `manifest.yaml` ganha `fixes_defects` (lista de ids de defeito); `isDefectFixing(manifest)` =
# `type === 'bugfix' || fixes_defects não vazio` (lib/defect-scope.mjs) é a ÚNICA fonte da
# verdade, consumida pelos nove sítios que antes testavam só `type === 'bugfix'`:
# red-evidence-ops.mjs (requireDefectFixing ×1, cmdEnsure ×1), check-red-first.mjs
# (evaluateRedFirst, cmdStatus, cmdWaive), red-evidence.sh (ci, init), hooks/git/lib/
# check-red-first.sh (loop de pre-push) e spec-verify.sh.
#
#   [1] feature + fixes_defects:[D1] SEM evidência — check-red-first reprova NOMEANDO D1
#       (positiva — a issue original: escrita recusava, leitura respondia n/a rc 0)
#   [2] feature SEM fixes_defects — check-red-first segue n/a, rc 0 (contrafactual — o campo
#       ausente não muda o comportamento de antes da issue)
#   [3] feature + fixes_defects:[D1, D2] com UMA entrada resolvida (D1, via replay real) —
#       check-red-first reprova NOMEANDO só D2 (o faltante), não D1
#   [4] PROPRIEDADE — para o domínio gerado (type em {bugfix, feature, refactor, chore} ×
#       fixes_defects em {ausente, vazio, 1, 2, 3 ids} — 20 combinações, cobertura EXAUSTIVA do
#       espaço, mais forte que amostragem por seed nesse domínio finito e pequeno), a
#       aplicabilidade reportada pelos nove sítios é idêntica entre si e igual a `isDefectFixing`
#   [5] MUTAÇÃO (sandbox) — reverter um dos sítios (check-red-first.mjs, evaluateRedFirst) para
#       `man.type === 'bugfix'` direto faz [4] falhar nomeando o arquivo
set -euo pipefail
# Isolamento git (LDG-0201): GIT_DIR herdado do ambiente faria os comandos git abaixo obedecerem
# ao repositório de quem invocou o gate, e não ao repositório sintético criado aqui.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w256.XXXXXX)"
trap 'rm -rf "$T" "${T4:-}" "${MT:-}"' EXIT

mk_root() { # mk_root <dir>
  local dir="$1"
  cp -R "$WS/template/.forge" "$dir/.forge"
  git -C "$dir" init -q
  git -C "$dir" config user.email t@t; git -C "$dir" config user.name t; git -C "$dir" config commit.gpgsign false
  git -C "$dir" add -A && git -C "$dir" commit -qm init >/dev/null
}

mk_root "$T"
SN="$T/.forge/scripts/spec-new.sh"
RE="$T/.forge/scripts/red-evidence.sh"
CR="$T/.forge/scripts/check-red-first.sh"

echo "[1] feature + fixes_defects:[D1] sem evidência — check-red-first reprova nomeando D1"
FORGE_ROOT="$T" bash "$SN" feat-d1 --type feature --scale 1 >/dev/null
printf 'fixes_defects: [D1]\n' >> "$T/.forge/specs/active/feat-d1/manifest.yaml"
out="$(FORGE_ROOT="$T" bash "$CR" check feat-d1 2>&1)" && rc=0 || rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [1]: check deveria reprovar (rc=$rc, saída: '$out')"; exit 1; }
grep -q "D1" <<<"$out" || { echo "FAIL [1]: mensagem não nomeia D1 ($out)"; exit 1; }
grep -qi "fixes_defects" <<<"$out" || { echo "FAIL [1]: mensagem não cita fixes_defects ($out)"; exit 1; }
echo "OK [1]"

echo "[2] feature sem fixes_defects — check-red-first segue n/a, rc 0"
FORGE_ROOT="$T" bash "$SN" feat-nofix --type feature --scale 1 >/dev/null
out="$(FORGE_ROOT="$T" bash "$CR" check feat-nofix 2>&1)" && rc=0 || rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [2]: check deveria passar n/a (rc=$rc, saída: '$out')"; exit 1; }
grep -qi "(n/a" <<<"$out" || { echo "FAIL [2]: mensagem não cita n/a ($out)"; exit 1; }
echo "OK [2]"

echo "[3] feature + fixes_defects:[D1, D2], D1 resolvido por replay real — check-red-first reprova nomeando só D2"
FORGE_ROOT="$T" bash "$SN" feat-d1d2 --type feature --scale 1 >/dev/null
DIR3="$T/.forge/specs/active/feat-d1d2"
printf 'fixes_defects: [D1, D2]\n' >> "$DIR3/manifest.yaml"
FORGE_ROOT="$T" bash "$RE" init feat-d1d2 >/dev/null
mkdir -p "$T/tests3" "$T/src3"
cat > "$T/src3/d1.mjs" <<'JS'
export function sum(a, b) { return a - b; }
JS
git -C "$T" add src3/d1.mjs
git -C "$T" commit -qm "feat: d1 (com bug)" >/dev/null
cat > "$T/tests3/d1.test.mjs" <<'JS'
import test from 'node:test';
import assert from 'node:assert';
import { sum } from '../src3/d1.mjs';
test('d1-regression', () => { assert.strictEqual(sum(2, 3), 5); });
JS
git -C "$T" add tests3/d1.test.mjs
git -C "$T" commit -qm "test: regressão D1" >/dev/null
cat > "$T/src3/d1.mjs" <<'JS'
export function sum(a, b) { return a + b; }
JS
git -C "$T" add src3/d1.mjs
git -C "$T" commit -qm "fix: D1" >/dev/null
FORGE_ROOT="$T" bash "$RE" record feat-d1d2 --id D1 --test-path tests3/d1.test.mjs --test-id d1-regression \
  --command "node --test tests3/d1.test.mjs" --fix-files src3/d1.mjs --failure-pattern AssertionError >/dev/null
replay_out="$(FORGE_ROOT="$T" bash "$RE" replay feat-d1d2 --id D1 2>&1)" && replay_rc=0 || replay_rc=$?
[ "$replay_rc" -eq 0 ] || { echo "FAIL [3]: replay de D1 deveria observar Red de verdade (rc=$replay_rc, saída: '$replay_out')"; exit 1; }
grep -qi observado <<<"$replay_out" || { echo "FAIL [3]: replay não confirmou observado ($replay_out)"; exit 1; }
out="$(FORGE_ROOT="$T" bash "$CR" check feat-d1d2 2>&1)" && rc=0 || rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [3]: check deveria reprovar — D2 nunca foi declarado (rc=$rc, saída: '$out')"; exit 1; }
grep -q "D2" <<<"$out" || { echo "FAIL [3]: mensagem não nomeia D2 ($out)"; exit 1; }
missing_list="$(grep -oE 'para: [^)]*' <<<"$out" | head -1)"
if grep -q "D1" <<<"$missing_list"; then echo "FAIL [3]: D1 (já resolvido) aparece na lista de faltantes ($out)"; exit 1; fi
echo "OK [3]"

echo "[4] PROPRIEDADE — aplicabilidade idêntica entre os nove sítios e igual a isDefectFixing (cobertura exaustiva: 4 types x 5 formas de fixes_defects)"

# raiz ISOLADA e nova (T4, nunca T) — T já acumula feat-d1/feat-nofix/feat-d1d2 dos cenários
# [1]-[3]; reaproveitar T faria `red-evidence.sh ci` e o hook de pre-push examinarem TODOS esses
# changes de uma vez, contaminando os contadores "examinado(s)"/"sujeito(s) ao red-first" que os
# probes de F (ci) e H (hook) leem. T4 nasce só com o único change sintético `pbt-change`.
T4="$(mktemp -d /tmp/forge-w256-pbt.XXXXXX)"
mk_root "$T4"
RE4="$T4/.forge/scripts/red-evidence.sh"
CR4="$T4/.forge/scripts/check-red-first.sh"
LIB="$T4/.forge/scripts/lib"
HOOK="$T4/.forge/hooks/git/lib/check-red-first.sh"
SV="$T4/.forge/scripts/spec-verify.sh"
ACTIVE="$T4/.forge/specs/active/pbt-change"
mkdir -p "$ACTIVE"
MAN="$ACTIVE/manifest.yaml"
ZERO_SHA="0000000000000000000000000000000000000000"

gen_manifest() { # gen_manifest <type> <fixes_defects-line-or-empty>
  local type="$1" fd="$2"
  cat > "$MAN" <<EOF
id: pbt-change
type: $type
mode: brownfield
rigor: spec-first
scale: 1
status: implementing
created_at: "2026-09-29"
updated_at: "2026-09-29"
owner: "pbt"
gates:
  requirements_reviewed: true
  design_reviewed: true
  tasks_reviewed: true
  implementation_verified: true
  human_archive_approval: false
EOF
  if [ -n "$fd" ]; then printf '%s\n' "$fd" >> "$MAN"; fi
}

probe_oracle() {
  node --input-type=module -e "
    import { parseYamlSubset } from '$LIB/yaml-lite.mjs';
    import { isDefectFixing } from '$LIB/defect-scope.mjs';
    import { readFileSync } from 'node:fs';
    const man = parseYamlSubset(readFileSync(process.argv[1], 'utf8'));
    process.stdout.write(isDefectFixing(man) ? '1' : '0');
  " "$MAN"
}
probe_record() {
  local out; out="$(FORGE_ROOT="$T4" bash "$RE4" record pbt-change --test-path t --test-id t --command t --failure-pattern t 2>&1)" || true
  grep -q "só se aplica" <<<"$out" && echo 0 || echo 1
}
probe_ensure() {
  local out; out="$(FORGE_ROOT="$T4" bash "$RE4" ensure pbt-change 2>&1)" || true
  grep -q "(n/a" <<<"$out" && echo 0 || echo 1
}
probe_check() {
  local out; out="$(FORGE_ROOT="$T4" bash "$CR4" check pbt-change 2>&1)" || true
  grep -q "(n/a" <<<"$out" && echo 0 || echo 1
}
probe_status() {
  local out; out="$(FORGE_ROOT="$T4" bash "$RE4" status pbt-change 2>&1)" || true
  grep -q "(n/a" <<<"$out" && echo 0 || echo 1
}
probe_waive() {
  local out; out="$(FORGE_ROOT="$T4" bash "$RE4" waive pbt-change --reason non-behavioral 2>&1)" || true
  grep -q "só se aplica" <<<"$out" && echo 0 || echo 1
}
probe_ci() {
  local out n; out="$(FORGE_ROOT="$T4" bash "$RE4" ci 2>&1)" || true
  n="$(grep -oE '[0-9]+ sujeito\(s\) ao red-first' <<<"$out" | head -1 | grep -oE '^[0-9]+')"
  [ "$n" = "1" ] && echo 1 || echo 0
}
probe_init() { # MUTA — cria evidence.json quando aplicável; sempre chamado por último
  local out; out="$(FORGE_ROOT="$T4" bash "$RE4" init pbt-change 2>&1)" || true
  grep -q "só se aplica" <<<"$out" && echo 0 || echo 1
}
probe_hook() {
  # Raiz DESCARTÁVEL e nova a cada chamada (nunca T4 acumulado): 20 iterações reaproveitando o
  # mesmo T4 empilhavam um commit `fix(...)` por iteração no MESMO histórico git — resolução de
  # base (_redfirst_resolve_base -> git rev-list --max-parents=0, sem origin/develop|main) e a
  # varredura de `active_dir` passavam a depender de estado acumulado por chamadas ANTERIORES
  # (histórico cada vez maior, timestamps de commit no mesmo segundo), produzindo divergência
  # não-reprodutível fora de contexto (medido: a mesma combinação type/fixes_defects passava
  # isolada e falhava dentro do laço, variando qual combinação falhava entre execuções). Uma raiz
  # nova por chamada — só com o commit inicial e o commit fix(...) desta iteração — elimina a
  # variável de estado acumulado por completo.
  local fix_sha out n hroot
  hroot="$(mktemp -d /tmp/forge-w256-hook.XXXXXX)"
  mk_root "$hroot"
  mkdir -p "$hroot/.forge/specs/active/pbt-change"
  cp "$MAN" "$hroot/.forge/specs/active/pbt-change/manifest.yaml"
  git -C "$hroot" commit --allow-empty -qm "fix(pbt): iteration probe" >/dev/null
  fix_sha="$(git -C "$hroot" rev-parse HEAD)"
  # set +e no subshell — a mesma condição de invocação real: o hook roda via git (pre-push), sem
  # herdar o -e do harness que o dispara, só o `set -u` que ele mesmo declara. Herdar -e daqui
  # (deste gate) é um artefato de teste que não existe em produção — sob -e, `out="$(...)"; rc=$?`
  # dentro de check_red_first (linha "check_script check") aborta o subshell no meio do laço
  # sempre que o check estático reprova (rc≠0, o caso normal quando a evidência está ausente),
  # antes de chegar ao forge_universe_check que imprime "N change(s) ... examinado(s)".
  out="$(
    {
      cd "$hroot"
      set +e
      unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG
      export REPO="$hroot"
      # shellcheck disable=SC1090,SC1091
      . "$hroot/.forge/hooks/git/lib/check-red-first.sh"
      printf 'refs/heads/main %s refs/heads/main %s\n' "$fix_sha" "$ZERO_SHA" | check_red_first
    } 2>&1
  )" || true
  rm -rf "$hroot"
  n="$(grep -oE '[0-9]+ change\(s\) sujeito\(s\) ao red-first examinado' <<<"$out" | head -1 | grep -oE '^[0-9]+')"
  [ "$n" = "1" ] && echo 1 || echo 0
}
probe_specverify() {
  mkdir -p "$ACTIVE/evidence/red"
  cat > "$ACTIVE/evidence/red/red-evidence.json" <<'JSON'
{"schema":"red-evidence/v1","change_id":"pbt-change","status":"pending","entries":[],"test_path":null,"test_id":null,"command":null,"base_commit":null,"failure_pattern":null,"excerpt":null,"excerpt_sha256":null,"classification":null,"base_result":null,"base_strategy":null,"revert_patch":null,"replay_head":null,"setup_command":null,"reproduces":null,"fix_files":[],"waiver":null,"recorded_at":null,"replayed_at":null,"waived_at":null}
JSON
  local out; out="$(FORGE_ROOT="$T4" bash "$SV" pbt-change 2>&1)" || true
  rm -rf "$ACTIVE/evidence"
  grep -q "red-first ensure:" <<<"$out" && echo 1 || echo 0
}

TYPES=(bugfix feature refactor chore)
FD_VARIANTS=("" "fixes_defects: []" "fixes_defects: [D1]" "fixes_defects: [D1, D2]" "fixes_defects: [D1, D2, D3]")
pbt_failures=0
cases_run=0
for type in "${TYPES[@]}"; do
  for fd in "${FD_VARIANTS[@]}"; do
    cases_run=$((cases_run + 1))
    rm -rf "$ACTIVE/evidence"
    gen_manifest "$type" "$fd"
    oracle="$(probe_oracle)"
    a="$(probe_record)"
    b="$(probe_ensure)"
    c="$(probe_check)"
    d="$(probe_status)"
    e="$(probe_waive)"
    f="$(probe_ci)"
    h="$(probe_hook)"
    i="$(probe_specverify)"
    rm -rf "$ACTIVE/evidence"
    g="$(probe_init)"
    rm -rf "$ACTIVE/evidence"
    label="type=$type fixes_defects='$fd'"
    for pair in "red-evidence-ops.mjs(requireDefectFixing)=$a" "red-evidence-ops.mjs(cmdEnsure)=$b" \
      "check-red-first.mjs(evaluateRedFirst)=$c" "check-red-first.mjs(cmdStatus)=$d" \
      "check-red-first.mjs(cmdWaive)=$e" "red-evidence.sh(ci)=$f" "red-evidence.sh(init)=$g" \
      "hooks/check-red-first.sh=$h" "spec-verify.sh=$i"; do
      site="${pair%%=*}"; val="${pair##*=}"
      if [ "$val" != "$oracle" ]; then
        echo "FAIL [4]: $site divergiu de isDefectFixing ($label — oracle=$oracle, sítio=$val)"
        pbt_failures=$((pbt_failures + 1))
      fi
    done
  done
done
[ "$pbt_failures" -eq 0 ] || { echo "FAIL [4]: $pbt_failures divergência(s) entre os nove sítios e isDefectFixing em $cases_run casos"; exit 1; }
echo "OK [4] — $cases_run casos, nove sítios sempre de acordo com isDefectFixing"

echo "[5] MUTAÇÃO (sandbox) — reverter check-red-first.mjs (evaluateRedFirst) para type==='bugfix' direto faz [4] falhar nomeando o arquivo"
MT="$(mktemp -d /tmp/forge-w256-mut.XXXXXX)"
mk_root "$MT"
CRF_MJS="$MT/.forge/scripts/lib/check-red-first.mjs"
cp "$CRF_MJS" "$MT/pristine.mjs"
perl -0pi -e "s/if \(!isDefectFixing\(man\)\) \{\n(\s+)\/\/ item 3d/if (man.type !== 'bugfix') {\n\$1\/\/ item 3d/" "$CRF_MJS"
if cmp -s "$CRF_MJS" "$MT/pristine.mjs"; then echo "FAIL [5]: mutação não alterou o arquivo (perl não casou o padrão)"; rm -rf "$MT"; exit 1; fi

MSN="$MT/.forge/scripts/spec-new.sh"
MCR="$MT/.forge/scripts/check-red-first.sh"
FORGE_ROOT="$MT" bash "$MSN" feat-mut --type feature --scale 1 >/dev/null
printf 'fixes_defects: [D1]\n' >> "$MT/.forge/specs/active/feat-mut/manifest.yaml"
mut_out="$(FORGE_ROOT="$MT" bash "$MCR" check feat-mut 2>&1)" && mut_rc=0 || mut_rc=$?
# com a mutação, evaluateRedFirst volta a testar só type==='bugfix' — um change type:feature com
# fixes_defects declarado (isDefectFixing real = true) é tratado como n/a (rc 0), divergindo do
# oracle isDefectFixing, exatamente o que a propriedade do passo [4] existe para pegar.
if [ "$mut_rc" -eq 0 ] && grep -qi "(n/a" <<<"$mut_out"; then
  echo "OK [5-mut] — mutação faz check-red-first.mjs tratar feature+fixes_defects como n/a (diverge de isDefectFixing, como [4] previa)"
else
  echo "FAIL [5]: mutação deveria fazer o change divergir do oracle (n/a inesperado ausente) (rc=$mut_rc, saída: '$mut_out')"; rm -rf "$MT"; exit 1
fi

cp "$MT/pristine.mjs" "$CRF_MJS"
cmp -s "$CRF_MJS" "$MT/pristine.mjs" || { echo "FAIL [5]: restauração (sandbox) não bateu byte a byte"; rm -rf "$MT"; exit 1; }
restored_out="$(FORGE_ROOT="$MT" bash "$MCR" check feat-mut 2>&1)" && restored_rc=0 || restored_rc=$?
[ "$restored_rc" -ne 0 ] && grep -q "D1" <<<"$restored_out" || { echo "FAIL [5-recontrole]: com a lib restaurada, o check deveria voltar a reprovar nomeando D1 ($restored_out)"; rm -rf "$MT"; exit 1; }
echo "OK [5-recontrole] — lib restaurada, check volta a reprovar nomeando D1"
rm -rf "$MT"
echo "OK [5]"

echo "OK"
