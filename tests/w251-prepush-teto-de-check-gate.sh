#!/usr/bin/env bash
# Gate W251 — issue #135: `run_check` (pre-push) ganha um teto OPT-IN de tempo via `perl alarm`,
# o mesmo mecanismo de `forge_run_gate` (lib/forge-runtime.sh:49) — mas SEM herdar o default de
# 300s dele (DA-11, docs/plans/2026-09-15-plano-issues-abertas.md, seção "#135"). A própria issue
# mediu ~470s acumulados em quatro testes de consumidor legítimos; reusar 300s como default mataria
# pushes hoje verdes. `FORGE_PREPUSH_CHECK_TIMEOUT_S` não tem valor de fábrica: AUSENTE é
# DESLIGADO, byte a byte o comportamento de antes da #135 — é o que o cenário [2] prova.
#
# Antes desta correção, `run_check` redirecionava a saída para um log temporário e só imprimia no
# fim, SEM teto algum: um consumidor mediu ~8min silenciosos em quatro testes pesados e cinco
# tentativas de diagnóstico concluíram "deadlock" quando era custo acumulado (issue #135, corpo).
#
#   [1] positiva — com teto (2s) e `runtime.test: sleep 8`, o hook sai BLOQUEADO em poucos
#       segundos (nunca espera os 8s inteiros), nomeando o check ("test") e o teto (2s), com a
#       mensagem literal do desenho: "excedeu o teto de 2s (morto por teto, não reprovado)"
#   [2] contrafactual — sem a variável (ausente, nunca "0" ou vazio-declarado), `runtime.test:
#       sleep 3` passa normalmente — o teto opt-in nunca vira default por acidente
#   [3] mutação — remover a condição que ativa o `perl alarm` faz o cenário [1] voltar a rc 0
#       (sleep 8 completo, sem bloqueio) — a proteção depende mesmo do alarm, não de outra coisa;
#       recontrole com a cópia pristina restaura o bloqueio
#   [4] PBT (semente fixa, LCG próprio — Numerical Recipes, bits altos — reproduz idêntico em
#       qualquer bash, nunca $RANDOM) — pares (duração d, teto t), d,t em [1,4], |d-t| >= 2: o
#       desfecho é "morto por teto" se e somente se d > t; cobre as duas direções
#   [5] SENTINELA — o gate examinou os cenários declarados (zero cenário executado reprova)
set -uo pipefail
# Isolamento git (LDG-0201): GIT_DIR herdado do ambiente faria os comandos git abaixo obedecerem
# ao repositório de quem invoca o gate, não ao repositório sintético criado aqui.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK_SRC="$WS/template/.forge/hooks/git/pre-push"
DECLARADOS=5
EXAMINADOS=0
cen() { EXAMINADOS=$((EXAMINADOS + 1)); }

[ -f "$HOOK_SRC" ] || { echo "FAIL [0]: $HOOK_SRC não existe"; exit 1; }

T="$(mktemp -d "${TMPDIR:-/tmp}/forge-w251.XXXXXX")" || { echo "FAIL [0]: mktemp -d falhou"; exit 1; }
trap 'rm -rf "$T"' EXIT

# ── fixture ───────────────────────────────────────────────────────────────────────────────────
# Repositório mínimo, SEM `.forge/scripts/` nem `.forge/hooks/git/lib/`: cada sítio de delegação
# do pre-push (docs-reviewed, red-first, ai-attribution, acks, liaison, worktree-prereqs, heavy-
# mutex, runtime.gates, harness-tests) degrada para no-op legítimo quando o DIRETÓRIO que o
# hospedaria não existe em nenhuma árvore (contrato de `resolve_delegated`, rc 2) — exatamente o
# comportamento já medido pelo w97 (mesma técnica). Isso isola o que este gate mede: só
# `run_check` para typecheck/test, sem precisar simular a instalação inteira do harness.
#
# `local_sha` é um SHA sintético (nunca resolvido por git; typecheck/test não tocam objetos) e
# `remote_sha` é zero — publica uma branch NOVA de verdade (não é o contrato de deleção das
# issues #132/#134, que pularia justamente o run_check sob teste).
R="$T/repo"
mkdir -p "$R/.forge/hooks/git"
git -C "$R" init -q -b main
cp "$HOOK_SRC" "$R/.forge/hooks/git/pre-push"

FEED='refs/heads/main aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa refs/heads/main 0000000000000000000000000000000000000000'

