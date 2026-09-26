#!/usr/bin/env bash
# Gate W222 — heavy-run.sh não perde o trap de INT/TERM quando o sinal chega ignorado na entrada
# de um shell não interativo (issue #146).
#
# POR QUE ESTE GATE EXISTE. `heavy-run.sh` instala `trap "_hr_sig $s" "$s"` para INT/TERM/HUP e
# depende disso para sinalizar o grupo da carga e liberar o mutex de forma limpa. Bash recusa por
# POLÍTICA armar (ou resetar) `trap` sobre um sinal que já chegou IGNORADO na entrada do
# (sub)shell — "Signals ignored upon entry to a non-interactive shell cannot be trapped or reset"
# — e nenhuma reordenação de `trap` DENTRO do script resolve isso, porque a disposição já estava
# fechada antes da primeira linha executável. Sob push detached via nohup duplo-fork sem tty (o
# padrão que este próprio ecossistema recomenda para sobreviver ao watchdog do harness), o
# processo que lança `heavy-run.sh` pode entregar INT (ou TERM) já ignorado, e um `kill -INT`
# real durante esse push NUNCA aciona `_hr_sig`: a carga roda até o fim como se o sinal nunca
# tivesse chegado, e o mutex não é liberado a tempo — o mesmo desfecho que este primitivo existe
# para impedir.
#
# EIXO DE VERSÃO DO BASH (achado BLOCKER de correção). A sonda de armabilidade em
# `_hr_reset_ignored_signals` lê `trap -p` de volta: bash 3.2 imprime VAZIO quando a tentativa de
# armar um trap-sonda sobre sinal herdado como ignorado falhou, mas bash >=4 imprime o TRAP ANTIGO
# (não vazio) no mesmo caso — testar só "não-vazio" passa por acidente no 3.2 e dá falso-negativo
# no 5.x, e o reset nunca dispara. Este gate roda os cenários [1]-[6] uma vez por INTERPRETADOR
# bash de major version distinta encontrado na máquina (pelo menos o `bash` do PATH; mais
# `/opt/homebrew/bin/bash` e `/usr/local/bin/bash` quando existirem e forem de outra major
# version) — `W222_BASHES` sobrescreve a lista de candidatos (separada por espaço).
#
# ISOLAMENTO. Todo cenário resolve dentro de `FORGE_HEAVY_MUTEX_ROOT` (mktemp) com
# `FORGE_HEAVY_MUTEX_TESTING=1` — a suíte NUNCA toca o lock real da máquina. Todo processo de
# teste criado é rastreado por PID (do processo lançador ATÉ o payload, por parentesco — `exec`
# preserva o PID ao longo da cadeia de reexecução) e morto no cleanup: um teste de heavy-run que
# ignora sinal não pode deixar `sleep` pendurado no init. O payload também publica o PRÓPRIO pid
# em `payload.pid` antes de virar `sleep` (achado MEDIUM de correção): a checagem de "morto" por
# `pgrep -P` enxerga só quem continua filho do lançador, e é cega a exatamente o caso que o #146
# media — o lançador morre e o payload é REPARENTADO ao init, sumindo da árvore de parentesco
# sem sumir do processo. A prova de morte é por `kill -0` no PID publicado, nunca só por árvore.
#
#   [1] controle — INT padrão na entrada: rc 130, payload morto, em menos de 3s DEPOIS do sinal.
#   [2] caso — INT IGNORADO na entrada (herdado, ex.: `trap '' INT; exec ...`): depois da
#       correção, rc 130 e payload morto em menos de 3s do sinal — sem a correção, rc 0 e ~12s (a
#       carga correu até o fim; ver mutação no PR).
#   [3] controle — TERM padrão na entrada: rc 143, payload morto, em menos de 3s do sinal.
#   [4] caso — TERM IGNORADO na entrada: rc 143, payload morto, em menos de 3s do sinal.
#   [5] HUP ignorado na entrada, com INT também ignorado (força a reexecução): a disposição de
#       HUP atravessa a reexecução SEM ser alterada — continua ignorada, então `kill -HUP` não
#       interrompe o payload, que termina sozinho pelo fim natural do comando.
#   [6] HUP padrão na entrada, com INT ignorado (força a reexecução): a disposição de HUP
#       atravessa a reexecução SEM ser alterada — continua padrão, o trap dispara normalmente e
#       `kill -HUP` mata com rc 129 em menos de 3s do sinal (prova que a correção não quebra o
#       caminho HUP que já funcionava).
#   [7] sem `perl` no PATH: com INT ignorado na entrada, a correção não pode resetar a
#       disposição — recusa com rc 70 e diagnóstico que nomeia 'perl', em vez de rodar a carga
#       sem trap.
#   [8] a guarda `_HR_SIG_RESET` não vaza para a carga (achado MEDIUM de correção): um heavy-run.sh
#       ANINHADO dentro do próprio payload, lançado por `&` sem `set -m` (herda INT ignorado por
#       regra POSIX de lista assíncrona sem controle de job — o mesmo mecanismo que o comentário
#       de `set -m` em heavy-run.sh descreve para o próprio wrapper), precisa da SUA PRÓPRIA
#       tentativa de reset — sem a correção, ele lê a guarda do pai como se já tivesse tentado e
#       recusa com rc 70 sem nunca ter tentado.
#
# TEMPO (achado HIGH de correção). O teto de cada cenário é medido a partir do SINAL, não do
# lançamento — o relógio de granularidade de segundo do bash embutia ~2s de overhead de
# lançamento dentro de um teto de 3s, e a fração de segundo em que o relógio caía decidia o
# resultado (medido: 3 falhas em 17 execuções em HEAD, sem mutação nenhuma). A medição usa
# `perl -MTime::HiRes` (milissegundos) e o teto passa a valer "segundos depois do sinal".
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HR="$WS/template/.forge/scripts/heavy-run.sh"
T="$(mktemp -d /tmp/forge-w222.XXXXXX)"

