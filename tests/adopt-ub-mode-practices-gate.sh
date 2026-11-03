#!/usr/bin/env bash
# Gate — change `adopt-ub-mode-practices` (Wave 1: "Attack the Premise" / REQ-01/REQ-02).
#
# POR QUE ESTE GATE EXISTE. O ub-mode (`unclebob/ub-mode`) propõe que, quando duas tentativas
# de correção falham o mesmo gate, a retomada tem que nomear a premissa compartilhada e o(s)
# ator(es) do desequilíbrio antes de tentar de novo — "remove the assignment... do not start
# another fix until you have done that". Este change enriquece o HALT existente (`implement.md`,
# `task-coder.md`) com esse mecanismo, SEM afrouxar o HALT (continua parando após a mesma
# quantidade de tentativas de hoje) e SEM tocar o caminho `/forge:red replay` (fora de escopo,
# ver design.md §2.1). Este gate prova o mecanismo sobre fixtures herméticas — nunca o
# `tasks.md`/`PROGRESS-TRACKING.md` reais deste repositório.
#
# Grupos (primeiro argumento; sem argumento roda todos): script · implement-wiring ·
# coding-loop-wiring · human-wiring · premise-mutation · suppression-grammar ·
# suppression-wiring · suppression-mutation · spike. Os quatro últimos (Wave 2/3 do mesmo
# change) ainda não têm cenário nesta rodada — contam 0 cenários declarados até a TASK
# correspondente ser implementada numa sessão futura. O ordinal wNNN real só se decide no merge.
set -euo pipefail

GROUP="${1:-all}"
case "$GROUP" in
  all|script|implement-wiring|coding-loop-wiring|human-wiring|premise-mutation|suppression-grammar|suppression-wiring|suppression-mutation|spike) : ;;
  *) echo "FAIL: grupo desconhecido '$GROUP'"; exit 2 ;;
esac
_want() { [ "$GROUP" = all ] || [ "$GROUP" = "$1" ]; }

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$WS" || { echo "FAIL: não foi possível entrar em '$WS'"; exit 2; }
command -v node >/dev/null 2>&1 || { echo "NÃO VERIFICADO: 'node' ausente"; exit 3; }

SCRIPT="$WS/template/.forge/scripts/check-attack-premise.sh"

T="$(mktemp -d "${TMPDIR:-/tmp}/forge-attack-premise.XXXXXX")"
trap 'rm -rf "$T"' EXIT

declare_scn() { case "$1" in script) echo 12;; implement-wiring) echo 4;; coding-loop-wiring) echo 4;; human-wiring) echo 0;; premise-mutation) echo 0;; suppression-grammar) echo 0;; suppression-wiring) echo 0;; suppression-mutation) echo 0;; spike) echo 0;; esac; }
ALL_GROUPS="script implement-wiring coding-loop-wiring human-wiring premise-mutation suppression-grammar suppression-wiring suppression-mutation spike"
SCN=0
_scn() { SCN=$((SCN + 1)); echo "$1"; }
_fail() { echo "FAIL [$1] $2"; exit 1; }
_ck() { bash "$SCRIPT" "$@"; } # chama o script sob teste

# ───────────────────────────── script (TASK-01: REQ-01/REQ-02) ─────────────────────────────
if _want script; then
  # --- tasks.md ---
  _scn "[script-1] tasks.md controle: causa 'gate falha após 2 tentativas de correção' com Gate/Premissa/Ator(es) preenchidos → aceito"
  F="$T/tasks1.md"
  cat > "$F" <<'EOF'
- [!] TASK-04 — algo (rastreia: REQ-02; paths: x)
  > FALHA: gate falha após 2 tentativas de correção — sintoma objetivo
  > Gate: dotnet build
  > Premissa: a suposição compartilhada pelas duas tentativas
  > Ator(es) com o desequilíbrio: o specialist que reexecutou sem investigar
