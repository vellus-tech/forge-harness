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
#   [0]  trava ESTATICA, antes de qualquer execucao: nenhum sinal ao proprio grupo
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
#  [22]  o remoto medido é o do PUSH, nunca `origin` fixo
#  [23]  destino da ref: sha do tronco para OUTRO destino nao e "resolvido"
#  [24]  LDG-0057 (disjuntas): interseção é a UNIÃO das refs publicadas, não o MÁXIMO (caso da issue)
#  [25]  LDG-0057 (sobrepostas): prefixo comum não é contado em dobro nem por MÁXIMO
#  [26]  LDG-0057 (contida): ref aninhada em outra não faz a união regredir
#  [27]  LDG-0057 (vazia): ref sem contribuição não quebra nem reduz a união
#  [28]  LDG-0057 canal real: `git push` de verdade, hook real, união correta pelo stdin do git
#  [29]  LDG-0058: trap cobre morte por sinal (TERM/HUP aqui; INT só por FORMA — ver comentário)
#  [30]  LDG-0060: falha do rev-list na publicação do próprio tronco cai na classe honesta (sha forjado)
#  [31]  LDG-0059: guarda de regressão — 150 refs não voltam a duas chamadas de git por ref
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
  # O verificador NÃO pode compartilhar grupo de processos com o verificado. Um script que sinalize
  # o próprio grupo derruba o gate inteiro, e o gate sai sem reprovar nada — silêncio que uma
  # bateria de mutação lê como aprovação. É a cicatriz deste repositório (um gate que assegura o
  # próprio exploit) em forma nova.
  #
  # A forma ANTERIOR desta função tentava `set -m` dentro de `$( ... & wait $! )` e NÃO isolava:
  # medido, filho e gate ficavam no mesmo pgid, porque o bash desliga job control dentro da
  # substituição de comando. O que salvava o gate era o `set -m` do PRÓPRIO SCRIPT SOB TESTE —
  # isto é, o verificador dependia do verificado para sobreviver, e essa dependência não era
  # verificada por ninguém. O background tem de ser lançado na shell principal da função, com a
  # saída capturada por ARQUIVO; só assim o filho ganha pgid próprio.
  local out _f; _f="$(mktemp "$T/runchk.XXXXXX")"
  set -m
  ( cd "$wt" && printf '%s' "$input" | env "$@" FORGE_ROOT="$wt" bash "$CHK" "$rem" "$(git -C "$wt" remote get-url "$rem" 2>/dev/null || echo '')" ) > "$_f" 2>&1 &
  wait $! 2>/dev/null
  set +m
  out="$(cat "$_f")"; rm -f "$_f"
  printf '%s\n' "$out"
}
# stdin real do pre-push: "<local ref> <local sha> <remote ref> <remote sha>"
refline() {  # refline <wt> <branch-local> <branch-remoto>
  local wt="$1" lb="$2" rb="$3" lsha rsha
  lsha="$(git -C "$wt" rev-parse "$lb" 2>/dev/null || echo 0000000000000000000000000000000000000000)"
  rsha="$(git -C "$wt" rev-parse "origin/$rb" 2>/dev/null || echo 0000000000000000000000000000000000000000)"
  printf 'refs/heads/%s %s refs/heads/%s %s\n' "$lb" "$lsha" "$rb" "$rsha"
}

# ── helpers do teste de propriedade LDG-0057 (união, não máximo) ────────────────────────────────
# Cada "linha" é um ramo com N commits em ARQUIVO PRÓPRIO (nunca f.txt compartilhado): merges de
# ramos concorrentes que tocam o mesmo arquivo podem produzir conflito de verdade, e o laboratório
# existe para medir a interseção, não para testar resolução de merge.
mkline_from() {  # mkline_from <wt> <branch> <start-ref> <n> -> cria n commits em <branch>.txt, ecoa o tip
  local wt="$1" br="$2" start="$3" n="$4" i
  git -C "$wt" checkout -q -b "$br" "$start"
  for i in $(seq 1 "$n"); do
    echo "$i-$RANDOM" >> "$wt/${br}.txt"
    git -C "$wt" add -A; git -C "$wt" commit -q -m "$br-$i"
  done
  git -C "$wt" rev-parse "$br"
}
merge_into_develop() {  # merge_into_develop <wt> <branch>
  git -C "$1" checkout -q develop
  git -C "$1" merge -q --no-ff -m "merge $2" "$2" >/dev/null
}
multiref_stdin() {  # multiref_stdin <wt> <branch>... -> stdin de refs NOVAS (remoto = 0000...)
  local wt="$1"; shift
  local b
  for b in "$@"; do
    printf 'refs/heads/%s %s refs/heads/%s %s\n' "$b" "$(git -C "$wt" rev-parse "$b")" "$b" "0000000000000000000000000000000000000000"
  done
}
extract_inter() {  # extract_inter <saída> -> ecoa N (ou 0 quando a linha diz "nenhum entra")
  local out="$1"
  if grep -q 'nenhum entra' <<<"$out"; then echo 0; return; fi
  grep -oE 'dos quais [0-9]+ entra' <<<"$out" | head -1 | grep -oE '[0-9]+'
}

scenario "[0] trava estática: nenhum sinal dirigido ao PRÓPRIO grupo de processos"
# ANTES de executar o script uma única vez. Dentro de um hook, o líder do grupo é o SHELL QUE
# INVOCOU o `git push`: um sinal para o próprio grupo mata o push do usuário — e, aqui, mataria
# este gate. Medido: com essa mutação o gate morria com rc=143 no [13], sem reprovar nada, e a
# bateria de mutação interpretava o silêncio como aprovação.
grep -q 'ISOLATED' "$CHK" \
  || { echo "FAIL [0]: o script não tem guarda de isolamento nomeada"; exit 1; }
grep -qE 'kill -(TERM|KILL) -- "-\$CHILD_PGID"' "$CHK" \
  || { echo "FAIL [0]: o sinal não é dirigido explicitamente ao grupo do FILHO"; exit 1; }
grep -qE '^[^#]*kill[^#]*-\$(SELF_PGID|\$)' "$CHK" \
  && { echo "FAIL [0]: há sinal dirigido ao PRÓPRIO grupo em linha de código — dentro de um hook isso mata o git push do usuário, e neste gate mataria o próprio verificador antes de ele poder reprovar"; exit 1; }