[ -f "$HR" ] || { echo "FAIL [setup]: $HR não existe"; exit 1; }
command -v perl >/dev/null 2>&1 \
  || { echo "FAIL [setup]: 'perl' não está no PATH — necessário para medir tempo com precisão sub-segundo"; exit 1; }

# Duração longa e sinteticamente distintiva (embute o ordinal e a issue) para os cenários que
# sinalizam cedo — nunca chega a ser esperada de verdade, e serve de marcador legível no `ps`
# durante depuração manual. O critério de vivo/morto do gate é DUPLO: por PARENTESCO de PID
# (pgrep -P, nunca por casar texto de argv) E pelo PID que o próprio payload publica (ver acima).
DUR_LONG=222146

PIDFILE="$T/fixture-pids"
: > "$PIDFILE"
track() { printf '%s\n' "$1" >> "$PIDFILE"; }
_kill_tree() {  # _kill_tree <pid> — mata o pid e todo filho direto (a cadeia exec preserva o
  # PID do lançador até o heavy-run.sh final; o payload é um FILHO real, com PID próprio)
  local pid="$1" c
  [ -n "$pid" ] || return 0
  for c in $(pgrep -P "$pid" 2>/dev/null || true); do _kill_tree "$c"; done
  kill -9 "$pid" 2>/dev/null || true
}
_cleanup() {
  while read -r p; do [ -n "$p" ] && _kill_tree "$p"; done < "$PIDFILE"
  pkill -9 -f "sleep $DUR_LONG" 2>/dev/null || true
  rm -rf "$T"
}
trap _cleanup EXIT INT TERM

SCENARIOS_RUN=0
scenario() { SCENARIOS_RUN=$((SCENARIOS_RUN + 1)); echo "$1"; }

FORGE_HEAVY_MUTEX_TESTING=1
export FORGE_HEAVY_MUTEX_TESTING

GATE_START="$(date +%s)"

# _now_ms — milissegundos desde a época, via `perl -MTime::HiRes` (o `date +%s` do bash tem
# granularidade de 1s, a raiz do achado HIGH de correção).
_now_ms() { perl -MTime::HiRes=time -e 'printf "%.0f", time()*1000'; }

# --- descoberta de interpretadores (achado BLOCKER de correção) ---------------------------
_bash_major() { "$1" -c 'printf "%s" "${BASH_VERSINFO[0]}"' 2>/dev/null; }

INTERP_BINS=()
INTERP_MAJORS=()
_add_interp_candidate() {
  local cand="$1" bin rp maj already l
  bin="$(command -v "$cand" 2>/dev/null || true)"
  [ -n "$bin" ] && [ -x "$bin" ] || return 0
  rp="$(cd "$(dirname "$bin")" 2>/dev/null && pwd)/$(basename "$bin")" || return 0
  already=0
  for l in "${INTERP_BINS[@]:-}"; do [ "$l" = "$rp" ] && already=1; done
  [ "$already" = "1" ] && return 0
  maj="$(_bash_major "$rp")"
  [ -n "$maj" ] || return 0
  already=0
  for l in "${INTERP_MAJORS[@]:-}"; do [ "$l" = "$maj" ] && already=1; done
  [ "$already" = "1" ] && return 0
  INTERP_BINS+=("$rp")
  INTERP_MAJORS+=("$maj")
}
for cand in ${W222_BASHES:-bash /bin/bash /opt/homebrew/bin/bash /usr/local/bin/bash}; do
  _add_interp_candidate "$cand"
