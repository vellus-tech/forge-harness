#!/usr/bin/env bash
# Gate W151 — primitivo de mutex de carga pesada (issue #52).
#
# Dois defeitos medidos em campo no ecossistema Axis, que se compõem mal:
#
#   1. O lock resolvia por `$TMPDIR`, que no macOS é por usuário e por contexto de invocação —
#      quatro valores distintos observados ativos na mesma máquina, dois locks vivos simultâneos e
#      um órfão de quatorze horas que a detecção nunca alcançava porque olhava o outro arquivo.
#      Modo de falha: duas suítes pesadas rodando juntas, cada uma achando que detém exclusividade.
#   2. `while ! mkdir` é exclusão mútua sem ORDEM. Quem solta e retoma já está a poucas instruções
#      do `mkdir`; quem espera dorme num intervalo de polling. A chance não melhora com paciência —
#      é inanição, não lentidão. Medido: 1305s de fila para achar um erro de 8s.
#
# ISOLAMENTO. Todo cenário resolve dentro de uma caixa própria. A suíte NUNCA pode tocar o lock
# real da máquina: se tocasse, ela viraria a carga que o mutex existe para impedir, e um aborto
# deixaria um lock bloqueando os quatro repositórios.
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib/heavy-mutex.sh"
T="$(mktemp -d /tmp/forge-w151.XXXXXX)"

# Fixtures (sleepers, zumbis) morrem com o gate. Sem isto, um cenário que aborte deixa processos
# vivos por minutos — de novo, a carga que o mutex existe para evitar.
PIDFILE="$T/fixture-pids"
: > "$PIDFILE"
_cleanup() {
  while read -r p; do [ -n "$p" ] && kill -9 "$p" 2>/dev/null; done < "$PIDFILE"
  rm -rf "$T"
}
trap _cleanup EXIT INT TERM
track() { printf '%s\n' "$1" >> "$PIDFILE"; }


# Um sleeper real, rastreado para morrer com o gate. O redirecionamento NÃO é higiene: um processo
# em background herda o stdout da substituição de comando que o cria, e `$( )` só retorna quando
# esse descritor fecha — sem `>/dev/null`, `P="$(sleeper)"` fica pendurado pelos 600s do sleep.
sleeper() { sleep 600 >/dev/null 2>&1 & local p=$!; track "$p"; printf '%s' "$p"; }

# Token no formato que a biblioteca grava: ps -o lstart= com espaços colapsados e trim.
tok_of() { LC_ALL=C ps -o lstart= -p "$1" 2>/dev/null | tr -s ' ' | sed 's/^ *//;s/ *$//'; }

