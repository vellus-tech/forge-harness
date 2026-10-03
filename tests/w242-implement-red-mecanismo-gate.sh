#!/usr/bin/env bash
# Gate W242 — o vermelho do TDD delegado é provado por EXECUÇÃO, não por leitura do diff (#156).
#
# POR QUE ESTE GATE EXISTE. Os três pontos de entrada que orientam TDD-first — `implement.md`
# (passo 2 do loop de execução), `task-coder.md` (`test_policy` do payload e validação local §3.5)
# e `coding-loop.md` (delegação onda a onda) — só diziam "TDD-first quando há lógica verificável".
# Medido na issue: duas de cinco tasks delegadas trouxeram cerca de 1.400 linhas de implementação
# num commit rotulado como "vermelho".
#
# DESENHO. O invariante verificável do TDD é: o teste do commit VERDE falha sobre a implementação
# do commit de vermelho, por asserção (não por compilação, símbolo ausente ou import quebrado), e
# passa sobre a implementação do verde. `red-evidence.sh task` prova isso rodando o teste em
# worktrees efêmeros: os arquivos de teste do verde são enxertados na árvore do vermelho, então o
# teste é fixo e o vermelho só pode diferir do verde na implementação. O vermelho não pode tocar
# infraestrutura (manifesto, lockfile, config de build/teste, scripts, arquivo citado pelo comando)
# e tem de ser o pai direto do verde, que é o HEAD da TASK. Vermelho e verde idênticos fora dos
# arquivos de teste reprovam antes de rodar o teste: o verde não implementa nada, e uma falha do
# vermelho só pode vir do ambiente (assunto do commit, arquivo gravado fora da worktree).
#
#   [1..3] implement.md, task-coder.md e coding-loop.md nomeiam o mecanismo: stub, falha de
#          asserção, commit de vermelho só com testes (stubs permitidos) e `red-evidence.sh task`;
#          nenhum deles ainda manda conferir o vermelho por `git show --stat`
#   [4]    espelhos do plugin byte-idênticos à fonte
#   [5]    §3.5 do task-coder chama `red-evidence.sh task` com --red/--green/--task-base/--task-id/
#          --command/--failure-pattern e NÃO contém classificação de diff (git show, awk, sed)
#   [6]    comportamental — o bloco bash do §3.5, extraído do arquivo, roda num repo git temporário:
#          A aceita o caminho legítimo (stub no vermelho, implementação no verde); reprova B verde
#          vazio, B2 vermelho que passa (o verde só mexe num comentário de produção), C compilação,
#          D stub que lança (falha não comportamental), E verde que falha, F ausência de vermelho,
#          G timeout, H/I TASK sem `Padrão de falha`/`Teste (comando)`, X1 implementação completa +
#          teste forjado no vermelho, X2 `assert.fail()` incondicional, X1V verde que só corrige o
#          teste, X3 implementação antes do vermelho, XE commit extra depois do verde, IS/IP vermelho
#          que altera setup ou package.json e o verde reverte, VV1/VV2 verde vazio com teste que lê
#          o assunto do commit ou grava arquivo fora da worktree, FX fixture forjada em fixtures/
#   [7]    mutação em cópias — motor (vermelho que passa aceito; build-error não distinguido; sem
#          enxerto; sem checagem de infra; sem checagem de topologia; sem checagem de verde vazio;
#          fixtures/ fora da convenção de teste) e fiação (falha do replay sem mark_failed; campo
#          ausente sem mark_failed); cada mutante é morto pelo caso que o cobre; controle antes,
#          recontrole depois, originais conferidos com cmp
#   [8]    tasks-writer e template de tasks do change emitem `Teste (comando)` e `Padrão de falha`
set -uo pipefail
# Isolamento git (LDG-0201): GIT_DIR herdado do ambiente faria os comandos git abaixo
# obedecerem ao repositório de quem invocou o gate, e não ao repositório sintético criado aqui.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMPL="$WS/template/.forge/commands/specs/implement.md"
CODER="$WS/template/.forge/agents/coding/task-coder.md"
LOOP="$WS/template/.forge/commands/coding/coding-loop.md"
PLUG_IMPL="$WS/plugin/forge/commands/implement.md"
PLUG_LOOP="$WS/plugin/forge/commands/coding-loop.md"
WRITER="$WS/template/.forge/agents/specifications/tasks-writer.md"
SPEC_TPL="$WS/template/.forge/templates/spec/tasks.md"
SCRIPTS="$WS/template/.forge/scripts"
ENGINE="$SCRIPTS/lib/red-replay.mjs"