write_test_cmd() {  # write_test_cmd <cmd> — grava runtime.test no FORGE.md da fixture
  cat > "$R/.forge/FORGE.md" <<EOF
runtime:
  typecheck:
  test: $1
EOF
}

push_out() {  # push_out -> stdout+stderr combinados do hook; usa FORGE_PREPUSH_CHECK_TIMEOUT_S
  # herdado do ambiente do chamador (export/unset feito por quem invoca)
  (cd "$R" && printf '%s\n' "$FEED" | bash .forge/hooks/git/pre-push origin "file://$R" 2>&1)
}

# ── [1] ──────────────────────────────────────────────────────────────────────────────────────
echo "[1] positiva — teto de 2s com 'runtime.test: sleep 8': bloqueia nomeando o check e o teto"
write_test_cmd "sleep 8"
export FORGE_PREPUSH_CHECK_TIMEOUT_S=2
t0=$(date +%s 2>/dev/null || echo 0)
out1="$(push_out)"; rc1=$?
t1=$(date +%s 2>/dev/null || echo 0)
unset FORGE_PREPUSH_CHECK_TIMEOUT_S
el1=$((t1 - t0))
[ "$rc1" -ne 0 ] || { echo "FAIL [1]: pre-push saiu rc 0 com teto de 2s e sleep 8 — saída:"; echo "$out1"; exit 1; }
case "$out1" in
  *"pre-push BLOQUEADO: test excedeu o teto de 2s (morto por teto, não reprovado)"*) : ;;
  *) echo "FAIL [1]: mensagem exata de teto ausente — saída:"; echo "$out1"; exit 1 ;;
esac
[ "$el1" -lt 6 ] || { echo "FAIL [1]: o hook levou ${el1}s — o teto de 2s não interrompeu o sleep 8"; exit 1; }
cen
echo "OK [1] — bloqueado em ${el1}s, nomeando 'test' e o teto de 2s"

# ── [2] ──────────────────────────────────────────────────────────────────────────────────────
echo "[2] contrafactual — sem teto (variável AUSENTE), 'runtime.test: sleep 3' passa normalmente"
write_test_cmd "sleep 3"
unset FORGE_PREPUSH_CHECK_TIMEOUT_S
out2="$(push_out)"; rc2=$?
[ "$rc2" -eq 0 ] || { echo "FAIL [2]: pre-push bloqueou sem a variável de teto (rc=$rc2) — saída:"; echo "$out2"; exit 1; }
case "$out2" in *"excedeu o teto"*) echo "FAIL [2]: mensagem de teto não deveria aparecer com a variável ausente — saída:"; echo "$out2"; exit 1 ;; esac
case "$out2" in *"pre-push: test OK"*) : ;; *) echo "FAIL [2]: 'test OK' ausente — saída:"; echo "$out2"; exit 1 ;; esac
cen
echo "OK [2] — passou sem menção a teto"

# ── [3] ──────────────────────────────────────────────────────────────────────────────────────
echo "[3] mutação — desligar a condição do perl alarm faz [1] voltar a rc 0; recontrole restaura"
cp "$R/.forge/hooks/git/pre-push" "$T/hook.pristino"
perl -pi -e 's/if \[ -n "\$FORGE_PREPUSH_CHECK_TIMEOUT_S" \] && command -v perl >\/dev\/null 2>&1; then/if false; then/' "$R/.forge/hooks/git/pre-push"
if cmp -s "$R/.forge/hooks/git/pre-push" "$T/hook.pristino"; then
  echo "FAIL [3]: mutação não alterou o hook — o padrão de busca não casou (drift entre este gate e o fonte)"; exit 1
fi
bash -n "$R/.forge/hooks/git/pre-push" || { echo "FAIL [3]: mutante não é bash sintaticamente válido"; cp "$T/hook.pristino" "$R/.forge/hooks/git/pre-push"; exit 1; }

write_test_cmd "sleep 8"
export FORGE_PREPUSH_CHECK_TIMEOUT_S=2
outm="$(push_out)"; rcm=$?
unset FORGE_PREPUSH_CHECK_TIMEOUT_S
if [ "$rcm" -ne 0 ]; then
  echo "FAIL [3]: mutante ainda bloqueou (rc=$rcm) — a mutação não removeu a proteção. saída:"
  echo "$outm"
  cp "$T/hook.pristino" "$R/.forge/hooks/git/pre-push"
  exit 1
fi

