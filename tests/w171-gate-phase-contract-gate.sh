#!/usr/bin/env bash
# Gate W171 — runtime.gates com FASE (issue #82: "runtime.gates só sabe agendar gate de árvore
# de fontes, e os gates de artefato ficam órfãos").
#
# O contrato de gate do harness inteiro é em forma de árvore de fontes: todo gate recebe caminho
# de repositório e lê arquivos; runtime.gates é lista plana executada no fechamento da wave;
# hooks rodam no commit/push. Os três momentos acontecem quando o artefato implantável AINDA NÃO
# EXISTE — não há onde declarar um gate de digest publicado, manifesto renderizado ou cluster no
# ar. Este gate cobre a peça central da Onda 3: `run-gates.sh` ganha um seletor `--phase`, cada
# entrada de runtime.gates tem uma fase (implícita "source" para toda forma já existente), e a
# fase "source" continua sendo o default — para que um consumidor que nunca declarou fase nenhuma
# não note diferença nenhuma.
#
#   [0] RETROCOMPAT byte-exata (golden capturado em tests/fixtures/w171 ANTES desta mudança,
#       com a run-gates.sh original): NO-GATES, OK e FAIL continuam produzindo a MESMA saída
#       (log path normalizado — é o único componente não determinístico), sem `--phase` nenhum.
#   [1] forma mapeada (block-sequence YAML): um gate escalar (phase source implícita) + dois
#       mapeados (`pre-deploy` e `post-deploy`) — chamada SEM --phase roda só o de source.
#   [2] `--phase pre-deploy` roda só os gates dessa fase; `--phase post-deploy` só os da outra.
#   [3] GUARDA DE VACUIDADE: `--phase` explícita sem gate nenhum casando a fase REPROVA (não
#       vira NO-GATES silencioso) — e a isenção declarada em empty-universe-allowlist.txt destrava.
#   [4] spec-verify.sh (migrado no LDG-0014) só roda gates da fase "source" mesmo quando o
#       FORGE.md declara gates de outras fases — não tenta rodar um gate de pre-deploy contra a
#       árvore de fontes durante /forge:verify (onde o artefato também ainda não existe).
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIX="$WS/tests/fixtures/w171"
T="$(mktemp -d /tmp/forge-w171.XXXXXX)"
trap 'rm -rf "$T"' EXIT
cp -R "$WS/template/.forge" "$T/.forge"
S="$T/.forge/scripts"

norm_logdir() { sed -E 's#/tmp/forge-gates\.[A-Za-z0-9]+#<LOGDIR>#g'; }

# ── [0] RETROCOMPAT byte-exata (golden pré-mudança) ─────────────────────────────────────────
echo "[0a] retrocompat: NO-GATES, sem --phase, byte-idêntico ao golden pré-mudança"
FORGE_ROOT="$T" bash "$S/run-gates.sh" chg-none W1 > "$T/out-no-gates.txt" 2>&1
cmp "$FIX/golden-no-gates.txt" "$T/out-no-gates.txt" \
  || { echo "FAIL [0a]: saída divergiu do golden — diff:"; diff "$FIX/golden-no-gates.txt" "$T/out-no-gates.txt" || true; exit 1; }
echo "OK [0a]"

echo "[0b] retrocompat: gate OK (CSV escalar), sem --phase, idêntico ao golden (LOGDIR normalizado)"
perl -pi -e 's/^  gates:[ \t]*$/  gates: fixture-gate/' "$T/.forge/FORGE.md"
printf '#!/usr/bin/env bash\necho "fixture rodou para $1"\nexit 0\n' > "$S/fixture-gate.sh"
chmod +x "$S/fixture-gate.sh"
FORGE_ROOT="$T" bash "$S/run-gates.sh" chg-ok W1 > "$T/out-ok-raw.txt" 2>&1
norm_logdir < "$T/out-ok-raw.txt" > "$T/out-ok.txt"
cmp "$FIX/golden-ok-source.txt" "$T/out-ok.txt" \
  || { echo "FAIL [0b]: saída divergiu do golden — diff:"; diff "$FIX/golden-ok-source.txt" "$T/out-ok.txt" || true; exit 1; }
echo "OK [0b]"

echo "[0c] retrocompat: gate FAIL (CSV escalar), sem --phase, idêntico ao golden (LOGDIR normalizado)"
printf '#!/usr/bin/env bash\nexit 1\n' > "$S/fixture-gate.sh"
set +e
FORGE_ROOT="$T" bash "$S/run-gates.sh" chg-fail W1 > "$T/out-fail-raw.txt" 2>&1
RC0C=$?
set -e
[ "$RC0C" -ne 0 ] || { echo "FAIL [0c]: run-gates.sh deveria reprovar (rc=0)"; exit 1; }
norm_logdir < "$T/out-fail-raw.txt" > "$T/out-fail.txt"
cmp "$FIX/golden-fail-source.txt" "$T/out-fail.txt" \
  || { echo "FAIL [0c]: saída divergiu do golden — diff:"; diff "$FIX/golden-fail-source.txt" "$T/out-fail.txt" || true; exit 1; }
echo "OK [0c]"

# ── [1]/[2] forma mapeada — fases distintas ──────────────────────────────────────────────────
echo "[1] forma mapeada: sem --phase roda só o gate de fase source (implícita)"
cat > "$T/.forge/FORGE.md" <<'FORGE_EOF'
---
runtime:
  primary_stack: bash
  gates:
    - fixture-source
    - name: fixture-predeploy
      phase: pre-deploy
    - name: fixture-postdeploy
      phase: post-deploy
---

# FORGE.md — fixture w171
FORGE_EOF
for g in source predeploy postdeploy; do
  printf '#!/usr/bin/env bash\necho "%s rodou"\nexit 0\n' "$g" > "$S/fixture-$g.sh"
  chmod +x "$S/fixture-$g.sh"
