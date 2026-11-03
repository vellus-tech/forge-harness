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

declare_scn() { case "$1" in script) echo 12;; implement-wiring) echo 4;; coding-loop-wiring) echo 4;; human-wiring) echo 3;; premise-mutation) echo 7;; suppression-grammar) echo 10;; suppression-wiring) echo 4;; suppression-mutation) echo 0;; spike) echo 0;; esac; }
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

# ──────────────────── human-wiring (TASK-05: REQ-01) ────────────────────
if _want human-wiring; then
  VERIFY="$WS/template/.forge/commands/specs/verify.md"
  ARCHIVE="$WS/template/.forge/commands/specs/archive.md"

  _scn "[human-wiring-1] verify.md ganha a seção '## Premissas atacadas' gerada por --list"
  grep -qF '## Premissas atacadas' "$VERIFY" || _fail human-wiring-1 "seção ausente em $VERIFY"
  grep -qF 'check-attack-premise.sh --list' "$VERIFY" || _fail human-wiring-1 "chamada --list ausente em $VERIFY"
  echo "OK [human-wiring-1] — seção e chamada --list presentes"

  _scn "[human-wiring-2] archive.md §2 ganha a linha de contagem derivada de 'Premissas atacadas'"
  SEC2="$(awk '/^## 2\. Gate HITL/{f=1} f{print} /^## 3\./{exit}' "$ARCHIVE")"
  grep -qF 'Premissas atacadas' <<<"$SEC2" || _fail human-wiring-2 "linha de contagem ausente em archive.md §2"
  grep -qF 'verification.md' <<<"$SEC2" || _fail human-wiring-2 "referência a verification.md ausente em archive.md §2"
  echo "OK [human-wiring-2] — linha de contagem presente no resumo que o humano lê"

  _scn "[human-wiring-3] comportamental: check-attack-premise.sh --list roda sobre fixture e produz saída consumível pela seção documentada"
  F="$T/human1.md"
  cat > "$F" <<'EOF'
- [!] TASK-09 — algo (rastreia: REQ-02; paths: x)
  > FALHA: gate falha após 2 tentativas de correção — sintoma
  > Gate: npm test
  > Premissa: suposição
  > Ator(es) com o desequilíbrio: fulano
EOF
  out="$(bash "$SCRIPT" --list --file "$F")" || _fail human-wiring-3 "--list reprovou: $out"
  grep -q "TASK-09" <<<"$out" || _fail human-wiring-3 "saída do --list não lista TASK-09: $out"
  echo "OK [human-wiring-3] — --list produz a listagem que a seção documentada consome"
fi

# ──────────────────── premise-mutation (TASK-06: REQ-02) ────────────────────
# Controle → mutação → recontrole, padrão w198-liaison-push-union-gate.sh: cada mutante
# tem de fazer o CENÁRIO QUE O COBRE falhar, e a restauração é bit-a-bit (`cmp`) antes de
# qualquer avaliação — nunca deixamos a árvore mutada se algo sair errado no meio.
if _want premise-mutation; then
  _mutate_and_check() { # _mutate_and_check <label> <file> <perl-expr> <check-fn>
    local label="$1" file="$2" expr="$3" checkfn="$4"
    cp "$file" "$T/orig.bak"
    set +e; "$checkfn" >/tmp/mut-control.log 2>&1; local ctrl=$?; set -e
    [ "$ctrl" -eq 0 ] || _fail "$label" "controle já falhava antes da mutação: $(cat /tmp/mut-control.log)"
    perl -0777 -pi -e "$expr" "$file"
    cmp -s "$file" "$T/orig.bak" && { cp "$T/orig.bak" "$file"; _fail "$label" "a mutação não alterou o arquivo"; }
    set +e; "$checkfn" >/tmp/mut-mutant.log 2>&1; local mut=$?; set -e
    cp "$T/orig.bak" "$file"
    cmp -s "$file" "$T/orig.bak" || _fail "$label" "restauração não bateu (cmp)"
    set +e; "$checkfn" >/tmp/mut-recontrole.log 2>&1; local recontrole=$?; set -e
    [ "$recontrole" -eq 0 ] || _fail "$label" "recontrole falhou: $(cat /tmp/mut-recontrole.log)"
    [ "$mut" -ne 0 ] || _fail "$label" "mutante sobreviveu — nenhum cenário o mata"
  }

  SCPT="$WS/template/.forge/scripts/check-attack-premise.sh"
  IMPL="$WS/template/.forge/commands/specs/implement.md"
  CODER="$WS/template/.forge/agents/coding/task-coder.md"
  ARCHIVE="$WS/template/.forge/commands/specs/archive.md"
  VERIFY="$WS/template/.forge/commands/specs/verify.md"
  FV="$T/mutviol.md"
  cat > "$FV" <<'EOF'
