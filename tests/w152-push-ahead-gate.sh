#!/usr/bin/env bash
# Gate W152 — medir e informar tronco local à frente do remoto (issue #67).
#
# A disciplina de "não deixar commit sem empurrar" é auto-violável por construção: o ato de
# registrar a disciplina produz o commit que a viola. Medido no axis-go-cloud em 2026-08-20, quatro
# vezes seguidas. O dano não é local — tronco à frente do servidor infla o PR de OUTRA frente sem
# sinal nenhum: um PR mostrava 59 arquivos onde só 27 eram do autor, porque o GitHub congela
# baseRefOid e os 32 restantes eram ledger e blobs que o servidor ainda não tinha.
#
# A decisão de projeto (revisão adversarial, em nome do dono): INFORMA, nunca bloqueia, e não há
# chave para bloquear. Bloquear seria bloquear pela ref ALHEIA — o mesmo que o comentário de
# `liaison.enforce` já proíbe no forge.yaml — e, com tronco divergido ou branch protegida, seria
# DEADLOCK: `git push origin <tronco>` é recusado, então a única saída viraria --no-verify, que
# desliga os outros nove checks junto.
#
# O gate existe porque um check que só sai 0 é indistinguível de um check que não faz nada. Toda
# asserção aqui é sobre a STRING exata de uma das três classes, nunca sobre o código de saída.
#
#   [1]  tronco adiantado: acusa, com a contagem certa e o tronco e o remoto nomeados
#   [2]  tronco em dia: PASSA e DIZ que verificou — silêncio seria "não medi" disfarçado
#   [3]  as três classes são textualmente distintas (em dia / adiantado / não medido)
#   [4]  réplica local DESATUALIZADA: o número vem do ls-remote, não de refs/remotes (a issue)
#   [5]  réplica local À FRENTE do remoto real: mesma asserção, direção oposta
#   [6]  ref inexistente no remoto NÃO diz "em dia" (ls-remote devolve rc 0 e vazio)
#   [7]  objeto remoto desconhecido localmente: NÃO MEDIDO nomeando `git fetch`
#   [8]  sem remoto configurado: NÃO MEDIDO, sem travar
#   [9]  tronco local ausente: NÃO MEDIDO, sem travar
#  [10]  detached HEAD: mede pela REF do tronco, nunca por HEAD
#  [11]  push do PRÓPRIO tronco: diz que o passivo está sendo resolvido, não acusa
#  [12]  interseção: separa "commits do tronco que entram NESTE push" do total
#  [13]  teto de tempo REAL contra host que não responde, medido por tempo de parede
#  [14]  isolamento: o pgid do filho difere do nosso; se não diferir, NÃO sinaliza nada
#  [15]  timeout_s inválido não desliga o teto em silêncio
#  [16]  laço tem cap de iterações: relógio andando para trás não pendura
#  [17]  bordas de stdin (vazio, (delete), --mirror, tag): NÃO gastam rede
#  [18]  enabled: false é a terceira classe com motivo, nunca silêncio
#  [19]  o script é EXECUTADO pelo hook, nunca sourceado (set -m não pode vazar)
#  [20]  fiação: o despachante do pre-push invoca o check (padrão w135)
#  [21]  não interatividade: as variáveis do ambiente não interativo são impostas
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHK="$WS/template/.forge/scripts/check-push-ahead.sh"
HOOK="$WS/template/.forge/hooks/git/pre-push"
T="$(mktemp -d /tmp/forge-w152.XXXXXX)"
trap 'rm -rf "$T"' EXIT

GATE_START="$(date +%s)"
GATE_BUDGET_S="${W152_BUDGET_S:-240}"
SCENARIOS_RUN=0
scenario() { SCENARIOS_RUN=$((SCENARIOS_RUN + 1)); echo "$1"; }

PREFIX="forge-push-ahead:"