# recontrole: cópia pristina de volta, mesmo cenário — o bloqueio tem de voltar
cp "$T/hook.pristino" "$R/.forge/hooks/git/pre-push"
write_test_cmd "sleep 8"
export FORGE_PREPUSH_CHECK_TIMEOUT_S=2
outr="$(push_out)"; rcr=$?
unset FORGE_PREPUSH_CHECK_TIMEOUT_S
[ "$rcr" -ne 0 ] || { echo "FAIL [3]: recontrole não restaurou o bloqueio (rc=0) — saída:"; echo "$outr"; exit 1; }
case "$outr" in *"excedeu o teto"*) : ;; *) echo "FAIL [3]: recontrole sem a mensagem de teto — saída:"; echo "$outr"; exit 1 ;; esac
cen
echo "OK [3] — mutante sai rc 0 (sleep 8 completo, sem bloqueio); recontrole restaura o bloqueio"

# ── [4] ──────────────────────────────────────────────────────────────────────────────────────
echo "[4] PBT — pares (duração d, teto t) gerados (semente fixa, LCG próprio): morto por teto sse d > t"
# LCG PRÓPRIO (Numerical Recipes: a=1103515245, c=12345, m=2^31), nunca \$RANDOM: \$RANDOM muda de
# gerador entre versões do bash, o que torna a "semente fixa" reprodutível só na máquina que a
# mediu (mesma nota do w224). Sorteio pelos BITS ALTOS (`>> 16`), nunca o bit baixo, que tem
# período curto em LCGs desta forma.
LCG_A=1103515245
LCG_C=12345
LCG_M=2147483648
_lcg_state=424899
lcg_next() { _lcg_state=$(( (LCG_A * _lcg_state + LCG_C) % LCG_M )); }
lcg_draw() { lcg_next; _lcg_draw=$(( (_lcg_state >> 16) % $1 )); }  # [0, k)

NPARES=5
i=0
vistos_maior=0
vistos_menor=0
while [ "$i" -lt "$NPARES" ]; do
  tent=0
  d=0; t=0
  while :; do
    tent=$((tent + 1))
    [ "$tent" -le 200 ] || { echo "FAIL [4]: gerador não produziu par válido em 200 tentativas (i=$i)"; exit 1; }
    lcg_draw 4; d=$((1 + _lcg_draw))
    lcg_draw 4; t=$((1 + _lcg_draw))
    diff=$((d - t)); [ "$diff" -ge 0 ] || diff=$((-diff))
    [ "$diff" -ge 2 ] && break
  done
  if [ "$d" -gt "$t" ]; then vistos_maior=$((vistos_maior + 1)); else vistos_menor=$((vistos_menor + 1)); fi
  write_test_cmd "sleep $d"
  export FORGE_PREPUSH_CHECK_TIMEOUT_S="$t"
  outp="$(push_out)"; rcp=$?
  unset FORGE_PREPUSH_CHECK_TIMEOUT_S
  if [ "$d" -gt "$t" ]; then
    [ "$rcp" -ne 0 ] || { echo "FAIL [4]: par (d=$d,t=$t) deveria estourar o teto e saiu rc 0 — saída:"; echo "$outp"; exit 1; }
    case "$outp" in *"excedeu o teto de ${t}s"*) : ;; *) echo "FAIL [4]: par (d=$d,t=$t) sem a mensagem de teto — saída:"; echo "$outp"; exit 1 ;; esac
  else
    [ "$rcp" -eq 0 ] || { echo "FAIL [4]: par (d=$d,t=$t) deveria passar e saiu rc=$rcp — saída:"; echo "$outp"; exit 1; }
    case "$outp" in *"excedeu o teto"*) echo "FAIL [4]: par (d=$d,t=$t) não deveria mencionar teto — saída:"; echo "$outp"; exit 1 ;; esac
  fi
  i=$((i + 1))
done
[ "$vistos_maior" -ge 1 ] && [ "$vistos_menor" -ge 1 ] \
  || { echo "FAIL [4]: PBT não cobriu as duas direções (d>t: $vistos_maior, d<t: $vistos_menor)"; exit 1; }
cen
echo "OK [4] — $NPARES pares (d>t: $vistos_maior, d<t: $vistos_menor)"

# ── [5] ──────────────────────────────────────────────────────────────────────────────────────
cen
echo "[5] SENTINELA — $EXAMINADOS/$DECLARADOS cenários examinados"
[ "$EXAMINADOS" -eq "$DECLARADOS" ] || { echo "FAIL [5]: $EXAMINADOS/$DECLARADOS cenários examinados — universo vazio não é ausência de defeito"; exit 1; }
echo "OK [5]"

echo "PASS w251-prepush-teto-de-check-gate"
