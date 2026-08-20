#!/usr/bin/env bash
# Gate W109 — `red-evidence.sh ci` (LDG-0004): a execução de referência do Red-first passa a ser a
# de um runner que o autor não controla. O subcomando varre os changes ativos type:bugfix, executa
# o replay em cada e agrega o veredito num exit code — é o que o workflow chama.
#
#   [1] os DOIS vazios do universo, que não são o mesmo estado (issue #49): `specs/active` presente
#       e vazio é REPOUSO legítimo — passa dizendo `0 change(s) ativo(s)`, porque um repositório
#       entre ciclos não tem change ativo e o CI roda em todo PR; `specs/active` AUSENTE é alvo
#       sumido — reprova nomeando universo vazio, e a única saída é a justificativa DECLARADA em
#       .forge/empty-universe-allowlist.txt, com linha própria, distinguível de "examinei N"
#   [2] change bugfix com evidência PENDENTE → exit≠0 nomeando o change
#   [3] change bugfix com Red observado de verdade → exit 0
#   [4] change de outro tipo é ignorado (nenhum falso positivo sobre feature/refactor)
#   [5] o subcomando NÃO aceita change-id — quem define o escopo é o repositório, não quem invoca
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w109.XXXXXX)"
trap 'rm -rf "$T"' EXIT

cp -R "$WS/template/.forge" "$T/.forge"
git -C "$T" init -q -b main
git -C "$T" config user.email t@t
git -C "$T" config user.name t
git -C "$T" config commit.gpgsign false
git -C "$T" add -A
git -C "$T" commit -qm "chore: init harness" >/dev/null

SN="$T/.forge/scripts/spec-new.sh"
RE="$T/.forge/scripts/red-evidence.sh"

echo "[1] repouso legítimo passa nomeado; alvo ausente reprova; justificativa declarada libera"
# O contador de controle da issue #49 exige que universo vazio não colapse com "examinei e estava
# limpo". Mas os dois vazios deste modo têm causas opostas, e tratá-los igual troca uma vacuidade
# por um falso positivo estrutural: `specs/active` presente e VAZIO é o estado de todo repositório
# entre ciclos de change, e o CI roda em todo PR — reprovar ali produziria vermelho em PR de
# manutenção, cuja única resposta operacional seria declarar `red-first-ci` na allowlist para
# sempre, esvaziando o gate justamente para o caso anômalo. `specs/active` AUSENTE é outra coisa:
# o alvo que o gate varre não está onde ele procura, que é o "confira o alvo, o glob e o range" da
# própria mensagem de reprovação.
[ -d "$T/.forge/specs/active" ] \
  || { echo "FAIL [1] (fixture não tem specs/active — o cenário mediria outro estado)"; exit 1; }
out="$(FORGE_ROOT="$T" bash "$RE" ci 2>&1)" && rc=0 || rc=$?
[ "$rc" -eq 0 ] \
  || { echo "FAIL [1] (repouso legítimo — specs/active presente e vazio — reprovou o CI, rc=$rc: $out)"; exit 1; }
grep -qE '0 change\(s\) ativo\(s\)' <<<"$out" \
  || { echo "FAIL [1] (passou sem dizer que examinou ZERO changes — é o silêncio que a issue #49 fecha: $out)"; exit 1; }

mv "$T/.forge/specs/active" "$T/.forge/specs/active-guardado"
out="$(FORGE_ROOT="$T" bash "$RE" ci 2>&1)" && rc=0 || rc=$?
[ "$rc" -ne 0 ] \
  || { echo "FAIL [1] (o alvo que o gate varre não existe e o CI aprovou assim mesmo, rc=$rc: $out)"; exit 1; }
grep -q 'universo-vazio' <<<"$out" \
  || { echo "FAIL [1] (reprovou sem nomear o estado de universo vazio: $out)"; exit 1; }
printf 'red-first-ci  # motivo: fixture sem specs/active, cenário [1] do w109\n' > "$T/.forge/empty-universe-allowlist.txt"
out="$(FORGE_ROOT="$T" bash "$RE" ci 2>&1)" && rc=0 || rc=$?
[ "$rc" -eq 0 ] \
  || { echo "FAIL [1] (justificativa declarada não liberou a vacuidade, rc=$rc: $out)"; exit 1; }
grep -q 'justificativa declarada' <<<"$out" \
  || { echo "FAIL [1] (vacuidade justificada saiu indistinguível de universo examinado: $out)"; exit 1; }
rm -f "$T/.forge/empty-universe-allowlist.txt"
mv "$T/.forge/specs/active-guardado" "$T/.forge/specs/active"
echo "OK [1]"

echo "[2] change bugfix com evidência pendente → exit≠0 nomeando o change"
FORGE_ROOT="$T" bash "$SN" bug-ci --type bugfix --scale 1 >/dev/null
out="$(FORGE_ROOT="$T" bash "$RE" ci 2>&1)" && rc=0 || rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [2] (evidência pendente passou no CI: $out)"; exit 1; }
grep -q 'bug-ci' <<<"$out" || { echo "FAIL [2] (a saída não nomeia o change: $out)"; exit 1; }
echo "OK [2]"