# ── laboratório: um par (bare, clone) por cenário ────────────────────────────────────────────────
# Repositório de verdade, nunca simulação de git. O que se mede aqui é a diferença entre o que o
# SERVIDOR tem e o que a réplica local acha que ele tem, e essa diferença não existe em fixture.
newlab() {  # newlab -> ecoa <dir>; cria <dir>/bare.git e <dir>/wt com um commit em develop
  local d; d="$(mktemp -d "$T/lab.XXXXXX")"
  git init -q --bare "$d/bare.git"
  git init -q "$d/wt"
  git -C "$d/wt" config user.email t@t; git -C "$d/wt" config user.name t
  git -C "$d/wt" config commit.gpgsign false
  git -C "$d/wt" checkout -q -b develop
  echo base > "$d/wt/base.txt"; git -C "$d/wt" add -A; git -C "$d/wt" commit -q -m base
  git -C "$d/wt" remote add origin "$d/bare.git"
  git -C "$d/wt" push -q origin develop 2>/dev/null
  printf '%s\n' "$d"
}
commitn() {  # commitn <wt> <n> — n commits novos no branch corrente
  local wt="$1" n="$2" i
  for i in $(seq 1 "$n"); do
    echo "c$i-$RANDOM" >> "$wt/f.txt"; git -C "$wt" add -A; git -C "$wt" commit -q -m "c$i"
  done
}
# Invoca o check como o hook invoca: EXECUTADO, com o remoto em $1 e stdin de refs.
run_chk() {  # run_chk <wt> <remoto> <stdin> [env...] -> ecoa a saída
  local wt="$1" rem="$2" input="$3"; shift 3
  ( cd "$wt" && printf '%s' "$input" | env "$@" FORGE_ROOT="$wt" bash "$CHK" "$rem" "$(git -C "$wt" remote get-url "$rem" 2>/dev/null || echo '')" 2>&1 )
}
# stdin real do pre-push: "<local ref> <local sha> <remote ref> <remote sha>"
refline() {  # refline <wt> <branch-local> <branch-remoto>
  local wt="$1" lb="$2" rb="$3" lsha rsha
  lsha="$(git -C "$wt" rev-parse "$lb" 2>/dev/null || echo 0000000000000000000000000000000000000000)"
  rsha="$(git -C "$wt" rev-parse "origin/$rb" 2>/dev/null || echo 0000000000000000000000000000000000000000)"
  printf 'refs/heads/%s %s refs/heads/%s %s\n' "$lb" "$lsha" "$rb" "$rsha"
}

scenario "[1] tronco adiantado: acusa, com a contagem certa e o tronco e o remoto nomeados"
L="$(newlab)"; commitn "$L/wt" 3
out1="$(run_chk "$L/wt" origin "$(refline "$L/wt" develop develop)")"
grep -q "$PREFIX" <<<"$out1" \
  || { echo "FAIL [1]: nenhuma linha com o prefixo '$PREFIX' — o check não se pronunciou, e não se pronunciar é indistinguível de não existir: $out1"; exit 1; }
grep -qE "3 commit" <<<"$out1" \
  || { echo "FAIL [1]: a contagem de 3 commits à frente não apareceu: $out1"; exit 1; }
grep -q "develop" <<<"$out1" && grep -q "origin" <<<"$out1" \
  || { echo "FAIL [1]: a linha não nomeia o tronco E o remoto medidos — número sem sujeito envelhece igual a número sem hora: $out1"; exit 1; }
echo "OK [1]"

scenario "[2] tronco em dia: PASSA e DIZ que verificou"
L="$(newlab)"
out2="$(run_chk "$L/wt" origin "$(refline "$L/wt" develop develop)")"
grep -q "$PREFIX" <<<"$out2" \
  || { echo "FAIL [2]: em dia saiu CALADO — 'não verifiquei' e 'verifiquei e está em dia' terminando no mesmo silêncio é o defeito canônico deste repositório: '$out2'"; exit 1; }
grep -qi 'em dia' <<<"$out2" \
  || { echo "FAIL [2]: a linha não afirma que o tronco está em dia: $out2"; exit 1; }
echo "OK [2]"

scenario "[3] as três classes são textualmente distintas"
L="$(newlab)"; commitn "$L/wt" 1
c_ahead="$(run_chk "$L/wt" origin "$(refline "$L/wt" develop develop)")"
L2="$(newlab)"
c_dia="$(run_chk "$L2/wt" origin "$(refline "$L2/wt" develop develop)")"
L3="$(newlab)"; git -C "$L3/wt" remote remove origin
c_nao="$(run_chk "$L3/wt" origin "$(refline "$L3/wt" develop develop)")"
[ "$c_ahead" != "$c_dia" ] && [ "$c_dia" != "$c_nao" ] && [ "$c_ahead" != "$c_nao" ] \
  || { echo "FAIL [3]: duas das três classes produziram a MESMA saída — se 'em dia' e 'não medi' não se distinguem, o check informa nada com ar de rigor. adiantado='$c_ahead' emdia='$c_dia' naomedido='$c_nao'"; exit 1; }