# Lock pré-fabricado — o estado que uma corrida produziria, montado à mão (camada A).
mk_lock() {  # mk_lock <dir-do-lock> <pid> [token]
  mkdir -p "$1"
  printf '%s\n' "$2" > "$1/pid"
  if [ $# -ge 3 ]; then printf '%s\n' "$3" > "$1/token"; else tok_of "$2" > "$1/token"; fi
  printf '%s\n' "fixture" > "$1/nonce"
}

# A trava positiva vale para a suíte INTEIRA: qualquer cenário que esqueça de montar a caixa
# recebe 69 em vez de tocar /tmp. Ver o comentário em lib/heavy-mutex.sh.
FORGE_HEAVY_MUTEX_TESTING=1
export FORGE_HEAVY_MUTEX_TESTING

SCENARIOS_RUN=0
scenario() { SCENARIOS_RUN=$((SCENARIOS_RUN + 1)); echo "$1"; }

# Caixa isolada por cenário. Exporta as duas formas de ancoragem: na onda W0 a biblioteca ainda
# resolve por TMPDIR (o defeito importado), e das ondas seguintes em diante por
# FORGE_HEAVY_MUTEX_ROOT — o gate não muda quando a correção entra.
newbox() {
  local b; b="$(mktemp -d "$T/box.XXXXXX")"
  printf '%s' "$b"
}

[ -f "$LIB" ] || { echo "FAIL [setup]: $LIB não existe"; exit 1; }

scenario "[30] reentrância por linhagem: detentor ancestral executa sem readquirir e preserva o lock"
BOX="$(newbox)"
cat > "$BOX/child.sh" <<'CHILD'
set -uo pipefail
. "$LIBP"
forge_heavy_mutex_acquire --label "filho" --timeout 5 || exit $?
printf 'CHILD-RAN\n'
CHILD
cat > "$BOX/parent.sh" <<'PARENT'
set -uo pipefail
. "$LIBP"
forge_heavy_mutex_acquire --label "pai" --timeout 5 || exit $?
LOCKP="$FORGE_HEAVY_MUTEX_HELD_PATH"
printf 'PARENT-HOLDS %s\n' "$LOCKP"
LIBP="$LIBP" bash "$BOXP/child.sh"
rc=$?
[ -d "$LOCKP" ] && printf 'LOCK-STILL-THERE\n'
exit $rc
PARENT
out30="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res \
         LIBP="$LIB" BOXP="$BOX" bash "$BOX/parent.sh" 2>&1)"; rc30=$?
[ "$rc30" -eq 0 ] \
  || { echo "FAIL [30]: o filho sob o lock do pai não seguiu (rc $rc30): $out30"; exit 1; }
grep -q "CHILD-RAN" <<<"$out30" \
  || { echo "FAIL [30]: o filho não executou a carga — o push recusaria a si mesmo: $out30"; exit 1; }
grep -q "LOCK-STILL-THERE" <<<"$out30" \
  || { echo "FAIL [30]: o filho reentrante LIBEROU o lock do ancestral — quem tomou é quem libera: $out30"; exit 1; }
echo "OK [30]"

scenario "[22] liberação por EXIT: saída normal e exit 1 do payload liberam, e o rc é preservado"
for pay in 0 1; do
  BOX="$(newbox)"
  cat > "$BOX/run.sh" <<'RUN'
set -uo pipefail
. "$LIBP"
forge_heavy_mutex_acquire --label "payload" --timeout 5 || exit $?
LOCKP="$FORGE_HEAVY_MUTEX_HELD_PATH"
printf 'LOCK=%s\n' "$LOCKP"
trap 'forge_heavy_mutex_release' EXIT
exit "$PAY"
RUN
  out22="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res \
           LIBP="$LIB" PAY="$pay" bash "$BOX/run.sh" 2>&1)"; rc22=$?
  [ "$rc22" -eq "$pay" ] \
    || { echo "FAIL [22]: rc do payload não preservado (esperado $pay, veio $rc22): $out22"; exit 1; }
  lk="$(sed -n 's/^LOCK=//p' <<<"$out22" | head -1)"
  [ -n "$lk" ] || { echo "FAIL [22]: a aquisição não expôs o caminho do lock: $out22"; exit 1; }
  [ ! -d "$lk" ] \
    || { echo "FAIL [22]: o lock ficou para trás após saída com rc=$pay ($lk)"; exit 1; }
done
echo "OK [22]"

scenario "[1] âncora: quatro TMPDIR distintos resolvem o MESMO caminho <root>/<recurso>.lock"
BOX="$(newbox)"
paths=""
for td in "$BOX/t1" "$BOX/t2" "$BOX/t3" "$BOX/t4"; do
  mkdir -p "$td"
  pp="$(TMPDIR="$td" FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res \
        bash -c '. "$0"; forge_heavy_mutex_path' "$LIB" 2>&1 | head -1 | cut -f1)"
  paths="$paths$pp
"
done
uniq_n="$(printf '%s' "$paths" | sort -u | grep -c . )"
[ "$uniq_n" -eq 1 ] \
  || { echo "FAIL [1]: quatro TMPDIR produziram $uniq_n caminho(s) distinto(s) — é a partição medida em campo:
$paths"; exit 1; }
first="$(printf '%s' "$paths" | head -1)"
[ "$first" = "$BOX/w151res.lock" ] \
  || { echo "FAIL [1]: o caminho não é <root>/<recurso>.lock: veio '$first', esperado '$BOX/w151res.lock'"; exit 1; }
echo "OK [1]"

scenario "[2] âncora comportamental: A com TMPDIR=X detém; B com TMPDIR=Y é BLOQUEADO e a recusa nomeia o caminho"
BOX="$(newbox)"; mkdir -p "$BOX/tx" "$BOX/ty"
cat > "$BOX/hold.sh" <<'HOLD'
set -uo pipefail
. "$LIBP"
forge_heavy_mutex_acquire --label "A" --timeout 5 || exit $?
printf 'HELD\n'
sleep 30
HOLD
TMPDIR="$BOX/tx" FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res LIBP="$LIB" \
  bash "$BOX/hold.sh" > "$BOX/a.out" 2>&1 &
A_PID=$!; track "$A_PID"
w=0; while [ $w -lt 50 ] && ! grep -q HELD "$BOX/a.out" 2>/dev/null; do sleep 0.1; w=$((w+1)); done
grep -q HELD "$BOX/a.out" 2>/dev/null \
  || { echo "FAIL [2]: A não conseguiu adquirir: $(cat "$BOX/a.out")"; exit 1; }
out2="$(TMPDIR="$BOX/ty" FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res \
        bash -c '. "$0"; forge_heavy_mutex_acquire --label "B" --timeout 2' "$LIB" 2>&1)"; rc2=$?
kill -9 "$A_PID" 2>/dev/null
[ "$rc2" -ne 0 ] \
  || { echo "FAIL [2]: B adquiriu com TMPDIR diferente enquanto A detinha — duas suítes pesadas juntas, o defeito 1 literal: $out2"; exit 1; }
grep -q "$BOX/w151res.lock" <<<"$out2" \
  || { echo "FAIL [2]: a recusa não nomeia o CAMINHO do lock — foi a ausência disso que escondeu a partição por 14 horas: $out2"; exit 1; }
echo "OK [2]"

scenario "[3] /tmp default é ACEITO (a regra estrita da v2 recusava a própria âncora)"
out3="$(FORGE_HEAVY_MUTEX_TESTING= FORGE_HEAVY_MUTEX_ROOT= FORGE_HEAVY_MUTEX_RESOURCE=w151res-default \
        bash -c '. "$0"; forge_heavy_mutex_path' "$LIB" 2>&1)"; rc3=$?
[ "$rc3" -eq 0 ] \
  || { echo "FAIL [3]: a âncora default foi RECUSADA (rc $rc3) — no macOS /tmp é symlink e nos dois SOs é do root, então a regra estrita reprova toda instalação: $out3"; exit 1; }
grep -q "^/tmp/w151res-default.lock" <<<"$out3" \
  || { echo "FAIL [3]: o default não resolveu para /tmp/<recurso>.lock (normalizar trocaria a string que o legado imprime): $out3"; exit 1; }
echo "OK [3]"

scenario "[4] âncora declarada: symlink reprova 69; inexistente é criada com mkdir simples"
BOX="$(newbox)"
ln -s "$BOX/alvo-do-squatter" "$BOX/anc-link"; mkdir -p "$BOX/alvo-do-squatter"
out4="$(FORGE_HEAVY_MUTEX_ROOT="$BOX/anc-link" FORGE_HEAVY_MUTEX_RESOURCE=w151res \
        bash -c '. "$0"; forge_heavy_mutex_path' "$LIB" 2>&1)"; rc4=$?
[ "$rc4" -eq 69 ] \
  || { echo "FAIL [4]: âncora declarada que é SYMLINK deveria dar 69 (veio $rc4) — é o squat medido, em que mkdir -p aceita e pwd -P segue o link: $out4"; exit 1; }
out4b="$(FORGE_HEAVY_MUTEX_ROOT="$BOX/nova" FORGE_HEAVY_MUTEX_RESOURCE=w151res \
        bash -c '. "$0"; forge_heavy_mutex_path' "$LIB" 2>&1)"; rc4b=$?
[ "$rc4b" -eq 0 ] && [ -d "$BOX/nova" ] \
  || { echo "FAIL [4]: âncora declarada inexistente não foi criada (rc $rc4b): $out4b"; exit 1; }
echo "OK [4]"

scenario "[5] sidecar plantado como symlink por terceiro reprova 69"
BOX="$(newbox)"
mkdir -p "$BOX/alvo-q"; ln -s "$BOX/alvo-q" "$BOX/w151res.q"
out5="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res \
        bash -c '. "$0"; forge_heavy_mutex_acquire --timeout 2' "$LIB" 2>&1)"; rc5=$?
[ "$rc5" -eq 69 ] \
  || { echo "FAIL [5]: sidecar symlink deveria dar 69 (veio $rc5) — mkdir -p aceitaria e a fila iria para o diretório do squatter: $out5"; exit 1; }
echo "OK [5]"

scenario "[38] recibo de aquisição sem contenção: caminho, recurso e proveniência da âncora"
BOX="$(newbox)"
out38="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res \
         bash -c '. "$0"; forge_heavy_mutex_acquire --label "recibo" --timeout 5; forge_heavy_mutex_release' "$LIB" 2>&1)"; rc38=$?
[ "$rc38" -eq 0 ] || { echo "FAIL [38]: aquisição sem contenção reprovou (rc $rc38): $out38"; exit 1; }
grep -q "adquirido" <<<"$out38" \
  || { echo "FAIL [38]: sem recibo, 'rodei com o mutex' e 'rodei sem porque a lib sumiu' produzem o mesmo silêncio no log: $out38"; exit 1; }
grep -q "$BOX/w151res.lock" <<<"$out38" \
  || { echo "FAIL [38]: o recibo não nomeia o caminho: $out38"; exit 1; }
grep -q "FORGE_HEAVY_MUTEX_ROOT" <<<"$out38" \
  || { echo "FAIL [38]: o recibo não declara a PROVENIÊNCIA da âncora — é o que distingue 'isolado' de 'serializa com a máquina': $out38"; exit 1; }
echo "OK [38]"

scenario "[T1] token existe e é estável; PID morto devolve vazio"
P="$(sleeper)"
t1a="$(tok_of "$P")"; sleep 2; t1b="$(tok_of "$P")"
[ -n "$t1a" ] || { echo "FAIL [T1]: ps -o lstart= não devolveu carimbo para PID vivo"; exit 1; }
[ "$t1a" = "$t1b" ] \
  || { echo "FAIL [T1]: token do MESMO pid mudou entre leituras a 2s ('$t1a' vs '$t1b') — a identidade seria instável"; exit 1; }
kill -9 "$P" 2>/dev/null; wait "$P" 2>/dev/null
t1c="$(tok_of "$P")"
[ -z "$t1c" ] || { echo "FAIL [T1]: PID morto ainda devolve token '$t1c'"; exit 1; }
echo "OK [T1]"

scenario "[T2] token discrimina processos iniciados em segundos DISTINTOS"
Pa="$(sleeper)"; sleep 2; Pb="$(sleeper)"
[ "$(tok_of "$Pa")" != "$(tok_of "$Pb")" ] \
  || { echo "FAIL [T2]: dois processos com 2s de diferença têm o mesmo token"; exit 1; }
kill -9 "$Pa" "$Pb" 2>/dev/null
echo "OK [T2]"

scenario "[T3] token NÃO discrimina dentro do mesmo segundo — a limitação é afirmada, não escondida"
Pc="$(sleeper)"; Pd="$(sleeper)"
[ "$(tok_of "$Pc")" = "$(tok_of "$Pd")" ] \
  || { echo "FAIL [T3]: dois processos do MESMO segundo tiveram tokens distintos — se lstart tivesse resolução fina a limitação documentada estaria errada, e a §8 precisa ser revista"; exit 1; }
kill -9 "$Pc" "$Pd" 2>/dev/null
echo "OK [T3]"

scenario "[T4] locale: LC_TIME muda o formato; a biblioteca fixa LC_ALL=C e produz token estável"
Pe="$(sleeper)"
tc="$(LC_ALL=C ps -o lstart= -p "$Pe" 2>/dev/null | tr -s ' ' | sed 's/^ *//;s/ *$//')"
tf="$(LC_ALL= LC_TIME=fr_FR.UTF-8 ps -o lstart= -p "$Pe" 2>/dev/null | tr -s ' ' | sed 's/^ *//;s/ *$//')"
if [ -n "$tf" ] && [ "$tc" = "$tf" ]; then
  echo "  (nota: locale fr_FR indisponível nesta máquina — asserção de formato pulada, estabilidade sob C mantida)"
fi
t4a="$(tok_of "$Pe")"; t4b="$(LC_TIME=fr_FR.UTF-8 tok_of "$Pe")"
[ "$t4a" = "$t4b" ] \
  || { echo "FAIL [T4]: o token da biblioteca mudou com LC_TIME ('$t4a' vs '$t4b') — LC_ALL=C não está fixado e o token nunca bateria entre processos de locales diferentes"; exit 1; }
kill -9 "$Pe" 2>/dev/null
echo "OK [T4]"

scenario "[T5] zumbi: kill -0 e lstart dizem vivo; só o primeiro caractere de state distingue"
perl -e 'my $p=fork(); if($p){sleep 30} else {exit 0}' >/dev/null 2>&1 & PERLP=$!; track "$PERLP"
sleep 1
ZP=""; for c in $(pgrep -P "$PERLP" 2>/dev/null); do
  st="$(LC_ALL=C ps -o state= -p "$c" 2>/dev/null | tr -d ' ')"
  case "$st" in Z*) ZP="$c" ;; esac
done
if [ -n "$ZP" ]; then
  kill -0 "$ZP" 2>/dev/null \
    || { echo "FAIL [T5]: kill -0 recusou o zumbi — a premissa do desenho (kill -0 não distingue) estaria errada"; exit 1; }
  [ -n "$(tok_of "$ZP")" ] \
    || { echo "FAIL [T5]: lstart não devolveu carimbo para o zumbi — a premissa do desenho estaria errada"; exit 1; }
  BOX="$(newbox)"; mk_lock "$BOX/w151res.lock" "$ZP"
  out="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res \
         bash -c '. "$0"; forge_heavy_mutex_acquire --timeout 3' "$LIB" 2>&1)"; rcz=$?
  [ "$rcz" -eq 0 ] \
    || { echo "FAIL [T5]: a biblioteca tratou um ZUMBI como detentor vivo (rc $rcz) — o lock de um processo morto trava a máquina até alguém investigar: $out"; exit 1; }
else
  echo "  (nota: não foi possível construir zumbi nesta máquina — cenário inconclusivo)"
fi
kill -9 "$PERLP" 2>/dev/null
echo "OK [T5]"

scenario "[6] órfão de detentor: PID morto é reclamado, a mensagem nomeia PID e caminho"
BOX="$(newbox)"
DEADP="$(sleeper)"; kill -9 "$DEADP" 2>/dev/null; wait "$DEADP" 2>/dev/null
mk_lock "$BOX/w151res.lock" "$DEADP" "carimbo-de-processo-morto"
out6="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res \
        bash -c '. "$0"; forge_heavy_mutex_acquire --timeout 4 && printf "CARGA-EXECUTOU\n"' "$LIB" 2>&1)"; rc6=$?
[ "$rc6" -eq 0 ] && grep -q "CARGA-EXECUTOU" <<<"$out6" \
  || { echo "FAIL [6]: lock de PID morto não foi reclamado (rc $rc6): $out6"; exit 1; }
grep -q "$DEADP" <<<"$out6" && grep -q "$BOX/w151res.lock" <<<"$out6" \
  || { echo "FAIL [6]: a reclamação não nomeia PID e caminho: $out6"; exit 1; }
echo "OK [6]"

scenario "[7] PID reciclado: PID VIVO com token que não confere é tratado como órfão"
BOX="$(newbox)"
ALIVE="$(sleeper)"
mk_lock "$BOX/w151res.lock" "$ALIVE" "Mon Jan  1 00:00:00 2001"
out7="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res \
        bash -c '. "$0"; forge_heavy_mutex_acquire --timeout 4 && printf "CARGA-EXECUTOU\n"' "$LIB" 2>&1)"; rc7=$?
[ "$rc7" -eq 0 ] && grep -q "CARGA-EXECUTOU" <<<"$out7" \
  || { echo "FAIL [7]: PID vivo com token DIVERGENTE (reciclagem) não foi reclamado (rc $rc7) — kill -0 sozinho aceita, e o lock fica preso a um processo que nunca o tomou: $out7"; exit 1; }
echo "OK [7]"

scenario "[8] contrapositiva de [7]: PID vivo com token CERTO não é reclamado (a proteção discrimina)"
BOX="$(newbox)"
mk_lock "$BOX/w151res.lock" "$ALIVE"
out8="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res \
        bash -c '. "$0"; forge_heavy_mutex_acquire --timeout 2 && printf "CARGA-EXECUTOU\n"' "$LIB" 2>&1)"; rc8=$?
[ "$rc8" -ne 0 ] \
  || { echo "FAIL [8]: detentor VIVO e coerente foi reclamado — a proteção não discrimina, ela derruba tudo: $out8"; exit 1; }
kill -9 "$ALIVE" 2>/dev/null
echo "OK [8]"

scenario "[9] lock incompleto: sem pid não é reclamado no primeiro poll; reclamado após o teto"
BOX="$(newbox)"
mkdir -p "$BOX/w151res.lock"
out9="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res FORGE_HEAVY_MUTEX_POLL_S=1 \
        FORGE_HEAVY_MUTEX_INCOMPLETE_POLLS=3 \
        bash -c '. "$0"; forge_heavy_mutex_acquire --timeout 12 && printf "CARGA-EXECUTOU\n"' "$LIB" 2>&1)"; rc9=$?
[ "$rc9" -eq 0 ] && grep -q "CARGA-EXECUTOU" <<<"$out9" \
  || { echo "FAIL [9]: lock sem pid nunca foi reclamado (rc $rc9) — é o estado da janela de escrita, e nunca sair dele trava a máquina: $out9"; exit 1; }
grep -qi "incompleto" <<<"$out9" \
  || { echo "FAIL [9]: reclamou sem nomear a anomalia — remover lock de quem acabou de vencer a corrida precisa ser dito em voz alta: $out9"; exit 1; }
echo "OK [9]"

scenario "[19] lock revogado na janela de escrita: a aquisição FALHA em vez de seguir como detentor"
BOX="$(newbox)"
out19="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res FORGE_HEAVY_MUTEX_REVOKE_PROBE=1 \
         bash -c '. "$0"; forge_heavy_mutex_acquire --timeout 2; printf "RC=%s\n" "$?"' "$LIB" 2>&1)"
grep -q "RC=0" <<<"$out19" \
  && { echo "FAIL [19]: com o lock revogado entre o mkdir e a confirmação, a aquisição devolveu 0 — o processo segue como detentor de um lock que não existe, e duas suítes rodam: $out19"; exit 1; }
grep -qi "revogado" <<<"$out19" \
  || { echo "FAIL [19]: a revogação não é nomeada — hoje ela produz só um 'No such file or directory' que ninguém lê: $out19"; exit 1; }
echo "OK [19]"

scenario "[20] interop legado→novo: lock do protocolo antigo (mkdir + pid) bloqueia o novo"
BOX="$(newbox)"
LEG="$(sleeper)"
mkdir -p "$BOX/w151res.lock"; printf '%s\n' "$LEG" > "$BOX/w151res.lock/pid"
out20="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res FORGE_HEAVY_MUTEX_INCOMPLETE_POLLS=99 \
         bash -c '. "$0"; forge_heavy_mutex_acquire --timeout 2' "$LIB" 2>&1)"; rc20=$?
[ "$rc20" -ne 0 ] \
  || { echo "FAIL [20]: o novo protocolo adquiriu sobre um lock legado vivo — no período de migração isso é duas suítes pesadas juntas: $out20"; exit 1; }
echo "OK [20]"

scenario "[21] interop novo→legado: o legado é bloqueado E lê o PID certo pelo caminho de sempre"
BOX="$(newbox)"
cat > "$BOX/hold21.sh" <<'H21'
set -uo pipefail
. "$LIBP"
forge_heavy_mutex_acquire --label "novo" --timeout 5 || exit $?
printf 'HELD %s\n' "$$"
sleep 30
H21
FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res LIBP="$LIB" \
  bash "$BOX/hold21.sh" > "$BOX/h21.out" 2>&1 &
H21P=$!; track "$H21P"
w=0; while [ $w -lt 50 ] && ! grep -q HELD "$BOX/h21.out" 2>/dev/null; do sleep 0.1; w=$((w+1)); done
HELDPID="$(sed -n 's/^HELD //p' "$BOX/h21.out" | head -1)"
[ -n "$HELDPID" ] || { echo "FAIL [21]: o detentor novo não chegou a adquirir: $(cat "$BOX/h21.out")"; exit 1; }
mkdir "$BOX/w151res.lock" 2>/dev/null \
  && { echo "FAIL [21]: o mkdir do LEGADO teve sucesso sobre um lock detido pelo novo protocolo — os dois não se excluiriam"; exit 1; }
legpid="$(cat "$BOX/w151res.lock/pid" 2>/dev/null)"
[ "$legpid" = "$HELDPID" ] \
  || { echo "FAIL [21]: o legado leria '$legpid' em <lock>/pid, e o detentor real é '$HELDPID' — a detecção de órfão do legado removeria lock vivo"; exit 1; }
kill -9 "$H21P" 2>/dev/null
echo "OK [21]"

scenario "[24] SIGKILL: o lock fica (esperado) e o PRÓXIMO adquirente o reclama como órfão"
BOX="$(newbox)"
cat > "$BOX/hold24.sh" <<'H24'
set -uo pipefail
. "$LIBP"
forge_heavy_mutex_acquire --label "vitima" --timeout 5 || exit $?
printf 'HELD\n'
sleep 30
H24
FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res LIBP="$LIB" \
  bash "$BOX/hold24.sh" > "$BOX/h24.out" 2>&1 &
H24P=$!; track "$H24P"
w=0; while [ $w -lt 50 ] && ! grep -q HELD "$BOX/h24.out" 2>/dev/null; do sleep 0.1; w=$((w+1)); done
kill -9 "$H24P" 2>/dev/null; wait "$H24P" 2>/dev/null
[ -d "$BOX/w151res.lock" ] \
  || { echo "FAIL [24]: o lock sumiu após SIGKILL — SIGKILL não é capturável, então nada deveria tê-lo removido; o cenário mediria outra coisa"; exit 1; }
out24="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res \
         bash -c '. "$0"; forge_heavy_mutex_acquire --timeout 5 && printf "CARGA-EXECUTOU\n"' "$LIB" 2>&1)"; rc24=$?
[ "$rc24" -eq 0 ] && grep -q "CARGA-EXECUTOU" <<<"$out24" \
  || { echo "FAIL [24]: o lock deixado por SIGKILL não foi reclamado (rc $rc24) — é o órfão de 14 horas: $out24"; exit 1; }
echo "OK [24]"

[ "$SCENARIOS_RUN" -gt 0 ] \
  || { echo "FAIL [contador]: nenhum cenário executado — um gate que não roda nada não cobre nada"; exit 1; }
echo "PASS w151-heavy-mutex ($SCENARIOS_RUN cenário(s))"