done
[ "${#INTERP_BINS[@]}" -ge 1 ] \
  || { echo "FAIL [setup]: nenhum interpretador bash utilizável encontrado"; exit 1; }

GATE_BUDGET_S="${W222_BUDGET_S:-$(( 150 * ${#INTERP_BINS[@]} + 60 ))}"

# newroot — âncora isolada por cenário, nunca compartilhada entre cenários (um lock deixado por
# um cenário anterior não pode envenenar o seguinte).
newroot() {
  local r; r="$(mktemp -d "$T/root.XXXXXX")"
  printf '%s' "$r"
}

# run_launch <root> <recurso> <sinais-ignorados-antes-do-exec (lista separada por espaço, pode
# ser vazia)> <segundos-do-payload> — define RUN_CHILD (global) com o PID do lançador e publica o
# PID do PAYLOAD (não o do lançador) em "$root/payload.pid" antes de virar `sleep`, para a prova
# de morte que sobrevive a reparentagem (achado MEDIUM de correção). Usa o interpretador
# `$CURRENT_BASH` (global, setado pelo laço por versão) tanto para o lançador quanto — via `$BASH`
# dentro do próprio heavy-run.sh — para a reexecução interna, então o cenário roda do início ao
# fim sob a MESMA major version. NUNCA chamada via `$(...)`: capturar o retorno por substituição
# de comando rodaria o `&` dentro de um SUBSHELL, o job em segundo plano deixaria de ser filho
# direto do script principal, e o `wait` do chamador falharia com rc 127 (medido). Confia em
# `set -m` para que o job assíncrono NÃO herde SIG_IGN automaticamente do próprio lançador
# (POSIX: comando assíncrono sem job control ignora INT/QUIT por conta própria) — só os sinais
# listados explicitamente chegam ignorados, isolando a variável sob teste.
run_launch() {
  local root="$1" res="$2" ignore_list="$3" dur="$4"
  local ignore_cmds="" s
  for s in $ignore_list; do ignore_cmds="${ignore_cmds}trap '' $s; "; done
  rm -f "$root/payload.pid"
  set -m
  FORGE_HEAVY_MUTEX_ROOT="$root" "$CURRENT_BASH" -c \
    "${ignore_cmds}exec \"\$0\" \"\$1\" --resource \"\$2\" -- sh -c 'echo \$\$ > \"\$FORGE_HEAVY_MUTEX_ROOT/payload.pid\"; exec sleep \"\$1\"' _ \"\$3\"" \
    "$CURRENT_BASH" "$HR" "$res" "$dur" >"$root/out.log" 2>&1 &
  RUN_CHILD=$!
  set +m
  track "$RUN_CHILD"
}

# _wait_payload_pid <root> <cap-décimos-de-segundo> — aguarda o payload publicar o próprio PID,
# em passos de 0,1s (nunca em foreground além do cap). Define WPP_PID (vazio se estourou o cap).
_wait_payload_pid() {
  local root="$1" cap="$2" waited=0
  WPP_PID=""
  while [ "$waited" -lt "$cap" ]; do
    if [ -s "$root/payload.pid" ]; then
      WPP_PID="$(cat "$root/payload.pid" 2>/dev/null || true)"
      [ -n "$WPP_PID" ] && return 0
    fi
    sleep 0.1
    waited=$((waited + 1))
  done
  return 1
}

# _wait_bounded <pid> <cap-segundos> — nunca bloqueia além do cap, em passos de 0,2s (achado HIGH
# de correção: granularidade mais fina reduz o overhead de detecção embutido no teto medido). No
# defeito do #146 o processo NÃO morre sozinho (é exatamente o que o vermelho prova), e um `wait`
# puro travaria o gate para sempre; por isso o cap poda a árvore e força o rc de fora, em vez de
# esperar o comando terminar por conta própria. Define WB_RC e WB_TIMEDOUT (0/1).
_wait_bounded() {
  local pid="$1" cap_s="$2" waited_ds=0 cap_ds
  cap_ds=$((cap_s * 10))
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$waited_ds" -ge "$cap_ds" ]; then
      WB_TIMEDOUT=1
      _kill_tree "$pid"
      wait "$pid" 2>/dev/null
      WB_RC=$?
      return 0
    fi
    sleep 0.2
    waited_ds=$((waited_ds + 2))
  done
  WB_TIMEDOUT=0
  wait "$pid" 2>/dev/null
  WB_RC=$?
}

