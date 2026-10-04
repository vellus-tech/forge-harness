#!/usr/bin/env bash
# Gate W280 — #159: o loop de Review dos gates de spec e as rodadas do /forge:analyze têm teto e regra de convergência.
#
# POR QUE ESTE GATE EXISTE. A decisão `Review` do gate humano "voltava ao passo 1" sem teto — o caminho percorrido quando o dono delega a decisão do gate a um revisor adversarial. Num consumidor, o gate `requirements_reviewed` delegado rodou 14 vezes: da 5ª à 13ª, cada rodada achou 1 ou 2 MAJOR criados pela correção da rodada anterior. No `/forge:analyze` do mesmo change, três rodadas seguidas abriram BLOCKER no mesmo mecanismo, e pendências operacionais (recibo de outra sessão, ledger fora do tronco) apareceram classificadas como defeito do artefato. O ciclo só convergiu quando o prompt do decisor pediu causa raiz e a régua de severidade ficou estável.
#
# O que se confere aqui é o protocolo em prosa que o agente segue (não há código a exercitar além do `approval-log.sh`, que é o freio mecânico citado pela regra). Cada checagem lê a SEÇÃO certa, não o arquivo inteiro, para que mover a regra para fora do gate reprove:
#   [1]  requirements.md §4 (entre `## 4. Gate HITL` e `## Regras`) tem a subseção de teto e convergência: teto explícito de N rodadas de Review, valendo para decisão delegada ou não, com escalada obrigatória ao dono ao atingir, e o bullet `Review` remete ao teto (não volta ao passo 1 sem condição)
#   [2]  o N do teto é UM só número em todo lugar: §3 do requirements ("máximo N iterações"), a subseção de teto, o bullet "Loop de review" do autonomy-yolo e o maior `--iteration` que o `approval-log.sh` aceita
#   [3]  regra de convergência: achado consequência direta da correção anterior no mesmo mecanismo é nota e não reabre o ciclo
#   [4]  régua de severidade fixada na primeira rodada e repetida no prompt de cada rodada seguinte
#   [5]  causa raiz pedida ao decisor quando o mesmo mecanismo reaparece pela segunda rodada — no requirements e no agent yolo-gate
#   [6]  design.md e tasks.md: o bullet `Review` remete ao teto do /forge:requirements, e o comando de registro passa `--iteration`
#   [7]  autonomy-yolo: o bullet "Loop de review" estende o teto ao caminho humano delegado e remete ao requirements
#   [8]  analyze.md `## Regras`: teto de rodadas, mesma convergência, régua estável e classificação defeito de artefato × pendência operacional (a pendência não bloqueia e vai para ledger ou handoff); a saída tem seção própria de pendências operacionais fora da tabela de achados, num formato que o detector de BLOCKER do spec-transition não casa
#   [9]  freio mecânico: approval-log.sh aceita `--iteration N` e recusa `--iteration N+1` para `review`
#   [10] espelhos do plugin idênticos à fonte (requirements, design, tasks, analyze)
# Propriedade PBT: não se aplica (protocolo em prosa; o único comportamento executável é o limite do approval-log, conferido nas duas bordas).
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$WS" || { echo "FAIL: não foi possível entrar em '$WS'"; exit 2; }

REQ="template/.forge/commands/specs/requirements.md"
DES="template/.forge/commands/specs/design.md"
TSK="template/.forge/commands/specs/tasks.md"
ANA="template/.forge/commands/specs/analyze.md"
YOLO="template/.forge/rules/conventions/autonomy-yolo.md"
GATEAG="template/.forge/agents/review/yolo-gate.md"
for f in "$REQ" "$DES" "$TSK" "$ANA" "$YOLO" "$GATEAG" template/.forge/scripts/approval-log.sh; do
  [ -f "$f" ] || { echo "FAIL: '$f' não existe"; exit 1; }
done

FALHAS=0
falha() { echo "FAIL $*"; FALHAS=$((FALHAS + 1)); }
ok() { echo "OK $*"; }

