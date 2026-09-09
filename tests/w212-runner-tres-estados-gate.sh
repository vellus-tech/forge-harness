#!/usr/bin/env bash
# Gate W212 — três estados no runner da suíte (LDG-0180).
#
# O DEFEITO. `run_one` do runner interno tinha dois desfechos: `if cmd; then pass; else fail; fi`.
# Um gate reprovado por asserção, um gate morto por SIGKILL sob pressão de memória, um gate que
# estourou o teto de tempo e um gate sem dependência terminavam com o mesmo marcador, a mesma
# parcela e o mesmo código de saída. Falso-VERMELHO: manda procurar defeito onde não há.
#
# O QUE ESTE GATE PROVA. Integração de ponta a ponta com o runner real, não asserção sobre o texto
# do fonte: o gate copia o runner para uma bancada em $TMPDIR, confere por `shasum -a 256` que a
# cópia é idêntica ao original — controle contra testar cópia velha —, planta fixtures de cada
# classe de desfecho e executa a cópia. O runner resolve seu WS por BASH_SOURCE e faz cd, então o
# universo executado é o das fixtures. Sem recursão sobre a suíte real.
#
# A SENTINELA DE ÁRVORE RASTREADA (LDG-0179) ENTRA NA BANCADA COMO DUBLÊ NEUTRO, pelo mesmo motivo:
# ela é um colaborador com gate próprio (w213), e o que se mede aqui é a classificação de desfecho.
#
# AS FIXTURES bats SÃO SHIM, E ISSO É DELIBERADO. O alvo sob teste é a CLASSIFICAÇÃO que o runner
# faz dos observáveis do bats (rc, plano TAP, linhas `^not ok`), não o bats. Um shim em PATH
# reproduz exatamente os observáveis medidos na especificação (§3.3) de forma determinista, sem
# depender da versão instalada nem tornar o gate vermelho numa máquina sem bats.
#
# CENÁRIOS (denominador fixo 27 — exceção legítima da invariante 14, e a divergência é o achado):
#   [1] existe um terceiro desfecho alcançável — o runner classifica por algo além de zero/não-zero
#   [2] gate que passa é contado em PASS e marcado com o marcador de passagem
#   [3] gate que reprova imprimindo FAIL é contado em FAIL
#   [4] gate que reprova SEM imprimir FAIL continua contado em FAIL — anti-regressão de D1
#   [5] gate morto por SIGKILL não é contado em FAIL nem marcado como reprovação
#   [6] gate morto por SIGTERM cai na mesma classe
#   [7] gate morto pelo teto de tempo (SIGALRM, rc 142) cai na mesma classe
#   [8] gate com dependência ausente (rc 127) cai na mesma classe
#   [9] gate morto por sinal DEPOIS de imprimir FAIL é contado em FAIL — a direção que agrava
#  [10] rc 128 é contado em FAIL, não no terceiro estado — D2
#  [11] suíte bats com `^not ok` é contada em FAIL
#  [12] suíte bats com rc não-zero e zero `^not ok` cai no terceiro estado — D3
#  [13] suíte bats com plano `1..0` cai no terceiro estado e nunca em PASS — D4
#  [14] desfecho cujo arquivo de log não pôde ser criado cai no terceiro estado — D5
#  [15] varredura exaustiva de rc 0..255: toda entrada recebe exatamente uma classe
#  [16] a partição bate com a fronteira declarada: 1 passagem, 66 no terceiro estado, 189 reprovações
#  [17] o marcador do terceiro estado é distinto dos de passagem, reprovação e SKIP — e o de skip é
#       colhido do runner REAL, numa bancada sem bats no PATH, não de um literal deste gate
#  [18] o resumo publica as quatro parcelas e a soma delas é o número de alvos executados — P7
#  [19] execução sem reprovação e sem não verificado sai 0
#  [20] execução com ao menos uma reprovação sai 1, com e sem não verificados — P6
#  [21] execução com não verificados e zero reprovações sai 3 — P5
#  [22] a lista nominal do terceiro estado é separada de FALHARAM: e traz o motivo de cada desfecho
#  [23] `bash -n` limpo no runner e nenhuma expansão de array desguardada sob `set -u` (bash 3.2),
#       medida em bancadas que de fato ESVAZIAM os arrays — sem .bats, e sem gate algum
#  [24] nenhuma linha não-comentário do runner INVOCA o runner (anti-recursão), com CONTROLE
#       POSITIVO da varredura antes de concluir da ausência — asserção PRÓPRIA
#       deste gate, porque as asserções [4] e [5] do w80 são pipelines iniciados por `!` e portanto
#       isentas do `set -e`: elas não reprovam nunca (ver §11 da especificação)
#  [25] linha VERDE que apenas CITA o token FAIL não converte morte por sinal em reprovação — é o
#       falso-vermelho que esta onda existe para eliminar, e a fixture é a linha literal do w51
#  [26] linha de reprovação INDENTADA (saída de sub-alvo) ainda agrava a morte por sinal — a
#       contra-direção de [25], que impede a correção de virar falso-verde
#  [27] SENTINELA — o gate examinou exatamente 27 cenários
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$WS/tests/run-all.sh"
DECLARADO=27
EXAMINADOS=0
cen() { EXAMINADOS=$((EXAMINADOS + 1)); }