# assert_signal <rótulo> <sinal> <sinais-ignorados-antes-do-exec> <rc-esperado>
# <teto-de-segundos-depois-do-sinal> — dispara <sinal> aos 2s de um payload de duração $DUR_LONG
# (nunca chega a expirar de verdade), confere rc, tempo DESDE O SINAL (não desde o lançamento —
# achado HIGH de correção), que a árvore do lançador morreu, que o PAYLOAD publicado morreu
# (achado MEDIUM de correção — sobrevive a reparentagem) e que o lock não ficou para trás.
assert_signal() {
  local label="$1" sig="$2" ignore_list="$3" rc_esperado="$4" teto="$5"
  local root child rc elapsed_ms teto_ms alive_after payload_pid lockdir res_safe
  # Recurso vira nome de arquivo/diretório sidecar dentro da lib — "/" no rótulo (usado para
  # distinguir interpretador, ex. "1/bash3") quebraria isso virando caminho aninhado.
  res_safe="sig-${label//\//-}"
  root="$(newroot)"
  run_launch "$root" "$res_safe" "$ignore_list" "$DUR_LONG"
  child="$RUN_CHILD"
  _wait_payload_pid "$root" 40 \
    || { echo "FAIL [$label]: payload não publicou o próprio pid em 4s. Log: $(cat "$root/out.log" 2>/dev/null)"; exit 1; }
  payload_pid="$WPP_PID"
  sleep 2
  kill -"$sig" "$child" 2>/dev/null
  local t_kill_ms; t_kill_ms="$(_now_ms)"
  _wait_bounded "$child" "$((teto + 4))"
  rc=$WB_RC
  elapsed_ms=$(( $(_now_ms) - t_kill_ms ))
  teto_ms=$((teto * 1000))
  sleep 1
  alive_after="$(pgrep -P "$child" 2>/dev/null | wc -l | tr -d ' ')"
  lockdir="$root/$res_safe.lock"
  _kill_tree "$child"
  if [ "$rc" -ne "$rc_esperado" ]; then
    echo "FAIL [$label]: rc=$rc, esperado $rc_esperado (sinal $sig, ignorados na entrada: '${ignore_list:-nenhum}'). Log: $(cat "$root/out.log" 2>/dev/null)"
    exit 1
  fi
  if [ "$elapsed_ms" -gt "$teto_ms" ]; then
    echo "FAIL [$label]: levou ${elapsed_ms}ms depois do sinal, esperado <= ${teto_ms}ms (sinal $sig, ignorados na entrada: '${ignore_list:-nenhum}')"
    exit 1
  fi
  if [ "$alive_after" != "0" ]; then
    echo "FAIL [$label]: sobrou $alive_after descendente(s) do lançador vivo(s) depois do sinal — a suíte deixaria processo pendurado"
    exit 1
  fi
  if [ -n "$payload_pid" ] && kill -0 "$payload_pid" 2>/dev/null; then
    echo "FAIL [$label]: payload pid=$payload_pid continua vivo depois do sinal — órfão reparentado, invisível a 'pgrep -P' (achado MEDIUM de correção)"
    exit 1
  fi
  if [ -e "$lockdir" ]; then
    echo "FAIL [$label]: o lock $lockdir ficou para trás depois do sinal"
    exit 1
  fi
  echo "OK [$label] rc=$rc elapsed=${elapsed_ms}ms-depois-do-sinal"
}