for f in "$IMPL" "$CODER" "$LOOP" "$PLUG_IMPL" "$PLUG_LOOP" "$WRITER" "$SPEC_TPL" "$SCRIPTS/red-evidence.sh" "$ENGINE"; do
  [ -f "$f" ] || { echo "FAIL: arquivo ausente — $f"; exit 2; }
done
command -v node >/dev/null 2>&1 || { echo "FAIL: node ausente"; exit 2; }
command -v npm >/dev/null 2>&1 || { echo "FAIL: npm ausente (cenário IP roda 'npm test')"; exit 2; }

T="$(mktemp -d "${TMPDIR:-/tmp}/w242.XXXXXX")"
trap 'rm -rf "$T"' EXIT
cp "$ENGINE" "$T/engine.snapshot"
cp "$CODER" "$T/coder.snapshot"

overall_rc=0

# ── [1..3] mecanismo nomeado ──────────────────────────────────────────────────────────────────
check_mechanism() {
  local path="$1" label="$2" missing=""
  grep -qi 'stub' "$path" || missing="$missing stub"
  grep -qiE 'falha de asserç(ã|a)o|falha por asserç(ã|a)o' "$path" || missing="$missing falha-de-asserção"
  grep -qiE 'só testes|somente testes' "$path" || missing="$missing vermelho-só-testes"
  grep -q 'red-evidence.sh task' "$path" || missing="$missing red-evidence.sh-task"
  if grep -q 'show --stat' "$path"; then missing="$missing (ainda-manda-git-show---stat)"; fi
  if [ -n "$missing" ]; then
    echo "FAIL [$label]: $path — faltando ou indevido:$missing"
    return 1
  fi
  echo "OK [$label] — stub, falha de asserção, vermelho só com testes e red-evidence.sh task"
}

echo "[1] implement.md"
check_mechanism "$IMPL" "1-implement.md" || overall_rc=1
echo "[2] task-coder.md"
check_mechanism "$CODER" "2-task-coder.md" || overall_rc=1
echo "[3] coding-loop.md"
check_mechanism "$LOOP" "3-coding-loop.md" || overall_rc=1

echo "[4] espelhos do plugin idênticos à fonte"
if ! cmp -s "$IMPL" "$PLUG_IMPL"; then
  echo "FAIL [4]: plugin/forge/commands/implement.md dessincronizado — rode: npm run build:plugin"; overall_rc=1
elif ! cmp -s "$LOOP" "$PLUG_LOOP"; then
  echo "FAIL [4]: plugin/forge/commands/coding-loop.md dessincronizado — rode: npm run build:plugin"; overall_rc=1
else
  echo "OK [4] — espelhos byte-idênticos à fonte"
fi

# ── [5] §3.5 sem classificação de diff ────────────────────────────────────────────────────────
SEC="$T/sec35.md"
awk '/^#### 3\.5 /{on=1} /^#### 3\.6 /{on=0} on' "$CODER" > "$SEC"
SNIP="$T/snip35.sh"
awk '/^```bash/{if(!done){on=1; next}} /^```/{if(on){on=0; done=1}} on' "$SEC" > "$SNIP"
echo "[5] §3.5 chama o replay e não classifica diff"
if [ ! -s "$SEC" ] || [ ! -s "$SNIP" ]; then
  echo "FAIL [5]: §3.5 ou o seu bloco bash não encontrado em $CODER"; overall_rc=1
else
  bad=""
  for pat in 'git show' 'awk ' 'sed ' 'red_logica' 'red_linha_stub' 'RED_OK' 'RED_TESTE' 'RED_DECL'; do
    grep -qF "$pat" "$SNIP" && bad="$bad '$pat'"
  done
  miss=""
  for pat in 'red-evidence.sh task' '--red' '--green' '--task-base' '--task-id' '--command' '--failure-pattern' 'mark_failed'; do
    grep -qF -- "$pat" "$SNIP" || miss="$miss '$pat'"
  done
  if [ -n "$bad" ] || [ -n "$miss" ]; then
    echo "FAIL [5]: §3.5 —${bad:+ classificação de diff presente:$bad}${miss:+ ausente:$miss}"; overall_rc=1
  else
    echo "OK [5] — §3.5 chama red-evidence.sh task e não contém regex de diff"
  fi