echo "[3] change bugfix com Red observado de verdade → exit 0"
# fixture mínima: defeito real, teste em um commit, correção no seguinte (estratégia ancestry)
mkdir -p "$T/src" "$T/tests"
cat > "$T/src/sum.mjs" <<'JS'
export function sum(a, b) { return a - b; }
JS
git -C "$T" add -A && git -C "$T" commit -qm "feat: sum (com bug)" >/dev/null
cat > "$T/tests/sum.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { sum } from '../src/sum.mjs';
test('bug-ci-regression', () => { assert.strictEqual(sum(2, 3), 5); });
JS
git -C "$T" add -A && git -C "$T" commit -qm "test: regressão bug-ci" >/dev/null
cat > "$T/src/sum.mjs" <<'JS'
export function sum(a, b) { return a + b; }
JS
git -C "$T" add -A && git -C "$T" commit -qm "fix: bug-ci" >/dev/null

FORGE_ROOT="$T" bash "$RE" record bug-ci --test-path tests/sum.test.mjs --test-id bug-ci-regression \
  --command "node --test tests/sum.test.mjs" --fix-files src/sum.mjs --failure-pattern AssertionError >/dev/null
out="$(FORGE_ROOT="$T" bash "$RE" ci 2>&1)" && rc=0 || rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [3] (Red observável reprovou no CI: $out)"; exit 1; }
grep -q 'bug-ci' <<<"$out" || { echo "FAIL [3] (a saída não relata o change verificado: $out)"; exit 1; }
echo "OK [3]"

echo "[4] change de outro tipo é ignorado"
FORGE_ROOT="$T" bash "$SN" feat-ci --type feature --scale 1 >/dev/null
out="$(FORGE_ROOT="$T" bash "$RE" ci 2>&1)" && rc=0 || rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [4] (change type:feature virou falso positivo: $out)"; exit 1; }
grep -q 'feat-ci' <<<"$out" && { echo "FAIL [4] (feature não deveria aparecer no relato: $out)"; exit 1; }
echo "OK [4]"

echo "[5] o subcomando não aceita change-id"
out="$(FORGE_ROOT="$T" bash "$RE" ci bug-ci 2>&1)" && rc=0 || rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [5] (ci aceitou change-id — o escopo passaria a ser escolhido por quem invoca: $out)"; exit 1; }
echo "OK [5]"

echo "[6] init materializa red-first.yml — e os dois instaladores fazem o mesmo"
# Paridade obrigatória: projeto instalado por `curl | bash` não passa por bin/forge.mjs. Se só um
# dos caminhos materializar o workflow, metade dos consumidores fica sem a autoridade do CI e
# ninguém percebe — o gate local continua verde nos dois casos.
I1="$T/inst-node"; mkdir -p "$I1"; git -C "$I1" init -q
node "$WS/bin/forge.mjs" init --target "$I1" --slug p1 --name P1 --desc t --yes --no-plugin >/dev/null 2>&1
[ -f "$I1/.github/workflows/red-first.yml" ] || { echo "FAIL [6] (bin/forge.mjs init não materializou red-first.yml)"; exit 1; }
grep -q 'red-evidence.sh ci' "$I1/.github/workflows/red-first.yml" || { echo "FAIL [6] (workflow não chama o subcomando ci)"; exit 1; }
grep -q 'fetch-depth: 0' "$I1/.github/workflows/red-first.yml" || { echo "FAIL [6] (sem fetch-depth: 0 o motor não tem histórico para derivar a base)"; exit 1; }

I2="$T/inst-bash"; mkdir -p "$I2"; git -C "$I2" init -q
# sem `|| true`: falha do instalador tem que aparecer aqui, não virar um FAIL enigmático adiante
bash "$WS/installer/install.sh" --target "$I2" --slug p2 --name P2 --desc t >"$T/inst-bash.log" 2>&1 \
  || { echo "FAIL [6] (installer/install.sh saiu ≠0: $(tail -3 "$T/inst-bash.log"))"; exit 1; }
[ -f "$I2/.github/workflows/red-first.yml" ] || { echo "FAIL [6] (installer/install.sh não materializou red-first.yml — paridade quebrada)"; exit 1; }

# não sobrescreve workflow existente do projeto
printf 'name: meu-proprio\n' > "$I1/.github/workflows/red-first.yml"
node "$WS/bin/forge.mjs" update --target "$I1" --source "$WS/template/.forge" --no-plugin --no-backup >/dev/null 2>&1 || true
grep -q 'meu-proprio' "$I1/.github/workflows/red-first.yml" || { echo "FAIL [6] (workflow do projeto foi sobrescrito)"; exit 1; }
echo "OK [6]"

echo "PASS w109-red-ci-gate"