# A guarda tem de COMPARAR os dois pgid. Um `ISOLATED=1` incondicional passa em qualquer teste
# executável onde o isolamento de fato funcione — e o caso perigoso é exatamente aquele em que ele
# FALHA, que não se forja sem desmontar o `set -m`. Por isso a exigência aqui é sobre a FORMA.
grep -qE '\[ "\$CHILD_PGID" != "\$SELF_PGID" \].*ISOLATED=1' "$CHK" \
  || { echo "FAIL [0]: a guarda de isolamento não compara o pgid do filho com o nosso antes de habilitar o sinal — sem a comparação ela autoriza o kill mesmo quando o filho ficou no NOSSO grupo"; exit 1; }
grep -qE '^[[:space:]]*ISOLATED=1[[:space:]]*$' "$CHK" \
  && { echo "FAIL [0]: há atribuição INCONDICIONAL de ISOLATED=1 — a guarda deixa de ser guarda"; exit 1; }
echo "OK [0]"

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
# Feature branch, NÃO o tronco: empurrar o tronco produz "passivo sendo resolvido", que é outra
# classe. Amostrar a errada fazia toda a asserção de vocabulário abaixo rodar sobre uma linha que
# ninguém filtra, e a acusação real — a que importa — ficava sem cobertura.
git -C "$L/wt" checkout -q -b feat-c3
c_ahead="$(run_chk "$L/wt" origin "refs/heads/feat-c3 $(git -C "$L/wt" rev-parse feat-c3) refs/heads/feat-c3 0000000000000000000000000000000000000000")"
grep -qE 'à frente' <<<"$c_ahead" \
  || { echo "FAIL [3]: o fixture não produziu a classe ADIANTADA — sem ela as asserções de vocabulário abaixo medem outra linha: $c_ahead"; exit 1; }
grep -qi 'resolvid' <<<"$c_ahead" \
  && { echo "FAIL [3]: o fixture produziu 'resolvido' em vez da acusação — é a classe errada: $c_ahead"; exit 1; }
L2="$(newlab)"
c_dia="$(run_chk "$L2/wt" origin "$(refline "$L2/wt" develop develop)")"
L3="$(newlab)"; git -C "$L3/wt" remote remove origin
c_nao="$(run_chk "$L3/wt" origin "$(refline "$L3/wt" develop develop)")"
[ "$c_ahead" != "$c_dia" ] && [ "$c_dia" != "$c_nao" ] && [ "$c_ahead" != "$c_nao" ] \
  || { echo "FAIL [3]: duas das três classes produziram a MESMA saída — se 'em dia' e 'não medi' não se distinguem, o check informa nada com ar de rigor. adiantado='$c_ahead' emdia='$c_dia' naomedido='$c_nao'"; exit 1; }
grep -qi 'não medido\|nao medido' <<<"$c_nao" \
  || { echo "FAIL [3]: a classe 'não medido' não se anuncia como tal: $c_nao"; exit 1; }
# E não podem compartilhar VOCABULÁRIO: comparar as strings inteiras é satisfeito de graça pela
# contagem e pelo carimbo de horário, então um mutante cuja linha de "adiantado" também diga
# "em dia" passaria — e é essa colisão, não a diferença de bytes, que faz um operador (ou um agente
# que consome a linha por grep) ler a classe errada.
grep -qi 'em dia' <<<"$c_ahead" \
  && { echo "FAIL [3]: a linha de ADIANTADO contém 'em dia' — quem filtra por essa expressão lê tranquilidade onde há passivo: $c_ahead"; exit 1; }
grep -qi 'em dia' <<<"$c_nao" \
  && { echo "FAIL [3]: a linha de NÃO MEDIDO contém 'em dia' — 'não verifiquei' passaria por 'verifiquei e está limpo': $c_nao"; exit 1; }
grep -qi 'não medido\|nao medido' <<<"$c_dia" \
  && { echo "FAIL [3]: a linha de EM DIA contém 'não medido': $c_dia"; exit 1; }
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

scenario "[5] réplica local À FRENTE do remoto real: mesma asserção, direção oposta"
# A réplica desatualiza NAS DUAS DIREÇÕES. O [4] cobre "o servidor andou e o clone não sabe"; este
# cobre o inverso, que é mais sutil: a réplica aponta para um commit que o servidor NÃO tem mais
# (rollback, force-push, branch recriada). Medir por refs/remotes aqui subestima o passivo.
L="$(newlab)"; commitn "$L/wt" 2
# publica e sincroniza a réplica — sem isso ela nunca chega à frente de nada
git -C "$L/wt" push -q origin develop; git -C "$L/wt" fetch -q origin
# agora o SERVIDOR volta atrás (rollback / force-push / branch recriada) e a réplica local fica
# apontando para um commit que o servidor não tem mais
BACK="$(git -C "$L/wt" rev-parse develop~2)"
git -C "$L/bare.git" update-ref refs/heads/develop "$BACK"
rep5="$(git -C "$L/wt" rev-parse origin/develop)"
real5="$(git ls-remote "$L/bare.git" refs/heads/develop | cut -f1)"
[ "$rep5" != "$real5" ] \
  || { echo "FAIL [5]: o laboratório não produziu réplica À FRENTE do remoto — sem isso o cenário não mede a direção oposta"; exit 1; }
out5="$(run_chk "$L/wt" origin "$(refline "$L/wt" develop develop)")"
n5="$(grep -oE '[0-9]+ commit' <<<"$out5" | head -1 | grep -oE '[0-9]+')"
[ "${n5:-0}" -eq 2 ] \
  || { echo "FAIL [5]: com a réplica À FRENTE do remoto real, a contagem devia vir do ls-remote e valer 2, veio '${n5:-vazio}': $out5"; exit 1; }
echo "OK [5]"

scenario "[7] objeto remoto desconhecido localmente: NÃO MEDIDO nomeando git fetch"
L="$(newlab)"
OTH7="$T/o7.$RANDOM"; git clone -q "$L/bare.git" "$OTH7"
git -C "$OTH7" config user.email t@t; git -C "$OTH7" config user.name t
git -C "$OTH7" config commit.gpgsign false; git -C "$OTH7" checkout -q develop
commitn "$OTH7" 1; git -C "$OTH7" push -q origin develop
out7="$(run_chk "$L/wt" origin "$(refline "$L/wt" develop develop)")"
grep -qi 'não medido\|nao medido' <<<"$out7" \
  || { echo "FAIL [7]: objeto remoto ausente localmente não produziu a classe 'não medido': $out7"; exit 1; }
grep -qi 'fetch' <<<"$out7" \
  || { echo "FAIL [7]: a linha não nomeia 'git fetch', que é o remédio DESTE caso — e é o que o distingue da ref inexistente do [6], onde fetch não resolve nada: $out7"; exit 1; }