- [!] TASK-05 — algo (rastreia: REQ-02; paths: x)
  > FALHA: gate falha após 2 tentativas de correção — sintoma objetivo
  > Gate: dotnet build
EOF

  _scn "[premise-mutation-1] checagem interna: sem a validação, violação deixa de ser reprovada"
  _check_internal() { ! bash "$SCPT" --file "$FV" --task-id TASK-05 >/dev/null 2>&1; } # true (rc0) = violação reprovada como esperado
  _mutate_and_check premise-mutation-1 "$SCPT" 's/if \(faltando\.length > 0\) \{/if (false) {/' _check_internal
  echo "OK [premise-mutation-1] — checagem interna é a causa real da reprovação"

  _scn "[premise-mutation-2] ponto de chamada 1 (implement.md, Loop/HALT): removê-lo faz implement-wiring-3 cair"
  _check_call1() { AFTER="$(awk '/pare a execução\*\* e reporte o que travou/{f=1} f{print; c++} c>40{exit}' "$IMPL")"; grep -qF 'check-attack-premise.sh --file tasks.md --task-id' <<<"$AFTER"; }
  _mutate_and_check premise-mutation-2 "$IMPL" 's/Rode `bash \.forge\/scripts\/check-attack-premise\.sh --file tasks\.md --task-id <TASK-NN>`: reprovado, complete os campos antes de emitir o relatório de HALT ao humano — não reporte com os campos vazios\.//' _check_call1
  echo "OK [premise-mutation-2] — a chamada no Loop/HALT é a causa real do implement-wiring-3"

  _scn "[premise-mutation-3] ponto de chamada 2 (task-coder.md §3.7): removê-lo faz coding-loop-wiring-2 cair"
  _check_call2() { SEC37="$(awk '/#### 3\.7 Falha/{f=1} f{print} /^### Fase 4/{exit}' "$CODER")"; grep -qF 'check-attack-premise.sh --file docs/product/modules' <<<"$SEC37"; }
  _mutate_and_check premise-mutation-3 "$CODER" 's/Depois de escrever o bloco, rode `bash \.forge\/scripts\/check-attack-premise\.sh --file docs\/product\/modules\/<modulo>\/PROGRESS-TRACKING\.md --task-id <TASK-NN>`: reprovado, complete os campos antes de declarar o HALT\.//' _check_call2
  echo "OK [premise-mutation-3] — a chamada em §3.7 é a causa real do coding-loop-wiring-2"

  _scn "[premise-mutation-4] pré-condição de retomada 1 (implement.md, preflight): removê-la faz implement-wiring-4 cair"
  _check_resume1() { PRE1="$(awk '/^1\. Status \`tasks-ready\`/{f=1} f{print} /^2\./{exit}' "$IMPL")"; grep -qiE 'recuse a retomada' <<<"$PRE1"; }
  _mutate_and_check premise-mutation-4 "$IMPL" 's/\*\*recuse a retomada\*\*/**aceite a retomada**/' _check_resume1
  echo "OK [premise-mutation-4] — a pré-condição no preflight do implement.md é a causa real do implement-wiring-4"

  _scn "[premise-mutation-5] pré-condição de retomada 2 (task-coder.md, preflight): removê-la faz coding-loop-wiring-3 cair"
  _check_resume2() { PRE="$(awk '/falha pendente de revisão humana/{f=1} f{print; c++} c>5{exit}' "$CODER")"; grep -qiE 'recuse reabrir' <<<"$PRE"; }
  _mutate_and_check premise-mutation-5 "$CODER" 's/\*\*recuse reabrir a onda\*\*/**aceite reabrir a onda**/' _check_resume2
  echo "OK [premise-mutation-5] — a pré-condição no preflight do task-coder.md é a causa real do coding-loop-wiring-3"

  _scn "[premise-mutation-6] linha de archive.md §2: removê-la faz human-wiring-2 cair"
  _check_archive() { SEC2="$(awk '/^## 2\. Gate HITL/{f=1} f{print} /^## 3\./{exit}' "$ARCHIVE")"; grep -qF 'Premissas atacadas' <<<"$SEC2"; }
  _mutate_and_check premise-mutation-6 "$ARCHIVE" 's/ \*\*mais uma linha derivada da contagem de `## Premissas atacadas` em `verification\.md`\*\* \("N premissa\(s\) atacada\(s\) nesta implementação — ver verification\.md"; N=0 também é mostrado, nunca omitido\)//' _check_archive
  echo "OK [premise-mutation-6] — a linha de archive.md §2 é a causa real do human-wiring-2"

  _scn "[premise-mutation-7] chamada --list de verify.md: removê-la faz human-wiring-1 cair"
  _check_verifylist() { grep -qF 'check-attack-premise.sh --list' "$VERIFY"; }
  _mutate_and_check premise-mutation-7 "$VERIFY" 's/check-attack-premise\.sh --list/SCRIPT-REMOVIDO/g' _check_verifylist
  echo "OK [premise-mutation-7] — a chamada --list em verify.md é a causa real do human-wiring-1"