# run_core_scenarios — cenários [1]-[6], que exercitam `_hr_reset_ignored_signals` (o coração do
# achado BLOCKER de correção). Rodados uma vez por interpretador em `$CURRENT_BASH`.
run_core_scenarios() {
  local tag="$1"

  scenario "[1/$tag] controle — INT padrão na entrada: rc 130 em menos de 3s do sinal"
  assert_signal "1/$tag" INT "" 130 3

  scenario "[2/$tag] caso — INT IGNORADO na entrada: rc 130 em menos de 3s do sinal (a correção reseta e relança)"
  assert_signal "2/$tag" INT "INT" 130 3

  scenario "[3/$tag] controle — TERM padrão na entrada: rc 143 em menos de 3s do sinal"
  assert_signal "3/$tag" TERM "" 143 3

  scenario "[4/$tag] caso — TERM IGNORADO na entrada: rc 143 em menos de 3s do sinal"
  assert_signal "4/$tag" TERM "TERM" 143 3

  scenario "[5/$tag] HUP ignorado na entrada (com INT também ignorado, força a reexecução): HUP atravessa sem ser alterado — kill -HUP não interrompe, o payload termina sozinho pelo fim natural"
  local root5 dur5=4 remaining5=2 child5 rc5 payload5 elapsed5_ms floor5_ms alive5 lockdir5
  root5="$(newroot)"
  run_launch "$root5" "hup-ignorado-$tag" "INT HUP" "$dur5"
  child5="$RUN_CHILD"
  _wait_payload_pid "$root5" 40 \
    || { echo "FAIL [5/$tag]: payload não publicou o próprio pid em 4s. Log: $(cat "$root5/out.log" 2>/dev/null)"; exit 1; }
  payload5="$WPP_PID"
  sleep 2
  kill -HUP "$child5" 2>/dev/null
  local t_hup5_ms; t_hup5_ms="$(_now_ms)"
  wait "$child5" 2>/dev/null
  rc5=$?
  elapsed5_ms=$(( $(_now_ms) - t_hup5_ms ))
  # O payload dura ${dur5}s e o HUP chega aos ~2s: se HUP continuar ignorado (esperado), o
  # processo só termina pelo FIM natural do comando, perto de ${remaining5}s DEPOIS do HUP —
  # nunca quase-instantâneo, que seria HUP matando (achado HIGH de correção: medido a partir do
  # sinal, não do lançamento, com piso tolerante a jitter em vez do teto de 1s original).
  floor5_ms=$(( (remaining5 * 1000) - 700 ))
  if [ "$elapsed5_ms" -lt "$floor5_ms" ]; then
    echo "FAIL [5/$tag]: terminou ${elapsed5_ms}ms depois do HUP (esperado >= ${floor5_ms}ms, fim natural do payload) — HUP parece ter interrompido, ou seja, a correção alterou a disposição de HUP herdada. Log: $(cat "$root5/out.log" 2>/dev/null)"
    exit 1
  fi
  if [ "$rc5" -eq 129 ]; then
    echo "FAIL [5/$tag]: rc=129 (morto por HUP) — a disposição de HUP herdada (ignorada) foi alterada pela correção, e não deveria ter sido"
    exit 1
  fi
  sleep 1
  alive5="$(pgrep -P "$child5" 2>/dev/null | wc -l | tr -d ' ')"
  lockdir5="$root5/hup-ignorado-$tag.lock"
  _kill_tree "$child5"
  [ "$alive5" = "0" ] \
    || { echo "FAIL [5/$tag]: sobrou $alive5 descendente(s) vivo(s) depois do fim esperado"; exit 1; }
  if [ -n "$payload5" ] && kill -0 "$payload5" 2>/dev/null; then
    echo "FAIL [5/$tag]: payload pid=$payload5 continua vivo depois do fim esperado — órfão reparentado, invisível a 'pgrep -P'"
    exit 1
  fi
  [ ! -e "$lockdir5" ] \
    || { echo "FAIL [5/$tag]: o lock $lockdir5 ficou para trás depois do fim esperado"; exit 1; }
  echo "OK [5/$tag] rc=$rc5 elapsed=${elapsed5_ms}ms-depois-do-HUP (HUP ignorado preservado)"

  scenario "[6/$tag] HUP padrão na entrada (com INT ignorado, força a reexecução): HUP atravessa sem ser alterado — kill -HUP mata com rc 129 em menos de 3s do sinal"
  assert_signal "6/$tag" HUP "INT" 129 3
}

for i in "${!INTERP_BINS[@]}"; do
  CURRENT_BASH="${INTERP_BINS[$i]}"
  TAG="bash${INTERP_MAJORS[$i]}"
  echo "--- interpretador $((i + 1))/${#INTERP_BINS[@]}: $CURRENT_BASH (bash major ${INTERP_MAJORS[$i]}, tag $TAG) ---"
  run_core_scenarios "$TAG"
done