T="$(mktemp -d /tmp/forge-w212.XXXXXX)" || { echo "FAIL [0]: mktemp -d falhou"; exit 1; }
trap 'rm -rf "$T"' EXIT

[ -f "$SRC" ] || { echo "FAIL [0]: $SRC não existe"; exit 1; }

# ── bancada ──────────────────────────────────────────────────────────────────────────────────
sha_de() { shasum -a 256 "$1" | awk '{print $1}'; }

mkbench() { # mkbench <nome> -> ecoa o diretório da bancada
  local b="$T/$1"
  mkdir -p "$b/tests/snapshot" "$b/bin"
  cp "$SRC" "$b/tests/run-all.sh"
  chmod +x "$b/tests/run-all.sh"
  [ "$(sha_de "$SRC")" = "$(sha_de "$b/tests/run-all.sh")" ] \
    || { echo "FAIL [0]: a cópia da bancada '$1' não é idêntica ao original"; exit 1; }
  # shim do bats: reproduz os observáveis medidos na §3.3 da especificação
  cat > "$b/bin/bats" <<'SHIM'
#!/usr/bin/env bash
alvo="$(basename "${!#}")"
case "$alvo" in
  validators.bats)      modo="${W212_BATS_VALIDATORS:-ok}" ;;
  claude-contract.bats) modo="${W212_BATS_CONTRATO:-ok}" ;;
  *)                    modo=ok ;;
esac
case "$modo" in
  ok)     echo "1..1"; echo "ok 1 fixture"; exit 0 ;;
  notok)  echo "1..1"; echo "not ok 1 fixture"; echo "# (in test file $alvo)"; exit 1 ;;
  morto)  echo "1..1"; echo "ok 1 fixture"; echo "Killed: 9"; exit 1 ;;
  vazio)  echo "1..0"; exit 0 ;;
  sinal)  echo "1..1"; exit 137 ;;
esac
SHIM
  chmod +x "$b/bin/bats"
  # DUBLÊ NEUTRO DA SENTINELA DE ÁRVORE RASTREADA (LDG-0179).
  # O runner exige a biblioteca `arvore-rastreada.sh` sob o seu WS e sai 4 sem ela — ausência de
  # guardião é erro, não silêncio, e está certo. Mas quem esta bancada mede é a CLASSIFICAÇÃO de
  # desfecho, e a sentinela é um colaborador com dono próprio (w213). O dublê devolve 0 nas duas
  # funções, isolando a unidade sob teste: se ele sumir, o runner sai 4 e todos os cenários acusam.
  mkdir -p "$b/template/.forge/scripts/lib"
  printf '%s\n' '#!/usr/bin/env bash' 'arvore_snapshot() { echo dublê; return 0; }' \
    'arvore_confere() { return 0; }' > "$b/template/.forge/scripts/lib/arvore-rastreada.sh"
  : > "$b/tests/validators.bats"
  : > "$b/tests/snapshot/claude-contract.bats"
  echo "$b"
}

fixture() { # fixture <bancada> <nome-do-arquivo> <corpo>
  printf '#!/usr/bin/env bash\n%s\n' "$3" > "$1/tests/$2"
  chmod +x "$1/tests/$2"
}

roda() { # roda <bancada> -> preenche OUT (arquivo) e RC
  OUT="$1/saida.txt"
  ( cd "$1" && PATH="$1/bin:$PATH" bash "$1/tests/run-all.sh" ) > "$OUT" 2>&1
  RC=$?
}

sem_ansi() { sed 's/'$'\033''\[[0-9;]*m//g' "$1"; }

# O awk do macOS compara strings multibyte de forma inconsistente — coage o marcador a 0 e faz
# `$1 == m` casar com qualquer marcador. Toda comparação de marcador acontece no shell ou por grep;
# o awk só é usado para RECORTAR o campo, nunca para compará-lo.
LINHA_ALVO='^  [^ -][^ ]* '   # marcador (bytes sem espaço, e nunca o '-' das listas nominais)