echo "OK [7]"

scenario "[9] tronco local ausente: NÃO MEDIDO, sem travar"
L="$(newlab)"; commitn "$L/wt" 1
git -C "$L/wt" checkout -q -b feat
git -C "$L/wt" branch -D develop >/dev/null 2>&1
out9="$(run_chk "$L/wt" origin "refs/heads/feat $(git -C "$L/wt" rev-parse feat) refs/heads/feat 0000000000000000000000000000000000000000")"
grep -qi 'não medido\|nao medido' <<<"$out9" \
  || { echo "FAIL [9]: sem o tronco local o check não se declarou 'não medido': $out9"; exit 1; }
echo "OK [9]"

scenario "[10] detached HEAD: não mede por HEAD nem sai calado"
L="$(newlab)"; commitn "$L/wt" 2
out10="$(run_chk "$L/wt" origin "HEAD $(git -C "$L/wt" rev-parse develop) refs/heads/develop $(git -C "$L/wt" rev-parse origin/develop)")"
grep -q "$PREFIX" <<<"$out10" \
  || { echo "FAIL [10]: push de detached HEAD saiu CALADO — certificar silêncio como correto é a vacuidade que este check existe para combater: '$out10'"; exit 1; }
grep -qi 'detached' <<<"$out10" \
  || { echo "FAIL [10]: a linha não nomeia o motivo (detached HEAD): $out10"; exit 1; }
echo "OK [10]"

scenario "[12] interseção: separa 'commits do tronco que entram NESTE push' do total"
# O número que transforma nag genérico em previsão específica. Ramificando ANTES dos commits do
# tronco, nenhum deles entra no push; ramificando DEPOIS, entram.
L="$(newlab)"
git -C "$L/wt" checkout -q -b feat-antes
commitn "$L/wt" 1
git -C "$L/wt" checkout -q develop; commitn "$L/wt" 3
out12a="$(run_chk "$L/wt" origin "refs/heads/feat-antes $(git -C "$L/wt" rev-parse feat-antes) refs/heads/feat-antes 0000000000000000000000000000000000000000")"
grep -qE 'nenhum entra' <<<"$out12a" \
  || { echo "FAIL [12]: branch ramificada ANTES dos commits do tronco recebeu previsão de interseção não-zero — o número perde o sentido se acusa quem não carrega nada: $out12a"; exit 1; }
git -C "$L/wt" checkout -q -b feat-depois
commitn "$L/wt" 1
out12b="$(run_chk "$L/wt" origin "refs/heads/feat-depois $(git -C "$L/wt" rev-parse feat-depois) refs/heads/feat-depois 0000000000000000000000000000000000000000")"
grep -qE '3 entra' <<<"$out12b" \
  || { echo "FAIL [12]: branch ramificada DEPOIS dos 3 commits do tronco devia prever 3 na interseção: $out12b"; exit 1; }
echo "OK [12]"

scenario "[13] teto de tempo REAL contra host que não responde, medido por tempo de parede"
# 192.0.2.0/24 é TEST-NET-1 (RFC 5737): roteável e sem resposta, que é o que produz a espera longa.
# O git sozinho leva ~75s para desistir; o teto tem de cortar MUITO antes, e o que se mede aqui é
# tempo de PAREDE — um teto que dispara no relógio mas cujo `$( )` só retorna aos 75s não é teto.
L="$(newlab)"; commitn "$L/wt" 1
git -C "$L/wt" remote set-url origin "https://192.0.2.1/x.git"
mkdir -p "$L/wt/.forge"; printf 'push_ahead:\n  enabled: true\n  timeout_s: 3\n' > "$L/wt/.forge/forge.yaml"
t0="$(date +%s)"
out13="$(run_chk "$L/wt" origin "$(refline "$L/wt" develop develop)")"
el13=$(( $(date +%s) - t0 ))
[ "$el13" -le 20 ] \
  || { echo "FAIL [13]: com teto de 3s o check levou ${el13}s de PAREDE — teto que não corta a espera real não é teto, e num pre-push isso é um push que parece travado: $out13"; exit 1; }
grep -qi 'não medido\|nao medido' <<<"$out13" \
  || { echo "FAIL [13]: o timeout não produziu a classe 'não medido' — dizer 'em dia' após não conseguir ler seria a pior saída possível: $out13"; exit 1; }
echo "OK [13] (${el13}s de parede, teto 3s)"

scenario "[14] isolamento: sem pgid próprio comprovado, NENHUM sinal é enviado"
# O cenário mais importante deste gate. Dentro de um hook, o líder do grupo de processos é o SHELL
# QUE INVOCOU o `git push` — sinalizar o grupo mataria o próprio push e o job do usuário. A guarda
# só sinaliza quando o pgid do filho difere do nosso; com `ps` cego, ela tem de degradar para
# "não sinaliza nada". O alvo morto é a mutação `kill -- -$SELF_PGID`, que sobrevivia ao gate.
# A parte estática desta regra vive no [0], antes de qualquer execução — ver o porquê lá.
# Alvo morto executável: com `ps` devolvendo lixo, o isolamento não se comprova e nada é sinalizado.
PSDIR="$T/psblind.$RANDOM"; mkdir -p "$PSDIR"
printf '#!/bin/sh\nexit 127\n' > "$PSDIR/ps"; chmod +x "$PSDIR/ps"
L="$(newlab)"; commitn "$L/wt" 1
git -C "$L/wt" remote set-url origin "https://192.0.2.1/x.git"
mkdir -p "$L/wt/.forge"; printf 'push_ahead:\n  enabled: true\n  timeout_s: 2\n' > "$L/wt/.forge/forge.yaml"
t14="$(date +%s)"
out14="$(run_chk "$L/wt" origin "$(refline "$L/wt" develop develop)" PATH="$PSDIR:$PATH")"
el14=$(( $(date +%s) - t14 ))
grep -qi 'não medido\|nao medido' <<<"$out14" \
  || { echo "FAIL [14]: com ps cego o check não degradou para 'não medido': $out14"; exit 1; }
[ "$el14" -le 25 ] \
  || { echo "FAIL [14]: com ps cego o check levou ${el14}s — degradar não pode virar espera indefinida"; exit 1; }