EOF
  out="$(_ck --file "$F" --task-id TASK-04)" || _fail script-1 "controle reprovou: $out"
  grep -q "^OK " <<<"$out" || _fail script-1 "saída sem OK: $out"
  echo "OK [script-1] — $out"

  _scn "[script-2] tasks.md violação: mesma causa, campos ausentes → reprovado nomeando o que falta"
  F="$T/tasks2.md"
  cat > "$F" <<'EOF'
- [!] TASK-05 — algo (rastreia: REQ-02; paths: x)
  > FALHA: gate falha após 2 tentativas de correção — sintoma objetivo
  > Gate: dotnet build
EOF
  set +e; out="$(_ck --file "$F" --task-id TASK-05)"; rc=$?; set -e
  [ "$rc" -eq 1 ] || _fail script-2 "esperado rc 1, obtido $rc — $out"
  grep -q "Premissa" <<<"$out" || _fail script-2 "mensagem não nomeia Premissa ausente: $out"
  grep -q "Ator(es)" <<<"$out" || _fail script-2 "mensagem não nomeia Ator(es) ausente: $out"
  echo "OK [script-2] — $out"

  _scn "[script-3] tasks.md contracontrole: causa 'dependência externa indisponível' sem campos → aceito (REQ não dispara)"
  F="$T/tasks3.md"
  cat > "$F" <<'EOF'
- [!] TASK-06 — algo (rastreia: REQ-02; paths: x)
  > FALHA: dependência externa indisponível — API fora do ar
EOF
  out="$(_ck --file "$F" --task-id TASK-06)" || _fail script-3 "contracontrole reprovou: $out"
  grep -q "^OK " <<<"$out" || _fail script-3 "saída sem OK: $out"
  echo "OK [script-3] — $out"

  _scn "[script-4] tasks.md contracontrole 2: causa 'decisão de produto necessária' sem campos → aceito"
  F="$T/tasks4.md"
  cat > "$F" <<'EOF'
- [!] TASK-07 — algo (rastreia: REQ-02; paths: x)
  > FALHA: decisão de produto necessária — qual rota seguir
EOF
  out="$(_ck --file "$F" --task-id TASK-07)" || _fail script-4 "contracontrole 2 reprovou: $out"
  grep -q "^OK " <<<"$out" || _fail script-4 "saída sem OK: $out"
  echo "OK [script-4] — $out"

  _scn "[script-5] tasks.md: TASK inexistente/sem [!] → rc 2 (erro de uso, não violação)"
  F="$T/tasks1.md"
  set +e; out="$(_ck --file "$F" --task-id TASK-99)"; rc=$?; set -e
  [ "$rc" -eq 2 ] || _fail script-5 "esperado rc 2, obtido $rc — $out"
  echo "OK [script-5] — $out"

  # --- PROGRESS-TRACKING.md ---
  _scn "[script-6] PROGRESS-TRACKING.md: 1ª ocorrência do par (TASK, Gate) sem campos → aceito (ainda não é 2ª)"
  F="$T/PROGRESS-TRACKING.md"
  cat > "$F" <<'EOF'
## ⚠️ Última falha — Wave 3 / TASK-01 (1ª ocorrência)

**Quando:** 2026-05-10 22:00
**Gate:** `dotnet build`
**Sintoma:** falhou
EOF
  out="$(_ck --file "$F" --task-id TASK-01)" || _fail script-6 "1ª ocorrência reprovou: $out"
  echo "OK [script-6] — $out"

  _scn "[script-7] PROGRESS-TRACKING.md: 2ª ocorrência consecutiva do mesmo par sem campos → reprovado"
  cat >> "$F" <<'EOF'

## ⚠️ Última falha — Wave 3 / TASK-01 (2ª ocorrência desta TASK neste gate)