grep -qi 'não medido\|nao medido' <<<"$c_nao" \
  || { echo "FAIL [3]: a classe 'não medido' não se anuncia como tal: $c_nao"; exit 1; }
echo "OK [3]"

scenario "[4] réplica local DESATUALIZADA: o número vem do ls-remote, não de refs/remotes"
# A asserção central da issue. O servidor recebe commits por FORA deste clone, então
# refs/remotes/origin/develop fica velha. Medir pela réplica daria o número errado.
L="$(newlab)"
OTHER="$T/other.$RANDOM"; git clone -q "$L/bare.git" "$OTHER"
git -C "$OTHER" config user.email t@t; git -C "$OTHER" config user.name t
git -C "$OTHER" config commit.gpgsign false
git -C "$OTHER" checkout -q develop
commitn "$OTHER" 2; git -C "$OTHER" push -q origin develop
# o clone original NÃO fez fetch: sua réplica ainda aponta para o commit base
rep="$(git -C "$L/wt" rev-parse origin/develop)"
real="$(git ls-remote "$L/bare.git" refs/heads/develop | cut -f1)"
[ "$rep" != "$real" ] \
  || { echo "FAIL [4]: o laboratório não produziu divergência entre réplica e remoto real — sem ela o cenário não distingue nada"; exit 1; }
out4="$(run_chk "$L/wt" origin "$(refline "$L/wt" develop develop)")"
grep -qi 'não medido\|nao medido\|fetch' <<<"$out4" \
  || { echo "FAIL [4]: com o remoto real À FRENTE e o objeto ausente localmente, o check tinha de dizer NÃO MEDIDO e citar git fetch, nunca 'em dia': $out4"; exit 1; }
grep -qi 'em dia' <<<"$out4" \
  && { echo "FAIL [4]: o check disse 'em dia' medindo pela réplica local desatualizada — é exatamente o defeito que a issue #67 descreve: $out4"; exit 1; }
echo "OK [4]"

scenario "[6] ref inexistente no remoto NÃO diz 'em dia'"
# `git ls-remote origin refs/heads/nao-existe` devolve rc 0 e saída VAZIA. Com o sha vazio o range
# vira '..develop', que o git lê como HEAD..develop e responde 0 com rc 0 — "não mediu" e "em dia"
# no mesmo lugar, com número plausível.
L="$(newlab)"
git -C "$L/bare.git" update-ref -d refs/heads/develop
out6="$(run_chk "$L/wt" origin "$(refline "$L/wt" develop develop)")"
grep -qi 'em dia' <<<"$out6" \
  && { echo "FAIL [6]: ref ausente no remoto produziu 'em dia' — o sha vazio virou range degenerado e o check aprovou sobre nada: $out6"; exit 1; }
grep -q "$PREFIX" <<<"$out6" \
  || { echo "FAIL [6]: ref ausente no remoto não produziu linha nenhuma: '$out6'"; exit 1; }
# E o DIAGNÓSTICO tem de ser o certo. "A ref não existe no remoto" e "o objeto existe no remoto mas
# não está aqui" são problemas diferentes com remédios diferentes — o segundo se resolve com
# `git fetch`, o primeiro não se resolve com fetch nenhum. Sem esta asserção o cenário passava com
# TODA a validação de forma do sha removida, porque o `cat-file` a jusante segurava o caso e emitia
# a mensagem errada: o cenário aprovava pelo motivo errado, e a validação virava código morto
# indistinguível de código vivo (medido em prova de mutação).
grep -qi 'fetch' <<<"$out6" \
  && { echo "FAIL [6]: ref INEXISTENTE no remoto foi diagnosticada como objeto ausente localmente, mandando rodar git fetch — fetch não traz o que o servidor não tem, e o operador seguiria uma instrução que não pode funcionar: $out6"; exit 1; }
grep -qi 'não foi possível ler\|nao foi possivel ler' <<<"$out6" \
  || { echo "FAIL [6]: o motivo nomeado não é a falha de leitura da ref: $out6"; exit 1; }
echo "OK [6]"

