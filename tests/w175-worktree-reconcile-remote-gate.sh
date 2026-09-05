#!/usr/bin/env bash
# Gate W175 — worktree-reconcile.sh mede ahead/behind pelo REMOTO REAL, não pela réplica local
# (LDG-0056).
#
# `refs/remotes/<remote>/*` é réplica LOCAL e pode estar desatualizada NAS DUAS DIREÇÕES: sem
# `fetch` recente ela ignora o que o servidor já tem, e depois de um `fetch` de outro processo ela
# pode registrar mais do que este processo ainda sabia. É o MESMO defeito que o
# `check-push-ahead.sh` corrigiu no `pre-push` (issue #67, `tests/w152`) — a técnica é a mesma
# (`git ls-remote`, nunca a réplica), mas o desenho aqui é diferente: `git worktree` COMPARTILHA
# `refs/remotes/*` e o banco de objetos entre TODOS os worktrees do mesmo repositório, então uma
# leitura de rede POR REMOTO — nunca por worktree — já cobre todos eles (0,55-0,73s por chamada
# medidos na #67; um `ls-remote` por worktree seria custo real em qualquer repositório com N
# worktrees ativos).
#
#   [1]  réplica DESATUALIZADA (servidor à frente, objeto ainda desconhecido localmente): o script
#        ANTIGO reportava "ahead=0 behind=0" com confiança — o sintoma exato descrito no ledger.
#        O corrigido diz NÃO MEDIDO em vez de mentir.
#   [2]  réplica em dia: medido via ls-remote, números corretos e rotulados como medidos.
#   [3]  leitura COMPARTILHADA: N worktrees do MESMO remoto pagam UMA chamada de rede só.
#   [4]  remoto inalcançável: NÃO MEDIDO, nunca trava — termina num teto generoso, não fino.
#   [5]  sem upstream configurado: não tenta medir, rótulo próprio ("sem upstream").
#   [6]  RED histórico: a versão pré-correção (HEAD) reproduz o [1] mentindo "ahead=0 behind=0";
#        controle e recontrole via cmp confirmam que restaurar o arquivo corrigido não o corrompeu.
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$WS/template/.forge/scripts/worktree-reconcile.sh"
T="$(mktemp -d /tmp/forge-w175.XXXXXX)"
trap 'rm -rf "$T"' EXIT

GATE_START="$(date +%s)"
GATE_BUDGET_S="${W175_BUDGET_S:-120}"
SCENARIOS_RUN=0
scenario() { SCENARIOS_RUN=$((SCENARIOS_RUN + 1)); echo "$1"; }

[ -f "$SCRIPT" ] || { echo "FAIL [setup]: $SCRIPT não existe"; exit 1; }
# Snapshot ANTES de qualquer fixture — o controle/recontrole do [6] confere contra ISTO, nunca
# contra o próprio arquivo do repositório (que seria uma comparação vazia, sempre verdadeira).
SNAPSHOT="$T/worktree-reconcile.snapshot.sh"
cp "$SCRIPT" "$SNAPSHOT"

# ── laboratório: bare "remoto" + clone real (nunca simulação de git) ────────────────────────────
newlab() {  # newlab <dir> -> cria <dir>/bare.git (HEAD=develop) e <dir>/wt1 com upstream configurado
  local d="$1"
  git init -q --bare "$d/bare.git"
  git init -q "$d/wt1"
  git -C "$d/wt1" config user.email t@t; git -C "$d/wt1" config user.name t
  git -C "$d/wt1" config commit.gpgsign false
  git -C "$d/wt1" checkout -q -b develop
  echo base > "$d/wt1/f.txt"; git -C "$d/wt1" add -A; git -C "$d/wt1" commit -q -m base
  git -C "$d/wt1" remote add origin "$d/bare.git"
  git -C "$d/wt1" push -q -u origin develop
  git -C "$d/bare.git" symbolic-ref HEAD refs/heads/develop
}
# `worktree_reconcile.timeout_s` baixo em todo cenário: os testes usam repositórios LOCAIS
# (transporte file://), então mesmo o "não medido" tem de terminar rápido — nada aqui depende de
# vencer uma corrida de rede real.
forge_yaml() {  # forge_yaml <dir> <timeout_s>
  mkdir -p "$1/.forge"
  printf 'worktree_reconcile:\n  timeout_s: %s\n' "$2" > "$1/.forge/forge.yaml"
}