fi

# ──────────────────── suppression-grammar (TASK-07/08/09: REQ-03/REQ-04) ────────────────────
if _want suppression-grammar; then
  SUPSCRIPT="$WS/template/.forge/scripts/check-suppression-reference.sh"
  _grepo() { # _grepo <dir> — repo git sintético, SEM remote, com um commit base (src/a.js vazio)
    local d="$1"; mkdir -p "$d/src"
    git -C . init -q "$d" 2>/dev/null || git init -q "$d"
    printf 'function f() {\n  return 1;\n}\n' > "$d/src/a.js"
    git -C "$d" add -A
    git -C "$d" -c user.email=t@t -c user.name=t commit -q -m base
  }
  _stage() { # _stage <dir> <file-relative> <conteúdo>
    printf '%s' "$3" > "$1/$2"
    git -C "$1" add -A
  }
  _run_staged() { ( cd "$1" && bash "$SUPSCRIPT" --staged ); } # roda no cwd do fixture (git rev-parse --show-toplevel usa cwd)

  _scn "[grammar-1] LDG-NNNN/ADR-NNNN/ISSUE-NNN (case-insensitive) contam como referência válida"
  F="$T/g1"; _grepo "$F"
  _stage "$F" src/a.js 'function f() {
  // eslint-disable-next-line no-unused-vars -- ver ldg-0007
  return 1;
}
'
  out="$(_run_staged "$F")" || _fail grammar-1 "LDG minúsculo reprovou: $out"
  _stage "$F" src/a.js 'function f() {
  // eslint-disable-next-line no-unused-vars -- ADR-0002
  return 1;
}
'
  out="$(_run_staged "$F")" || _fail grammar-1 "ADR reprovou: $out"
  echo "OK [grammar-1] — $out"

  _scn "[grammar-2] issue/closes/fixes/ver #NNN (case-insensitive, fronteira de palavra) válido; 'never #12'/'prefixes #3' NÃO casam"
  F="$T/g2"; _grepo "$F"
  _stage "$F" src/a.js 'function f() {
  // eslint-disable-next-line no-unused-vars -- Closes #45
  return 1;
}
'
  out="$(_run_staged "$F")" || _fail grammar-2 "'Closes #45' deveria passar: $out"
  _stage "$F" src/a.js 'function f() {
  // eslint-disable-next-line no-unused-vars -- never #12
  return 1;
}
'
  set +e; out="$(_run_staged "$F")"; rc=$?; set -e
  [ "$rc" -ne 0 ] || _fail grammar-2 "'never #12' não deveria casar a palavra-chave: $out"
  echo "OK [grammar-2] — $out"

  _scn "[grammar-3] '#NNN' bare (cor hex) NUNCA conta como referência — reprova"
  F="$T/g3"; _grepo "$F"
  _stage "$F" src/a.js 'function f() {
  // eslint-disable-next-line no-unused-vars -- cor #123
  return 1;
}
'
  set +e; out="$(_run_staged "$F")"; rc=$?; set -e
  [ "$rc" -eq 1 ] || _fail grammar-3 "esperado rc 1, obtido $rc — $out"
  echo "OK [grammar-3] — $out"

  _scn "[grammar-4] @ts-nocheck entra na lista de supressões cobertas"
  F="$T/g4"; _grepo "$F"
  _stage "$F" src/a.js '// @ts-nocheck