# CONTRAPOSITIVA: com `ps` funcionando, o filho de rede TEM de morrer no teto. Sem esta metade, um
# CHILD_PGID que leia o nosso pgid passaria — a guarda faria o certo ao não sinalizar, mas o teto
# deixaria órfão em TODA execução e nada acusaria.
L14b="$(newlab)"; commitn "$L14b/wt" 1
# URL ÚNICA por execução. Um padrão que casa `192.0.2.1` genérico conta processos de OUTRAS
# execuções — medido: duas rodadas anteriores deixaram resíduo e o cenário acusou "2 órfãos" antes
# de este teste rodar qualquer coisa. É a mesma cicatriz do `pgrep` casando o próprio shell, e ela
# transforma um gate honesto em vermelho por motivo alheio, que é o defeito que esta suíte inteira
# existe para eliminar.
U14="w152-$$-${RANDOM}"
git -C "$L14b/wt" remote set-url origin "https://192.0.2.1/$U14.git"
mkdir -p "$L14b/wt/.forge"; printf 'push_ahead:\n  enabled: true\n  timeout_s: 2\n' > "$L14b/wt/.forge/forge.yaml"
# O contador precisa de CONTROLE POSITIVO, no molde do [17]: um padrão que nunca casa nada mede
# zero órfão tanto no código certo quanto no que deixa órfão sempre. O padrão anterior
# (`ls-remote.*<url>`) não casava NENHUM dos dois processos reais — o `ls-remote` roda com remoto
# NOMEADO, sem a URL no cmdline, e o neto `git-remote-https` tem a URL mas não a palavra
# `ls-remote`. O único casamento possível era um processo alheio, que é a cicatriz de `pgrep -f`
# casando o próprio shell já registrada neste repositório.
conta14() { pgrep -f "remote-https.*$U14" 2>/dev/null | wc -l | tr -d ' '; }
run_chk "$L14b/wt" origin "$(refline "$L14b/wt" develop develop)" >/dev/null 2>&1 &
RC14=$!
dur=0; viu=0
while [ "$dur" -lt 20 ]; do
  [ "$(conta14)" -gt 0 ] && { viu=1; break; }
  sleep 0.2; dur=$((dur + 1))
done
wait "$RC14" 2>/dev/null
[ "$viu" -eq 1 ] \
  || { echo "FAIL [14]: o contador não enxergou o processo de rede NEM DURANTE a leitura — o instrumento está cego, e 'zero órfãos' depois seria zero sobre nada"; exit 1; }
sleep 2
orf="$(conta14)"
[ "${orf:-0}" -eq 0 ] \
  || { echo "FAIL [14]: $orf processo(s) de rede sobreviveram ao teto — o sinal não alcançou o filho, e cada push deixaria um órfão segurando conexão"; exit 1; }
echo "OK [14] (ps cego: não sinaliza, ${el14}s; ps normal: sem órfão)"

scenario "[15] timeout_s inválido não desliga o teto em silêncio"
# Três escapes medidos em revisão: `08`/`09` matam o script em aritmética (bash lê zero à esquerda
# como octal), `00` vale zero e reduz o teto pela metade, e vinte dígitos estouram o inteiro do
# shell fazendo o cap de 60 NÃO ser aplicado — teto desligado.
L="$(newlab)"; commitn "$L/wt" 1
mkdir -p "$L/wt/.forge"
for bad in 08 09 00 0 abc 99999999999999999999 18446744073709551646 90; do
  printf 'push_ahead:\n  enabled: true\n  timeout_s: %s\n' "$bad" > "$L/wt/.forge/forge.yaml"
  o="$(run_chk "$L/wt" origin "$(refline "$L/wt" develop develop)")"
  grep -qiE 'value too great|unbound variable|integer expression' <<<"$o" \
    && { echo "FAIL [15]: timeout_s=$bad produziu erro CRU de bash na saída de um push: $o"; exit 1; }
  grep -q "$PREFIX" <<<"$o" \
    || { echo "FAIL [15]: timeout_s=$bad fez o check perder as três classes de saída — o valor inválido desligou o check inteiro: '$o'"; exit 1; }
done
# O wrap tem de ser DENUNCIADO, nao apenas absorvido: 2^64+30 = 18446744073709551646 vira
# exatamente 30 na aritmetica de 64 bits do bash, cai DENTRO da faixa 1..60 e passa por qualquer
# validacao de VALOR sem um aviso — o operador recebe um teto de 30s achando que pediu outra
# coisa. E o unico caso que so o cap de COMPRIMENTO pega: medido, a mutacao que remove o cap
# sobrevivia a todo o resto do cenario.
printf 'push_ahead:\n  enabled: true\n  timeout_s: 18446744073709551646\n' > "$L/wt/.forge/forge.yaml"
ow="$(run_chk "$L/wt" origin "$(refline "$L/wt" develop develop)")"
grep -qi 'aviso' <<<"$ow" \
  || { echo "FAIL [15]: timeout_s=2^64+30 NAO produziu aviso — o wrap de 64 bits o transformou em 30 silenciosamente, e o teto virou um numero que ninguem pediu: $ow"; exit 1; }
# Zero com padding é ZERO, não um número grande: `0000` clampado para 60 daria ao operador o
# diagnóstico oposto ao fato, dizendo "acima do máximo" sobre um valor nulo.
for z in 0000 00000 0060; do
  printf 'push_ahead:\n  enabled: true\n  timeout_s: %s\n' "$z" > "$L/wt/.forge/forge.yaml"
  oz="$(run_chk "$L/wt" origin "$(refline "$L/wt" develop develop)")"
  grep -qi 'acima do máximo\|acima do maximo' <<<"$oz" \
    && { echo "FAIL [15]: timeout_s=$z foi diagnosticado como 'acima do máximo' — o valor é $(( 10#$z )), e o operador recebe o oposto do fato: $oz"; exit 1; }
done
# CONTROLE: valor válido não produz aviso, senão o cenário passaria com um script que avisa sempre.
printf 'push_ahead:\n  enabled: true\n  timeout_s: 5\n' > "$L/wt/.forge/forge.yaml"
o15="$(run_chk "$L/wt" origin "$(refline "$L/wt" develop develop)")"
grep -qi 'aviso' <<<"$o15" \
  && { echo "FAIL [15]: timeout_s VÁLIDO produziu aviso — um script que avisa sempre passaria em todas as asserções acima sem validar nada: $o15"; exit 1; }
echo "OK [15]"

scenario "[16] o laço de espera tem cap de iterações além do relógio"
# Se a espera fosse derivada só de `date`, um relógio andando para trás (NTP, laptop suspenso)
# deixaria a diferença negativa e o laço NUNCA terminaria — um `git push` que não termina.
grep -qE 'MAXI=' "$CHK" \
  || { echo "FAIL [16]: não há cap de iterações no laço de espera"; exit 1; }