# Bloco entre a primeira linha que casa $2 e a primeira linha seguinte que casa $3 (exclusiva). Vazio se $2 não existir.
bloco() { awk -v a="$2" -v b="$3" 'f && $0 ~ b {exit} $0 ~ a {f=1} f' "$1"; }
# Linhas do bloco que casam TODOS os padrões ERE (case-insensitive) — a regra precisa estar numa mesma frase/parágrafo, não espalhada.
linha_com() { local txt="$1"; shift; local out; out="$(printf '%s\n' "$txt")"; for p in "$@"; do out="$(printf '%s\n' "$out" | grep -iE -- "$p" || true)"; done; printf '%s' "$out"; }

# ── [1] subseção de teto no §4 do requirements ───────────────────────────────────────────────
echo "[1] requirements.md §4: teto explícito de rodadas de Review, delegado ou não, com escalada ao dono"
G4="$(bloco "$REQ" '^## 4\. Gate HITL' '^## Regras')"
[ -n "$G4" ] || falha "[1] não achei o bloco '## 4. Gate HITL' … '## Regras' em $REQ"
TETO="$(printf '%s\n' "$G4" | bloco /dev/stdin '^### Teto e convergência do Review' '^##')"
if [ -z "$TETO" ]; then
  falha "[1] subseção '### Teto e convergência do Review' ausente do §4 de $REQ"
else
  [ -n "$(linha_com "$TETO" 'teto de [0-9]+ rodadas' 'review' 'delegad')" ] || falha "[1] nenhuma frase da subseção declara 'teto de N rodadas' de Review valendo para decisão delegada ou não"
  [ -n "$(linha_com "$TETO" 'ao atingir|atingido' 'escala' 'dono')" ] || falha "[1] nenhuma frase da subseção torna obrigatória a escalada ao dono ao atingir o teto"
  [ -n "$(linha_com "$TETO" 'approval-log' '--iteration')" ] || falha "[1] a subseção não nomeia o freio mecânico (approval-log.sh --iteration)"
fi
RBUL="$(printf '%s\n' "$G4" | grep -E '^- \*\*Review\*\*' || true)"
[ -n "$RBUL" ] || falha "[1] bullet '- **Review**' ausente do §4 de $REQ"
[ -n "$RBUL" ] && { printf '%s' "$RBUL" | grep -qi 'teto' || falha "[1] o bullet Review do requirements volta ao passo 1 sem remeter ao teto: $RBUL"; }
[ "$FALHAS" -eq 0 ] && ok "[1]"

# ── [2] um só número de teto ─────────────────────────────────────────────────────────────────
echo "[2] o teto é o mesmo número no §3, na subseção de teto, no autonomy-yolo e no approval-log"
F2=$FALHAS
n_loop="$(grep -oE '^## 3\. Loop \(máximo [0-9]+ iterações\)' "$REQ" | grep -oE '[0-9]+' | tail -1)"
n_teto="$(printf '%s\n' "${TETO:-}" | grep -oiE 'teto de [0-9]+ rodadas' | head -1 | grep -oE '[0-9]+')"
LOOPY="$(grep -E '^- \*\*Loop de review\*\*' "$YOLO" -A4 | awk 'NR>1 && /^- \*\*/{exit} {print}')"
n_yolo="$(printf '%s\n' "$LOOPY" | grep -oE '\*\*[0-9]+ iterações\*\*' | head -1 | grep -oE '[0-9]+')"
n_log="$(grep -E 'case "\$ITERATION" in' template/.forge/scripts/approval-log.sh | grep -oE 'in [0-9|]+\)' | grep -oE '[0-9]+' | sort -n | tail -1)"
for v in n_loop n_teto n_yolo n_log; do [ -n "${!v}" ] || falha "[2] não consegui extrair $v (seção ausente ou mudou de forma)"; done
if [ -n "$n_loop" ] && [ -n "$n_teto" ] && [ -n "$n_yolo" ] && [ -n "$n_log" ]; then
  if [ "$n_loop" = "$n_teto" ] && [ "$n_teto" = "$n_yolo" ] && [ "$n_yolo" = "$n_log" ]; then ok "[2] teto = $n_teto em todos"; else falha "[2] tetos divergentes: §3=$n_loop teto=$n_teto yolo=$n_yolo approval-log=$n_log"; fi
fi
[ "$FALHAS" -eq "$F2" ] || true