function f() {
  return 1;
}
'
  set +e; out="$(_run_staged "$F")"; rc=$?; set -e
  [ "$rc" -eq 1 ] || _fail grammar-4 "@ts-nocheck sem referência deveria reprovar: $out"
  echo "OK [grammar-4] — $out"

  _scn "[grammar-5] Python '# noqa' e '# type: ignore' cobertos"
  F="$T/g5"; _grepo "$F"
  _stage "$F" src/a.py 'def f():
    return 1  # noqa
'
  set +e; out="$(_run_staged "$F")"; rc=$?; set -e
  [ "$rc" -eq 1 ] || _fail grammar-5 "# noqa sem referência deveria reprovar: $out"
  _stage "$F" src/a.py 'def f():
    return 1  # type: ignore -- ISSUE-9
'
  out="$(_run_staged "$F")" || _fail grammar-5 "# type: ignore com ISSUE-9 deveria aceitar: $out"
  echo "OK [grammar-5] — $out"

  _scn "[grammar-6] código gerado excluído por glob (_pb2.py) e por cabeçalho (@generated)"
  F="$T/g6"; _grepo "$F"
  _stage "$F" src/x_pb2.py 'def f():
    return 1  # noqa
'
  out="$(_run_staged "$F")" || _fail grammar-6 "_pb2.py deveria ser excluído (glob): $out"
  _stage "$F" src/y.py '# @generated — DO NOT EDIT
def f():
    return 1  # noqa
'
  out="$(_run_staged "$F")" || _fail grammar-6 "cabeçalho @generated deveria excluir o arquivo: $out"
  echo "OK [grammar-6] — $out"

  _scn "[grammar-7] .forge/** da RAIZ excluído (um nível); template/.forge/ IRMÃO fica visível"
  F="$T/g7"; _grepo "$F"
  mkdir -p "$F/.forge/scripts" "$F/template/.forge/scripts"
  _stage "$F" .forge/scripts/x.js '// eslint-disable-next-line no-unused-vars
function f() { return 1; }
'
  out="$(_run_staged "$F")" || _fail grammar-7 ".forge/ da raiz deveria ser excluído: $out"
  _stage "$F" template/.forge/scripts/x.js '// eslint-disable-next-line no-unused-vars
