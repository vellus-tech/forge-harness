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
# ISOLAMENTO. Todo cenário resolve dentro de `FORGE_HEAVY_MUTEX_ROOT` (mktemp) com
# `FORGE_HEAVY_MUTEX_TESTING=1` — a suíte NUNCA toca o lock real da máquina. Todo processo de
# teste criado é rastreado por PID (do processo lançador ATÉ o payload, por parentesco — `exec`
# preserva o PID ao longo da cadeia de reexecução) e morto no cleanup: um teste de heavy-run que
# ignora sinal não pode deixar `sleep` pendurado no init.
#
#   [1] controle — INT padrão na entrada: rc 130, sleep morto, em menos de 3s.
#   [2] caso — INT IGNORADO na entrada (herdado, ex.: `trap '' INT; exec ...`): depois da
#       correção, rc 130 e sleep morto em menos de 3s — sem a correção, rc 0 e ~12s (a carga
#       correu até o fim; ver mutação no PR).
#   [3] controle — TERM padrão na entrada: rc 143, sleep morto, em menos de 3s.
#   [4] caso — TERM IGNORADO na entrada: rc 143, sleep morto, em menos de 3s.
#   [5] HUP ignorado na entrada, com INT também ignorado (força a reexecução): a disposição de
#       HUP atravessa a reexecução SEM ser alterada — continua ignorada, então `kill -HUP` não
#       interrompe o payload, que termina sozinho pelo fim natural do comando.
#   [6] HUP padrão na entrada, com INT ignorado (força a reexecução): a disposição de HUP
#       atravessa a reexecução SEM ser alterada — continua padrão, o trap dispara normalmente e
#       `kill -HUP` mata com rc 129 em menos de 3s (prova que a correção não quebra o caminho HUP
#       que já funcionava).
#   [7] sem `perl` no PATH: com INT ignorado na entrada, a correção não pode resetar a
#       disposição — recusa com rc 70 e diagnóstico que nomeia 'perl', em vez de rodar a carga
#       sem trap.
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HR="$WS/template/.forge/scripts/heavy-run.sh"
T="$(mktemp -d /tmp/forge-w222.XXXXXX)"

[ -f "$HR" ] || { echo "FAIL [setup]: $HR não existe"; exit 1; }

# Duração longa e sinteticamente distintiva (embute o ordinal e a issue) para os cenários que
# sinalizam cedo — nunca chega a ser esperada de verdade, e serve de marcador legível no `ps`
# durante depuração manual. O critério de vivo/morto do gate, porém, é por PARENTESCO de PID
# (pgrep -P), nunca por casar texto de argv.
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
GATE_BUDGET_S="${W222_BUDGET_S:-180}"

# newroot — âncora isolada por cenário, nunca compartilhada entre cenários (um lock deixado por
# um cenário anterior não pode envenenar o seguinte).
newroot() {
  local r; r="$(mktemp -d "$T/root.XXXXXX")"
  printf '%s' "$r"
}

# run_launch <root> <recurso> <sinais-ignorados-antes-do-exec (lista separada por espaço, pode
# ser vazia)> <segundos-do-payload> — define RUN_CHILD (global) com o PID do lançador. NUNCA
# chamada via `$(...)`: capturar o retorno por substituição de comando rodaria o `&` dentro de um
# SUBSHELL, o job em segundo plano deixaria de ser filho direto do script principal, e o `wait`
# do chamador falharia com rc 127 (medido). Confia em `set -m` para que o job assíncrono NÃO
# herde SIG_IGN automaticamente do próprio lançador (POSIX: comando assíncrono sem job control
# ignora INT/QUIT por conta própria) — só os sinais listados explicitamente chegam ignorados,
# isolando a variável sob teste.
run_launch() {
  local root="$1" res="$2" ignore_list="$3" dur="$4"
  local ignore_cmds="" s
  for s in $ignore_list; do ignore_cmds="${ignore_cmds}trap '' $s; "; done
  set -m
  FORGE_HEAVY_MUTEX_ROOT="$root" bash -c \
    "${ignore_cmds}exec bash \"\$0\" --resource \"\$1\" -- sleep \"\$2\"" \
    "$HR" "$res" "$dur" >"$root/out.log" 2>&1 &
  RUN_CHILD=$!
  set +m
  track "$RUN_CHILD"
}

# _wait_bounded <pid> <cap-segundos> — nunca bloqueia além do cap. No defeito do #146 o processo
# NÃO morre sozinho (é exatamente o que o vermelho prova), e um `wait` puro travaria o gate para
# sempre; por isso o cap poda a árvore e força o rc de fora, em vez de esperar o comando terminar
# por conta própria. Define WB_RC e WB_TIMEDOUT (0/1).
_wait_bounded() {
  local pid="$1" cap="$2" waited=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$waited" -ge "$cap" ]; then
      WB_TIMEDOUT=1
      _kill_tree "$pid"
      wait "$pid" 2>/dev/null
      WB_RC=$?
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done
  WB_TIMEDOUT=0
  wait "$pid" 2>/dev/null
  WB_RC=$?
}