marcador_de() { # marcador_de <saida> <nome-do-alvo>
  sem_ansi "$1" | grep -E "${LINHA_ALVO}$2\$" | head -1 | awk '{print $1}'
}

conta_alvos() { # conta_alvos <saida> <regex-do-nome> [marcador]
  local n
  if [ "$#" -ge 3 ]; then n="$(sem_ansi "$1" | grep -cE "^  $3 $2\$")"
  else                    n="$(sem_ansi "$1" | grep -cE "${LINHA_ALVO}$2\$")"; fi
  echo "${n:-0}"
}

parcela() { # parcela <saida> <rótulo>
  sem_ansi "$1" | awk -v r="$2" '
    /^PASS=/ { for (i = 1; i <= NF; i++) { split($i, kv, "="); if (kv[1] == r) { print kv[2]; exit } } }'
}

bloco() { # bloco <saida> <cabeçalho> — ecoa as linhas "  - x" logo após o cabeçalho
  sem_ansi "$1" | awk -v h="$2" '
    $0 == h { dentro = 1; next }
    dentro && /^  - / { print substr($0, 5); next }
    dentro { dentro = 0 }'
}

exige() { # exige <condição-já-avaliada:rc> <mensagem>
  [ "$1" -eq 0 ] || { echo "FAIL: $2"; exit 1; }
}

# ── RUN A — universo com um representante de cada classe ─────────────────────────────────────
A="$(mkbench runA)" || exit 1
fixture "$A" a01-pass-gate.sh    'echo "progresso"; exit 0'
fixture "$A" a02-assert-gate.sh  'echo "FAIL [2]: asserção violada"; exit 1'
fixture "$A" a03-silent-gate.sh  'set -e; echo "[1] progresso"; [ 1 -eq 2 ]'
fixture "$A" a04-kill-gate.sh    'echo "[1] progresso"; kill -KILL $$'
fixture "$A" a05-term-gate.sh    'echo "[1] progresso"; kill -TERM $$'
fixture "$A" a06-alarm-gate.sh   'echo "[1] progresso"; exec perl -e "alarm 1; exec @ARGV" /bin/sleep 5'
fixture "$A" a07-missing-gate.sh 'set -e; echo "[1] progresso"; __ldg0180_binario_ausente__'
fixture "$A" a08-agrava-gate.sh  'echo "FAIL [9]: violação observada"; kill -KILL $$'
fixture "$A" a09-rc128-gate.sh   'echo "[1] progresso"; exit 128'
# a10 e a11 sustentam os cenários [25] e [26], as duas direções do predicado de agravamento.
# a10 é a linha de progresso do caminho VERDE de tests/w51-waves-progress-gate.sh:90, copiada
# literalmente: um gate de produção que NARRA o token FAIL numa execução que passa. a11 é uma
# reprovação de verdade que chega ao log indentada, como chega a saída de sub-alvo dos quatro
# gates que a repassam com `sed 's/^/      /'`.
fixture "$A" a10-narra-gate.sh   'echo "[4] wave-ops close: OK fecha; FAIL recusa"; kill -KILL $$'
fixture "$A" a11-indent-gate.sh  'echo "      FAIL [3]: violação observada em sub-gate"; kill -KILL $$'
W212_BATS_VALIDATORS=notok W212_BATS_CONTRATO=morto roda "$A"
A_OUT="$OUT"; A_RC="$RC"

MARK_PASS="$(marcador_de "$A_OUT" a01-pass-gate.sh)"
MARK_FAIL="$(marcador_de "$A_OUT" a02-assert-gate.sh)"
MARK_UNV="$(marcador_de "$A_OUT" a04-kill-gate.sh)"

echo "[1] existe um terceiro desfecho alcançável"; cen
[ -n "$MARK_PASS" ] && [ -n "$MARK_FAIL" ] && [ -n "$MARK_UNV" ]
exige $? "o runner não marcou os três alvos de referência (pass='$MARK_PASS' fail='$MARK_FAIL' terceiro='$MARK_UNV')"
[ "$MARK_UNV" != "$MARK_PASS" ] && [ "$MARK_UNV" != "$MARK_FAIL" ]
exige $? "gate morto por sinal recebeu o mesmo marcador de passagem ou de reprovação ('$MARK_UNV')"
UNV_A="$(parcela "$A_OUT" UNVERIFIED)"
[ -n "$UNV_A" ]
exige $? "a linha de resumo não publica a parcela UNVERIFIED: $(sem_ansi "$A_OUT" | grep '^PASS=' || true)"
echo "OK [1]"