grep -qE 'while \[ "\$i" -lt "\$MAXI" \]' "$CHK" \
  || { echo "FAIL [16]: o laço não é limitado pelo cap de iterações"; exit 1; }
grep -qE '\$\(\( *\$\(date' "$CHK" \
  && { echo "FAIL [16]: o laço deriva a espera de aritmética sobre date — relógio para trás pendura o push"; exit 1; }
echo "OK [16]"

scenario "[21] não interatividade: o ambiente é imposto e o comando ssh é DERIVADO, não sobrescrito"
for v in GIT_TERMINAL_PROMPT GIT_ASKPASS SSH_ASKPASS_REQUIRE; do
  grep -q "$v" "$CHK" \
    || { echo "FAIL [21]: $v não é imposto — o check pode abrir prompt e pendurar o push"; exit 1; }
done
grep -q 'BatchMode=yes' "$CHK" \
  || { echo "FAIL [21]: sem BatchMode=yes o ssh ainda pergunta senha e confirmação de host key"; exit 1; }
grep -qE 'GIT_SSH_COMMAND:-\$\(git .*core\.sshCommand' "$CHK" \
  || { echo "FAIL [21]: o comando ssh não é DERIVADO do existente — sobrescrever quebra identidade dedicada e ProxyCommand corporativo"; exit 1; }
grep -q '</dev/null' "$CHK" \
  || { echo "FAIL [21]: a leitura de rede não fecha o stdin"; exit 1; }
echo "OK [21]"

scenario "[22] remoto medido é o do PUSH, não 'origin' fixo"
# O hook recebe nome e URL do remoto em $1/$2. Fixar `origin` erraria em `git push outro-remote` e,
# pior, em fluxo de fork — onde origin é o fork e o tronco de verdade mora no upstream. O cenário
# monta um remoto com OUTRO nome e um `origin` que aponta para um bare DIFERENTE e em dia, para que
# medir o remoto errado produza a classe errada.
L="$(newlab)"; commitn "$L/wt" 4
git -C "$L/wt" remote rename origin upstream
git init -q --bare "$L/decoy.git"
git -C "$L/wt" remote add origin "$L/decoy.git"
git -C "$L/wt" push -q origin develop   # o decoy fica EM DIA de propósito
out22="$(run_chk "$L/wt" upstream "refs/heads/develop $(git -C "$L/wt" rev-parse develop) refs/heads/develop $(git -C "$L/wt" rev-parse upstream/develop)")"
grep -q 'upstream' <<<"$out22" \
  || { echo "FAIL [22]: a linha não nomeia o remoto 'upstream' que estava sendo empurrado: $out22"; exit 1; }
grep -qE '4 commit' <<<"$out22" \
  || { echo "FAIL [22]: o check mediu o remoto errado — 'origin' aqui é um decoy EM DIA, e medir por ele esconde os 4 commits de passivo no remoto que realmente está sendo empurrado: $out22"; exit 1; }
echo "OK [22]"

scenario "[23] destino da ref: sha IGUAL ao tip do tronco, publicado para OUTRO destino, NÃO é 'resolvido'"
# Vermelho que faltava para a correção do pior bloqueante da revisão anterior. Casar apenas o SHA
# entre as refs empurradas dizia "passivo sendo resolvido" para `git push origin feat-nova` quando
# a branch nova apontava para o tip do tronco — e `refs/heads/<tronco>` no servidor NÃO avançava.
# É a única das três classes que afirma "não há nada a fazer", dita sobre o estado exato que este
# check existe para denunciar: pior que silêncio.
#
# Nenhum dos outros cenários alcança isso: o [12] usa branches com commit PRÓPRIO, então o sha
# nunca coincide com o tip do tronco, e a correção passava sem vermelho — que é justamente o que a
# regra red-first deste repositório existe para impedir.
L="$(newlab)"; commitn "$L/wt" 3
TIP23="$(git -C "$L/wt" rev-parse develop)"
git -C "$L/wt" branch feat-nova develop     # mesma ponta, SEM commit próprio
out23="$(run_chk "$L/wt" origin "refs/heads/feat-nova $TIP23 refs/heads/feat-nova 0000000000000000000000000000000000000000")"
grep -qi 'resolvid' <<<"$out23" \
  && { echo "FAIL [23]: publicar uma ref com o sha do tronco para um destino que NÃO é o tronco foi lido como 'passivo sendo resolvido' — refs/heads/develop no servidor continua atrás, e esta é a única classe que diz ao operador que não há nada a fazer: $out23"; exit 1; }
grep -qE '3 commit' <<<"$out23" \
  || { echo "FAIL [23]: o passivo de 3 commits não foi acusado: $out23"; exit 1; }
# CONTRAPOSITIVA no mesmo fôlego: o MESMO sha, agora publicado PARA o tronco, TEM de dizer resolvido
# — senão o cenário passaria com um script que nunca reconhece resolução alguma.
out23b="$(run_chk "$L/wt" origin "refs/heads/develop $TIP23 refs/heads/develop $(git -C "$L/wt" rev-parse origin/develop)")"
grep -qi 'resolvid' <<<"$out23b" \
  || { echo "FAIL [23]: o mesmo sha publicado PARA o tronco deixou de ser reconhecido como resolução — a checagem de destino virou recusa indiscriminada: $out23b"; exit 1; }
echo "OK [23]"

scenario "[24] LDG-0057 (disjuntas): a interseção é a UNIÃO das refs publicadas, não o MÁXIMO — caso da issue"
# A issue, em números: se a ref A carrega os commits 1-2 e a ref B carrega o commit 3, a resposta
# certa é 3 (a UNIÃO), e o laço antigo guardava só o maior valor visto (2). É conservação: o todo
# não pode ser menor que qualquer parte.
L="$(newlab)"
R="$(git -C "$L/wt" rev-parse develop)"
P_TIP="$(mkline_from "$L/wt" feat-p24 develop 2)"; merge_into_develop "$L/wt" feat-p24
Q_TIP="$(mkline_from "$L/wt" feat-q24 "$R" 1)"; merge_into_develop "$L/wt" feat-q24
stdin24="$(multiref_stdin "$L/wt" feat-p24 feat-q24)"
out24="$(run_chk "$L/wt" origin "$stdin24")"
expected24="$(git -C "$L/wt" rev-list --count "$P_TIP" "$Q_TIP" --not "$R")"
[ "$expected24" = "3" ] \
  || { echo "FAIL [24]: o laboratório não produziu o oráculo esperado (3): expected24=$expected24 — o desenho do cenário está errado, não o alvo"; exit 1; }