# assert_signal <rótulo> <sinal> <sinais-ignorados-antes-do-exec> <rc-esperado>
# <teto-de-segundos> — dispara <sinal> aos 2s de um payload de duração $DUR_LONG (nunca chega a
# expirar de verdade), confere rc e tempo, e que a árvore do lançador morreu.
assert_signal() {
  local label="$1" sig="$2" ignore_list="$3" rc_esperado="$4" teto="$5"
  local root child t0 rc elapsed alive_after
  root="$(newroot)"
  t0="$(date +%s)"
  run_launch "$root" "sig-$label" "$ignore_list" "$DUR_LONG"
  child="$RUN_CHILD"
  sleep 2
  kill -"$sig" "$child" 2>/dev/null
  _wait_bounded "$child" "$((teto + 4))"
  rc=$WB_RC
  elapsed=$(( $(date +%s) - t0 ))
  sleep 1
  alive_after="$(pgrep -P "$child" 2>/dev/null | wc -l | tr -d ' ')"
  _kill_tree "$child"
  if [ "$rc" -ne "$rc_esperado" ]; then
    echo "FAIL [$label]: rc=$rc, esperado $rc_esperado (sinal $sig, ignorados na entrada: '${ignore_list:-nenhum}'). Log: $(cat "$root/out.log" 2>/dev/null)"
    exit 1
  fi
  if [ "$elapsed" -gt "$teto" ]; then
    echo "FAIL [$label]: levou ${elapsed}s, esperado <= ${teto}s (sinal $sig, ignorados na entrada: '${ignore_list:-nenhum}')"
    exit 1
  fi
  if [ "$alive_after" != "0" ]; then
    echo "FAIL [$label]: sobrou $alive_after descendente(s) do lançador vivo(s) depois do sinal — a suíte deixaria processo pendurado"
    exit 1
  fi
  echo "OK [$label] rc=$rc elapsed=${elapsed}s"
}

scenario "[1] controle — INT padrão na entrada: rc 130 em menos de 3s"
assert_signal "1" INT "" 130 3

scenario "[2] caso — INT IGNORADO na entrada: rc 130 em menos de 3s (a correção reseta e relança)"
assert_signal "2" INT "INT" 130 3

scenario "[3] controle — TERM padrão na entrada: rc 143 em menos de 3s"
assert_signal "3" TERM "" 143 3

scenario "[4] caso — TERM IGNORADO na entrada: rc 143 em menos de 3s"
assert_signal "4" TERM "TERM" 143 3

scenario "[5] HUP ignorado na entrada (com INT também ignorado, força a reexecução): HUP atravessa sem ser alterado — kill -HUP não interrompe, o payload termina sozinho pelo fim natural"
root5="$(newroot)"
t05="$(date +%s)"
run_launch "$root5" "hup-ignorado" "INT HUP" 4
child5="$RUN_CHILD"
sleep 2
kill -HUP "$child5" 2>/dev/null
wait "$child5" 2>/dev/null
rc5=$?
elapsed5=$(( $(date +%s) - t05 ))
# O payload dura 4s e o HUP chega aos 2s: se HUP continuar ignorado (comportamento esperado), o
# processo só termina pelo FIM do comando, perto de 4s — nunca em ~2-3s, que seria HUP matando.
if [ "$elapsed5" -lt 4 ]; then
  echo "FAIL [5]: terminou em ${elapsed5}s (esperado ~4s, fim natural do payload) — HUP parece ter interrompido, ou seja, a correção alterou a disposição de HUP herdada. Log: $(cat "$root5/out.log" 2>/dev/null)"
  exit 1
fi
if [ "$rc5" -eq 129 ]; then
  echo "FAIL [5]: rc=129 (morto por HUP) — a disposição de HUP herdada (ignorada) foi alterada pela correção, e não deveria ter sido"
  exit 1
fi
sleep 1
alive5="$(pgrep -P "$child5" 2>/dev/null | wc -l | tr -d ' ')"
_kill_tree "$child5"
[ "$alive5" = "0" ] \
  || { echo "FAIL [5]: sobrou $alive5 descendente(s) vivo(s) depois do fim esperado"; exit 1; }
echo "OK [5] rc=$rc5 elapsed=${elapsed5}s (HUP ignorado preservado)"

scenario "[6] HUP padrão na entrada (com INT ignorado, força a reexecução): HUP atravessa sem ser alterado — kill -HUP mata com rc 129 em menos de 3s"
assert_signal "6" HUP "INT" 129 3

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

[ "$SCENARIOS_RUN" -ge 6 ] \
  || { echo "FAIL [contador]: apenas $SCENARIOS_RUN cenário(s) executado(s) — universo raso demais para o espaço {INT,TERM}×{padrão,ignorado} + HUP + ausência de perl"; exit 1; }

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
echo "PASS w222-heavy-run-signal-disposition ($SCENARIOS_RUN cenário(s), ${GATE_ELAPSED}s de ${GATE_BUDGET_S}s)"