# ── [3] convergência ─────────────────────────────────────────────────────────────────────────
echo "[3] convergência: consequência direta da correção anterior no mesmo mecanismo vira nota e não reabre o ciclo"
F3=$FALHAS
[ -n "$(linha_com "${TETO:-}" 'consequência direta da correção' 'mesmo mecanismo' 'nota' 'não reabre')" ] || falha "[3] a regra de convergência não está numa frase da subseção de teto"
[ "$FALHAS" -eq "$F3" ] && ok "[3]"

# ── [4] régua estável ────────────────────────────────────────────────────────────────────────
echo "[4] régua de severidade fixada na primeira rodada e repetida a cada rodada"
F4=$FALHAS
[ -n "$(linha_com "${TETO:-}" 'régua de severidade' 'primeira rodada' 'repetida')" ] || falha "[4] a subseção não fixa a régua de severidade na primeira rodada nem manda repeti-la"
[ "$FALHAS" -eq "$F4" ] && ok "[4]"

# ── [5] causa raiz na segunda rodada ─────────────────────────────────────────────────────────
echo "[5] causa raiz pedida ao decisor quando o mesmo mecanismo reaparece pela segunda rodada (requirements e yolo-gate)"
F5=$FALHAS
[ -n "$(linha_com "${TETO:-}" 'causa raiz' 'segunda rodada' 'mesmo mecanismo')" ] || falha "[5] a subseção não manda pedir causa raiz quando o mesmo mecanismo reaparece pela segunda rodada"
PROC="$(bloco "$GATEAG" '^## Processo' '^## Saída')"
[ -n "$(linha_com "$PROC" 'causa raiz' 'segunda rodada' 'mesmo mecanismo')" ] || falha "[5] o Processo do agent yolo-gate não pede causa raiz quando o mesmo mecanismo reaparece pela segunda rodada"
[ "$FALHAS" -eq "$F5" ] && ok "[5]"

# ── [6] design e tasks herdam ────────────────────────────────────────────────────────────────
echo "[6] design.md e tasks.md: bullet Review remete ao teto do /forge:requirements e o registro passa --iteration"
F6=$FALHAS
for f in "$DES" "$TSK"; do
  b="$(grep -E '^- \*\*Review\*\*' "$f" || true)"
  [ -n "$b" ] || { falha "[6] bullet '- **Review**' ausente em $f"; continue; }
  printf '%s' "$b" | grep -qi 'teto' && printf '%s' "$b" | grep -q '/forge:requirements' || falha "[6] o bullet Review de $f não remete ao teto do /forge:requirements: $b"
  grep -E 'approval-log\.sh .*--gate (design|tasks)_reviewed' "$f" | grep -q -- '--iteration' || falha "[6] o comando approval-log de $f não passa --iteration (o freio mecânico não alcança este gate)"
done
[ "$FALHAS" -eq "$F6" ] && ok "[6]"

# ── [7] autonomy-yolo ────────────────────────────────────────────────────────────────────────
echo "[7] autonomy-yolo: o teto vale também para o Review humano delegado e remete ao requirements"
F7=$FALHAS
[ -n "$LOOPY" ] || falha "[7] bullet '- **Loop de review**' ausente de $YOLO"
printf '%s' "$LOOPY" | grep -qi 'delega' || falha "[7] o bullet Loop de review não estende o teto ao Review humano delegado"
printf '%s' "$LOOPY" | grep -q '/forge:requirements' || falha "[7] o bullet Loop de review não remete à regra do /forge:requirements"
[ "$FALHAS" -eq "$F7" ] && ok "[7]"