fi

# ── [6] comportamental ────────────────────────────────────────────────────────────────────────
TEST_OK='import assert from "node:assert/strict";
import { soma } from "../src/soma.mjs";
assert.equal(soma(2, 3), 5);
console.log("ok soma");'
# X1: teste forjado — espera um valor errado, então falha por asserção mesmo com a implementação
TEST_FORJADO='import assert from "node:assert/strict";
import { soma } from "../src/soma.mjs";
assert.equal(soma(2, 3), 6);
console.log("ok soma");'
# X2: assert.fail() incondicional — falha por asserção com qualquer implementação
TEST_INCOND='import assert from "node:assert/strict";
import { soma } from "../src/soma.mjs";
assert.fail("vermelho forjado");
assert.equal(soma(2, 3), 5);'
SRC_STUB='export function soma(a, b) { return 0; }'
SRC_IMPL='export function soma(a, b) { return a + b; }'
# o verde que só mexe num comentário de produção — passa pela checagem de verde vazio
SRC_IMPL_COMENTADO='export function soma(a, b) { return a + b; } // revisado'
SRC_THROW='export function soma(a, b) { throw new Error("não implementado"); }'
SRC_WRONG='export function soma(a, b) { return a - b; }'
PKG_OK='{ "name": "w242", "private": true, "scripts": { "test": "node test/soma.test.mjs" } }'
PKG_SABOTADO="{ \"name\": \"w242\", \"private\": true, \"scripts\": { \"test\": \"node -e \\\"require('assert').strictEqual(1, 2)\\\"\" } }"
SETUP_OK='true'
# VV1: o teste lê o assunto do commit — falha no vermelho, passa no verde, sem depender do código
TEST_ASSUNTO='import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
const s = execFileSync("git", ["log", "-1", "--format=%s"], { encoding: "utf8" });
assert.ok(!s.includes("vermelho"), "assunto do commit: " + s);'
# VV2: o teste grava um marcador fora da worktree — a primeira execução (vermelho) falha, a segunda
# (verde) passa
VV2_MARK="$T/vv2-marcador"
TEST_MARCADOR="import assert from \"node:assert/strict\";
import { existsSync, writeFileSync } from \"node:fs\";
const m = \"$VV2_MARK\";
if (!existsSync(m)) { writeFileSync(m, \"x\"); assert.fail(\"primeira execução\"); }
console.log(\"ok marcador\");"
# FX: o teste lê a expectativa de fixtures/soma.json
TEST_FIXTURE='import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { soma } from "../src/soma.mjs";
const f = JSON.parse(readFileSync(new URL("../fixtures/soma.json", import.meta.url), "utf8"));
assert.equal(soma(f.a, f.b), f.esperado);'
FIX_OK='{ "a": 2, "b": 3, "esperado": 5 }'
FIX_FORJADA='{ "a": 2, "b": 3, "esperado": 6 }'
SETUP_SABOTADO="printf 'export function soma(a, b) { return 0; }\\n' > src/soma.mjs"

# new_repo <dir>: commit de base (README, .gitignore, package.json, scripts/setup-test.sh) com a tag
# task-base — o "início da TASK" (task-coder §3.3)
new_repo() {
  local r="$1"
  mkdir -p "$r/scripts"
  git -C "$r" init -q
  git -C "$r" config user.email gate@w242.local
  git -C "$r" config user.name w242
  git -C "$r" config commit.gpgsign false
  echo base > "$r/README"
  printf '.forge/\n' > "$r/.gitignore"
  printf '%s\n' "$PKG_OK" > "$r/package.json"
  printf '%s\n' "$SETUP_OK" > "$r/scripts/setup-test.sh"
  git -C "$r" add -A && git -C "$r" commit -qm "chore(base): base"
  git -C "$r" tag task-base
}
# put <repo> <path> <conteúdo>
put() { mkdir -p "$(dirname "$1/$2")"; printf '%s\n' "$3" > "$1/$2"; }
# cm <repo> <mensagem>
cm() { git -C "$1" add -A && git -C "$1" commit -q --allow-empty -m "$2"; }
RED_MSG="test(soma): TASK-01 — vermelho"
GREEN_MSG="feat(soma): TASK-01 — soma"

# run_snip <repo> <scripts> <snippet> [VAR=valor ...] -> saída combinada
run_snip() {
  local r="$1" scr="$2" snip="$3"; shift 3
  rm -rf "$r/.forge" && mkdir -p "$r/.forge" && cp -R "$scr" "$r/.forge/scripts"
  (
    cd "$r" || exit 9
    mark_failed() { echo "MARK_FAILED"; }
    DOMINANT_STACK=none TASK_ID=TASK-01 TEST_CMD='node test/soma.test.mjs' FAILURE_PATTERN=AssertionError SETUP_CMD=''
    TASK_BASE="$(git rev-parse --verify -q task-base)"
    for kv in "$@"; do export "${kv?}"; done
    # shellcheck disable=SC1090
    . "$snip"
  ) 2>&1
}

# expect <rótulo> <repo> <scripts> <snippet> <ok|token> [VAR=valor ...]
expect() {
  local label="$1" r="$2" scr="$3" snip="$4" want="$5" out; shift 5
  out="$(run_snip "$r" "$scr" "$snip" "$@")"
  if [ "$want" = ok ]; then
    if grep -q MARK_FAILED <<<"$out" || ! grep -q '^OK task' <<<"$out"; then
      echo "FAIL [$label]: esperado aceito; saída:"; printf '%s\n' "$out" | head -8 | sed 's/^/    /'; return 1
    fi
  else
    if ! grep -q MARK_FAILED <<<"$out" || ! grep -qF -- "$want" <<<"$out"; then
      echo "FAIL [$label]: esperado reprovado com '$want'; saída:"; printf '%s\n' "$out" | head -8 | sed 's/^/    /'; return 1
    fi
  fi
  echo "OK [$label] — $(printf '%s\n' "$out" | grep -E '^(OK|FAIL) task|encontrado|campo do plano' | head -1)"
}

echo "[6] comportamental — bloco bash do §3.5 num repo git temporário"
# A — caminho legítimo: stub no vermelho, implementação no verde
new_repo "$T/A"; put "$T/A" test/soma.test.mjs "$TEST_OK"; put "$T/A" src/soma.mjs "$SRC_STUB"; cm "$T/A" "$RED_MSG"
put "$T/A" src/soma.mjs "$SRC_IMPL"; cm "$T/A" "$GREEN_MSG"
# B — o vermelho já traz a implementação; o verde é vazio
new_repo "$T/B"; put "$T/B" test/soma.test.mjs "$TEST_OK"; put "$T/B" src/soma.mjs "$SRC_IMPL"; cm "$T/B" "$RED_MSG"; cm "$T/B" "$GREEN_MSG"
# B2 — o vermelho já traz a implementação; o verde só mexe num comentário de produção
new_repo "$T/B2"; put "$T/B2" test/soma.test.mjs "$TEST_OK"; put "$T/B2" src/soma.mjs "$SRC_IMPL"; cm "$T/B2" "$RED_MSG"
put "$T/B2" src/soma.mjs "$SRC_IMPL_COMENTADO"; cm "$T/B2" "$GREEN_MSG"
# C — vermelho sem o módulo: falha de import
new_repo "$T/C"; put "$T/C" test/soma.test.mjs "$TEST_OK"; cm "$T/C" "$RED_MSG"; put "$T/C" src/soma.mjs "$SRC_IMPL"; cm "$T/C" "$GREEN_MSG"
# D — stub que lança: falha por exceção, não por asserção
new_repo "$T/D"; put "$T/D" test/soma.test.mjs "$TEST_OK"; put "$T/D" src/soma.mjs "$SRC_THROW"; cm "$T/D" "$RED_MSG"
put "$T/D" src/soma.mjs "$SRC_IMPL"; cm "$T/D" "$GREEN_MSG"
# E — verde com implementação errada
new_repo "$T/E"; put "$T/E" test/soma.test.mjs "$TEST_OK"; put "$T/E" src/soma.mjs "$SRC_STUB"; cm "$T/E" "$RED_MSG"
put "$T/E" src/soma.mjs "$SRC_WRONG"; cm "$T/E" "$GREEN_MSG"
# F — sem commit de vermelho
new_repo "$T/F"; put "$T/F" test/soma.test.mjs "$TEST_OK"; put "$T/F" src/soma.mjs "$SRC_IMPL"; cm "$T/F" "$GREEN_MSG"
# X1 — implementação completa + teste forjado no vermelho; o verde corrige o teste e mexe num
# comentário de produção (para passar pela checagem de verde vazio)
new_repo "$T/X1"; put "$T/X1" test/soma.test.mjs "$TEST_FORJADO"; put "$T/X1" src/soma.mjs "$SRC_IMPL"; cm "$T/X1" "$RED_MSG"
put "$T/X1" test/soma.test.mjs "$TEST_OK"; put "$T/X1" src/soma.mjs "$SRC_IMPL_COMENTADO"; cm "$T/X1" "$GREEN_MSG"
# X1V — implementação completa + teste forjado no vermelho; o verde SÓ corrige o teste
new_repo "$T/X1V"; put "$T/X1V" test/soma.test.mjs "$TEST_FORJADO"; put "$T/X1V" src/soma.mjs "$SRC_IMPL"; cm "$T/X1V" "$RED_MSG"
put "$T/X1V" test/soma.test.mjs "$TEST_OK"; cm "$T/X1V" "$GREEN_MSG"
# X2 — assert.fail() incondicional no vermelho; o verde remove a linha e mexe num comentário
new_repo "$T/X2"; put "$T/X2" test/soma.test.mjs "$TEST_INCOND"; put "$T/X2" src/soma.mjs "$SRC_IMPL"; cm "$T/X2" "$RED_MSG"
put "$T/X2" test/soma.test.mjs "$TEST_OK"; put "$T/X2" src/soma.mjs "$SRC_IMPL_COMENTADO"; cm "$T/X2" "$GREEN_MSG"
# VV1 — verde vazio (git commit --allow-empty); o teste lê o assunto do commit
new_repo "$T/VV1"; put "$T/VV1" test/assunto.test.mjs "$TEST_ASSUNTO"; cm "$T/VV1" "$RED_MSG"; cm "$T/VV1" "$GREEN_MSG"
# VV2 — verde vazio; o teste grava um marcador fora da worktree
new_repo "$T/VV2"; put "$T/VV2" test/marcador.test.mjs "$TEST_MARCADOR"; cm "$T/VV2" "$RED_MSG"; cm "$T/VV2" "$GREEN_MSG"
# FX — implementação completa + fixture forjada no vermelho; o verde corrige a fixture e mexe num
# comentário de produção
new_repo "$T/FX"; put "$T/FX" test/soma.test.mjs "$TEST_FIXTURE"; put "$T/FX" fixtures/soma.json "$FIX_FORJADA"; put "$T/FX" src/soma.mjs "$SRC_IMPL"
cm "$T/FX" "$RED_MSG"; put "$T/FX" fixtures/soma.json "$FIX_OK"; put "$T/FX" src/soma.mjs "$SRC_IMPL_COMENTADO"; cm "$T/FX" "$GREEN_MSG"
# X3 — implementação num commit antes do "vermelho", teste forjado no vermelho, verde corrige o teste
new_repo "$T/X3"; put "$T/X3" src/soma.mjs "$SRC_IMPL"; cm "$T/X3" "feat(soma): TASK-01 — antecipada"
put "$T/X3" test/soma.test.mjs "$TEST_FORJADO"; cm "$T/X3" "$RED_MSG"; put "$T/X3" test/soma.test.mjs "$TEST_OK"; cm "$T/X3" "$GREEN_MSG"
# XE — commit extra depois do verde (o HEAD da TASK não é o commit de implementação)
new_repo "$T/XE"; put "$T/XE" test/soma.test.mjs "$TEST_OK"; put "$T/XE" src/soma.mjs "$SRC_STUB"; cm "$T/XE" "$RED_MSG"
put "$T/XE" src/soma.mjs "$SRC_IMPL"; cm "$T/XE" "$GREEN_MSG"; put "$T/XE" README "extra"; cm "$T/XE" "fix(soma): TASK-01 — ajuste depois do verde"
# IS — o vermelho traz a implementação e sabota o script de setup; o verde reverte o setup
new_repo "$T/IS"; put "$T/IS" test/soma.test.mjs "$TEST_OK"; put "$T/IS" src/soma.mjs "$SRC_IMPL"; put "$T/IS" scripts/setup-test.sh "$SETUP_SABOTADO"
cm "$T/IS" "$RED_MSG"; put "$T/IS" scripts/setup-test.sh "$SETUP_OK"; cm "$T/IS" "$GREEN_MSG"
# IP — o vermelho traz a implementação e troca o script de teste do package.json; o verde reverte
new_repo "$T/IP"; put "$T/IP" test/soma.test.mjs "$TEST_OK"; put "$T/IP" src/soma.mjs "$SRC_IMPL"; put "$T/IP" package.json "$PKG_SABOTADO"
cm "$T/IP" "$RED_MSG"; put "$T/IP" package.json "$PKG_OK"; cm "$T/IP" "$GREEN_MSG"

if [ -s "$SNIP" ]; then
  expect 6A  "$T/A"  "$SCRIPTS" "$SNIP" ok                                         || overall_rc=1
  expect 6B  "$T/B"  "$SCRIPTS" "$SNIP" '[vermelho-vazio]'                         || overall_rc=1
  expect 6B2 "$T/B2" "$SCRIPTS" "$SNIP" '[vermelho-passa]'                         || overall_rc=1
  expect 6C  "$T/C"  "$SCRIPTS" "$SNIP" '[vermelho-compilacao]'                    || overall_rc=1
  expect 6D  "$T/D"  "$SCRIPTS" "$SNIP" '[vermelho-padrao]'                        || overall_rc=1
  expect 6E  "$T/E"  "$SCRIPTS" "$SNIP" '[verde-falha]'                            || overall_rc=1
  expect 6F  "$T/F"  "$SCRIPTS" "$SNIP" '0 encontrado(s)'                          || overall_rc=1
  expect 6H  "$T/A"  "$SCRIPTS" "$SNIP" 'campo do plano ausente — Padrão de falha' FAILURE_PATTERN= || overall_rc=1
  expect 6I  "$T/A"  "$SCRIPTS" "$SNIP" 'campo do plano ausente — Teste (comando)' TEST_CMD=        || overall_rc=1
  expect 6X1 "$T/X1" "$SCRIPTS" "$SNIP" '[vermelho-passa]'                         || overall_rc=1
  expect 6X2 "$T/X2" "$SCRIPTS" "$SNIP" '[vermelho-passa]'                         || overall_rc=1
  expect 6X1V "$T/X1V" "$SCRIPTS" "$SNIP" '[vermelho-vazio]'                       || overall_rc=1
  expect 6VV1 "$T/VV1" "$SCRIPTS" "$SNIP" '[vermelho-vazio]' 'TEST_CMD=node test/assunto.test.mjs' || overall_rc=1
  rm -f "$VV2_MARK"
  expect 6VV2 "$T/VV2" "$SCRIPTS" "$SNIP" '[vermelho-vazio]' 'TEST_CMD=node test/marcador.test.mjs' || overall_rc=1
  expect 6FX "$T/FX" "$SCRIPTS" "$SNIP" '[vermelho-passa]'                         || overall_rc=1
  expect 6X3 "$T/X3" "$SCRIPTS" "$SNIP" '[topologia]'                              || overall_rc=1
  expect 6XE "$T/XE" "$SCRIPTS" "$SNIP" '[topologia]'                              || overall_rc=1
  expect 6IS "$T/IS" "$SCRIPTS" "$SNIP" '[vermelho-infra]' 'SETUP_CMD=bash scripts/setup-test.sh' || overall_rc=1
  expect 6IP "$T/IP" "$SCRIPTS" "$SNIP" '[vermelho-infra]' 'TEST_CMD=npm test --silent'          || overall_rc=1
else
  echo "FAIL [6]: sem bloco bash no §3.5 para executar"; overall_rc=1
fi
echo "[6G] timeout explícito reprova"
RED_A="$(git -C "$T/A" rev-parse HEAD~1)"
out="$(cd "$T/A" && bash "$SCRIPTS/red-evidence.sh" task --red "$RED_A" --green HEAD \
  --command 'sleep 10' --failure-pattern AssertionError --timeout 1 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && grep -qF '[vermelho-timeout]' <<<"$out"; then
  echo "OK [6G] — rc=$rc, $(printf '%s\n' "$out" | head -1)"
else
  echo "FAIL [6G]: esperado rc≠0 com [vermelho-timeout]; rc=$rc saída: $(printf '%s' "$out" | head -3)"; overall_rc=1
fi

# ── [7] mutação em cópias ─────────────────────────────────────────────────────────────────────
echo "[7] mutação — motor e fiação, em cópias"
# mut_engine <tag> <perl> <caso> <repo> <token-que-deve-sumir> [VAR=valor ...]
mut_engine() {
  local tag="$1" expr="$2" caso="$3" r="$4" tok="$5" m="$T/mut-$1"; shift 5
  rm -rf "$m" && cp -R "$SCRIPTS" "$m"
  perl -pi -e "$expr" "$m/lib/red-replay.mjs"
  if cmp -s "$m/lib/red-replay.mjs" "$ENGINE"; then
    echo "FAIL [7-$tag]: a mutação não alterou o motor — o ponto de mutação mudou de forma"; return 1
  fi
  if expect "$caso-mut" "$r" "$m" "$SNIP" "$tok" "$@" >/dev/null 2>&1; then
    echo "FAIL [7-$tag]: mutante sobrevivente — $caso ainda reprova com $tok"; return 1
  fi
  echo "OK [7-$tag] — mutante morto: $caso deixa de reprovar com $tok"
}
# mut_snip <tag> <perl> <caso> <repo> <token-que-deve-sumir> [VAR=valor ...]
mut_snip() {
  local tag="$1" expr="$2" caso="$3" r="$4" tok="$5" m="$T/snip-mut-$1.sh"; shift 5
  perl -pe "$expr" "$SNIP" > "$m"
  if cmp -s "$SNIP" "$m"; then
    echo "FAIL [7-$tag]: a mutação não alterou o snippet — o ponto de mutação mudou de forma"; return 1
  fi
  if expect "$caso-mut" "$r" "$SCRIPTS" "$m" "$tok" "$@" >/dev/null 2>&1; then
    echo "FAIL [7-$tag]: mutante sobrevivente — $caso ainda marca falha com $tok"; return 1
  fi
  echo "OK [7-$tag] — mutante morto: $caso deixa de marcar a task como falha"
}
if [ -s "$SNIP" ]; then
  # controle: os casos que as mutações miram reprovam com o motor e o snippet originais
  ctrl_ok=1
  expect 7-controle-B2 "$T/B2" "$SCRIPTS" "$SNIP" '[vermelho-passa]' >/dev/null || ctrl_ok=0
  expect 7-controle-VV1 "$T/VV1" "$SCRIPTS" "$SNIP" '[vermelho-vazio]' 'TEST_CMD=node test/assunto.test.mjs' >/dev/null || ctrl_ok=0
  expect 7-controle-FX "$T/FX" "$SCRIPTS" "$SNIP" '[vermelho-passa]' >/dev/null || ctrl_ok=0
  expect 7-controle-X1 "$T/X1" "$SCRIPTS" "$SNIP" '[vermelho-passa]' >/dev/null || ctrl_ok=0
  expect 7-controle-IS "$T/IS" "$SCRIPTS" "$SNIP" '[vermelho-infra]' 'SETUP_CMD=bash scripts/setup-test.sh' >/dev/null || ctrl_ok=0
  expect 7-controle-XE "$T/XE" "$SCRIPTS" "$SNIP" '[topologia]' >/dev/null || ctrl_ok=0
  if [ "$ctrl_ok" = 1 ]; then echo "OK [7-controle] — B2, VV1, FX, X1, IS e XE reprovam com o original"
  else echo "FAIL [7-controle]: algum caso-alvo não reprova com o original"; overall_rc=1; fi
  mut_engine passa   's/if \(redRun\.exitCode === 0\)/if (false)/' 6B2 "$T/B2" '[vermelho-passa]' || overall_rc=1
  mut_engine build   "s/if \\(redClass === 'build-error'\\)/if (false)/" 6C "$T/C" '[vermelho-compilacao]' || overall_rc=1
  mut_engine enxerto 's/graftTaskTests\(root, dir, redSha, graftFrom\)/[]/' 6X1 "$T/X1" '[vermelho-passa]' || overall_rc=1
  mut_engine infra   's/if \(infraTouched\.length\)/if (false)/' 6IS "$T/IS" '[vermelho-infra]' 'SETUP_CMD=bash scripts/setup-test.sh' || overall_rc=1
  mut_engine topo    's/if \(parents\.length !== 1 \|\| parents\[0\] !== redSha\)/if (false)/' 6XE "$T/XE" '[topologia]' || overall_rc=1
  mut_engine vazio   's/if \(!implChanged\.length\)/if (false)/' 6VV1 "$T/VV1" '[vermelho-vazio]' 'TEST_CMD=node test/assunto.test.mjs' || overall_rc=1
  mut_engine fixtures "s/'fixtures', //" 6FX "$T/FX" '[vermelho-passa]' || overall_rc=1
  mut_snip fiacao 's/(reprovado pelo replay[^"]*"); mark_failed/$1; :/' 6B2 "$T/B2" '[vermelho-passa]' || overall_rc=1
  mut_snip campos 's/(campo do plano ausente[^"]*"); mark_failed/$1; :/' 6I "$T/A" 'campo do plano ausente — Teste (comando)' TEST_CMD= || overall_rc=1
  # recontrole: originais intocados (cmp) e os casos voltam a reprovar com o original
  if cmp -s "$ENGINE" "$T/engine.snapshot" && cmp -s "$CODER" "$T/coder.snapshot"; then
    echo "OK [7-cmp] — red-replay.mjs e task-coder.md byte-idênticos ao início do gate"
  else
    echo "FAIL [7-cmp]: um original foi alterado durante as mutações"; overall_rc=1
  fi
  rctrl_ok=1
  expect 7-recontrole-B2 "$T/B2" "$SCRIPTS" "$SNIP" '[vermelho-passa]' >/dev/null || rctrl_ok=0
  expect 7-recontrole-VV1 "$T/VV1" "$SCRIPTS" "$SNIP" '[vermelho-vazio]' 'TEST_CMD=node test/assunto.test.mjs' >/dev/null || rctrl_ok=0
  expect 7-recontrole-X1 "$T/X1" "$SCRIPTS" "$SNIP" '[vermelho-passa]' >/dev/null || rctrl_ok=0
  expect 7-recontrole-A  "$T/A"  "$SCRIPTS" "$SNIP" ok >/dev/null || rctrl_ok=0
  if [ "$rctrl_ok" = 1 ]; then echo "OK [7-recontrole] — B2, VV1 e X1 voltam a reprovar e A volta a ser aceito"
  else echo "FAIL [7-recontrole]: o original não se comporta como antes das mutações"; overall_rc=1; fi
fi

# ── [8] o plano emite os campos que o §3.5 consome ────────────────────────────────────────────
echo "[8] tasks-writer e template de tasks emitem os campos do teste"
miss8=""
for f in "$WRITER" "$SPEC_TPL"; do
  for fld in 'Teste (comando)' 'Padrão de falha' 'Setup do teste'; do
    grep -qF "$fld" "$f" || miss8="$miss8 ${f#"$WS"/}:'$fld'"
  done
done
WTASK="$T/writer-task.md"
awk '/^## Padrão de Cada TASK/{on=1} on && /^## Coverage Gates/{on=0} on' "$WRITER" > "$WTASK"
for fld in '**Teste (comando)**' '**Padrão de falha**'; do
  grep -qF "$fld" "$WTASK" || miss8="$miss8 tasks-writer§Padrão-de-Cada-TASK:'$fld'"
done
if [ -n "$miss8" ]; then
  echo "FAIL [8]: campo ausente —$miss8"; overall_rc=1
else
  echo "OK [8] — tasks-writer (formato da TASK) e templates/spec/tasks.md emitem Teste (comando), Padrão de falha e Setup do teste"
fi

exit "$overall_rc"