function f() { return 1; }
'
  set +e; out="$(_run_staged "$F")"; rc=$?; set -e
  [ "$rc" -eq 1 ] || _fail grammar-7 "template/.forge/ (irmão) deveria continuar visível: $out"
  echo "OK [grammar-7] — $out"

  _scn "[grammar-8] sem origin/develop acessível (sem remote algum): fallback resolve pelo commit raiz, nunca aprova por diff vazio — Red real"
  F="$T/g8"; mkdir -p "$F/src"
  git init -q "$F"
  printf 'function f() {\n  return 1;\n}\n' > "$F/src/a.js"
  git -C "$F" add -A; git -C "$F" -c user.email=t@t -c user.name=t commit -q -m base
  _stage "$F" src/a.js 'function f() {
  // eslint-disable-next-line no-unused-vars
  return 1;
}
'
  set +e; out="$(_run_staged "$F")"; rc=$?; set -e
  [ "$rc" -eq 1 ] || _fail grammar-8 "sem remote, violação real deveria reprovar (nunca diff vazio): rc=$rc — $out"
  grep -qF "src/a.js" <<<"$out" || _fail grammar-8 "saída não aponta o arquivo — suspeita de diff vazio: $out"
  echo "OK [grammar-8] — $out"

  _scn "[grammar-9] --range <base>...<head> (modo pre-push, base já resolvida) e erro de uso sem --staged/--range"
  F="$T/g9"; _grepo "$F"
  BASE_SHA="$(git -C "$F" rev-parse HEAD)"
  printf 'function f() {\n  // eslint-disable-next-line no-unused-vars\n  return 1;\n}\n' > "$F/src/a.js"
  git -C "$F" add -A; git -C "$F" -c user.email=t@t -c user.name=t commit -q -m violacao
  HEAD_SHA="$(git -C "$F" rev-parse HEAD)"
  set +e; out="$(cd "$F" && bash "$SUPSCRIPT" --range "$BASE_SHA...$HEAD_SHA")"; rc=$?; set -e
  [ "$rc" -eq 1 ] || _fail grammar-9 "--range deveria reprovar a violação: rc=$rc — $out"
  set +e; out="$(cd "$F" && bash "$SUPSCRIPT")"; rc=$?; set -e
  [ "$rc" -eq 2 ] || _fail grammar-9 "sem --staged/--range deveria sair 2 (erro de uso): rc=$rc — $out"
  echo "OK [grammar-9] — --range funcional; erro de uso reprova com rc 2"

  _scn "[grammar-10] .forge/suppression-scan-exclude.txt do consumidor: glob com '# motivo:' exclui; linha sem motivo reprova por integridade"
  F="$T/g10"; _grepo "$F"
  mkdir -p "$F/.forge" "$F/vendor"
  printf 'legado/**  # motivo: código de terceiros congelado, não editamos\n' > "$F/.forge/suppression-scan-exclude.txt"
  mkdir -p "$F/legado"
  _stage "$F" legado/old.js 'function f() {
  // eslint-disable-next-line no-unused-vars
  return 1;
}
'
  out="$(_run_staged "$F")" || _fail grammar-10 "glob com motivo deveria excluir legado/**: $out"
  printf 'legado/**\n' > "$F/.forge/suppression-scan-exclude.txt"
  set +e; out="$(_run_staged "$F")"; rc=$?; set -e
  [ "$rc" -eq 1 ] || _fail grammar-10 "linha sem '# motivo:' deveria reprovar por integridade: rc=$rc — $out"
  grep -qiE "motivo" <<<"$out" || _fail grammar-10 "mensagem não nomeia a exigência de motivo: $out"
  echo "OK [grammar-10] — exclusão do consumidor funcional; integridade sem motivo reprova"
fi