scenario "[1] réplica DESATUALIZADA: o corrigido diz NÃO MEDIDO em vez de 'ahead=0 behind=0' (o defeito do LDG-0056)"
T1="$T/lab1"; mkdir -p "$T1"; newlab "$T1"; forge_yaml "$T1" 3
# Um SEGUNDO clone publica um commit novo no bare — o servidor avança, mas wt1 nunca dá fetch.
git clone -q "$T1/bare.git" "$T1/otherpusher" 2>/dev/null
git -C "$T1/otherpusher" config user.email o@o; git -C "$T1/otherpusher" config user.name o
git -C "$T1/otherpusher" config commit.gpgsign false
git -C "$T1/otherpusher" checkout -q develop 2>/dev/null || git -C "$T1/otherpusher" checkout -q -b develop origin/develop
echo servidor-avancou >> "$T1/otherpusher/f.txt"
git -C "$T1/otherpusher" add -A; git -C "$T1/otherpusher" commit -q -m "so no servidor"
git -C "$T1/otherpusher" push -q origin develop
# Pré-condição: a réplica local de wt1 CONTINUA achando que está em dia (nunca buscou o commit novo).
replica_ahead="$(git -C "$T1/wt1" rev-list --count refs/remotes/origin/develop..develop 2>/dev/null)"
replica_behind="$(git -C "$T1/wt1" rev-list --count develop..refs/remotes/origin/develop 2>/dev/null)"
[ "$replica_ahead" = "0" ] && [ "$replica_behind" = "0" ] \
  || { echo "FAIL [1]: pré-condição não se sustenta — a réplica já não estava 'em dia' (ahead=$replica_ahead behind=$replica_behind), o cenário não mede o que deveria"; exit 1; }
out1="$(FORGE_ROOT="$T1" bash "$SCRIPT" --root "$T1/wt1" 2>&1)"
grep -q "NÃO MEDIDO" <<<"$out1" \
  || { echo "FAIL [1]: com o servidor à frente e o objeto desconhecido localmente, o script não disse NÃO MEDIDO — reportou com confiança sobre um estado que não conferiu: $out1"; exit 1; }
grep -qE 'ahead=0 behind=0 \(NÃO MEDIDO' <<<"$out1" \
  || { echo "FAIL [1]: NÃO MEDIDO apareceu mas não colado ao ahead=0 behind=0 que seria a mentira — a asserção não prova que é O MESMO número da réplica sendo rotulado como não confiável: $out1"; exit 1; }
echo "OK [1]"

scenario "[2] réplica em dia: medido via ls-remote, números corretos"
T2="$T/lab2"; mkdir -p "$T2"; newlab "$T2"; forge_yaml "$T2" 3
out2="$(FORGE_ROOT="$T2" bash "$SCRIPT" --root "$T2/wt1" 2>&1)"
grep -qE 'ahead=0 behind=0 \(medido via ls-remote\)' <<<"$out2" \
  || { echo "FAIL [2]: réplica sincronizada não foi rotulada como MEDIDA via ls-remote: $out2"; exit 1; }
# Agora wt1 avança sozinho (publica) — ahead real e verificável pelas duas fontes ao mesmo tempo.
echo commit-local >> "$T2/wt1/f.txt"; git -C "$T2/wt1" add -A; git -C "$T2/wt1" commit -q -m "local"
out2b="$(FORGE_ROOT="$T2" bash "$SCRIPT" --root "$T2/wt1" 2>&1)"
grep -qE 'ahead=1 behind=0 \(medido via ls-remote\)' <<<"$out2b" \
  || { echo "FAIL [2]: 1 commit local não publicado não apareceu como ahead=1 medido: $out2b"; exit 1; }
echo "OK [2]"