got24="$(extract_inter "$out24")"
[ -n "$got24" ] \
  || { echo "FAIL [24]: a saída não trouxe nenhum número de interseção: $out24"; exit 1; }
[ "$got24" -eq "$expected24" ] \
  || { echo "FAIL [24]: interseção relatada foi $got24, a união real (oráculo independente via rev-list) é $expected24 — feat-p24 carrega 2 commits, feat-q24 carrega 1, disjuntos entre si, e o total tem de ser a UNIÃO (3), não o MÁXIMO entre as duas (2): $out24"; exit 1; }
echo "OK [24] (relatado=$got24, união=$expected24)"

scenario "[25] LDG-0057 (sobrepostas): prefixo comum não é contado em dobro nem por MÁXIMO"
# feat-x25 e feat-y25 divergem do MESMO commit feat-m25 (não de develop diretamente): cada uma
# sozinha soma 2, a SOMA das duas seria 4, o MÁXIMO seria 2 — só a união deduplicada dá 3.
L="$(newlab)"
R="$(git -C "$L/wt" rev-parse develop)"
M_TIP="$(mkline_from "$L/wt" feat-m25 develop 1)"; merge_into_develop "$L/wt" feat-m25
X_TIP="$(mkline_from "$L/wt" feat-x25 feat-m25 1)"; merge_into_develop "$L/wt" feat-x25
Y_TIP="$(mkline_from "$L/wt" feat-y25 feat-m25 1)"; merge_into_develop "$L/wt" feat-y25
stdin25="$(multiref_stdin "$L/wt" feat-x25 feat-y25)"
out25="$(run_chk "$L/wt" origin "$stdin25")"
expected25="$(git -C "$L/wt" rev-list --count "$X_TIP" "$Y_TIP" --not "$R")"
[ "$expected25" = "3" ] \
  || { echo "FAIL [25]: oráculo não bateu com o desenho esperado (3): expected25=$expected25"; exit 1; }
got25="$(extract_inter "$out25")"
[ -n "$got25" ] \
  || { echo "FAIL [25]: sem número de interseção na saída: $out25"; exit 1; }
[ "$got25" -eq "$expected25" ] \
  || { echo "FAIL [25]: interseção relatada foi $got25, a união real (deduplicada) é $expected25 — feat-x25 e feat-y25 compartilham o commit de feat-m25 e cada uma soma 2 sozinha; nem SOMA (4) nem MÁXIMO (2) está certo, só a UNIÃO: $out25"; exit 1; }
echo "OK [25] (relatado=$got25, união=$expected25)"

scenario "[26] LDG-0057 (contida): ref aninhada em outra não faz a união regredir"
L="$(newlab)"
R="$(git -C "$L/wt" rev-parse develop)"
git -C "$L/wt" checkout -q -b feat-a26 develop
echo "1-$RANDOM" >> "$L/wt/feat-a26.txt"; git -C "$L/wt" add -A; git -C "$L/wt" commit -q -m feat-a26-1
echo "2-$RANDOM" >> "$L/wt/feat-a26.txt"; git -C "$L/wt" add -A; git -C "$L/wt" commit -q -m feat-a26-2
A2="$(git -C "$L/wt" rev-parse feat-a26)"
echo "3-$RANDOM" >> "$L/wt/feat-a26.txt"; git -C "$L/wt" add -A; git -C "$L/wt" commit -q -m feat-a26-3
A3_TIP="$(git -C "$L/wt" rev-parse feat-a26)"
merge_into_develop "$L/wt" feat-a26
git -C "$L/wt" branch feat-a2-26 "$A2"
stdin26="$(multiref_stdin "$L/wt" feat-a2-26 feat-a26)"
out26="$(run_chk "$L/wt" origin "$stdin26")"
expected26="$(git -C "$L/wt" rev-list --count "$A2" "$A3_TIP" --not "$R")"
[ "$expected26" = "3" ] \
  || { echo "FAIL [26]: oráculo não bateu (esperava 3): expected26=$expected26"; exit 1; }
got26="$(extract_inter "$out26")"
[ -n "$got26" ] \
  || { echo "FAIL [26]: sem número de interseção: $out26"; exit 1; }
[ "$got26" -eq "$expected26" ] \
  || { echo "FAIL [26]: interseção relatada $got26, união real $expected26 — feat-a2-26 está CONTIDA em feat-a26, e publicar as duas juntas não pode fazer a união regredir: $out26"; exit 1; }
echo "OK [26] (relatado=$got26, união=$expected26)"

scenario "[27] LDG-0057 (vazia): ref sem contribuição não quebra nem reduz a união"
L="$(newlab)"
R="$(git -C "$L/wt" rev-parse develop)"
P_TIP="$(mkline_from "$L/wt" feat-p27 develop 2)"; merge_into_develop "$L/wt" feat-p27
git -C "$L/wt" branch feat-empty27 "$R"
stdin27="$(multiref_stdin "$L/wt" feat-p27 feat-empty27)"
out27="$(run_chk "$L/wt" origin "$stdin27")"
expected27="$(git -C "$L/wt" rev-list --count "$P_TIP" "$R" --not "$R")"
[ "$expected27" = "2" ] \
  || { echo "FAIL [27]: oráculo não bateu (esperava 2): expected27=$expected27"; exit 1; }
got27="$(extract_inter "$out27")"
[ -n "$got27" ] \
  || { echo "FAIL [27]: sem número de interseção: $out27"; exit 1; }
[ "$got27" -eq "$expected27" ] \
  || { echo "FAIL [27]: interseção relatada $got27, esperado $expected27 — feat-empty27 (na ponta do próprio remoto, zero contribuição) não pode reduzir nem quebrar o cálculo: $out27"; exit 1; }
echo "OK [27] (relatado=$got27, união=$expected27)"

scenario "[28] LDG-0057 canal real: git push de verdade, hook real, união correta pelo stdin do git"
# testing/gate-delivery-channel.md: a prova exercita o CANAL de entrega, não só o alvo isolado. O
# check-push-ahead é invocado pelo pre-push, que recebe refs no STDIN do próprio git — este cenário
# dirige um `git push` de verdade contra um bare local, com o hook real instalado, e lê o número
# direto da saída do push, não de uma chamada isolada ao script.
L="$(newlab)"
R="$(git -C "$L/wt" rev-parse develop)"
P_TIP="$(mkline_from "$L/wt" feat-p28 develop 2)"; merge_into_develop "$L/wt" feat-p28
Q_TIP="$(mkline_from "$L/wt" feat-q28 "$R" 1)"; merge_into_develop "$L/wt" feat-q28
expected28="$(git -C "$L/wt" rev-list --count "$P_TIP" "$Q_TIP" --not "$R")"
[ "$expected28" = "3" ] \
  || { echo "FAIL [28]: oráculo do laboratório não bateu (esperava 3): expected28=$expected28"; exit 1; }