echo "[2] gate que passa é contado em PASS"; cen
[ "$(parcela "$A_OUT" PASS)" = "1" ]
exige $? "PASS=$(parcela "$A_OUT" PASS), esperado 1 (só a01-pass-gate.sh passa)"
echo "OK [2]"

echo "[3] gate que reprova imprimindo FAIL é contado em FAIL"; cen
[ "$(marcador_de "$A_OUT" a02-assert-gate.sh)" = "$MARK_FAIL" ]
exige $? "a02-assert-gate.sh não recebeu o marcador de reprovação"
bloco "$A_OUT" 'FALHARAM:' | grep -qx 'a02-assert-gate.sh'
exige $? "a02-assert-gate.sh ausente da lista FALHARAM:"
echo "OK [3]"

echo "[4] reprovação silenciosa continua reprovação"; cen
[ "$(marcador_de "$A_OUT" a03-silent-gate.sh)" = "$MARK_FAIL" ]
exige $? "a03-silent-gate.sh (rc 1, zero FAIL no log) não foi classificado como reprovação"
bloco "$A_OUT" 'FALHARAM:' | grep -qx 'a03-silent-gate.sh'
exige $? "a03-silent-gate.sh ausente da lista FALHARAM: — falso-verde no lugar do falso-vermelho"
echo "OK [4]"

for par in "5:a04-kill-gate.sh:SIGKILL" "6:a05-term-gate.sh:SIGTERM" \
           "7:a06-alarm-gate.sh:SIGALRM (teto de tempo)" "8:a07-missing-gate.sh:dependência ausente"; do
  n="${par%%:*}"; resto="${par#*:}"; alvo="${resto%%:*}"; como="${resto#*:}"
  echo "[$n] $como não é reprovação"; cen
  [ "$(marcador_de "$A_OUT" "$alvo")" = "$MARK_UNV" ]
  exige $? "$alvo ($como) não caiu no terceiro estado (marcador '$(marcador_de "$A_OUT" "$alvo")')"
  bloco "$A_OUT" 'FALHARAM:' | grep -qx "$alvo"
  [ $? -ne 0 ]
  exige $? "$alvo ($como) apareceu na lista FALHARAM: — falso-vermelho"
  echo "OK [$n]"
done

echo "[9] morte por sinal DEPOIS de imprimir FAIL agrava para reprovação"; cen
[ "$(marcador_de "$A_OUT" a08-agrava-gate.sh)" = "$MARK_FAIL" ]
exige $? "a08 (FAIL no log, morto por sinal) não foi classificado como reprovação — achado real escondido"
echo "OK [9]"

echo "[10] rc 128 é reprovação, não terceiro estado"; cen
[ "$(marcador_de "$A_OUT" a09-rc128-gate.sh)" = "$MARK_FAIL" ]
exige $? "rc 128 caiu no terceiro estado — o fatal do git viraria 'não verificado'"
echo "OK [10]"

echo "[11] bats com 'not ok' é reprovação"; cen
[ "$(marcador_de "$A_OUT" validators.bats)" = "$MARK_FAIL" ]
exige $? "suíte bats com linha '^not ok' não foi classificada como reprovação"
echo "OK [11]"

echo "[12] bats com rc não-zero e zero 'not ok' cai no terceiro estado"; cen
[ "$(marcador_de "$A_OUT" claude-contract.bats)" = "$MARK_UNV" ]
exige $? "bats cujo worker morreu (rc 1, zero '^not ok') foi contado como reprovação"
echo "OK [12]"

echo "[18] o resumo publica as quatro parcelas e a soma é o número de alvos"; cen
ALVOS_A="$(conta_alvos "$A_OUT" '.*(-gate\.sh|\.bats)')"
SOMA_A=$(( $(parcela "$A_OUT" PASS) + $(parcela "$A_OUT" FAIL) \
          + $(parcela "$A_OUT" SKIP) + $(parcela "$A_OUT" UNVERIFIED) ))
[ "$SOMA_A" = "$ALVOS_A" ] && [ "$ALVOS_A" = "13" ]
exige $? "soma das parcelas=$SOMA_A, alvos marcados=$ALVOS_A, esperado 13 — algum desfecho se perdeu"
echo "OK [18]"