scenario "[7] sem 'perl' no PATH: INT ignorado na entrada não pode ser resetado — recusa com rc 70 e diagnóstico"
NOPERL="$T/noperl-path"
mkdir -p "$NOPERL"
for tool in bash sh cat sleep kill mkdir rm printf grep sed date mktemp dirname; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [ -n "$p" ] && ln -sf "$p" "$NOPERL/$tool" 2>/dev/null
done
root7="$(newroot)"
out7="$(PATH="$NOPERL" FORGE_HEAVY_MUTEX_TESTING=1 FORGE_HEAVY_MUTEX_ROOT="$root7" \
        bash -c "trap '' INT; exec bash \"\$0\" --resource sem-perl -- sleep 1" "$HR" 2>&1)"
rc7=$?
[ "$rc7" -eq 70 ] \
  || { echo "FAIL [7]: rc=$rc7, esperado 70 (sem perl, INT ignorado na entrada). Saída: $out7"; exit 1; }
echo "$out7" | grep -qi "perl" \
  || { echo "FAIL [7]: rc 70 correto, mas o diagnóstico não nomeia 'perl' como o que falta: $out7"; exit 1; }
echo "OK [7] rc=$rc7"

scenario "[8] a guarda _HR_SIG_RESET não vaza para a carga: heavy-run.sh aninhado no payload (lançado por '&' sem 'set -m', herda INT ignorado por regra POSIX) não recusa por engano"
root8="$(newroot)"
nested_res="inner-$$-w222"
out8="$(FORGE_HEAVY_MUTEX_TESTING=1 FORGE_HEAVY_MUTEX_ROOT="$root8" bash -c \
  "trap '' INT; exec bash \"\$0\" --resource outer-8 -- sh -c 'bash \"\$0\" --resource \"\$1\" -- true & NPID=\$!; wait \$NPID; echo NESTED_RC=\$?' \"\$0\" \"\$1\"" \
  "$HR" "$nested_res" 2>&1)"
outer_rc8=$?
[ "$outer_rc8" -eq 0 ] \
  || { echo "FAIL [8]: heavy-run.sh externo saiu rc=$outer_rc8, esperado 0. Saída: $out8"; exit 1; }
nested_line="$(printf '%s\n' "$out8" | grep '^NESTED_RC=' || true)"
[ "$nested_line" = "NESTED_RC=0" ] \
  || { echo "FAIL [8]: heavy-run.sh aninhado não saiu rc 0 (linha: '${nested_line:-ausente}') — a guarda _HR_SIG_RESET do pai vazou para o filho. Saída: $out8"; exit 1; }
echo "$out8" | grep -qi "continua ignorado mesmo depois do reset" \
  && { echo "FAIL [8]: o heavy-run.sh aninhado recusou citando a guarda de reset — a guarda vazou do pai. Saída: $out8"; exit 1; }
echo "OK [8] $nested_line"

MIN_SCENARIOS=$(( 6 * ${#INTERP_BINS[@]} + 2 ))
[ "$SCENARIOS_RUN" -ge "$MIN_SCENARIOS" ] \
  || { echo "FAIL [contador]: apenas $SCENARIOS_RUN cenário(s) executado(s), esperado >= $MIN_SCENARIOS — universo raso demais para o espaço {INT,TERM}×{padrão,ignorado}×{interpretadores} + HUP + ausência de perl + vazamento de guarda"; exit 1; }

sleep 1
RESIDUAL=0
while read -r p; do
  [ -n "$p" ] || continue
  n="$(pgrep -P "$p" 2>/dev/null | wc -l | tr -d ' ')"
  [ "$n" != "0" ] && RESIDUAL=$((RESIDUAL + n))
done < "$PIDFILE"
pgrep -f "sleep $DUR_LONG" >/dev/null 2>&1 && RESIDUAL=$((RESIDUAL + 1))
if [ "$RESIDUAL" != "0" ]; then
  echo "FAIL [processos]: $RESIDUAL processo(s) do gate ainda vivo(s) ao final"
  exit 1
fi

GATE_ELAPSED=$(( $(date +%s) - GATE_START ))
[ "$GATE_ELAPSED" -le "$GATE_BUDGET_S" ] \
  || { echo "FAIL [orçamento]: a suíte levou ${GATE_ELAPSED}s, acima do teto declarado de ${GATE_BUDGET_S}s"; exit 1; }
echo "PASS w222-heavy-run-signal-disposition ($SCENARIOS_RUN cenário(s) em ${#INTERP_BINS[@]} interpretador(es) [${INTERP_MAJORS[*]}], ${GATE_ELAPSED}s de ${GATE_BUDGET_S}s)"