**Quando:** 2026-05-10 22:23
**Gate:** `dotnet build`
**Sintoma:** falhou de novo
EOF
  set +e; out="$(_ck --file "$F" --task-id TASK-01)"; rc=$?; set -e
  [ "$rc" -eq 1 ] || _fail script-7 "esperado rc 1, obtido $rc — $out"
  echo "OK [script-7] — $out"

  _scn "[script-8] PROGRESS-TRACKING.md: 3ª ocorrência com Premissa/Ator(es) preenchidos (retomada informada) → aceito"
  cat >> "$F" <<'EOF'

## ⚠️ Última falha — Wave 3 / TASK-01 (3ª ocorrência, retomada informada)

**Quando:** 2026-05-11 09:00
**Gate:** `dotnet build`
**Sintoma:** falhou outra vez
**Premissa:** a suposição compartilhada
**Ator(es) com o desequilíbrio:** fulano
EOF
  out="$(_ck --file "$F" --task-id TASK-01)" || _fail script-8 "retomada informada reprovou: $out"
  echo "OK [script-8] — $out"

  _scn "[script-9] PROGRESS-TRACKING.md: reinvocação após retomada informada abre série nova (1ª do par outra vez) → aceito sem campos"
  cat >> "$F" <<'EOF'

## ⚠️ Última falha — Wave 3 / TASK-01 (reinvocação pós retomada informada)

**Quando:** 2026-05-12 09:00
**Gate:** `dotnet build`
**Sintoma:** nova tentativa
EOF
  out="$(_ck --file "$F" --task-id TASK-01)" || _fail script-9 "série nova reprovou: $out"
  echo "OK [script-9] — $out"

  _scn "[script-10] PROGRESS-TRACKING.md: gate DIFERENTE da mesma TASK é sempre 1ª ocorrência desse par → aceito"
  F2="$T/PROGRESS-TRACKING-2.md"
  cat > "$F2" <<'EOF'
## ⚠️ Última falha — Wave 3 / TASK-02 (1ª ocorrência, gate A)

**Quando:** 2026-05-10 22:00
**Gate:** `dotnet build`
**Sintoma:** falhou

## ⚠️ Última falha — Wave 3 / TASK-02 (1ª ocorrência, gate B — diferente do anterior)

**Quando:** 2026-05-10 23:00
**Gate:** `npm test`
**Sintoma:** falhou noutro gate
EOF
  out="$(_ck --file "$F2" --task-id TASK-02)" || _fail script-10 "gate diferente tratado como 2ª ocorrência: $out"
  echo "OK [script-10] — $out"

  # --- --list ---
  _scn "[script-11] --list em tasks.md e PROGRESS-TRACKING.md lista toda TASK com Premissa/Ator(es) preenchidos"
  out="$(_ck --list --file "$T/tasks1.md")" || _fail script-11 "--list tasks.md reprovou: $out"
  grep -q "TASK-04" <<<"$out" || _fail script-11 "--list tasks.md não listou TASK-04: $out"
  out="$(_ck --list --file "$F")" || _fail script-11 "--list PROGRESS-TRACKING.md reprovou: $out"
  grep -q "TASK-01" <<<"$out" || _fail script-11 "--list PROGRESS-TRACKING.md não listou TASK-01: $out"
  out="$(_ck --list --file "$T/tasks3.md")" || _fail script-11 "--list sem premissa reprovou: $out"
  grep -q "^0 premissa" <<<"$out" || _fail script-11 "--list sem premissa deveria declarar 0: $out"
  echo "OK [script-11] — listagem funcional nos dois formatos"

  _scn "[script-12] erro de uso: sem --file, arquivo inexistente e flag desconhecida reprovam com rc 2"
  set +e; out="$(_ck --task-id TASK-01)"; rc=$?; set -e
  [ "$rc" -eq 2 ] || _fail script-12 "sem --file deveria sair 2 — rc=$rc: $out"
  set +e; out="$(_ck --file "$T/nao-existe.md" --task-id TASK-01)"; rc=$?; set -e
  [ "$rc" -eq 2 ] || _fail script-12 "arquivo inexistente deveria sair 2 — rc=$rc: $out"
  set +e; out="$(_ck --file "$F" --task-id TASK-01 --bogus x)"; rc=$?; set -e
  [ "$rc" -eq 2 ] || _fail script-12 "flag desconhecida deveria sair 2 — rc=$rc: $out"
  echo "OK [script-12] — 3 erros de uso com rc 2"