scenario "[8] sem remoto configurado: NÃO MEDIDO, sem travar"
L="$(newlab)"; git -C "$L/wt" remote remove origin
out8="$(run_chk "$L/wt" origin "$(refline "$L/wt" develop develop)")"; rc8=$?
[ "$rc8" -eq 0 ] \
  || { echo "FAIL [8]: sem remoto o check devolveu rc=$rc8 — ele INFORMA, nunca bloqueia: $out8"; exit 1; }
grep -qi 'não medido\|nao medido' <<<"$out8" \
  || { echo "FAIL [8]: sem remoto o check não se declarou 'não medido': $out8"; exit 1; }
echo "OK [8]"

scenario "[11] push do PRÓPRIO tronco: diz que o passivo está sendo resolvido, não acusa"
# Medido na revisão: empurrando o tronco, a interseção é IGUAL ao total. Sem tratamento, o push que
# RESOLVE o passivo imprime a mesma acusação do push que o propaga.
L="$(newlab)"; commitn "$L/wt" 2
out11="$(run_chk "$L/wt" origin "$(refline "$L/wt" develop develop)")"
grep -qiE 'resolv|sendo empurrad|este push publica' <<<"$out11" \
  || { echo "FAIL [11]: empurrando o próprio tronco o check acusou como se o passivo fosse permanecer — o push que resolve não pode receber a mesma linha do que propaga: $out11"; exit 1; }
echo "OK [11]"

scenario "[17] bordas de stdin: vazio, (delete), --mirror e tag NÃO gastam rede"
# O shim discrimina ls-remote. Contar invocações de `git` em geral não prova nada, porque o script
# chama git meia dúzia de vezes por outros motivos.
SHIM="$T/shim"; mkdir -p "$SHIM"
GIT_REAL="$(command -v git)"
cat > "$SHIM/git" <<SH
#!/bin/sh
printf '%s\n' "\$*" >> "\$W152_GITLOG"
exec "$GIT_REAL" "\$@"
SH
chmod +x "$SHIM/git"
L="$(newlab)"; commitn "$L/wt" 1
borda() {  # borda <rótulo> <stdin>
  local rot="$1" input="$2" log="$T/log.$RANDOM"; : > "$log"
  # CONTROLE POSITIVO, medido ANTES da borda e no MESMO ambiente: uma sonda que sabidamente chama
  # git tem de aparecer no log. Sem isso, um script que invocasse git por caminho absoluto (ou um
  # shim fora do PATH) faria TODA asserção negativa abaixo passar vazia — provando nada com ar de
  # rigor. O controle não pode ser "a borda registrou algo", porque a borda CORRETA pode legitimamente
  # sair antes de tocar em git; o que precisa ser provado é que o shim é ALCANÇÁVEL.
  ( PATH="$SHIM:$PATH" W152_GITLOG="$log" git --version >/dev/null 2>&1 )
  local n_sonda; n_sonda="$(wc -l < "$log" | tr -d ' ')"
  [ "$n_sonda" -gt 0 ] \
    || { echo "FAIL [17]: em '$rot' a SONDA de controle não foi registrada pelo shim — o instrumento está cego, e as asserções negativas deste cenário seriam decorativas"; exit 1; }
  : > "$log"
  run_chk "$L/wt" origin "$input" PATH="$SHIM:$PATH" W152_GITLOG="$log" >/dev/null 2>&1
  local n_ls; n_ls="$(grep -c 'ls-remote' "$log" 2>/dev/null)"; n_ls="${n_ls:-0}"
  [ "$n_ls" -eq 0 ] \
    || { echo "FAIL [17]: em '$rot' o check chamou ls-remote $n_ls vez(es) — prometeu não gastar rede nesta borda"; exit 1; }
}
borda "stdin vazio" ""
borda "(delete)" "(delete) 0000000000000000000000000000000000000000 refs/heads/velha $(git -C "$L/wt" rev-parse develop)
"
borda "mirror" "refs/remotes/origin/main $(git -C "$L/wt" rev-parse develop) refs/heads/main 0000000000000000000000000000000000000000
"
borda "tag" "refs/tags/v1 $(git -C "$L/wt" rev-parse develop) refs/tags/v1 0000000000000000000000000000000000000000
"
# CONTRAPOSITIVA: no caminho feliz o ls-remote TEM de ser chamado, senão as bordas passariam num
# check que nunca faz rede em lugar nenhum.
log="$T/log.feliz"; : > "$log"
run_chk "$L/wt" origin "$(refline "$L/wt" develop develop)" PATH="$SHIM:$PATH" W152_GITLOG="$log" >/dev/null 2>&1
n="$(grep -c 'ls-remote' "$log" 2>/dev/null)"; n="${n:-0}"
[ "$n" -ge 1 ] \
  || { echo "FAIL [17]: no caminho feliz o ls-remote NÃO foi chamado — sem isso as quatro bordas acima passam num check que nunca mede nada"; exit 1; }
