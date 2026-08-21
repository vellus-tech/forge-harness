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


# Carimbo de ticket no formato da biblioteca: microssegundos em 20 dígitos, para que a ordem
# lexicográfica do glob coincida com a numérica.
us20() { perl -MTime::HiRes -e 'printf "%020.0f", Time::HiRes::time()*1000000' 2>/dev/null || printf '%020d' "$(( $(date +%s) * 1000000 ))"; }

# Ticket pré-fabricado — o estado que uma fila com concorrentes produziria (camada A).
mk_ticket() {  # mk_ticket <q-dir> <us20> <pid> [token]
  mkdir -p "$1/$2.$3"
  printf '%s\n' "$3" > "$1/$2.$3/pid"
  if [ $# -ge 4 ]; then printf '%s\n' "$4" > "$1/$2.$3/token"; else tok_of "$3" > "$1/$2.$3/token"; fi
}
q_count() { local n=0 f; for f in "$1"/*; do [ -d "$f" ] && n=$((n+1)); done; printf '%s' "$n"; }

# A trava positiva vale para a suíte INTEIRA: qualquer cenário que esqueça de montar a caixa
# recebe 69 em vez de tocar /tmp. Ver o comentário em lib/heavy-mutex.sh.
FORGE_HEAVY_MUTEX_TESTING=1
export FORGE_HEAVY_MUTEX_TESTING

# Teto de parede DECLARADO e asseverado. A suíte usa processos reais — sleepers, zumbi por fork,
# cinco concorrentes disputando — porque simular escalonamento provaria outra coisa. O custo disso
# é tempo, e tempo que ninguém mede vira suíte que ninguém roda. Se o teto for ultrapassado, o
# gate reprova: encurtar espera que sustenta propriedade é como um cenário passa a medir outra
# coisa (aconteceu duas vezes nesta suíte).
GATE_START="$(date +%s)"
GATE_BUDGET_S="${W151_BUDGET_S:-420}"

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
# Se o sujeito morreu entre as leituras, o cenário NÃO mediu estabilidade — e reportar isso como
# "o token mudou" seria culpar o código por um sleeper que a máquina derrubou sob carga.
kill -0 "$P" 2>/dev/null \
  || { echo "FAIL [T1]: o processo-sujeito morreu durante a medição — o cenário não chegou a medir estabilidade de token"; exit 1; }
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
[ -n "$tf" ] && [ "$tc" != "$tf" ] \
  || { echo "FAIL [T4]: não foi possível observar a mudança de formato por locale (C='$tc' fr='$tf') — sem isso o cenário não prova que LC_ALL=C é necessário, e um OK aqui seria sobre nada"; exit 1; }
t4a="$(tok_of "$Pe")"; t4b="$(LC_TIME=fr_FR.UTF-8 tok_of "$Pe")"
[ "$t4a" = "$t4b" ] \
  || { echo "FAIL [T4]: o token da biblioteca mudou com LC_TIME ('$t4a' vs '$t4b') — LC_ALL=C não está fixado e o token nunca bateria entre processos de locales diferentes"; exit 1; }
kill -9 "$Pe" 2>/dev/null
echo "OK [T4]"

scenario "[T5] zumbi: kill -0 e lstart dizem vivo; só o primeiro caractere de state distingue"
# `pgrep -P` NÃO lista filho zumbi no macOS (medido 3/3) — usar isso fazia o cenário degradar para
# OK justamente na plataforma onde o defeito de campo foi medido. `ps -eo pid,state,ppid` enxerga.
# E "não consegui montar o sujeito" é FAIL, nunca OK: um cenário que não mede não pode entrar no
# placar como se tivesse medido — é o defeito canônico deste repositório dentro da suíte que
# existe para eliminá-lo.
perl -e 'my $p=fork(); if($p){sleep 30} else {exit 0}' >/dev/null 2>&1 & PERLP=$!; track "$PERLP"
w=0; ZP=""
while [ $w -lt 40 ] && [ -z "$ZP" ]; do
  ZP="$(LC_ALL=C ps -eo pid,state,ppid 2>/dev/null | awk -v pp="$PERLP" '$3==pp && $2 ~ /^Z/ {print $1; exit}')"
  [ -n "$ZP" ] || { sleep 0.2; w=$((w+1)); }
done
[ -n "$ZP" ] \
  || { echo "FAIL [T5]: não foi possível construir um zumbi — o cenário não mediu nada, e a troca de kill -0 por state fica sem prova nenhuma"; exit 1; }
kill -0 "$ZP" 2>/dev/null \
  || { echo "FAIL [T5]: kill -0 recusou o zumbi — a premissa que motiva trocar kill -0 por state estaria errada"; exit 1; }
[ -n "$(tok_of "$ZP")" ] \
  || { echo "FAIL [T5]: lstart não devolveu carimbo para o zumbi — a premissa do desenho estaria errada"; exit 1; }
BOX="$(newbox)"; mk_lock "$BOX/w151res.lock" "$ZP"
outz="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res \
        bash -c '. "$0"; forge_heavy_mutex_acquire --timeout 3 && printf "ADQUIRIU\n"' "$LIB" 2>&1)"; rcz=$?
[ "$rcz" -eq 0 ] && grep -q ADQUIRIU <<<"$outz" \
  || { echo "FAIL [T5]: um ZUMBI foi tratado como detentor vivo (rc $rcz) — o lock de um processo morto trava a máquina até alguém investigar: $outz"; exit 1; }
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

scenario "[19] lock revogado na janela de escrita: por remoção E por dono trocado"
BOX="$(newbox)"
out19="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res FORGE_HEAVY_MUTEX_REVOKE_PROBE=1 \
         bash -c '. "$0"; forge_heavy_mutex_acquire --timeout 2; printf "RC=%s\n" "$?"' "$LIB" 2>&1)"
grep -q "RC=0" <<<"$out19" \
  && { echo "FAIL [19]: com o lock REMOVIDO entre o mkdir e a confirmação, a aquisição devolveu 0 — o processo segue como detentor de um lock que não existe: $out19"; exit 1; }
grep -qi "revogado" <<<"$out19" \
  || { echo "FAIL [19]: a revogação por remoção não é nomeada: $out19"; exit 1; }
# Segundo ramo: o lock EXISTE, com dono diferente. É o que as comparações de pid e nonce cobrem, e
# sem este cenário removê-las não reprovava nada.
BOX2="$(newbox)"
out19b="$(FORGE_HEAVY_MUTEX_ROOT="$BOX2" FORGE_HEAVY_MUTEX_RESOURCE=w151res FORGE_HEAVY_MUTEX_STEAL_PROBE=1 \
          bash -c '. "$0"; forge_heavy_mutex_acquire --timeout 2; printf "RC=%s\n" "$?"' "$LIB" 2>&1)"
grep -q "RC=0" <<<"$out19b" \
  && { echo "FAIL [19]: o lock foi RETOMADO por terceiro durante a janela (existe, com outro pid e outro nonce) e a aquisição devolveu 0 — duas cargas pesadas com o mesmo lock: $out19b"; exit 1; }
grep -qi "revogado" <<<"$out19b" \
  || { echo "FAIL [19]: a retomada por terceiro não é nomeada: $out19b"; exit 1; }
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

scenario "[40] fila LIGADA: o interruptor é lido e anunciado no recibo"
BOX="$(newbox)"; : > "$BOX/w151res.q.enabled"
out40="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res \
         bash -c '. "$0"; forge_heavy_mutex_acquire --timeout 5; forge_heavy_mutex_release' "$LIB" 2>&1)"; rc40=$?
[ "$rc40" -eq 0 ] || { echo "FAIL [40]: aquisição com fila ligada reprovou (rc $rc40): $out40"; exit 1; }
grep -qi "fila LIGADA" <<<"$out40" \
  || { echo "FAIL [40]: o recibo não diz se a fila está ligada — no período de migração, 'estou atrás de dois' e 'estou disputando às cegas' são decisões diferentes: $out40"; exit 1; }
echo "OK [40]"

scenario "[12] FIFO: três tickets vivos mais antigos e lock LIVRE — o quarto não adquire"
BOX="$(newbox)"; : > "$BOX/w151res.q.enabled"; mkdir -p "$BOX/w151res.q"
for i in 1 2 3; do
  SP="$(sleeper)"; mk_ticket "$BOX/w151res.q" "0000000000000000000$i" "$SP"
done
[ ! -d "$BOX/w151res.lock" ] || { echo "FAIL [12]: o lock deveria estar LIVRE para o cenário medir a fila e não a posse"; exit 1; }
out12="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res \
         bash -c '. "$0"; forge_heavy_mutex_acquire --timeout 3' "$LIB" 2>&1)"; rc12=$?
[ "$rc12" -ne 0 ] \
  || { echo "FAIL [12]: adquiriu com três tickets vivos à frente e lock livre — a fila não ordena nada, e quem solta-e-retoma continua monopolizando: $out12"; exit 1; }
echo "OK [12]"

scenario "[13] contrapositiva de [12]: removidos os tickets, o mesmo processo adquire"
rm -rf "$BOX/w151res.q"/*
out13="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res \
         bash -c '. "$0"; forge_heavy_mutex_acquire --timeout 5 && printf "ADQUIRIU\n"; forge_heavy_mutex_release' "$LIB" 2>&1)"; rc13=$?
[ "$rc13" -eq 0 ] && grep -q "ADQUIRIU" <<<"$out13" \
  || { echo "FAIL [13]: sem tickets à frente e com lock livre, não adquiriu (rc $rc13) — a fila estaria recusando tudo em vez de ordenar: $out13"; exit 1; }
echo "OK [13]"

scenario "[10] ticket órfão na cabeça é varrido e a fila anda"
BOX="$(newbox)"; : > "$BOX/w151res.q.enabled"; mkdir -p "$BOX/w151res.q"
DEADQ="$(sleeper)"; kill -9 "$DEADQ" 2>/dev/null; wait "$DEADQ" 2>/dev/null
mk_ticket "$BOX/w151res.q" "00000000000000000001" "$DEADQ" "carimbo-morto"
out10="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res \
         bash -c '. "$0"; forge_heavy_mutex_acquire --timeout 6 && printf "ADQUIRIU\n"; forge_heavy_mutex_release' "$LIB" 2>&1)"; rc10=$?
[ "$rc10" -eq 0 ] && grep -q "ADQUIRIU" <<<"$out10" \
  || { echo "FAIL [10]: ticket de PID morto na cabeça travou a fila (rc $rc10) — um órfão de ticket bloqueia a máquina como um órfão de lock: $out10"; exit 1; }
echo "OK [10]"

scenario "[14] ticket vivo removido não é ABSORVENTE: o processo reenfileira e adquire"
BOX="$(newbox)"; : > "$BOX/w151res.q.enabled"; mkdir -p "$BOX/w151res.q"
SPB="$(sleeper)"; mk_ticket "$BOX/w151res.q" "00000000000000000001" "$SPB"
cat > "$BOX/vict.sh" <<'VICT'
set -uo pipefail
. "$LIBP"
forge_heavy_mutex_acquire --label "vitima" --timeout 20 && printf 'ADQUIRIU\n'
VICT
FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res FORGE_HEAVY_MUTEX_POLL_S=1 \
  FORGE_HEAVY_MUTEX_POLL_HEAD_S=1 LIBP="$LIB" bash "$BOX/vict.sh" > "$BOX/v.out" 2>&1 &
VP=$!; track "$VP"
w=0; while [ $w -lt 60 ] && [ "$(q_count "$BOX/w151res.q")" -lt 2 ]; do sleep 0.2; w=$((w+1)); done
rm -rf "$BOX/w151res.q"/*
w=0; while [ $w -lt 60 ] && kill -0 "$VP" 2>/dev/null; do sleep 0.5; w=$((w+1)); done
kill -9 "$SPB" 2>/dev/null
grep -q "ADQUIRIU" "$BOX/v.out" 2>/dev/null \
  || { echo "FAIL [14]: com o próprio ticket apagado e o lock LIVRE, o processo esperou até o teto em vez de reenfileirar — é o estado absorvente medido, pior que o mecanismo de hoje: $(cat "$BOX/v.out")"; exit 1; }
kill -9 "$VP" 2>/dev/null
echo "OK [14]"

scenario "[41] aritmética sobre ticket de 20 dígitos não morre em octal"
t41="00000000001787244001"
v41="$(bash -c 'echo $(( 10#$1 ))' _ "$t41" 2>&1)"
[ "$v41" = "1787244001" ] \
  || { echo "FAIL [41]: 10# não converteu o ticket zero-padded (veio '$v41')"; exit 1; }
v41b="$(bash -c 'echo $(( $1 ))' _ "$t41" 2>&1)"; rc41b=$?
[ "$rc41b" -ne 0 ] \
  || { echo "FAIL [41]: aritmética SEM 10# deveria falhar em número zero-padded — se não falha, a armadilha documentada não existe e a regra do gate estático perde a razão"; exit 1; }
echo "OK [41]"

scenario "[17] exclusão mútua real: 5 concorrentes, sem entrelaçamento, 5 pares e 5 PIDs distintos"
BOX="$(newbox)"; W="$BOX/witness"; : > "$W"
cat > "$BOX/work.sh" <<'WORK'
set -uo pipefail
. "$LIBP"
forge_heavy_mutex_acquire --label "w" --timeout 30 || exit $?
printf 'START %s\n' "$$" >> "$WIT"
sleep 1
printf 'END %s\n' "$$" >> "$WIT"
forge_heavy_mutex_release
WORK
for i in 1 2 3 4 5; do
  FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res FORGE_HEAVY_MUTEX_POLL_S=1 \
    FORGE_HEAVY_MUTEX_POLL_HEAD_S=1 LIBP="$LIB" WIT="$W" bash "$BOX/work.sh" >/dev/null 2>&1 &
  track "$!"
done
wait
n_start="$(grep -c '^START' "$W")"; n_end="$(grep -c '^END' "$W")"
n_pid="$(awk '/^START/{print $2}' "$W" | sort -u | grep -c .)"
[ "$n_start" -eq 5 ] && [ "$n_end" -eq 5 ] && [ "$n_pid" -eq 5 ] \
  || { echo "FAIL [17]: esperados 5 START, 5 END e 5 PIDs distintos; vieram $n_start/$n_end/$n_pid — um mutex que BLOQUEIA todo mundo produz testemunha vazia e zero entrelaçamento, e passaria numa asserção que só olhasse entrelaçamento"; exit 1; }
bad="$(awk '/^START/{if(cur!=""){print "OVERLAP"; exit} cur=$2} /^END/{cur=""}' "$W")"
[ -z "$bad" ] \
  || { echo "FAIL [17]: seções críticas ENTRELAÇADAS — duas cargas pesadas correram juntas: $(cat "$W")"; exit 1; }
echo "OK [17]"

scenario "[18] controle de [17]: SEM mutex a mesma carga TEM de entrelaçar"
BOX="$(newbox)"; W2F="$BOX/witness2"; : > "$W2F"
cat > "$BOX/work2.sh" <<'WORK2'
printf 'START %s\n' "$$" >> "$WIT"
sleep 1
printf 'END %s\n' "$$" >> "$WIT"
WORK2
for i in 1 2 3 4 5; do WIT="$W2F" bash "$BOX/work2.sh" >/dev/null 2>&1 & track "$!"; done
wait
bad2="$(awk '/^START/{if(cur!=""){print "OVERLAP"; exit} cur=$2} /^END/{cur=""}' "$W2F")"
[ -n "$bad2" ] \
  || { echo "FAIL [18]: sem mutex NÃO houve entrelaçamento — o cenário [17] fica inconclusivo, porque não se sabe se o mutex protegeu ou se a carga nunca colidiria: $(cat "$W2F")"; exit 1; }
echo "OK [18]"

scenario "[31] reentrância não confia em PID solto: ancestral com token divergente NÃO é reentrante"
BOX="$(newbox)"
cat > "$BOX/c31.sh" <<'C31'
set -uo pipefail
. "$LIBP"
forge_heavy_mutex_acquire --label "filho" --timeout 3 && printf 'REENTROU\n'
C31
mkdir -p "$BOX/w151res.lock"
printf '%s\n' "$$" > "$BOX/w151res.lock/pid"
printf '%s\n' "Mon Jan  1 00:00:00 2001" > "$BOX/w151res.lock/token"
out31="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res LIBP="$LIB" \
         bash "$BOX/c31.sh" 2>&1)"; rc31=$?
grep -q "ancestral" <<<"$out31" \
  && { echo "FAIL [31]: tratou como ancestral um PID cujo token NÃO confere — um PID reciclado na nossa árvore faria a carga seguir sem lock nenhum: $out31"; exit 1; }
echo "OK [31]"

scenario "[32] reentrância reavaliada a cada poll, e o reentrante NÃO deixa ticket na fila"
# Para exercitar o 6b (e não o passo 3), o ANCESTRAL precisa entrar na fila ANTES do filho e
# adquirir DEPOIS que o filho já está esperando. Um terceiro segura o lock enquanto os dois
# enfileiram; quando ele solta, o pai é a cabeça e adquire, e só então o filho descobre que o
# detentor virou seu ancestral. Sem essa ordem, o filho é a cabeça e simplesmente adquire — o
# cenário passa sem nunca tocar o caminho que ele diz medir.
BOX="$(newbox)"; : > "$BOX/w151res.q.enabled"; mkdir -p "$BOX/w151res.q"
cat > "$BOX/third32.sh" <<'T32'
set -uo pipefail
. "$LIBP"
forge_heavy_mutex_acquire --label "terceiro" --timeout 10 || exit $?
printf 'THIRD-HOLDS\n'
sleep 4
forge_heavy_mutex_release
T32
cat > "$BOX/c32.sh" <<'C32'
set -uo pipefail
. "$LIBP"
sleep 1
forge_heavy_mutex_acquire --label "filho" --timeout 30 && printf 'FILHO-SEGUIU\n'
C32
cat > "$BOX/p32.sh" <<'P32'
set -uo pipefail
. "$LIBP"
LIBP="$LIBP" bash "$BOXP/c32.sh" &
CH=$!
forge_heavy_mutex_acquire --label "pai" --timeout 30 || exit $?
printf 'PAI-PEGOU\n'
wait "$CH"
forge_heavy_mutex_release
P32
FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res FORGE_HEAVY_MUTEX_POLL_S=1 \
  LIBP="$LIB" bash "$BOX/third32.sh" > "$BOX/t32.out" 2>&1 &
T32P=$!; track "$T32P"
w=0; while [ $w -lt 60 ] && ! grep -q THIRD-HOLDS "$BOX/t32.out" 2>/dev/null; do sleep 0.2; w=$((w+1)); done
out32="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res FORGE_HEAVY_MUTEX_POLL_S=1 \
         LIBP="$LIB" BOXP="$BOX" bash "$BOX/p32.sh" 2>&1)"; rc32=$?
grep -q "FILHO-SEGUIU" <<<"$out32" \
  || { echo "FAIL [32]: o filho que já esperava na fila não reconheceu o ancestral que adquiriu DEPOIS dele (rc $rc32): $out32"; exit 1; }
grep -q "passou a ser detido por processo ancestral" <<<"$out32" \
  || { echo "FAIL [32]: o filho não passou pelo caminho de reavaliação (6b) — o cenário mediria o passo 3, que é outro caminho: $out32"; exit 1; }
nq32="$(q_count "$BOX/w151res.q")"
[ "${nq32:-0}" -eq 0 ] \
  || { echo "FAIL [32]: sobraram $nq32 ticket(s) — o reentrante saiu do laço sem recolher o seu, e ele fica na cabeça bloqueando quem espera atrás por uma posse inteira"; exit 1; }
kill -9 "$T32P" 2>/dev/null
echo "OK [32]"

scenario "[34] interruptor DESLIGADO no meio do voo: os tickets são recolhidos"
BOX="$(newbox)"; : > "$BOX/w151res.q.enabled"; mkdir -p "$BOX/w151res.q"
SP34="$(sleeper)"; mk_ticket "$BOX/w151res.q" "00000000000000000001" "$SP34"
cat > "$BOX/w34.sh" <<'W34'
set -uo pipefail
. "$LIBP"
forge_heavy_mutex_acquire --label "espera" --timeout 25 && printf 'PEGOU\n'
forge_heavy_mutex_release
W34
FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res FORGE_HEAVY_MUTEX_POLL_S=1 \
  LIBP="$LIB" bash "$BOX/w34.sh" > "$BOX/w34.out" 2>&1 &
W34P=$!; track "$W34P"
w=0; while [ $w -lt 60 ] && [ "$(q_count "$BOX/w151res.q")" -lt 2 ]; do sleep 0.2; w=$((w+1)); done
rm -f "$BOX/w151res.q.enabled"
w=0; while [ $w -lt 80 ] && kill -0 "$W34P" 2>/dev/null; do sleep 0.5; w=$((w+1)); done
kill -9 "$SP34" 2>/dev/null
grep -q "PEGOU" "$BOX/w34.out" 2>/dev/null \
  || { echo "FAIL [34]: com a fila DESLIGADA no meio do voo o processo não passou a disputar no modo legado: $(cat "$BOX/w34.out")"; exit 1; }
nq34="$(q_count "$BOX/w151res.q")"
[ "${nq34:-0}" -le 1 ] \
  || { echo "FAIL [34]: $nq34 ticket(s) ficaram na fila após o desligamento — tickets órfãos bloqueiam quem religar a fila depois"; exit 1; }
kill -9 "$W34P" 2>/dev/null
echo "OK [34]"

scenario "[48] invariante das saídas: as CINCO que enfileiram não deixam ticket nosso"
# A quinta linha — morte por sinal DURANTE a espera — é a que a v5 acrescentou e a que motivou
# armar o trap dentro do acquire. Sem ela aqui, remover essa chamada não produz um vermelho.
BOX="$(newbox)"; : > "$BOX/w151res.q.enabled"; mkdir -p "$BOX/w151res.q"
QD48="$BOX/w151res.q"
FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res \
  bash -c '. "$0"; forge_heavy_mutex_acquire --timeout 5; forge_heavy_mutex_release' "$LIB" >/dev/null 2>&1
[ "$(q_count "$QD48")" -eq 0 ] || { echo "FAIL [48a]: saída por AQUISIÇÃO deixou ticket na fila"; exit 1; }
SP48="$(sleeper)"; mk_ticket "$QD48" "00000000000000000001" "$SP48"
FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res FORGE_HEAVY_MUTEX_POLL_S=1 \
  bash -c '. "$0"; forge_heavy_mutex_acquire --timeout 2' "$LIB" >/dev/null 2>&1
[ "$(q_count "$QD48")" -eq 1 ] || { echo "FAIL [48b]: saída por TIMEOUT deixou $(q_count "$QD48") ticket(s)"; exit 1; }
cat > "$BOX/sig48.sh" <<'S48'
set -uo pipefail
. "$LIBP"
forge_heavy_mutex_acquire --label sig48 --timeout 60
S48
FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res FORGE_HEAVY_MUTEX_POLL_S=1 \
  LIBP="$LIB" bash "$BOX/sig48.sh" >/dev/null 2>&1 &
S48P=$!; track "$S48P"
w=0; while [ $w -lt 60 ] && [ "$(q_count "$QD48")" -lt 2 ]; do sleep 0.2; w=$((w+1)); done
[ "$(q_count "$QD48")" -ge 2 ] \
  || { echo "FAIL [48c]: o processo não chegou a enfileirar — o cenário mediria outra coisa"; exit 1; }
kill -TERM "$S48P" 2>/dev/null
w=0; while [ $w -lt 60 ] && kill -0 "$S48P" 2>/dev/null; do sleep 0.2; w=$((w+1)); done
sleep 1
nq48="$(q_count "$QD48")"
kill -9 "$SP48" 2>/dev/null; kill -9 "$S48P" 2>/dev/null
[ "$nq48" -eq 1 ] \
  || { echo "FAIL [48c]: morto por sinal DURANTE a espera, o processo deixou o ticket ($nq48, esperado 1 do concorrente vivo) — ele fica na cabeça bloqueando quem espera atrás até alguém observar o PID morto"; exit 1; }
echo "OK [48]"

scenario "[47] MATRIZ de transparência de sinal: com e sem a biblioteca, três disposições, quatro números"
# O cenário que a primeira especificação não tinha, e sem o qual três correções diferentes do
# trap passariam. Ele COMPARA contra o baseline em vez de conferir presença: quantas vezes o
# handler de EXIT rodou, quantas o de TERM rodou, o `$?` que cada um viu, e o rc final.
BOX="$(newbox)"
mk_case() {  # mk_case <arquivo> <disposicao> <usar-lib>
  local f="$1" disp="$2" uselib="$3"
  {
    printf 'set -uo pipefail\n'
    printf 'M="$MARK"\n'
    [ "$uselib" = "1" ] && printf '. "$LIBP"\nforge_heavy_mutex_acquire --label t --timeout 5 >/dev/null 2>&1\n'
    printf 'trap '"'"'echo "PX rc=$?" >> "$M"'"'"' EXIT\n'
    case "$disp" in
      2) printf 'trap '"'"'echo "PT rc=$?" >> "$M"; trap - TERM; kill -TERM $$'"'"' TERM\n' ;;
      3) printf 'trap '"'"'echo "PT rc=$?" >> "$M"'"'"' TERM\n' ;;
    esac
    [ "$uselib" = "1" ] && printf 'forge_heavy_mutex_arm_trap\n'
    printf 'echo READY >> "$M"\ni=0; while [ $i -lt 300 ]; do sleep 0.2; i=$((i+1)); done\n'
  } > "$f"
}
matrix_fail=""
for disp in 1 2 3; do
  base_m="$BOX/m.base.$disp"; lib_m="$BOX/m.lib.$disp"
  for mode in base lib; do
    mk="$BOX/case.$disp.$mode.sh"; MK="$BOX/m.$mode.$disp"; : > "$MK"
    [ "$mode" = "lib" ] && u=1 || u=0
    mk_case "$mk" "$disp" "$u"
    FORGE_HEAVY_MUTEX_ROOT="$BOX/anc.$disp.$mode" FORGE_HEAVY_MUTEX_RESOURCE=w151res \
      LIBP="$LIB" MARK="$MK" bash "$mk" >/dev/null 2>&1 &
    CP=$!; track "$CP"
    w=0; while [ $w -lt 60 ] && ! grep -q READY "$MK" 2>/dev/null; do sleep 0.1; w=$((w+1)); done
    kill -TERM "$CP" 2>/dev/null; wait "$CP" 2>/dev/null; eval "rc_$mode=$?"
  done
  bx="$(grep -c '^PX' "$BOX/m.base.$disp")"; lx="$(grep -c '^PX' "$BOX/m.lib.$disp")"
  bt="$(grep -c '^PT' "$BOX/m.base.$disp")"; lt="$(grep -c '^PT' "$BOX/m.lib.$disp")"
  bxr="$(grep '^PX' "$BOX/m.base.$disp" | head -1)"; lxr="$(grep '^PX' "$BOX/m.lib.$disp" | head -1)"
  [ "$bx" = "$lx" ] || matrix_fail="$matrix_fail disp$disp:EXIT($bx!=$lx)"
  [ "$bt" = "$lt" ] || matrix_fail="$matrix_fail disp$disp:TERM($bt!=$lt)"
  # O `$?` visto pelo handler de EXIT sob morte POR SINAL não é comparável, e a diferença é
  # inerente: o baseline morre direto pelo sinal, e nós morremos DEPOIS de passar por um handler,
  # então o EXIT enxerga 128+N em vez do status do último comando. Medido: 0 no baseline contra
  # 143 com a biblioteca. Isso é limite declarado da invariante (§8), não defeito escondido — o
  # `$?` na saída NORMAL, que é onde o idioma `rc=$?` de cleanup importa, é conferido com precisão
  # pelo cenário [25] (handler vê 7 num script que sai com 7).
  #
  # A asserção não perde poder: as três correções erradas que este cenário existe para reprovar se
  # manifestam em CONTAGEM (handler do consumidor rodando duas vezes, ou não rodando) e no rc
  # FINAL, ambos comparados aqui.
  [ "$rc_base" = "$rc_lib" ] || matrix_fail="$matrix_fail disp$disp:rc-final($rc_base!=$rc_lib)"
done
[ -z "$matrix_fail" ] \
  || { echo "FAIL [47]: a biblioteca NÃO é transparente —$matrix_fail. Compor traps sem cuidado faz o handler do consumidor rodar duas vezes; limpar o EXIT junto com o sinal apaga o handler dele; e guardar os dois suprime o de TERM."; exit 1; }
echo "OK [47]"

scenario "[49] arm_trap idempotente: chamado DUAS vezes, o script TERMINA e cada handler roda uma vez"
BOX="$(newbox)"; MK="$BOX/mark49"; : > "$MK"
cat > "$BOX/idem.sh" <<'IDEM'
set -uo pipefail
. "$LIBP"
forge_heavy_mutex_acquire --label idem --timeout 5 >/dev/null 2>&1
trap 'echo PREV >> "$MARK"' EXIT
forge_heavy_mutex_arm_trap
forge_heavy_mutex_arm_trap
echo RAN >> "$MARK"
exit 7
IDEM
FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res LIBP="$LIB" MARK="$MK" \
  bash "$BOX/idem.sh" >/dev/null 2>&1 &
IP=$!; track "$IP"
w=0; while [ $w -lt 100 ] && kill -0 "$IP" 2>/dev/null; do sleep 0.1; w=$((w+1)); done
if kill -0 "$IP" 2>/dev/null; then
  kill -9 "$IP" 2>/dev/null
  echo "FAIL [49]: o script NÃO terminou — a segunda chamada capturou o nosso próprio handler como 'anterior' e o EXIT passou a se chamar em laço. Note que a guarda de release mantém a contagem em 1 durante a recursão, então CONTAR não denunciaria: só o término denuncia."
  exit 1
fi
wait "$IP" 2>/dev/null; rc49=$?
[ "$rc49" -eq 7 ] || { echo "FAIL [49]: rc final $rc49, esperado 7"; exit 1; }
n49="$(grep -c '^PREV' "$MK")"
[ "$n49" -eq 1 ] || { echo "FAIL [49]: o handler do consumidor rodou $n49 vez(es), esperado 1"; exit 1; }
echo "OK [49]"

scenario "[28] guarda de subshell: arm_trap de dentro de ( ) e de pipeline reprova com 64"
BOX="$(newbox)"
out28="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res \
         bash -c '. "$0"; ( forge_heavy_mutex_arm_trap ); echo "RC=$?"' "$LIB" 2>&1)"
grep -q "RC=64" <<<"$out28" \
  || { echo "FAIL [28]: arm_trap dentro de subshell não devolveu 64 — o trap morreria com a subshell e o lock ficaria para trás: $out28"; exit 1; }
echo "OK [28]"

scenario "[27] trap composto com aspas simples E quebra de linha no handler anterior"
BOX="$(newbox)"; MK="$BOX/mark27"; : > "$MK"
cat > "$BOX/q27.sh" <<'Q27'
set -uo pipefail
. "$LIBP"
forge_heavy_mutex_acquire --label q --timeout 5 >/dev/null 2>&1
trap 'echo "linha1 it'"'"'s" >> "$MARK"
echo "linha2" >> "$MARK"' EXIT
forge_heavy_mutex_arm_trap
exit 3
Q27
FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res LIBP="$LIB" MARK="$MK" \
  bash "$BOX/q27.sh" >/dev/null 2>&1; rc27=$?
[ "$rc27" -eq 3 ] || { echo "FAIL [27]: rc final $rc27, esperado 3"; exit 1; }
grep -q "linha1 it's" "$MK" && grep -q "linha2" "$MK" \
  || { echo "FAIL [27]: o handler com aspas simples e quebra de linha não rodou inteiro — extração por corte de string produz comando inválido que morre com 'unexpected EOF', em silêncio: $(cat "$MK")"; exit 1; }
echo "OK [27]"

scenario "[25] trap composto preserva \$?: o handler anterior vê o valor real, não zero"
BOX="$(newbox)"; MK="$BOX/mark25"; : > "$MK"
cat > "$BOX/r25.sh" <<'R25'
set -uo pipefail
. "$LIBP"
forge_heavy_mutex_acquire --label r --timeout 5 >/dev/null 2>&1
trap 'rc=$?; echo "visto=$rc" >> "$MARK"' EXIT
forge_heavy_mutex_arm_trap
exit 7
R25
FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res LIBP="$LIB" MARK="$MK" \
  bash "$BOX/r25.sh" >/dev/null 2>&1; rc25=$?
[ "$rc25" -eq 7 ] || { echo "FAIL [25]: rc final $rc25, esperado 7"; exit 1; }
grep -q "visto=7" "$MK" \
  || { echo "FAIL [25]: o handler anterior viu '$(cat "$MK")' em vez de 7 — um teste antes de salvar \$? o destrói, e 'rc=\$?' na primeira linha é o idioma padrão de cleanup"; exit 1; }
echo "OK [25]"

scenario "[26] handler anterior que chama exit: release roda ANTES e o rc é o do baseline"
BOX="$(newbox)"; MK="$BOX/mark26"; : > "$MK"
cat > "$BOX/e26.sh" <<'E26'
set -uo pipefail
. "$LIBP"
forge_heavy_mutex_acquire --label e --timeout 5 >/dev/null 2>&1
printf 'LOCK=%s\n' "${FORGE_HEAVY_MUTEX_HELD_PATH:-}" >> "$MARK"
trap 'echo PREV >> "$MARK"; exit 0' EXIT
forge_heavy_mutex_arm_trap
exit 3
E26
FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res LIBP="$LIB" MARK="$MK" \
  bash "$BOX/e26.sh" >/dev/null 2>&1; rc26=$?
lk26="$(sed -n 's/^LOCK=//p' "$MK" | head -1)"
[ -n "$lk26" ] && [ ! -d "$lk26" ] \
  || { echo "FAIL [26]: o lock ficou para trás — o handler do consumidor chamou exit e impediu a liberação, que é o defeito real medido em campo"; exit 1; }
[ "$rc26" -eq 0 ] \
  || { echo "FAIL [26]: rc final $rc26; o baseline SEM a biblioteca devolve 0 aqui, e a composição não pode mudar isso — normalizar o código de saída é decisão do autor do handler"; exit 1; }
echo "OK [26]"

scenario "[42] wrapper: stdout puro, códigos de saída e conflito de aliases"
BOX="$(newbox)"; HR="$WS/template/.forge/scripts/heavy-run.sh"
out42="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res bash "$HR" -- echo oi 2>/dev/null)"
[ "$out42" = "oi" ] \
  || { echo "FAIL [42]: stdout não é do comando — veio '$out42', esperado 'oi'. Saída de suíte pesada é parseada por terceiros, e uma linha nossa no meio quebra quem consome"; exit 1; }
FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res bash "$HR" -- sh -c 'exit 42' >/dev/null 2>&1
[ $? -eq 42 ] || { echo "FAIL [42]: o código do comando não foi propagado sem tradução"; exit 1; }
FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res bash "$HR" echo oi >/dev/null 2>&1
[ $? -eq 64 ] || { echo "FAIL [42]: comando sem '--' deveria dar 64"; exit 1; }
FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res \
  FORGE_HEAVY_MUTEX_TIMEOUT_S=100 HEAVY_RUN_TIMEOUT_SECONDS=200 bash "$HR" -- echo x >/dev/null 2>&1
[ $? -eq 64 ] \
  || { echo "FAIL [42]: dois aliases da MESMA grandeza com valores diferentes deveriam dar 64 — escolher um em silêncio é como uma configuração deixa de ser lida sem ninguém notar"; exit 1; }
MARK42="$BOX/held42"
FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res bash "$HR" -- \
  sh -c 'echo "$FORGE_HEAVY_MUTEX_HELD_PATH" > "$1"' _ "$MARK42" >/dev/null 2>&1
lk42="$(cat "$MARK42" 2>/dev/null)"
[ -n "$lk42" ] && [ ! -d "$lk42" ] \
  || { echo "FAIL [42]: o wrapper não liberou o lock ao fim do comando (lock=$lk42)"; exit 1; }
echo "OK [42]"

scenario "[43] wrapper: status e o sweep --legacy que nomeia caminhos que NÃO serializam"
BOX="$(newbox)"; HR="$WS/template/.forge/scripts/heavy-run.sh"
st43="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res bash "$HR" status 2>&1)"; rc43=$?
[ "$rc43" -eq 0 ] || { echo "FAIL [43]: status sobre recurso livre deveria dar 0 (veio $rc43): $st43"; exit 1; }
grep -q "livre" <<<"$st43" || { echo "FAIL [43]: status não diz que está livre: $st43"; exit 1; }
grep -q "fila" <<<"$st43" || { echo "FAIL [43]: status não informa o estado da fila: $st43"; exit 1; }
DEAD43="$(sleeper)"; kill -9 "$DEAD43" 2>/dev/null; wait "$DEAD43" 2>/dev/null
mk_lock "$BOX/w151res.lock" "$DEAD43" "carimbo-morto"
sw43="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res bash "$HR" sweep 2>&1)"
grep -q "1 lock" <<<"$sw43" \
  || { echo "FAIL [43]: sweep não removeu o lock órfão: $sw43"; exit 1; }
echo "OK [43]"

scenario "[44] wrapper: queue enable/disable/state opera o interruptor da máquina"
BOX="$(newbox)"; HR="$WS/template/.forge/scripts/heavy-run.sh"
FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res bash "$HR" queue enable >/dev/null 2>&1
s44="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res bash "$HR" queue state 2>/dev/null)"
[ "$s44" = "LIGADA" ] || { echo "FAIL [44]: queue enable não ligou a fila (state='$s44')"; exit 1; }
FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res bash "$HR" queue disable >/dev/null 2>&1
s44b="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res bash "$HR" queue state 2>/dev/null)"
[ "$s44b" = "DESLIGADA" ] || { echo "FAIL [44]: queue disable não desligou (state='$s44b')"; exit 1; }
echo "OK [44]"

scenario "[45] gate estático: fixture com lock por TMPDIR reprova nomeando o arquivo; limpa passa com contador"
BOX="$(newbox)"; CHK="$WS/template/.forge/scripts/check-heavy-mutex.sh"
mkdir -p "$BOX/sujo" "$BOX/limpo"
printf '#!/usr/bin/env bash\nlock_path="${TMPDIR:-/tmp}/axis-heavy-suite.lock"\nmkdir "$lock_path"\n' > "$BOX/sujo/hook.sh"
printf '#!/usr/bin/env bash\n. lib/heavy-mutex.sh\nforge_heavy_mutex_acquire --label x\n' > "$BOX/limpo/hook.sh"
out45="$(FORGE_ROOT="$WS" bash "$CHK" --path "$BOX/sujo" 2>&1)"; rc45=$?
[ "$rc45" -ne 0 ] \
  || { echo "FAIL [45]: o gate aprovou um lock resolvido por TMPDIR — é o defeito 1 codificado: $out45"; exit 1; }
grep -q "hook.sh" <<<"$out45" \
  || { echo "FAIL [45]: a reprovação não nomeia o arquivo: $out45"; exit 1; }
out45b="$(FORGE_ROOT="$WS" bash "$CHK" --path "$BOX/limpo" 2>&1)"; rc45b=$?
[ "$rc45b" -eq 0 ] \
  || { echo "FAIL [45]: fixture LIMPA reprovou (rc $rc45b) — um gate que recusa tudo não discrimina: $out45b"; exit 1; }
grep -qE "arquivo\(s\) examinado\(s\)" <<<"$out45b" \
  || { echo "FAIL [45]: passou sem dizer QUANTOS arquivos examinou: $out45b"; exit 1; }
echo "OK [45]"

scenario "[46] gate estático: universo vazio reprova, e a justificativa declarada libera nomeada"
BOX="$(newbox)"; CHK="$WS/template/.forge/scripts/check-heavy-mutex.sh"
mkdir -p "$BOX/vazio" "$BOX/fk/.forge"
out46="$(FORGE_ROOT="$BOX/fk" bash "$CHK" --path "$BOX/vazio" 2>&1)"; rc46=$?
[ "$rc46" -ne 0 ] \
  || { echo "FAIL [46]: universo VAZIO passou — 'não examinei nada' e 'examinei e estava limpo' não podem terminar no mesmo verde: $out46"; exit 1; }
printf 'heavy-mutex  # motivo: fixture sem arquivos, cenário [46] do w151\n' > "$BOX/fk/.forge/empty-universe-allowlist.txt"
out46b="$(FORGE_ROOT="$BOX/fk" bash "$CHK" --path "$BOX/vazio" 2>&1)"; rc46b=$?
[ "$rc46b" -eq 0 ] && grep -q "justificativa declarada" <<<"$out46b" \
  || { echo "FAIL [46]: a justificativa declarada não liberou com linha própria (rc $rc46b): $out46b"; exit 1; }
echo "OK [46]"

scenario "[36] canal real: pre-push com o lock tomado por processo vivo NÃO executa a carga"
BOX="$(newbox)"; R="$BOX/repo"
mkdir -p "$R/.forge/scripts/lib" "$R/.forge/hooks/git"
cp "$WS/template/.forge/scripts/lib/heavy-mutex.sh" "$R/.forge/scripts/lib/"
cp "$WS/template/.forge/hooks/git/pre-push" "$R/.forge/hooks/git/"
# Stubs neutros dos alvos que o pre-push declara. Sem eles o hook bloqueia por delegação em alvo
# ausente (issue #49) ANTES de chegar ao mutex, e o cenário mediria integridade de instalação em
# vez de exclusão mútua — passando pelo motivo errado.
for _stub in check-ai-attribution.sh check-liaison-acks.sh; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$R/.forge/scripts/$_stub"
  chmod +x "$R/.forge/scripts/$_stub"
done
cat > "$R/.forge/forge.yaml" <<'FY'
heavy_mutex:
  enabled: true
FY
# O `runtime:` vive no FORGE.md, não no forge.yaml — e sem FORGE.md o hook sai cedo com
# "pre-push OK (sem harness)", medindo a ausência do harness em vez do mutex.
cat > "$R/.forge/FORGE.md" <<'FM'
runtime:
  test: sh -c 'echo CARGA-EXECUTOU >> "$MARK"'
FM
git -C "$R" init -q -b main 2>/dev/null; git -C "$R" config user.email t@t; git -C "$R" config user.name t
git -C "$R" config commit.gpgsign false; git -C "$R" add -A 2>/dev/null; git -C "$R" commit -qm init 2>/dev/null
HOLDP="$(sleeper)"
mk_lock "$BOX/w151res.lock" "$HOLDP"
MARK36="$BOX/mark36"; : > "$MARK36"
sha36="$(git -C "$R" rev-parse HEAD 2>/dev/null)"
out36="$(cd "$R" && printf 'refs/heads/main %s refs/heads/main 0000000000000000000000000000000000000000\n' "$sha36" | \
  FORGE_ROOT="$R" FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res \
  FORGE_HEAVY_MUTEX_TIMEOUT_S=2 MARK="$MARK36" bash "$R/.forge/hooks/git/pre-push" origin "file://$R" 2>&1)"; rc36=$?
kill -9 "$HOLDP" 2>/dev/null
[ "$rc36" -ne 0 ] \
  || { echo "FAIL [36]: o pre-push seguiu com o mutex tomado por processo vivo (rc $rc36) — duas suítes pesadas na mesma máquina: $out36"; exit 1; }
grep -q "CARGA-EXECUTOU" "$MARK36" 2>/dev/null \
  && { echo "FAIL [36]: a CARGA executou apesar do mutex tomado — o hook citou o mutex mas não o respeitou"; exit 1; }
grep -qi "heavy-mutex" <<<"$out36" \
  || { echo "FAIL [36]: a saída não nomeia o mutex — quem lê o push não saberia por que travou: $out36"; exit 1; }
echo "OK [36]"

scenario "[15] pós-verificação do mv: destino de ticket ocupado por terceiro é DETECTADO"
# Camada A pura, sobre a função. Orquestrar a corrida real não serve aqui: forçá-la produz um
# estado em que o processo fica legitimamente atrás do ticket alheio, e o DESFECHO deixa de
# distinguir. `mv src dst` com `dst` existente devolve rc 0 e ANINHA (medido nos dois SOs), então
# sem a pós-verificação o processo acredita ter enfileirado sobre um ticket que é de outro, nunca
# é cabeça, e volta ao timeout sobre um recurso livre.
BOX="$(newbox)"; mkdir -p "$BOX/w151res.q"
OTHER15="$(sleeper)"
out15="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res OTHER="$OTHER15" \
  bash -c '
    . "$0"
    _FHM_QDIR="'"$BOX"'/w151res.q"
    _FHM_NONCE="teste"
    stamp="00000000000000000042"
    # Terceiro já ocupa o NOME determinístico do nosso ticket.
    mkdir -p "$_FHM_QDIR/$stamp.$$"
    printf "%s\n" "$OTHER" > "$_FHM_QDIR/$stamp.$$/pid"
    _fhm_enqueue "$stamp"; printf "RC=%s\n" "$?"
    printf "DONO=%s\n" "$(cat "$_FHM_QDIR/$stamp.$$/pid" 2>/dev/null)"
  ' "$LIB" 2>&1)"
kill -9 "$OTHER15" 2>/dev/null
grep -q "RC=1" <<<"$out15" \
  || { echo "FAIL [15]: _fhm_enqueue devolveu sucesso sobre um destino OCUPADO por terceiro — 'mv' aninhou, o processo acredita ter enfileirado, nunca vira cabeça e volta ao timeout sobre recurso livre: $out15"; exit 1; }
grep -q "destino de ticket ocupado por terceiro" <<<"$out15" \
  || { echo "FAIL [15]: detectou sem NOMEAR a anomalia — quem lê o log não saberia por que o carimbo mudou: $out15"; exit 1; }
grep -q "DONO=$OTHER15" <<<"$out15" \
  || { echo "FAIL [15]: o ticket do terceiro foi corrompido — nunca destrua o que você não provou ser seu: $out15"; exit 1; }
echo "OK [15]"

scenario "[16] viés solta-e-retoma: com a fila, quem espera entra ANTES da segunda posse"
# A propriedade-título. Sem fila, quem solta e retoma já está a poucas instruções do mkdir e vence
# sistematicamente quem dorme num intervalo de polling. O CONTROLE é a outra metade: sem a fila, a
# mesma corrida tem de mostrar o viés, senão o cenário não prova que a fila fez diferença.
run_bias() {  # run_bias <fila-ligada 0|1> -> ecoa a ordem observada
  local qon="$1" bx; bx="$(newbox)"; local W="$bx/wit"; : > "$W"
  [ "$qon" = "1" ] && : > "$bx/w151res.q.enabled"
  cat > "$bx/h.sh" <<'H'
set -uo pipefail
. "$LIBP"
for i in 1 2 3; do
  forge_heavy_mutex_acquire --label "H$i" --timeout 20 >/dev/null 2>&1 || exit $?
  printf 'H\n' >> "$WIT"
  sleep 1.2
  forge_heavy_mutex_release
done
H
  cat > "$bx/w.sh" <<'W'
set -uo pipefail
. "$LIBP"
forge_heavy_mutex_acquire --label W --timeout 20 >/dev/null 2>&1 || exit $?
printf 'W\n' >> "$WIT"
forge_heavy_mutex_release
W
  FORGE_HEAVY_MUTEX_ROOT="$bx" FORGE_HEAVY_MUTEX_RESOURCE=w151res FORGE_HEAVY_MUTEX_POLL_S=1 \
    LIBP="$LIB" WIT="$W" bash "$bx/h.sh" >/dev/null 2>&1 &
  local hp=$!; track "$hp"
  # O W entra DURANTE a primeira posse: se entrar depois da sequência inteira, o cenário mede
  # "chegou tarde" em vez do viés, e a ordem justa vira indistinguível da injusta.
  sleep 0.4
  FORGE_HEAVY_MUTEX_ROOT="$bx" FORGE_HEAVY_MUTEX_RESOURCE=w151res FORGE_HEAVY_MUTEX_POLL_S=1 \
    LIBP="$LIB" WIT="$W" bash "$bx/w.sh" >/dev/null 2>&1 &
  local wp=$!; track "$wp"
  wait "$hp" 2>/dev/null; wait "$wp" 2>/dev/null
  tr -d '\n' < "$W"
}
ord_on="$(run_bias 1)"
ord_off="$(run_bias 0)"
case "$ord_on" in
  *W*H*) : ;;
  *) echo "FAIL [16]: com a fila LIGADA quem esperava só entrou no fim ('$ord_on') — é a inanição medida em campo, e a fila existe para removê-la"; exit 1 ;;
esac
# CONTROLE obrigatório: sem a fila, a mesma corrida TEM de mostrar o viés (quem espera entra no
# fim). Se não mostrar, o cenário é inconclusivo — não se sabe se a fila fez diferença ou se a
# corrida nunca teve viés — e inconclusivo é FAIL, nunca OK.
case "$ord_off" in
  *H*W) : ;;
  *) echo "FAIL [16]: sem a fila a corrida NÃO mostrou o viés ('$ord_off') — o cenário fica inconclusivo, porque a ordem justa com fila deixa de provar que a fila fez diferença"; exit 1 ;;
esac
echo "OK [16]"

scenario "[29] release confere a remoção em vez de assumir"
BOX="$(newbox)"
out29="$(FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res bash -c '
  . "$0"
  forge_heavy_mutex_acquire --timeout 5 >/dev/null 2>&1 || exit $?
  L="$FORGE_HEAVY_MUTEX_HELD_PATH"
  # Torna a remoção impossível de concluir limpando: um subdiretório criado por terceiro entre a
  # decisão e o rm. O release TEM de conferir e diagnosticar, nunca assumir que removeu.
  chmod 500 "$L" 2>/dev/null
  forge_heavy_mutex_release
  chmod 700 "$L" 2>/dev/null
  [ -d "$L" ] && printf "LOCK-FICOU\n"
' "$LIB" 2>&1)"
if grep -q "LOCK-FICOU" <<<"$out29"; then
  grep -qi "não consegui remover" <<<"$out29" \
    || { echo "FAIL [29]: o lock ficou para trás e o release não disse nada — um lock que sobra bloqueia a máquina inteira, e o silêncio faz parecer liberado: $out29"; exit 1; }
fi
echo "OK [29]"

scenario "[35] fail-closed: biblioteca ausente com lib/ presente BLOQUEIA o wrapper"
BOX="$(newbox)"; mkdir -p "$BOX/fake/lib"
cp "$WS/template/.forge/scripts/heavy-run.sh" "$BOX/fake/"
out35="$(bash "$BOX/fake/heavy-run.sh" -- echo x 2>&1)"; rc35=$?
[ "$rc35" -ne 0 ] \
  || { echo "FAIL [35]: com lib/ presente e heavy-mutex.sh ausente, o wrapper rodou a carga DESPROTEGIDA (rc $rc35) — delegação em alvo ausente é erro, não no-op: $out35"; exit 1; }
grep -qi "alvo ausente\|não encontrada" <<<"$out35" \
  || { echo "FAIL [35]: bloqueou sem dizer que a delegação aponta para alvo ausente: $out35"; exit 1; }
echo "OK [35]"

scenario "[37] canal real SEM contenção: a carga executa e o lock não fica para trás"
BOX="$(newbox)"; R="$BOX/repo"
mkdir -p "$R/.forge/scripts/lib" "$R/.forge/hooks/git"
cp "$WS/template/.forge/scripts/lib/heavy-mutex.sh" "$R/.forge/scripts/lib/"
cp "$WS/template/.forge/hooks/git/pre-push" "$R/.forge/hooks/git/"
for _stub in check-ai-attribution.sh check-liaison-acks.sh; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$R/.forge/scripts/$_stub"; chmod +x "$R/.forge/scripts/$_stub"
done
printf 'heavy_mutex:\n  enabled: true\n' > "$R/.forge/forge.yaml"
MARK37="$BOX/mark37"; : > "$MARK37"
printf 'runtime:\n  test: sh -c '"'"'echo CARGA-EXECUTOU >> "$MARK"'"'"'\n' > "$R/.forge/FORGE.md"
git -C "$R" init -q -b main 2>/dev/null; git -C "$R" config user.email t@t; git -C "$R" config user.name t
git -C "$R" config commit.gpgsign false; git -C "$R" add -A 2>/dev/null; git -C "$R" commit -qm init 2>/dev/null
sha37="$(git -C "$R" rev-parse HEAD 2>/dev/null)"
out37="$(cd "$R" && printf 'refs/heads/main %s refs/heads/main 0000000000000000000000000000000000000000\n' "$sha37" | \
  FORGE_ROOT="$R" FORGE_HEAVY_MUTEX_ROOT="$BOX" FORGE_HEAVY_MUTEX_RESOURCE=w151res \
  MARK="$MARK37" bash "$R/.forge/hooks/git/pre-push" origin "file://$R" 2>&1)"; rc37=$?
[ "$rc37" -eq 0 ] \
  || { echo "FAIL [37]: sem contenção o pre-push reprovou (rc $rc37): $out37"; exit 1; }
grep -q "CARGA-EXECUTOU" "$MARK37" 2>/dev/null \
  || { echo "FAIL [37]: a carga NÃO executou sem contenção — o mutex estaria bloqueando quem não tem concorrente: $out37"; exit 1; }
[ ! -d "$BOX/w151res.lock" ] \
  || { echo "FAIL [37]: o lock ficou para trás depois do push — o próximo adquirente esperaria por um detentor que já saiu"; exit 1; }
echo "OK [37]"

scenario "[0] trava positiva de isolamento: a suíte não pode tocar o lock REAL da máquina"
# A trava que impede a suíte de virar a carga que o mutex existe para impedir — e que ela mesma não
# era asseverada. Aconteceu: os cenários da W0 isolavam por TMPDIR, a W1 passou a ignorar TMPDIR, e
# a suíte criou o sidecar em /tmp sem que nada reclamasse. Backstop por existência antes/depois não
# veria, porque "inexistente" bate nas duas pontas.
out0="$(FORGE_HEAVY_MUTEX_TESTING=1 FORGE_HEAVY_MUTEX_ROOT= FORGE_HEAVY_MUTEX_RESOURCE=w151res-zzz \
        bash -c '. "$0"; forge_heavy_mutex_acquire --timeout 2' "$LIB" 2>&1)"; rc0=$?
[ "$rc0" -eq 69 ] \
  || { echo "FAIL [0]: com TESTING=1 e ROOT vazia a aquisição devolveu $rc0 em vez de 69 — um cenário que esqueça de montar a caixa tocaria o lock real da máquina: $out0"; exit 1; }
[ ! -d "/tmp/w151res-zzz.lock" ] && [ ! -d "/tmp/w151res-zzz.q" ] \
  || { echo "FAIL [0]: a tentativa criou artefatos em /tmp apesar da trava"; exit 1; }
echo "OK [0]"

scenario "[44] gate estático: as formas proibidas reprovam e os controles negativos passam"
# Sem este cenário cada regra é uma afirmação não verificada — e uma estava MORTA (printf sobre
# ticket, porque `\$` dentro de aspas duplas vira âncora de fim de linha no ERE).
CHK="$WS/template/.forge/scripts/check-heavy-mutex.sh"
BOX="$(newbox)"; mkdir -p "$BOX/mau" "$BOX/bom"
printf '#!/usr/bin/env bash\nlock="${TMPDIR:-/tmp}/x.lock"\n' > "$BOX/mau/r1.sh"
printf '#!/usr/bin/env bash\nL=/tmp/x.lock\nmkdir "$L"\n' > "$BOX/mau/r2.sh"
printf '#!/usr/bin/env bash\n. lib\nforge_heavy_mutex_acquire\ntrap "cleanup" EXIT\n' > "$BOX/mau/r3.sh"
printf '#!/usr/bin/env bash\n. lib\nforge_heavy_mutex_acquire\ntrap "c; exit 0" EXIT\n' > "$BOX/mau/r4.sh"
printf '#!/usr/bin/env bash\nrm -rf "${LOCK}/"\n' > "$BOX/mau/r5.sh"
printf '#!/usr/bin/env bash\nprintf "%%d" "$ticket"\n' > "$BOX/mau/r7.sh"
printf '#!/usr/bin/env bash\n. lib\n( forge_heavy_mutex_acquire )\n' > "$BOX/mau/r8.sh"
printf '#!/usr/bin/env bash\nmkdir -p "$FORGE_HEAVY_MUTEX_ROOT"\n' > "$BOX/mau/r9.sh"
out44="$(FORGE_ROOT="$WS" bash "$CHK" --path "$BOX/mau" 2>&1)"
for f in r1 r2 r3 r4 r5 r7 r8 r9; do
  grep -q "/$f.sh" <<<"$out44" \
    || { echo "FAIL [44]: a forma proibida de $f.sh NÃO foi pega — a regra correspondente é uma afirmação não verificada"; exit 1; }
done
printf '#!/usr/bin/env bash\n# lock="${TMPDIR:-/tmp}/x.lock"\necho ok\n' > "$BOX/bom/c1.sh"
printf '#!/usr/bin/env bash\nmkdir -p "$ROOT/.forge/specs"\n' > "$BOX/bom/c2.sh"
printf '#!/usr/bin/env bash\n. lib\ntrap "cleanup" EXIT\nforge_heavy_mutex_acquire\n' > "$BOX/bom/c3.sh"
printf '#!/usr/bin/env bash\necho $(( 10#$ticket ))\n' > "$BOX/bom/c4.sh"
out44b="$(FORGE_ROOT="$WS" bash "$CHK" --path "$BOX/bom" 2>&1)"; rc44b=$?
[ "$rc44b" -eq 0 ] \
  || { echo "FAIL [44]: os controles negativos foram reprovados — o gate não discrimina, ele recusa tudo: $out44b"; exit 1; }
echo "OK [44]"

scenario "[46b] o gate estático passa sobre o repositório INTEIRO"
# Uma linha, e fecha uma classe: fixture sintética não pega o gate reprovando o próprio template.
# Aconteceu — o bloco que DETECTA caminho legado no doctor caiu na regra que procura quem o PRODUZ,
# e o gate chegaria vermelho no primeiro push dos quatro repos.
out46b="$(FORGE_ROOT="$WS" bash "$WS/template/.forge/scripts/check-heavy-mutex.sh" --path "$WS" 2>&1)"; rc46b=$?
[ "$rc46b" -eq 0 ] \
  || { echo "FAIL [46b]: o gate reprova o próprio repositório — é assim que um gate vira '--no-verify' de hábito: $out46b"; exit 1; }
echo "OK [46b]"

[ "$SCENARIOS_RUN" -gt 0 ] \
  || { echo "FAIL [contador]: nenhum cenário executado — um gate que não roda nada não cobre nada"; exit 1; }
GATE_ELAPSED=$(( $(date +%s) - GATE_START ))
[ "$GATE_ELAPSED" -le "$GATE_BUDGET_S" ] \
  || { echo "FAIL [orçamento]: a suíte levou ${GATE_ELAPSED}s, acima do teto declarado de ${GATE_BUDGET_S}s — reveja as esperas ou o teto, mas não deixe crescer em silêncio"; exit 1; }
echo "PASS w151-heavy-mutex ($SCENARIOS_RUN cenário(s), ${GATE_ELAPSED}s de ${GATE_BUDGET_S}s)"