fi

# ──────────────────── implement-wiring (TASK-02: REQ-01/REQ-02) ────────────────────
if _want implement-wiring; then
  IMPL="$WS/template/.forge/commands/specs/implement.md"

  _scn "[implement-wiring-1] âncora real do HALT intacta (literal, com os negritos originais)"
  grep -qF '**Falha irrecuperável** (gate falha após 2 tentativas de correção, dependência externa indisponível, decisão de produto necessária): marque `[!]`, **pare a execução** e reporte o que travou' "$IMPL" \
    || _fail implement-wiring-1 "âncora literal do HALT ausente/drift em $IMPL"
  echo "OK [implement-wiring-1] — âncora do HALT presente"

  _scn "[implement-wiring-2] bloco 'Premissa nomeada' nomeia os três campos e a causa específica, imediatamente após a âncora"
  AFTER="$(awk '/pare a execução\*\* e reporte o que travou/{f=1} f{print; c++} c>40{exit}' "$IMPL")"
  grep -qF 'Premissa nomeada' <<<"$AFTER" || _fail implement-wiring-2 "parágrafo 'Premissa nomeada' ausente após a âncora: $IMPL"
  for campo in "Gate:" "Premissa:" "Ator(es) com o desequilíbrio:"; do
    grep -qF "$campo" <<<"$AFTER" || _fail implement-wiring-2 "campo '$campo' ausente no bloco: $IMPL"
  done
  grep -qF 'gate falha após 2 tentativas de correção' <<<"$AFTER" || _fail implement-wiring-2 "causa específica não citada no bloco: $IMPL"
  echo "OK [implement-wiring-2] — Gate/Premissa/Ator(es) e causa citados"

  _scn "[implement-wiring-3] chamada real a check-attack-premise.sh --file tasks.md --task-id, condicionada à causa"
  grep -qF 'check-attack-premise.sh --file tasks.md --task-id' <<<"$AFTER" \
    || _fail implement-wiring-3 "chamada ao script ausente/flags divergentes: $IMPL"
  echo "OK [implement-wiring-3] — chamada ao script presente com as flags documentadas"

  _scn "[implement-wiring-4] pré-condição de retomada no pré-flight (passo 1) recusa retomar [!] sem os campos"
  PRE1="$(awk '/^1\. Status `tasks-ready`/{f=1} f{print} /^2\./{exit}' "$IMPL")"
  grep -qF 'check-attack-premise.sh' <<<"$PRE1" || _fail implement-wiring-4 "pré-flight não chama o script antes de retomar: $IMPL"
  grep -qiE 'recuse a retomada' <<<"$PRE1" || _fail implement-wiring-4 "pré-flight não nomeia a recusa de retomada: $IMPL"
  echo "OK [implement-wiring-4] — pré-condição de retomada presente no passo 1"
fi