# ── [8] analyze ──────────────────────────────────────────────────────────────────────────────
echo "[8] analyze.md: teto, convergência, régua estável e defeito de artefato × pendência operacional"
F8=$FALHAS
REG="$(bloco "$ANA" '^## Regras' '^## [^R]')"
[ -n "$REG" ] || falha "[8] seção '## Regras' ausente de $ANA"
[ -n "$(linha_com "$REG" 'teto de [0-9]+ rodadas' 'analyze' 'escala')" ] || falha "[8] ## Regras não declara teto de rodadas de analyze com escalada"
[ -n "$(linha_com "$REG" 'consequência direta da correção' 'mesmo mecanismo' 'causa raiz')" ] || falha "[8] ## Regras não aplica a convergência (consequência direta da correção no mesmo mecanismo → causa raiz)"
[ -n "$(linha_com "$REG" 'régua de severidade' 'primeira rodada' 'estável|não muda')" ] || falha "[8] ## Regras não declara régua de severidade estável entre rodadas"
[ -n "$(linha_com "$REG" 'defeito de artefato' 'pendência operacional')" ] || falha "[8] ## Regras não classifica achado em defeito de artefato × pendência operacional"
[ -n "$(linha_com "$REG" 'pendência operacional' 'não bloqueia' 'ledger' 'handoff')" ] || falha "[8] ## Regras não diz que a pendência operacional não bloqueia e vai para ledger ou handoff"
SAIDA="$(bloco "$ANA" '^## Saída' '^\*\*Quem julga')"
PEND="$(printf '%s\n' "$SAIDA" | bloco /dev/stdin '^## Pendências operacionais' '^## ')"
if [ -z "$PEND" ]; then
  falha "[8] o template de saída do analyze não tem a seção '## Pendências operacionais' fora da tabela de achados"
else
  # Mesmo detector do spec-transition.sh (linha '| BLOCKER |' bloqueia implementing): a seção de pendências não pode ter esse formato.
  printf '%s\n' "$PEND" | grep -qE '\| *BLOCKER *\|' && falha "[8] a seção de pendências operacionais usa linha '| BLOCKER |' — o spec-transition a trataria como bloqueio"
  printf '%s\n' "$PEND" | grep -qE '^- ' || falha "[8] a seção de pendências operacionais não é uma lista ('- ') fora da tabela"
  grep -qF "grep -cE '\| *BLOCKER *\|'" template/.forge/scripts/spec-transition.sh || falha "[8] o detector de BLOCKER do spec-transition.sh mudou de forma — reveja esta checagem"
fi
[ "$FALHAS" -eq "$F8" ] && ok "[8]"

# ── [9] freio mecânico ───────────────────────────────────────────────────────────────────────
echo "[9] approval-log.sh aceita --iteration N e recusa N+1 para review"
F9=$FALHAS
T="$(mktemp -d "${TMPDIR:-/tmp}/forge-w280.XXXXXX")"; trap 'rm -rf "$T"' EXIT
cp -R "$WS/template/.forge" "$T/.forge"
(cd "$T" && git init -q && git config user.name "Humano Fixture" && git config user.email h@fixture.invalid)
if (cd "$T" && bash .forge/scripts/spec-new.sh chg-teto --type feature --scale 1 >"$T/sn.log" 2>&1); then
  N="${n_log:-3}"
  out="$(cd "$T" && bash .forge/scripts/approval-log.sh chg-teto --gate requirements_reviewed --decision review --reason 'rodada no teto' --iteration "$N" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || falha "[9] --iteration $N (no teto) foi recusado: rc=$rc $out"
  out="$(cd "$T" && bash .forge/scripts/approval-log.sh chg-teto --gate requirements_reviewed --decision review --reason 'rodada além do teto' --iteration "$((N + 1))" 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'FAIL' || falha "[9] --iteration $((N + 1)) (além do teto) foi aceito: rc=$rc $out"
else
  falha "[9] spec-new falhou na fixture: $(tail -3 "$T/sn.log")"
fi
[ "$FALHAS" -eq "$F9" ] && ok "[9]"

# ── [10] espelhos do plugin ──────────────────────────────────────────────────────────────────
echo "[10] espelhos do plugin idênticos à fonte"
F10=$FALHAS
for n in requirements design tasks analyze; do
  cmp -s "template/.forge/commands/specs/$n.md" "plugin/forge/commands/$n.md" || falha "[10] plugin/forge/commands/$n.md diverge da fonte — rode npm run build:plugin"
done
[ "$FALHAS" -eq "$F10" ] && ok "[10]"

if [ "$FALHAS" -eq 0 ]; then echo "W280 PASS"; exit 0; fi
echo "W280 FAIL ($FALHAS falha(s))"; exit 1
