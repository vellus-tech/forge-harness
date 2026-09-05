#!/usr/bin/env bash
# Gate W163 — red-replay.mjs detecta clone shallow e devolve mensagem acionável (LDG-0038).
#
# Por que existe: `deriveBase()` cai em `not-possible` com "fix_files '<f>' sem histórico git —
# revert-synthesis inviável" sempre que `git log`/`git log -1` não encontra o commit que tocou
# fix_files — mas essa MESMA mensagem genérica sai tanto quando o arquivo de fato nunca foi
# versionado quanto quando o repositório é um clone RASO (fetch-depth pequeno, comum em CI) e o
# commit está fora da janela visível. No segundo caso, a mensagem manda implicitamente o autor
# tentar de novo (`/forge:red replay`) — que NUNCA muda nada, porque o problema é do AMBIENTE
# (profundidade do clone), não do comando. `git rev-parse --is-shallow-repository` resolve a
# ambiguidade determinística e barata (um rev-parse) no início de `deriveBase()`.
#
#   [1] CONTROLE — clone COMPLETO do fixture (mesma história) → deriveBase resolve com sucesso
#       (revert-synthesis) — prova que o fixture é válido e o defeito é ESPECIFICAMENTE do shallow
#   [2] o clone raso do MESMO fixture é de fato shallow (`git rev-parse --is-shallow-repository`)
#   [3] deriveBase no clone raso → not-possible com mensagem que NOMEIA a causa (clone raso) e a
#       AÇÃO corretiva (`git fetch --unshallow`) — não mais a mensagem genérica de antes
#   [4] CONTROLE NEGATIVO (escopo cirúrgico) — no MESMO clone raso, um not-possible por causa
#       NÃO-relacionada a histórico (test_id que não existe em lugar nenhum) NÃO menciona
#       shallow/raso — a mensagem só muda quando a causa É a profundidade do clone
#   [5] CONTROLE NEGATIVO — argumentos ausentes (test_path/fix_files) no clone raso continua com
#       a mensagem original, inalterada (nada a ver com histórico git)
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib/red-replay.mjs"
[ -f "$LIB" ]
T="$(mktemp -d /tmp/forge-w163.XXXXXX)"
trap 'rm -rf "$T"' EXIT

ORIGIN="$T/origin"
mkdir -p "$ORIGIN/src" "$ORIGIN/tests"
git -C "$ORIGIN" init -q -b main
git -C "$ORIGIN" config user.email t@t
git -C "$ORIGIN" config user.name t
git -C "$ORIGIN" config commit.gpgsign false

# commit 0 — genesis, ANTES do commit que cria fix_file. Sem isto, esse commit seria a raiz de
# verdade do repositório inteiro, e `parentOf` falharia nele mesmo num clone COMPLETO — o que não
# provaria nada sobre shallow (é exatamente o "commit raiz de verdade" que noParentReason() tem
# de continuar tratando como tal, mensagem original, fora de um clone raso).
printf 'genesis\n' > "$ORIGIN/README.md"
git -C "$ORIGIN" add README.md
git -C "$ORIGIN" commit -qm "chore: genesis"

# commit 1 — cria fix_file (ÚNICO commit que o toca; é o que precisa ficar FORA da janela rasa)
printf 'export function calc() { return 1; }\n' > "$ORIGIN/src/calc.mjs"
git -C "$ORIGIN" add src/calc.mjs
git -C "$ORIGIN" commit -qm "feat: calc (com bug)"

# commits 2-4 — enchimento, só para empurrar o commit 1 para fora da janela rasa
for i in 2 3 4; do
  printf 'filler %s\n' "$i" >> "$ORIGIN/filler.txt"
  git -C "$ORIGIN" add filler.txt
  git -C "$ORIGIN" commit -qm "chore: filler $i"
done

# commit 5 (HEAD) — cria test_path já com o caso declarado; NÃO toca fix_file (squash não se
# aplica: caseCarriesFix fica false, exercitando o mesmo ramo de revert-synthesis que a mensagem
# genérica original cobria)
cat > "$ORIGIN/tests/calc.test.mjs" <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
test('shallow-repro-case', () => { assert.strictEqual(1, 1); });
JS
git -C "$ORIGIN" add tests/calc.test.mjs
git -C "$ORIGIN" commit -qm "test: shallow-repro-case"