echo "[22] lista do terceiro estado separada de FALHARAM: e com motivo"; cen
LISTA_UNV="$(bloco "$A_OUT" 'NÃO VERIFICADOS:')"
[ -n "$LISTA_UNV" ]
exige $? "não há bloco 'NÃO VERIFICADOS:' na saída"
echo "$LISTA_UNV" | grep -q 'a04-kill-gate.sh.*sinal-9'
exige $? "a04 não traz o motivo 'sinal-9' na lista: $LISTA_UNV"
echo "$LISTA_UNV" | grep -q 'a05-term-gate.sh.*sinal-15'
exige $? "a05 não traz o motivo 'sinal-15' na lista: $LISTA_UNV"
echo "$LISTA_UNV" | grep -q 'a07-missing-gate.sh.*dependencia-ausente'
exige $? "a07 não traz o motivo 'dependencia-ausente' na lista: $LISTA_UNV"
echo "$LISTA_UNV" | grep -q 'claude-contract.bats.*sem-not-ok'
exige $? "claude-contract.bats não traz o motivo 'sem-not-ok' na lista: $LISTA_UNV"
echo "OK [22]"

# ── RUN B — tudo verde ───────────────────────────────────────────────────────────────────────
B="$(mkbench runB)" || exit 1
fixture "$B" b01-pass-gate.sh 'exit 0'
roda "$B"; B_OUT="$OUT"; B_RC="$RC"

echo "[19] execução sem reprovação e sem não verificado sai 0"; cen
[ "$B_RC" -eq 0 ]
exige $? "rc=$B_RC numa execução 100% verde: $(sem_ansi "$B_OUT" | tail -4 | tr '\n' '|')"
echo "OK [19]"

# ── RUN C — só não verificados ───────────────────────────────────────────────────────────────
C="$(mkbench runC)" || exit 1
fixture "$C" c01-kill-gate.sh 'kill -KILL $$'
fixture "$C" c02-term-gate.sh 'kill -TERM $$'
roda "$C"; C_OUT="$OUT"; C_RC="$RC"

echo "[21] não verificados sem reprovação saem 3, nunca 0"; cen
[ "$(parcela "$C_OUT" FAIL)" = "0" ] && [ "$(parcela "$C_OUT" UNVERIFIED)" = "2" ]
exige $? "parcelas inesperadas: $(sem_ansi "$C_OUT" | grep '^PASS=' || true)"
[ "$C_RC" -eq 3 ]
exige $? "rc=$C_RC com dois desfechos não verificados e zero reprovações — esperado 3 (0 seria falso-verde)"
echo "OK [21]"

# ── RUN D — bats que não examinou nada ───────────────────────────────────────────────────────
D="$(mkbench runD)" || exit 1
fixture "$D" d01-pass-gate.sh 'exit 0'
W212_BATS_VALIDATORS=vazio roda "$D"; D_OUT="$OUT"; D_RC="$RC"

echo "[13] bats com plano 1..0 cai no terceiro estado e nunca em PASS"; cen
MARK_UNV_D="$(marcador_de "$D_OUT" validators.bats)"
[ "$MARK_UNV_D" = "$MARK_UNV" ]
exige $? "bats com plano '1..0' e rc 0 recebeu marcador '$MARK_UNV_D' — aprovar por não ter olhado para nada"
bloco "$D_OUT" 'NÃO VERIFICADOS:' | grep -q 'validators.bats.*plano-vazio'
exige $? "validators.bats não traz o motivo 'plano-vazio': $(bloco "$D_OUT" 'NÃO VERIFICADOS:')"
[ "$D_RC" -eq 3 ]
exige $? "rc=$D_RC — vacuidade de bats saiu verde"
echo "OK [13]"

# ── RUN E — infraestrutura do runner falhando ────────────────────────────────────────────────
E="$(mkbench runE)" || exit 1
fixture "$E" e01-pass-gate.sh 'exit 0'
printf '#!/usr/bin/env bash\nexit 1\n' > "$E/bin/mktemp"
chmod +x "$E/bin/mktemp"
roda "$E"; E_OUT="$OUT"; E_RC="$RC"

echo "[14] log que não pôde ser criado cai no terceiro estado"; cen
[ "$(marcador_de "$E_OUT" e01-pass-gate.sh)" = "$MARK_UNV" ]
exige $? "gate que PASSA foi classificado como reprovação por falha da infraestrutura do runner"
bloco "$E_OUT" 'NÃO VERIFICADOS:' | grep -q 'e01-pass-gate.sh.*sem-log'
exige $? "e01 não traz o motivo 'sem-log': $(bloco "$E_OUT" 'NÃO VERIFICADOS:')"
[ "$E_RC" -eq 3 ]
exige $? "rc=$E_RC com desfecho não verificado por falta de log"
echo "OK [14]"