# ──────────────────── coding-loop-wiring (TASK-03/04: REQ-01/REQ-02) ────────────────────
if _want coding-loop-wiring; then
  CODER="$WS/template/.forge/agents/coding/task-coder.md"

  _scn "[coding-loop-wiring-1] §3.7 — bloco 'Última falha' acumula (nunca sobrescreve) e ganha o campo Gate"
  grep -qiE 'nunca sobrescreva' "$CODER" || _fail coding-loop-wiring-1 "instrução de nunca sobrescrever ausente: $CODER"
  grep -qF '**Gate:**' "$CODER" || _fail coding-loop-wiring-1 "campo **Gate:** ausente no bloco: $CODER"
  echo "OK [coding-loop-wiring-1] — bloco acumulativo com campo Gate"

  _scn "[coding-loop-wiring-2] §3.7 — Premissa/Ator(es) e chamada ao check-attack-premise.sh sobre PROGRESS-TRACKING.md"
  SEC37="$(awk '/#### 3\.7 Falha/{f=1} f{print} /^### Fase 4/{exit}' "$CODER")"
  grep -qF '**Premissa:**' <<<"$SEC37" || _fail coding-loop-wiring-2 "campo **Premissa:** ausente em §3.7"
  grep -qF '**Ator(es) com o desequilíbrio:**' <<<"$SEC37" || _fail coding-loop-wiring-2 "campo **Ator(es) com o desequilíbrio:** ausente em §3.7"
  grep -qF 'check-attack-premise.sh --file docs/product/modules' <<<"$SEC37" || _fail coding-loop-wiring-2 "chamada ao script ausente em §3.7"
  echo "OK [coding-loop-wiring-2] — campos e chamada ao script em §3.7"

  _scn "[coding-loop-wiring-3] preflight recusa reabrir onda com [!] pendente sem os campos"
  PRE="$(awk '/falha pendente de revisão humana/{f=1} f{print; c++} c>5{exit}' "$CODER")"
  grep -qF 'check-attack-premise.sh' <<<"$PRE" || _fail coding-loop-wiring-3 "preflight não chama o script: $CODER"
  grep -qiE 'recuse reabrir' <<<"$PRE" || _fail coding-loop-wiring-3 "preflight não nomeia a recusa: $CODER"
  echo "OK [coding-loop-wiring-3] — preflight com pré-condição de retomada"

  _scn "[coding-loop-wiring-4] documentação do mecanismo acumulativo e receita 'Premissa nomeada' em coding-loop.md/coding-status.md/session-discipline.md/gate-runner SKILL.md"
  LOOP="$WS/template/.forge/commands/coding/coding-loop.md"
  STATUS="$WS/template/.forge/commands/coding/coding-status.md"
  DISC="$WS/template/.forge/rules/conventions/session-discipline.md"
  SKILL="$WS/template/.forge/skills/gate-runner/SKILL.md"
  for f in "$LOOP" "$STATUS" "$DISC" "$SKILL"; do [ -f "$f" ] || _fail coding-loop-wiring-4 "arquivo ausente: $f"; done
  grep -qiE 'acumul' "$LOOP" || _fail coding-loop-wiring-4 "coding-loop.md não documenta o bloco acumulativo"
  grep -qiE 'acumul' "$STATUS" || _fail coding-loop-wiring-4 "coding-status.md não documenta o bloco acumulativo"
  grep -qF 'Premissa nomeada' "$DISC" || _fail coding-loop-wiring-4 "session-discipline.md sem referência a 'Premissa nomeada'"
  grep -qF 'Premissa nomeada' "$SKILL" || _fail coding-loop-wiring-4 "gate-runner/SKILL.md sem a receita 'Premissa nomeada'"
  echo "OK [coding-loop-wiring-4] — documentação do mecanismo nos 4 arquivos"
fi

# ───────────────────────────── fechamento ─────────────────────────────
if [ "$GROUP" = all ]; then sel="$ALL_GROUPS"; else sel="$GROUP"; fi
DECL=0; for g in $sel; do DECL=$((DECL + $(declare_scn "$g"))); done
[ "$SCN" -gt 0 ] || _fail final "nenhum cenário executado para '$GROUP'"
[ "$SCN" -eq "$DECL" ] || _fail final "$SCN cenário(s) executado(s), $DECL declarado(s) para '$GROUP' — cenário perdido ou não declarado"
echo "PASS adopt-ub-mode-practices ($GROUP: $SCN cenário(s))"
