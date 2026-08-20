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
TMPDIR="$TMPDIR" LIBP="$LIBP" bash "$BOXP/child.sh"
rc=$?
[ -d "$LOCKP" ] && printf 'LOCK-STILL-THERE\n'
exit $rc
PARENT
out30="$(TMPDIR="$BOX" LIBP="$LIB" BOXP="$BOX" bash "$BOX/parent.sh" 2>&1)"; rc30=$?
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
  out22="$(TMPDIR="$BOX" LIBP="$LIB" PAY="$pay" bash "$BOX/run.sh" 2>&1)"; rc22=$?
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
out3="$(FORGE_HEAVY_MUTEX_ROOT= FORGE_HEAVY_MUTEX_RESOURCE=w151res-default \
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

[ "$SCENARIOS_RUN" -gt 0 ] \
  || { echo "FAIL [contador]: nenhum cenário executado — um gate que não roda nada não cobre nada"; exit 1; }
echo "PASS w151-heavy-mutex ($SCENARIOS_RUN cenário(s))"