scenario "[3] leitura COMPARTILHADA: N worktrees do MESMO remoto pagam 1 chamada de rede só"
T3="$T/lab3"; mkdir -p "$T3"; newlab "$T3"; forge_yaml "$T3" 3
git -C "$T3/wt1" checkout -q -b feat/x
git -C "$T3/wt1" push -q -u origin feat/x
git -C "$T3/wt1" checkout -q develop
git -C "$T3/wt1" worktree add -q -b feat/a "$T3/wt-a" develop 2>/dev/null
git -C "$T3/wt1" worktree add -q "$T3/wt-b" feat/x 2>/dev/null
SPY="$T3/spy"; mkdir -p "$SPY"
CALLLOG="$T3/lsremote-calls.log"; : > "$CALLLOG"
cat > "$SPY/git" <<SPYEOF
#!/bin/sh
case " \$* " in
  *" ls-remote "*) echo "CALL" >> "$CALLLOG" ;;
esac
exec /usr/bin/git "\$@"
SPYEOF
chmod +x "$SPY/git"
out3="$(PATH="$SPY:$PATH" FORGE_ROOT="$T3" bash "$SCRIPT" --root "$T3/wt1" 2>&1)"
n_wt="$(grep -c '^branch=' <<<"$(printf '%s\n' "$out3" | grep '^  branch=')" 2>/dev/null || true)"
grep -q "Total: 3 worktree(s)." <<<"$out3" \
  || { echo "FAIL [3]: a fixture não montou os 3 worktrees esperados: $out3"; exit 1; }
grep -qE 'develop.*medido via ls-remote|medido via ls-remote' <<<"$out3" \
  || { echo "FAIL [3]: nenhum worktree saiu como medido — a fixture não exercitou o caminho: $out3"; exit 1; }
n_calls="$(wc -l < "$CALLLOG" 2>/dev/null | tr -d ' ')"
[ "${n_calls:-0}" = "1" ] \
  || { echo "FAIL [3]: esperava EXATAMENTE 1 chamada real a 'git ls-remote' para 3 worktrees do mesmo remoto — vieram $n_calls. Ou o cache por remoto não está funcionando, ou está lendo rede por worktree (o custo que a issue registra: 0,55-0,73s por chamada)"; exit 1; }
echo "OK [3]"

scenario "[4] remoto inalcançável: NÃO MEDIDO, nunca trava — teto generoso, não fino"
T4="$T/lab4"; mkdir -p "$T4"; newlab "$T4"; forge_yaml "$T4" 2
git -C "$T4/wt1" remote set-url origin "$T4/nao-existe-mais.git"
t0="$(date +%s)"
out4="$(FORGE_ROOT="$T4" bash "$SCRIPT" --root "$T4/wt1" 2>&1)"; rc4=$?
t1="$(date +%s)"
elapsed=$((t1 - t0))
[ "$rc4" -eq 0 ] \
  || { echo "FAIL [4]: remoto inalcançável fez o script sair com rc=$rc4 (deveria degradar, não falhar): $out4"; exit 1; }
grep -q "NÃO MEDIDO" <<<"$out4" \
  || { echo "FAIL [4]: remoto inalcançável não produziu NÃO MEDIDO: $out4"; exit 1; }
# Bound GENEROSO de propósito (LDG-0055 mesma cautela): a máquina sob carga não pode reprovar por
# contenção. O que se prova é que TERMINA — não que termina no teto exato configurado.
[ "$elapsed" -le 60 ] \
  || { echo "FAIL [4]: levou ${elapsed}s para degradar sobre um remoto local inexistente — parece preso, não terminando: $out4"; exit 1; }
echo "OK [4]"

scenario "[5] sem upstream configurado: rótulo próprio, não tenta medir"
T5="$T/lab5"; mkdir -p "$T5"
git init -q "$T5/solo"
git -C "$T5/solo" config user.email t@t; git -C "$T5/solo" config user.name t
git -C "$T5/solo" config commit.gpgsign false
git -C "$T5/solo" checkout -q -b develop
echo x > "$T5/solo/f.txt"; git -C "$T5/solo" add -A; git -C "$T5/solo" commit -q -m x
forge_yaml "$T5" 2
out5="$(FORGE_ROOT="$T5" bash "$SCRIPT" --root "$T5/solo" 2>&1)"
grep -qE 'upstream=<none>.*\(sem upstream\)' <<<"$out5" \
  || { echo "FAIL [5]: sem upstream configurado não recebeu o rótulo 'sem upstream': $out5"; exit 1; }