done
OUT1="$(FORGE_ROOT="$T" bash "$S/run-gates.sh" chg-phases W1)"
grep -q 'fixture-source: passed' <<< "$OUT1" || { echo "FAIL [1]: gate source não rodou: $OUT1"; exit 1; }
grep -q 'fixture-predeploy' <<< "$OUT1" && { echo "FAIL [1]: gate pre-deploy rodou sem --phase: $OUT1"; exit 1; }
grep -q 'fixture-postdeploy' <<< "$OUT1" && { echo "FAIL [1]: gate post-deploy rodou sem --phase: $OUT1"; exit 1; }
grep -q '^OK$' <<< "$OUT1" || { echo "FAIL [1]: veredito final não é OK: $OUT1"; exit 1; }
echo "OK [1]"

echo "[2] --phase pre-deploy roda só o gate dessa fase; --phase post-deploy só o da outra"
OUT2A="$(FORGE_ROOT="$T" bash "$S/run-gates.sh" chg-phases W1 --phase pre-deploy)"
grep -q 'fixture-predeploy: passed' <<< "$OUT2A" || { echo "FAIL [2]: pre-deploy não rodou: $OUT2A"; exit 1; }
grep -q 'fixture-source' <<< "$OUT2A" && { echo "FAIL [2]: gate source rodou sob --phase pre-deploy: $OUT2A"; exit 1; }
grep -q 'fixture-postdeploy' <<< "$OUT2A" && { echo "FAIL [2]: post-deploy rodou sob --phase pre-deploy: $OUT2A"; exit 1; }

OUT2B="$(FORGE_ROOT="$T" bash "$S/run-gates.sh" chg-phases W1 --phase post-deploy)"
grep -q 'fixture-postdeploy: passed' <<< "$OUT2B" || { echo "FAIL [2]: post-deploy não rodou: $OUT2B"; exit 1; }
grep -q 'fixture-source' <<< "$OUT2B" && { echo "FAIL [2]: gate source rodou sob --phase post-deploy: $OUT2B"; exit 1; }
grep -q 'fixture-predeploy' <<< "$OUT2B" && { echo "FAIL [2]: pre-deploy rodou sob --phase post-deploy: $OUT2B"; exit 1; }
echo "OK [2]"

# ── [3] guarda de vacuidade ──────────────────────────────────────────────────────────────────
echo "[3] --phase explícita sem gate nenhum casando a fase REPROVA (não é NO-GATES silencioso)"
set +e
OUT3="$(FORGE_ROOT="$T" bash "$S/run-gates.sh" chg-phases W1 --phase staging 2>&1)"
RC3=$?
set -e
[ "$RC3" -ne 0 ] || { echo "FAIL [3]: --phase staging (0 gates) passou (rc=0): $OUT3"; exit 1; }
grep -q '^FAIL$' <<< "$OUT3" || { echo "FAIL [3]: veredito final não é FAIL: $OUT3"; exit 1; }
grep -qi 'universo-vazio' <<< "$OUT3" || { echo "FAIL [3]: não é a guarda de vacuidade (gate-universe.sh) reprovando: $OUT3"; exit 1; }

echo "[3b] isenção declarada em empty-universe-allowlist.txt destrava a fase vazia"
printf 'run-gates-phase-staging  # motivo: fase staging ainda não adotada por este consumidor (fixture w171)\n' \
  > "$T/.forge/empty-universe-allowlist.txt"
OUT3B="$(FORGE_ROOT="$T" bash "$S/run-gates.sh" chg-phases W1 --phase staging)"
grep -q '^NO-GATES$' <<< "$OUT3B" || { echo "FAIL [3b]: isenção declarada não destravou: $OUT3B"; exit 1; }
grep -qi 'justificativa declarada' <<< "$OUT3B" || { echo "FAIL [3b]: não ecoou a justificativa: $OUT3B"; exit 1; }
echo "OK [3]"

# ── [4] spec-verify.sh (LDG-0014) fica em source mesmo com FORGE.md multi-fase ──────────────
echo "[4] spec-verify.sh só roda gate(s) de fase source, mesmo com pre-deploy/post-deploy declarados"
git -C "$T" init -q
git -C "$T" -c user.email=w171@t -c user.name=w171 add -A >/dev/null
git -C "$T" -c user.email=w171@t -c user.name=w171 commit -qm init >/dev/null
(cd "$T" && bash "$S/spec-new.sh" chg-verify --type feature --scale 0 >/dev/null
            bash "$S/spec-transition.sh" chg-verify tasks-ready >/dev/null
            bash "$S/spec-transition.sh" chg-verify implementing >/dev/null)
perl -pi -e 's/^(\s*)- \[ \] /$1- [X] /' "$T/.forge/specs/active/chg-verify/tasks.md"
(cd "$T" && bash "$S/spec-transition.sh" chg-verify implemented >/dev/null)
OUT4="$(FORGE_ROOT="$T" bash "$S/spec-verify.sh" chg-verify)"
grep -q 'fixture-source: passed' <<< "$OUT4" || { echo "FAIL [4]: gate de source não rodou no verify: $OUT4"; exit 1; }
grep -q 'fixture-predeploy' <<< "$OUT4" && { echo "FAIL [4]: verify tentou rodar gate de pre-deploy: $OUT4"; exit 1; }
grep -q 'fixture-postdeploy' <<< "$OUT4" && { echo "FAIL [4]: verify tentou rodar gate de post-deploy: $OUT4"; exit 1; }
grep -q '^OK ' <<< "$OUT4" || { echo "FAIL [4]: verify não deu OK: $OUT4"; exit 1; }
echo "OK [4]"

echo "OK"