FULL="$T/full-clone"
SHALLOW="$T/shallow-clone"
git clone -q "$ORIGIN" "$FULL"
# --depth é ignorado em clones locais por caminho (git recusa a otimizar e clona tudo); file://
# força o protocolo "de rede" mesmo local, e aí o shallow é honrado de verdade.
git clone -q --depth 2 "file://$ORIGIN" "$SHALLOW"

run_derive() {
  local root="$1" testId="$2"
  node --input-type=module -e "
import { deriveBase } from '$LIB';
const r = deriveBase({ root: '$root', testPath: 'tests/calc.test.mjs', fixFiles: ['src/calc.mjs'], testId: '$testId' });
console.log(JSON.stringify(r));
"
}

echo "[1] CONTROLE — clone completo resolve com sucesso (fixture válido)"
out1="$(run_derive "$FULL" shallow-repro-case)"
strategy1="$(node -e "console.log(JSON.parse(process.argv[1]).strategy)" "$out1")"
[ "$strategy1" != "not-possible" ] \
  || { echo "FAIL [1]: fixture já nasce not-possible no clone COMPLETO — não prova nada sobre shallow ($out1)"; exit 1; }
echo "OK [1] (strategy=$strategy1)"

echo "[2] o clone raso é de fato shallow"
is_shallow="$(git -C "$SHALLOW" rev-parse --is-shallow-repository)"
[ "$is_shallow" = "true" ] || { echo "FAIL [2]: clone --depth 2 não ficou shallow (rev-parse devolveu '$is_shallow')"; exit 1; }
echo "OK [2]"

echo "[3] deriveBase no clone raso -> not-possible nomeando a causa (shallow) e a ação (git fetch --unshallow)"
out3="$(run_derive "$SHALLOW" shallow-repro-case)"
strategy3="$(node -e "console.log(JSON.parse(process.argv[1]).strategy)" "$out3")"
reason3="$(node -e "console.log(JSON.parse(process.argv[1]).reason)" "$out3")"
[ "$strategy3" = "not-possible" ] || { echo "FAIL [3]: esperava not-possible no clone raso, veio strategy=$strategy3 ($out3)"; exit 1; }
grep -qi 'raso\|shallow' <<< "$reason3" || { echo "FAIL [3]: reason não nomeia a causa (clone raso/shallow): $reason3"; exit 1; }
grep -qF 'git fetch --unshallow' <<< "$reason3" || { echo "FAIL [3]: reason não indica a ação corretiva (git fetch --unshallow): $reason3"; exit 1; }
echo "OK [3] (reason: $reason3)"

echo "[4] CONTROLE NEGATIVO — not-possible por causa NÃO-histórica no mesmo clone raso não menciona shallow"
out4="$(run_derive "$SHALLOW" test-id-que-nunca-existiu-em-lugar-nenhum)"
strategy4="$(node -e "console.log(JSON.parse(process.argv[1]).strategy)" "$out4")"
reason4="$(node -e "console.log(JSON.parse(process.argv[1]).reason)" "$out4")"
[ "$strategy4" = "not-possible" ] || { echo "FAIL [4]: esperava not-possible (test_id inexistente), veio strategy=$strategy4 ($out4)"; exit 1; }
! grep -qi 'raso\|shallow\|unshallow' <<< "$reason4" \
  || { echo "FAIL [4]: reason cita shallow numa causa que não tem nada a ver com profundidade de clone: $reason4"; exit 1; }
echo "OK [4] (reason: $reason4)"

echo "[5] CONTROLE NEGATIVO — argumentos ausentes no clone raso: mensagem original, inalterada"
out5="$(node --input-type=module -e "
import { deriveBase } from '$LIB';
const r = deriveBase({ root: '$SHALLOW', testPath: '', fixFiles: [], testId: null });
console.log(JSON.stringify(r));
")"
reason5="$(node -e "console.log(JSON.parse(process.argv[1]).reason)" "$out5")"
[ "$reason5" = "test_path/fix_files ausentes — grave com /forge:red record antes de replay" ] \
  || { echo "FAIL [5]: mensagem de argumentos ausentes mudou inesperadamente: $reason5"; exit 1; }
echo "OK [5]"

echo "PASS w163-red-replay-shallow-clone-gate"