mkdir -p "$L/wt/.forge/scripts"
printf '# FORGE.md (fixture minimal para canal real do w152)\n' > "$L/wt/.forge/FORGE.md"
cp "$CHK" "$L/wt/.forge/scripts/check-push-ahead.sh"
# ai-attribution e liaison-acks são gates ORTOGONAIS a este cenário — stubados como no-op, no mesmo
# espírito do shim de git do [17]: isolar o canal que está sob teste, não simular o harness inteiro.
printf '#!/bin/sh\nexit 0\n' > "$L/wt/.forge/scripts/check-ai-attribution.sh"
printf '#!/bin/sh\nexit 0\n' > "$L/wt/.forge/scripts/check-liaison-acks.sh"
chmod +x "$L/wt/.forge/scripts/"*.sh
mkdir -p "$L/wt/.git/hooks"
cp "$HOOK" "$L/wt/.git/hooks/pre-push"
chmod +x "$L/wt/.git/hooks/pre-push"
out28="$(git -C "$L/wt" push origin feat-p28 feat-q28 2>&1)"
grep -q "$PREFIX" <<<"$out28" \
  || { echo "FAIL [28]: o push real não produziu NENHUMA linha do check-push-ahead — o canal (hook -> script) não está de pé: $out28"; exit 1; }
got28="$(extract_inter "$out28")"
[ -n "$got28" ] \
  || { echo "FAIL [28]: o push real não trouxe número de interseção: $out28"; exit 1; }
[ "$got28" -eq "$expected28" ] \
  || { echo "FAIL [28]: pelo CANAL REAL (git push -> pre-push -> check-push-ahead, refs no stdin do git) a interseção relatada foi $got28, a união real é $expected28 — o mesmo defeito de [24], agora observado pelo caminho de entrega de produção, não pela função isolada: $out28"; exit 1; }
echo "OK [28] (canal real: relatado=$got28, união=$expected28)"

scenario "[29] LDG-0058: o temporário não vaza quando o script morre por sinal"
# Ambiente medido: SIGTERM e SIGHUP chegam normalmente a um processo em segundo plano NESTE
# sandbox, mas SIGINT NÃO — verificado de forma isolada (até um `( sleep N ) &` puro, sem bash
# script nenhum no meio, fica vivo após `kill -INT`, enquanto TERM e HUP o derrubam sem exceção).
# Não é peculiaridade do alvo: é o ambiente de execução deste agente. A cobertura COMPORTAMENTAL
# deste cenário fica em TERM/HUP; INT (o sinal do Ctrl-C real) é verificado por FORMA (grep).
#
# Achado da investigação, registrado para quem reabrir isto: `trap 'CMD' EXIT` sozinho (o código
# ANTES da correção) já sobrevive a TERM/HUP sem vazar NESTE bash — a shell roda o trap de EXIT
# antes de morrer por um sinal não tratado explicitamente. O que NÃO funciona é registrar
# `trap 'rm -f "$OUT"' TERM` sem `exit` explícito: medido, o processo executa o rm e CONTINUA
# vivo (a shell não sai sozinha de um trap de sinal sem `exit` embutido). Por isso a correção usa
# um `exit` por sinal (128+n), e por isso o [29] também prova PRONTIDÃO (morre em <2s), não só
# ausência de arquivo — sem essa prova um "fix" que só acrescenta os nomes ao trap (a forma
# literal sugerida no ledger) passaria aqui sem realmente terminar o processo a tempo.
run_signal_leak_case() {  # run_signal_leak_case <rótulo> <SINAL> -> "OK" | "LEAK:n" | "ALIVE" | "BLIND"
  local label="$1" sig="$2" tmpd wt reflinef pid i n
  tmpd="$(mktemp -d "$T/tmpd29-$label.XXXXXX")"
  wt="$T/lab29-$label"
  git init -q --bare "$T/bare29-$label.git"
  git init -q "$wt"
  git -C "$wt" config user.email t@t; git -C "$wt" config user.name t; git -C "$wt" config commit.gpgsign false
  git -C "$wt" checkout -q -b develop
  echo base > "$wt/base.txt"; git -C "$wt" add -A; git -C "$wt" commit -q -m base
  git -C "$wt" remote add origin "$T/bare29-$label.git"
  git -C "$wt" push -q origin develop
  echo x >> "$wt/base.txt"; git -C "$wt" add -A; git -C "$wt" commit -q -m c1
  git -C "$wt" remote set-url origin "https://192.0.2.1/x.git"
  mkdir -p "$wt/.forge"; printf 'push_ahead:\n  enabled: true\n  timeout_s: 20\n' > "$wt/.forge/forge.yaml"
  reflinef="$T/refline29-$label"; refline "$wt" develop develop > "$reflinef"
  # SEM subshell/pipe: `$!` precisa ser o PID exato do check-push-ahead.sh, não de um wrapper.
  TMPDIR="$tmpd" FORGE_ROOT="$wt" bash "$CHK" origin "https://192.0.2.1/x.git" < "$reflinef" >/dev/null 2>&1 &
  pid=$!
  i=0
  while [ "$i" -lt 50 ]; do
    ls "$tmpd"/forge-pushahead-* >/dev/null 2>&1 && break
    sleep 0.1; i=$((i + 1))
  done
  if ! ls "$tmpd"/forge-pushahead-* >/dev/null 2>&1; then
    kill -9 "$pid" 2>/dev/null
    echo "BLIND"; return
  fi
  kill "-$sig" "$pid" 2>/dev/null
  sleep 1.8
  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" 2>/dev/null
    echo "ALIVE"; return
  fi
  n="$(ls "$tmpd"/forge-pushahead-* 2>/dev/null | wc -l | tr -d ' ')"
  [ "${n:-0}" -gt 0 ] && echo "LEAK:$n" || echo "OK"
}
r_term="$(run_signal_leak_case term TERM)"
[ "$r_term" != "BLIND" ] \
  || { echo "FAIL [29]: o instrumento não viu o temporário aparecer (TERM) — sem isso 'não vaza' seria decorativo"; exit 1; }