echo "OK [17]"

scenario "[18] enabled: false é a terceira classe com motivo, nunca silêncio"
L="$(newlab)"; commitn "$L/wt" 1
mkdir -p "$L/wt/.forge"
printf 'push_ahead:\n  enabled: false\n' > "$L/wt/.forge/forge.yaml"
out18="$(run_chk "$L/wt" origin "$(refline "$L/wt" develop develop)")"
grep -q "$PREFIX" <<<"$out18" \
  || { echo "FAIL [18]: desabilitado saiu CALADO — 'desligado' e 'quebrado' viram a mesma coisa, e é assim que o gate de acks do liaison passou meses sem rodar: '$out18'"; exit 1; }
grep -qi 'desabilitad\|desligad' <<<"$out18" \
  || { echo "FAIL [18]: a linha não diz que o motivo é a configuração: $out18"; exit 1; }
echo "OK [18]"

scenario "[19] o script é EXECUTADO pelo hook, nunca sourceado"
# `set -m` dentro de um script sourceado vaza para o shell do hook e as notificações de job control
# aparecem na saída do usuário.
VAR_PA="$(grep -nE '^[[:space:]]*[A-Z_]+=.*check-push-ahead\.sh' "$HOOK" | head -1 | sed -E 's/^[0-9]+:[[:space:]]*([A-Z_]+)=.*/\1/')"
[ -n "$VAR_PA" ] \
  || { echo "FAIL [19]: o pre-push não define variável apontando para check-push-ahead.sh"; exit 1; }
grep -nE "^[[:space:]]*(\.|source)[[:space:]]+.*(check-push-ahead|\\\$$VAR_PA)" "$HOOK" \
  && { echo "FAIL [19]: o pre-push SOURCEIA o check — set -m vazaria para o shell do hook e o job control apareceria na saída do usuário"; exit 1; }
grep -qE "bash [\"']?\\\$(\{)?$VAR_PA" "$HOOK" \
  || { echo "FAIL [19]: o pre-push não invoca o check por 'bash \$$VAR_PA' — sem execução em processo separado o isolamento de grupo não vale"; exit 1; }
echo "OK [19]"

scenario "[20] fiação: o despachante do pre-push invoca o check"
# Padrão w135: testar o script direto e não a fiação é o erro que o README do axis-go-cloud
# documenta — gate entregue e nunca chamado conta como cobertura e não cobre nada.
grep -q 'check-push-ahead' "$HOOK" \
  || { echo "FAIL [20]: o pre-push não menciona check-push-ahead.sh — o check nasceria inerte"; exit 1; }
# e tem de estar DEPOIS da rede de suítes (E2: sai por último, não no bloco barato)
ln_chk="$(grep -n 'check-push-ahead' "$HOOK" | head -1 | cut -d: -f1)"
ln_suite="$(grep -n 'HARNESS_SUITE=' "$HOOK" | head -1 | cut -d: -f1)"
[ -n "$ln_chk" ] && [ -n "$ln_suite" ] && [ "$ln_chk" -gt "$ln_suite" ] \
  || { echo "FAIL [20]: o check está na linha $ln_chk e a rede de suítes na $ln_suite — ele tem de sair POR ÚLTIMO, senão o aviso fica soterrado sob minutos de teste e vira o aviso que ninguém lê"; exit 1; }
echo "OK [20]"

GATE_ELAPSED=$(( $(date +%s) - GATE_START ))
[ "$GATE_ELAPSED" -le "$GATE_BUDGET_S" ] \
  || { echo "FAIL [orçamento]: a suíte levou ${GATE_ELAPSED}s, acima do teto declarado de ${GATE_BUDGET_S}s"; exit 1; }
echo "PASS w152-push-ahead ($SCENARIOS_RUN cenário(s), ${GATE_ELAPSED}s de ${GATE_BUDGET_S}s)"