# ── RUN F — varredura exaustiva de rc 0..255 ─────────────────────────────────────────────────
F="$(mkbench runF)" || exit 1
i=0
while [ "$i" -le 255 ]; do
  printf '#!/usr/bin/env bash\necho "[1] progresso"\nexit %d\n' "$i" \
    > "$F/tests/$(printf 'f%03d' "$i")-rc-gate.sh"
  i=$((i + 1))
done
chmod +x "$F"/tests/f*-rc-gate.sh
roda "$F"; F_OUT="$OUT"; F_RC="$RC"

VARR='f[0-9][0-9][0-9]-rc-gate\.sh'
NP="$(conta_alvos "$F_OUT" "$VARR" "$MARK_PASS")"
NF_="$(conta_alvos "$F_OUT" "$VARR" "$MARK_FAIL")"
NU="$(conta_alvos "$F_OUT" "$VARR" "$MARK_UNV")"
TOTAL_F="$(conta_alvos "$F_OUT" "$VARR")"

echo "[15] varredura exaustiva 0..255: uma classe por entrada, zero não classificadas"; cen
[ "$TOTAL_F" = "256" ]
exige $? "denominador da varredura=$TOTAL_F, esperado 256 — algum rc não produziu linha de marcador"
[ $((NP + NF_ + NU)) -eq 256 ]
exige $? "classificadas=$((NP + NF_ + NU)) de 256 (PASS=$NP FAIL=$NF_ TERCEIRO=$NU) — há rc sem classe ou com duas"
echo "OK [15]"

echo "[16] a partição bate com a fronteira declarada"; cen
[ "$NP" = "1" ] && [ "$NU" = "66" ] && [ "$NF_" = "189" ]
exige $? "partição PASS=$NP TERCEIRO=$NU FAIL=$NF_, esperado 1/66/189 (66 = 64 sinais em [129,192] + 126 + 127)"
echo "OK [16]"