[ "$r_term" != "ALIVE" ] \
  || { echo "FAIL [29]: o script continuou vivo 1,8s depois do SIGTERM — o trap não terminou o processo a tempo"; exit 1; }
[ "$r_term" = "OK" ] \
  || { echo "FAIL [29]: SIGTERM vazou o temporário ($r_term) — o trap não cobre morte por este sinal"; exit 1; }
r_hup="$(run_signal_leak_case hup HUP)"
[ "$r_hup" != "BLIND" ] \
  || { echo "FAIL [29]: o instrumento não viu o temporário aparecer (HUP)"; exit 1; }
[ "$r_hup" != "ALIVE" ] \
  || { echo "FAIL [29]: o script continuou vivo 1,8s depois do SIGHUP"; exit 1; }
[ "$r_hup" = "OK" ] \
  || { echo "FAIL [29]: SIGHUP vazou o temporário ($r_hup) — o trap não cobre morte por este sinal"; exit 1; }
grep -qE 'trap .rm -f "\$OUT".*EXIT' "$CHK" \
  || { echo "FAIL [29]: não há trap de limpeza no EXIT"; exit 1; }
grep -qE "trap '[^']*rm -f \"\\\$OUT\"[^']*exit 130'[[:space:]]+INT" "$CHK" \
  || { echo "FAIL [29]: não há trap para INT que limpe \$OUT E saia explicitamente — SIGINT é o sinal do Ctrl-C real, e este sandbox não permite comprová-lo em execução (verificado: nem um 'sleep &' puro morre de kill -INT aqui), então esta é a única prova possível de que a cobertura existe"; exit 1; }
grep -qE "trap '[^']*rm -f \"\\\$OUT\"[^']*exit 143'[[:space:]]+TERM" "$CHK" \
  || { echo "FAIL [29]: o trap de TERM não chama exit explícito — sem ele um sinal tratado sem sair deixa o processo vivo (medido nesta investigação)"; exit 1; }
grep -qE "trap '[^']*rm -f \"\\\$OUT\"[^']*exit 129'[[:space:]]+HUP" "$CHK" \
  || { echo "FAIL [29]: o trap de HUP não chama exit explícito"; exit 1; }
echo "OK [29] (TERM: $r_term em <1,8s; HUP: $r_hup em <1,8s; INT verificado por forma — sandbox não entrega o sinal)"

scenario "[30] LDG-0060: falha do rev-list na publicação do próprio tronco cai na classe honesta"
# git NUNCA envia um sha que não possui — este caminho só é alcançável por INJEÇÃO DIRETA de
# stdin (o próprio ledger documenta isso como a forma honesta de exercitá-lo). O sha é válido em
# FORMA (hex) e o objeto não existe: `git rev-list --count $TO_TRUNK..$TRUNK_LOCAL` falha, e a
# troca de rest=0 por rest=1 tem de rotear para a mensagem de publicação PARCIAL, não para
# "passivo sendo resolvido" (a classe tranquilizadora, errada aqui).
L="$(newlab)"; commitn "$L/wt" 2
OLDR="$(git -C "$L/wt" rev-parse origin/develop)"
FAKE="deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
git -C "$L/wt" cat-file -e "${FAKE}^{commit}" 2>/dev/null \
  && { echo "FAIL [30]: o sha forjado existe como objeto real no laboratório — o cenário não isola o caminho de falha"; exit 1; }
stdin30="$(printf 'refs/heads/develop %s refs/heads/develop %s\n' "$FAKE" "$OLDR")"
out30="$(run_chk "$L/wt" origin "$stdin30")"
grep -qE 'publica parte' <<<"$out30" \
  || { echo "FAIL [30]: sha forjado (válido em forma, objeto inexistente) publicado PARA refs/heads/develop não caiu na classe honesta de publicação parcial: $out30"; exit 1; }
grep -qi 'sendo resolvid' <<<"$out30" \
  && { echo "FAIL [30]: o rev-list falhou e o check disse 'passivo sendo resolvido' mesmo assim — rest caiu como 0 (a classe tranquilizadora) em vez de 1 (a honesta): $out30"; exit 1; }
echo "OK [30]: $out30"

scenario "[31] LDG-0059: guarda de regressão — custo de push multi-ref não volta a duas chamadas de git por ref"
# Medido nesta investigação (mesma máquina, mesma hora, A/B direto): o fix do LDG-0057 reduziu o
# laço de interseção de DUAS invocações de git por ref (merge-base + rev-list) para UMA por ref
# (só merge-base) mais uma única rev-list no final — 800 refs caiu de 60,98s para 26,33s (~2,3x).
# Não é a otimização completa que o item original cogitava (teto de refs com truncagem DECLARADA
# — adiada de propósito por risco de desenho, não improvisada aqui); é a guarda para que ninguém
# reintroduza as duas chamadas por ref sem perceber. 150 refs: ~5,2s esperado depois do fix,
# ~11,9s se a regressão voltar — 8s separa os dois com folga para variação de máquina.
L="$(newlab)"; commitn "$L/wt" 2
SAMESHA="$(git -C "$L/wt" rev-parse develop)"
N31=150
stdin31="$(i=1; while [ "$i" -le "$N31" ]; do
  printf 'refs/heads/branch%d %s refs/heads/branch%d 0000000000000000000000000000000000000000\n' "$i" "$SAMESHA" "$i"
  i=$((i + 1))
done)"
t0_31="$(date +%s)"
out31="$(run_chk "$L/wt" origin "$stdin31")"
el31=$(( $(date +%s) - t0_31 ))
grep -qE 'entra' <<<"$out31" \
  || { echo "FAIL [31]: push de $N31 refs não produziu a linha de interseção: $out31"; exit 1; }
[ "$el31" -le 8 ] \
  || { echo "FAIL [31]: push de $N31 refs levou ${el31}s (teto 8s) — o custo linear voltou a subir, possivelmente por uma regressão a duas chamadas de git por ref (LDG-0059): $out31"; exit 1; }
echo "OK [31] ($N31 refs em ${el31}s, teto 8s)"

GATE_ELAPSED=$(( $(date +%s) - GATE_START ))
[ "$GATE_ELAPSED" -le "$GATE_BUDGET_S" ] \
  || { echo "FAIL [orçamento]: a suíte levou ${GATE_ELAPSED}s, acima do teto declarado de ${GATE_BUDGET_S}s"; exit 1; }
echo "PASS w152-push-ahead ($SCENARIOS_RUN cenário(s), ${GATE_ELAPSED}s de ${GATE_BUDGET_S}s)"