echo "OK [5]"

scenario "[6] RED histórico: a versão pré-correção mentia 'ahead=0 behind=0'; controle e recontrole via cmp"
# Prova que o cenário [1] de fato mediria o defeito ANTES da correção — não só depois. Sem isto, a
# suíte prova que o código NOVO funciona, mas não prova que o código VELHO tinha o defeito relatado.
OLD_SCRIPT="$T/worktree-reconcile-old.sh"
if git -C "$WS" show HEAD:template/.forge/scripts/worktree-reconcile.sh > "$OLD_SCRIPT" 2>/dev/null \
   && [ -s "$OLD_SCRIPT" ] \
   && ! grep -q "ls-remote" "$OLD_SCRIPT"; then
  T6="$T/lab6"; mkdir -p "$T6"; newlab "$T6"
  git clone -q "$T6/bare.git" "$T6/otherpusher" 2>/dev/null
  git -C "$T6/otherpusher" config user.email o@o; git -C "$T6/otherpusher" config user.name o
  git -C "$T6/otherpusher" config commit.gpgsign false
  git -C "$T6/otherpusher" checkout -q develop 2>/dev/null || git -C "$T6/otherpusher" checkout -q -b develop origin/develop
  echo servidor-avancou >> "$T6/otherpusher/f.txt"
  git -C "$T6/otherpusher" add -A; git -C "$T6/otherpusher" commit -q -m "so no servidor"
  git -C "$T6/otherpusher" push -q origin develop
  out6="$(FORGE_ROOT="$T6" bash "$OLD_SCRIPT" --root "$T6/wt1" 2>&1)"
  grep -qE 'ahead=0 behind=0($| )' <<<"$out6" \
    || { echo "FAIL [6]: a versão HEAD (pré-correção) não reproduziu 'ahead=0 behind=0' sobre o servidor adiantado — o RED histórico não se sustenta, e sem ele não há prova de que a correção mudou comportamento: $out6"; exit 1; }
  ! grep -q "NÃO MEDIDO\|ls-remote" <<<"$out6" \
    || { echo "FAIL [6]: a versão 'antiga' capturada já usa ls-remote/NÃO MEDIDO — o snapshot de HEAD não é mais o código pré-correção (rode este cenário só na sessão que introduz a correção): $out6"; exit 1; }
  echo "  RED confirmado: $(grep 'ahead=' <<<"$out6")"
else
  echo "  (HEAD já é a versão corrigida — pulando a reprodução do RED histórico; controle/recontrole por cmp abaixo continua valendo)"
fi
# Controle e recontrole: o script sob teste é BYTE A BYTE o mesmo do início ao fim do gate — nenhum
# cenário (nem a leitura do HEAD histórico acima) o mutou por engano.
cmp -s "$SCRIPT" "$SNAPSHOT" \
  || { echo "FAIL [6]: o script sob teste divergiu do snapshot tirado no início do gate — algum cenário mutou o arquivo do repositório"; exit 1; }
echo "OK [6]"

[ "$SCENARIOS_RUN" -gt 0 ] \
  || { echo "FAIL [contador]: nenhum cenário executado"; exit 1; }
GATE_ELAPSED=$(( $(date +%s) - GATE_START ))
[ "$GATE_ELAPSED" -le "$GATE_BUDGET_S" ] \
  || { echo "FAIL [orçamento]: a suíte levou ${GATE_ELAPSED}s, acima do teto declarado de ${GATE_BUDGET_S}s"; exit 1; }
echo "PASS w175-worktree-reconcile-remote ($SCENARIOS_RUN cenário(s), ${GATE_ELAPSED}s de ${GATE_BUDGET_S}s)"