# ──────────────────── suppression-wiring (TASK-10/11: REQ-03/REQ-04) ────────────────────
if _want suppression-wiring; then
  SHIP="$WS/template/.forge/commands/git/ship.md"
  PREPUSH="$WS/template/.forge/hooks/git/pre-push"
  SKILL2="$WS/template/.forge/skills/gate-runner/SKILL.md"
  QGATES="$WS/template/.forge/rules/testing/quality-gates.md"

  _scn "[wiring-1] ship.md passo 3 (antes do commit do passo 4) chama check-suppression-reference.sh --staged"
  SEC3="$(awk '/^3\. \*\*Testes\/gates do FORGE\.md\.\*\*/{f=1} f{print} /^## Commit\(s\)/{exit}' "$SHIP")"
  grep -qF 'check-suppression-reference.sh --staged' <<<"$SEC3" || _fail wiring-1 "ship.md passo 3 não chama o script --staged"
  echo "OK [wiring-1] — ship.md passo 3 chama o scanner antes do commit"

  _scn "[wiring-2] pre-push chama check-suppression-reference.sh --range reusando _redfirst_resolve_base"
  BLOCK="$(awk '/>>> suppression-reference BEGIN/{f=1} f{print} /<<< suppression-reference END/{exit}' "$PREPUSH")"
  [ -n "$BLOCK" ] || _fail wiring-2 "âncoras de extração BEGIN/END ausentes em pre-push"
  grep -qF '_redfirst_resolve_base' <<<"$BLOCK" || _fail wiring-2 "pre-push não reusa _redfirst_resolve_base"
  grep -qF 'check-suppression-reference.sh' <<<"$BLOCK" || _fail wiring-2 "pre-push não referencia o script"
  grep -qF -- '--range' <<<"$BLOCK" || _fail wiring-2 "pre-push não chama o script com --range"
  echo "OK [wiring-2] — pre-push referencia o script, --range e o resolvedor de base"

  _scn "[wiring-3] comportamental: bloco extraído do pre-push bloqueia push com supressão suja e aceita push limpo"
  F="$T/wire3"; mkdir -p "$F/.forge/scripts" "$F/src"
  cp "$WS/template/.forge/scripts/check-suppression-reference.sh" "$F/.forge/scripts/check-suppression-reference.sh"
  chmod +x "$F/.forge/scripts/check-suppression-reference.sh"
  git init -q "$F"
  printf 'function f() {\n  return 1;\n}\n' > "$F/src/a.js"
  git -C "$F" add -A; git -C "$F" -c user.email=t@t -c user.name=t commit -q -m base
  BASE_SHA="$(git -C "$F" rev-parse HEAD)"
  printf 'function f() {\n  // eslint-disable-next-line no-unused-vars\n  return 1;\n}\n' > "$F/src/a.js"
  git -C "$F" add -A; git -C "$F" -c user.email=t@t -c user.name=t commit -q -m violacao
  DIRTY_SHA="$(git -C "$F" rev-parse HEAD)"

  RESOLVE_FN="$(awk '/^resolve_delegated\(\) \{/{f=1} f{print} f && /^}/{exit}' "$PREPUSH")"
  HARNESS="$T/wire3-harness.sh"
  {
    echo '#!/usr/bin/env bash'
    echo 'set -u'
    printf 'ROOT="%s"\n' "$F"
    printf 'export REPO="%s"\n' "$F"
    printf 'cd "%s" || exit 2\n' "$F"
    echo 'HOOK_FORGE_DIR=""'
    printf '%s\n' "$RESOLVE_FN"
    echo '. "'"$WS"'/template/.forge/hooks/git/lib/check-red-first.sh"'
    printf '%s\n' "$BLOCK"
  } > "$HARNESS"

  export INPUT="refs/heads/work $DIRTY_SHA refs/heads/work $BASE_SHA"
  set +e; out="$(bash "$HARNESS" 2>&1)"; rc=$?; set -e
  [ "$rc" -eq 1 ] || _fail wiring-3 "push sujo deveria bloquear (rc 1): rc=$rc — $out"
  grep -qiE "bloqueado" <<<"$out" || _fail wiring-3 "mensagem não nomeia o bloqueio: $out"

  export INPUT="refs/heads/work $BASE_SHA refs/heads/work 0000000000000000000000000000000000000000"
  set +e; out="$(bash "$HARNESS" 2>&1)"; rc=$?; set -e
  [ "$rc" -eq 0 ] || _fail wiring-3 "push limpo (sem violação) não deveria bloquear: rc=$rc — $out"
  unset INPUT
  echo "OK [wiring-3] — bloco real do pre-push bloqueia sujo e aceita limpo"

  _scn "[wiring-4] receita 'Supressão sem referência' em gate-runner/SKILL.md e linha nova em quality-gates.md"
  grep -qF "Supressão sem referência" "$SKILL2" || _fail wiring-4 "receita ausente em gate-runner/SKILL.md"
  grep -qF "check-suppression-reference.sh" "$SKILL2" || _fail wiring-4 "receita não cita o script"
  SECLINT="$(awk '/^## Portão de decisão para burndown de lint/{f=1} f{print} /^## Testes de Acessibilidade/{exit}' "$QGATES")"
  grep -qF "check-suppression-reference.sh" <<<"$SECLINT" || _fail wiring-4 "quality-gates.md sem linha citando o script novo"
  grep -qF -- "-- ver ISSUE-123" "$QGATES" || _fail wiring-4 "exemplo canônico '-- ver ISSUE-123' não deveria mudar"
  echo "OK [wiring-4] — receita e linha de enforcement presentes, exemplo canônico intacto"
fi

# ───────────────────────────── fechamento ─────────────────────────────
if [ "$GROUP" = all ]; then sel="$ALL_GROUPS"; else sel="$GROUP"; fi
DECL=0; for g in $sel; do DECL=$((DECL + $(declare_scn "$g"))); done
[ "$SCN" -gt 0 ] || _fail final "nenhum cenário executado para '$GROUP'"
[ "$SCN" -eq "$DECL" ] || _fail final "$SCN cenário(s) executado(s), $DECL declarado(s) para '$GROUP' — cenário perdido ou não declarado"
echo "PASS adopt-ub-mode-practices ($GROUP: $SCN cenário(s))"