# ── RUN H — sem bats no PATH, para colher o marcador de SKIP do runner REAL ──────────────────
# Sete bancadas plantavam o shim de bats em $b/bin e os dois arquivos .bats, então o ramo
# `have_bats -eq 0` do runner nunca era exercitado e o marcador de skip nunca era OBSERVADO. O [17]
# comparava o terceiro estado contra um literal '○' escrito aqui dentro, e por isso era meio-vivo:
# pegava o terceiro estado migrando para '○', e não pegava '○' migrando para o terceiro estado.
# Aqui o shim sai da bancada e o PATH é reduzido a um diretório MONTADO com symlinks só para as
# ferramentas que o runner usa, de modo que o `bats` fica comprovadamente fora de alcance em
# qualquer máquina — reduzir a `/usr/bin:/bin` funcionaria neste Mac (o bats mora em
# /opt/homebrew/bin) e silenciaria o cenário num host onde ele esteja em /usr/bin, que é o defeito
# desta mesma classe. A ausência do bats é CONFERIDA antes de qualquer conclusão, e a lista de
# ferramentas é resolvida por `command -v`: se alguma faltar, o gate reprova em vez de medir nada.
H="$(mkbench runH)" || exit 1
rm -f "$H/bin/bats"
mkdir -p "$H/binmin"
for _t in bash env dirname ls sort date mktemp basename rm sed grep tail; do
  # O resultado tem de ser CAMINHO ABSOLUTO: `command -v` também devolve o nome de uma função ou de
  # um builtin, e um symlink para 'grep' apontando para 'grep' é o alvo cego que o LDG-0177 nomeia.
  _p="$(command -v "$_t" 2>/dev/null || true)"
  case "$_p" in
    /*) ln -sf "$_p" "$H/binmin/$_t" ;;
    *)  echo "FAIL [17]: ferramenta '$_t' não resolve para caminho absoluto ('$_p') — a bancada sem bats não pode ser montada"; exit 1 ;;
  esac
done
PATH="$H/binmin" command -v bats >/dev/null 2>&1 \
  && { echo "FAIL [17]: 'bats' alcançável no PATH mínimo da bancada — o ramo de skip não seria exercitado e o cenário não mediria nada"; exit 1; }
fixture "$H" h01-pass-gate.sh 'exit 0'
H_OUT="$H/saida.txt"
( cd "$H" && PATH="$H/binmin" bash "$H/tests/run-all.sh" ) > "$H_OUT" 2>&1
H_RC=$?

echo "[17] o marcador do terceiro estado é distinto dos outros três, com o skip colhido do runner"; cen
[ "$(parcela "$H_OUT" SKIP)" = "2" ]
exige $? "a bancada sem bats não pulou as duas suítes: $(sem_ansi "$H_OUT" | grep '^PASS=' || true)"
MARK_SKIP="$(sem_ansi "$H_OUT" | grep -E "${LINHA_ALVO}bats indisponível" | head -1 | awk '{print $1}')"
[ -n "$MARK_SKIP" ]
exige $? "o runner não publicou marcador na linha de skip: $(sem_ansi "$H_OUT" | grep -i 'bats indispon' || true)"
[ "$MARK_UNV" != "$MARK_PASS" ] && [ "$MARK_UNV" != "$MARK_FAIL" ] && [ "$MARK_UNV" != "$MARK_SKIP" ]
exige $? "marcador do terceiro estado ('$MARK_UNV') colide com passagem ('$MARK_PASS'), reprovação ('$MARK_FAIL') ou skip ('$MARK_SKIP')"
[ "$MARK_SKIP" != "$MARK_PASS" ] && [ "$MARK_SKIP" != "$MARK_FAIL" ]
exige $? "o marcador de skip ('$MARK_SKIP') colide com passagem ou reprovação"
[ "$H_RC" -eq 0 ]
exige $? "rc=$H_RC numa bancada com um gate verde e duas suítes puladas — skip não é desfecho"
echo "OK [17]"

echo "[20] reprovação tem precedência sobre o terceiro estado no código de saída"; cen
[ "$A_RC" -eq 1 ]
exige $? "rc=$A_RC com reprovações E não verificados na mesma execução — esperado 1"
G="$(mkbench runG)" || exit 1
fixture "$G" g01-assert-gate.sh 'echo "FAIL [1]: x"; exit 1'
roda "$G"; G_RC="$RC"
[ "$G_RC" -eq 1 ]
exige $? "rc=$G_RC com reprovação e zero não verificados — esperado 1"
echo "OK [20]"

# ── RUN I e RUN J — bancadas que de fato ESVAZIAM os arrays do runner ────────────────────────
# A versão anterior do [23] varria 'unbound variable' nas saídas das bancadas A a F, e TODAS tinham
# os dois arrays não vazios por construção do `mkbench` — a asserção não podia falhar. Enquanto
# isso o runner tinha três expansões desguardadas de verdade (as duas do `--list`, o laço dos gates
# e o dos bats), e uma árvore sem `tests/validators.bats` fazia o runner morrer DEPOIS de executar
# todos os gates, sem imprimir `== Resultado ==` e devolvendo rc 1: o colapso de dois estados que
# esta onda combate, com toda a classificação já apurada perdida. Aqui os arrays ficam vazios de
# verdade, e a asserção é o resumo PUBLICADO, não a ausência de uma mensagem.
I_="$(mkbench runI)" || exit 1
rm -f "$I_/tests/validators.bats" "$I_/tests/snapshot/claude-contract.bats"
fixture "$I_" i01-pass-gate.sh 'exit 0'
roda "$I_"; I_OUT="$OUT"; I_RC="$RC"

J="$(mkbench runJ)" || exit 1
rm -f "$J/tests/validators.bats" "$J/tests/snapshot/claude-contract.bats"
roda "$J"; J_OUT="$OUT"
J_LIST="$J/lista.txt"
( cd "$J" && PATH="$J/bin:$PATH" bash "$J/tests/run-all.sh" --list ) > "$J_LIST" 2>&1
J_LIST_RC=$?

echo "[23] bash -n limpo e nenhuma expansão de array desguardada sob set -u"; cen
bash -n "$SRC"
exige $? "bash -n reprovou em $SRC"
for saida in "$A_OUT" "$B_OUT" "$C_OUT" "$D_OUT" "$E_OUT" "$F_OUT" "$H_OUT" "$I_OUT" "$J_OUT" "$J_LIST"; do
  grep -q 'unbound variable' "$saida" && { echo "FAIL [23]: 'unbound variable' em $saida"; exit 1; }
done
grep -q '^PASS=' "$I_OUT"
exige $? "sem nenhuma suíte .bats o runner não publicou o resumo: $(sem_ansi "$I_OUT" | tail -3 | tr '\n' '|')"
[ "$I_RC" -eq 0 ]
exige $? "rc=$I_RC com um gate verde e zero suítes .bats — o array vazio matou a suíte"
grep -q '^PASS=' "$J_OUT"
exige $? "sem gate e sem .bats o runner não publicou o resumo: $(sem_ansi "$J_OUT" | tail -3 | tr '\n' '|')"
[ "$J_LIST_RC" -eq 0 ]
exige $? "rc=$J_LIST_RC no --list com os dois arrays vazios: $(cat "$J_LIST" | tr '\n' '|')"
echo "OK [23]"

echo "[24] nenhuma linha não-comentário do runner INVOCA o runner"; cen
# A propriedade é ANTI-RECURSÃO, não a ausência do token: uma mensagem de diagnóstico pode nomear o
# runner legitimamente, e nesta mesma branch isso aconteceu de verdade — a sentinela de árvore
# rastreada (LDG-0179) imprime "run-all.sh: sentinela ausente" quando a biblioteca falta. O que não
# pode existir é INVOCAÇÃO: bash/sh/exec/source/`.` seguido de um alvo que cite o runner.
# CONTROLE POSITIVO DA VARREDURA, antes de concluir qualquer coisa da ausência de casamento.
# Medido nesta implementação, por acidente: uma mutação inseriu um byte NUL no runner, o `grep` do
# PATH devolveu VAZIO sobre o arquivo inteiro, e a asserção de ausência passou em falso — o cenário
# 24 virou verde sobre um runner que continha a invocação proibida. É o LDG-0177: varredura vazia
# não prova ausência. O controle usa um token que o runner tem por construção; se ele some, quem
# está cego é o scanner, não o arquivo.
CONTROLE_VARREDURA="$(grep -vE '^[[:space:]]*#' "$SRC" | grep -cE 'run_one')"
[ "${CONTROLE_VARREDURA:-0}" -ge 1 ]
exige $? "controle da varredura vazio — o scanner não enxerga o runner (byte de controle?); a ausência de casamento não provaria nada"
ALVO_RECURSAO="$(grep -vE '^[[:space:]]*#' "$SRC" | grep -nE '(bash|sh|exec|source|\.)[[:space:]]+[^[:space:]]*run-all' || true)"
[ -z "$ALVO_RECURSAO" ]
exige $? "linha não-comentário invocando o runner de dentro do runner (recursão): $ALVO_RECURSAO"
echo "OK [24]"

# As duas direções do predicado de agravamento. O [9] já cobria a direção que AGRAVA; o que faltava
# era a direção que NÃO pode agravar, e era exatamente onde o defeito estava vivo: o predicado
# procurava o token FAIL em qualquer posição do log, então a morte por sinal de um gate cujo caminho
# VERDE apenas cita o token voltava a ser contada como reprovação — o falso-vermelho que esta onda
# existe para eliminar, medido em três gates de produção (w131, w51, req13).
echo "[25] linha VERDE que apenas CITA o token FAIL não converte morte por sinal em reprovação"; cen
[ "$(marcador_de "$A_OUT" a10-narra-gate.sh)" = "$MARK_UNV" ]
exige $? "a10 (log verde citando 'FAIL' no meio da linha, morto por sinal) recebeu o marcador '$(marcador_de "$A_OUT" a10-narra-gate.sh)' — falso-vermelho de volta"
bloco "$A_OUT" 'FALHARAM:' | grep -qx 'a10-narra-gate.sh'
[ $? -ne 0 ]
exige $? "a10-narra-gate.sh apareceu em FALHARAM: — o predicado voltou a aceitar o token em qualquer posição"
bloco "$A_OUT" 'NÃO VERIFICADOS:' | grep -q 'a10-narra-gate.sh.*sinal-9'
exige $? "a10 não aparece na lista do terceiro estado com o motivo 'sinal-9': $(bloco "$A_OUT" 'NÃO VERIFICADOS:')"
echo "OK [25]"

echo "[26] linha de reprovação INDENTADA ainda agrava a morte por sinal"; cen
[ "$(marcador_de "$A_OUT" a11-indent-gate.sh)" = "$MARK_FAIL" ]
exige $? "a11 (reprovação indentada de sub-alvo, morto por sinal) não agravou — a correção de [25] virou falso-verde"
bloco "$A_OUT" 'FALHARAM:' | grep -qx 'a11-indent-gate.sh'
exige $? "a11-indent-gate.sh ausente da lista FALHARAM: — achado real escondido atrás de 'não verificado'"
echo "OK [26]"

echo "[27] sentinela — cenários examinados contra o denominador declarado"; cen
[ "$EXAMINADOS" = "$DECLARADO" ]
exige $? "examinou $EXAMINADOS cenário(s), declarou $DECLARADO"
echo "OK [27] — $EXAMINADOS/$DECLARADO cenários examinados"

echo "OK"
