#!/usr/bin/env bash
# Gate W247 — três estados no runner do TEMPLATE, o que o harness entrega aos consumidores (LDG-0181).
#
# O DEFEITO. `template/.forge/scripts/tests/run-all.sh` tinha dois desfechos por alvo: todo rc
# diferente de zero virava a mesma parcela FAIL, o mesmo marcador ✗ e o mesmo rc 1. Um teste morto
# por SIGKILL (o OOM killer), por teto de tempo, ou sem o interpretador (`node` ausente) ficava
# indistinguível de um teste que reprovou por asserção — falso-VERMELHO, o mesmo defeito que o
# LDG-0180 fechou no runner interno. E pior: o ramo de falha REEXECUTAVA o alvo para imprimir a saída,
# de modo que um alvo morto por falta de memória era morto duas vezes, a saída exibida era a de OUTRA
# execução (que pode morrer de outro jeito, ou nem morrer), e essa segunda execução acontecia FORA da
# janela da sentinela de árvore rastreada (LDG-0179) — um teste que sujasse a árvore só na segunda
# rodada passava sem ser medido.
#
# O QUE ESTE GATE PROVA. Integração de ponta a ponta com o runner real: o gate copia o runner para
# bancadas em $TMPDIR que imitam o layout do consumidor (`.forge/scripts/tests/` + `.forge/scripts/lib/`,
# repositório git sintético), confere por sha256 que cada cópia é idêntica ao original — controle
# contra testar cópia velha — planta alvos de cada classe e executa a cópia. A sentinela de árvore
# rastreada entra como DUBLÊ NEUTRO (ela tem gate próprio, o w213); o que se mede aqui é a
# classificação de desfecho. Cada alvo grava uma linha num marcador FORA do diretório de testes a
# cada execução, e é isso que prova "executou exatamente uma vez".
#
# MAPA DE CÓDIGOS (DA-01 do plano 2026-09-15): 0 verde; 1 reprovação, com precedência; 3 não
# verificado (sem veredito do alvo, ou árvore não medida); 64 argumento desconhecido; 66 `--path` que
# não é diretório. Zero testes continua rc 0 com a linha nominal `nada a rodar` — o template é
# DISTRIBUÍDO sem teste algum e o pre-push o executa em todo consumidor, então piso 1 aqui bloquearia
# o push de todo adotante que nunca escreveu teste próprio.
#
# CENÁRIOS (denominador fixo 30 — exceção legítima da invariante 14; a divergência é o achado):
#   [1] existe um terceiro desfecho alcançável — morto por sinal não recebe ✓ nem ✗
#   [2] alvo que passa → ✓ e PASS
#   [3] alvo que reprova imprimindo FAIL → ✗
#   [4] alvo que reprova SEM imprimir FAIL continua ✗ (a ausência do marcador nunca abranda)
#   [5] SIGKILL → sem veredito, motivo sinal-9, fora de FALHARAM:
#   [6] SIGTERM → mesma classe, motivo sinal-15
#   [7] teto de tempo (SIGALRM, rc 142) → mesma classe, motivo sinal-14
#   [8] `exit 127` (dependência ausente) → sem veredito, motivo dependencia-ausente
#   [9] morto por sinal DEPOIS de imprimir linha FAIL → ✗ (o log agrava, nunca abranda)
#  [10] rc 128 → ✗ (é o fatal do git, não sinal)
#  [11] linha VERDE que só CITA o token FAIL no meio não agrava a morte por sinal
#  [12] linha FAIL INDENTADA (sub-alvo) agrava a morte por sinal
#  [13] alvo `.test.mjs` morto por SIGKILL → sem veredito (o ramo `node` também classifica)
#  [14] interpretador ausente — `node` fora do PATH — → sem veredito, dependencia-ausente, rc 3
#  [15] log que não pôde ser criado (mktemp falhando) → sem veredito, motivo sem-log, alvo NÃO executado
#  [16] cada alvo executa exatamente UMA vez — inclusive o que reprova e o que morre (não reexecução)
#  [17] alvo que morre na 1ª execução e reprovaria numa 2ª é relatado pela 1ª: sinal-9, e a saída
#       exibida não contém nada da 2ª (que não existe)
#  [18] varredura exaustiva de rc 0..255: 256 linhas de veredito, uma classe por entrada
#  [19] a partição bate com a fronteira: 1 PASS, 66 sem veredito (64 sinais em [129,192] + 126 + 127),
#       189 FAIL
#  [20] o resumo publica PASS/FAIL/SEM-VEREDITO e a soma é o número de arquivos examinados
#  [21] a lista SEM VEREDITO: é separada de FALHARAM: e traz o motivo de cada alvo
#  [22] só verdes → rc 0 com `OK harness-tests`
#  [23] reprovação + sem veredito → rc 1 (precedência), e a lista SEM VEREDITO: ainda é publicada
#  [24] só sem veredito → rc 3
#  [25] contrato 64 e 66 intacto: argumento desconhecido → 64, `--path` inexistente → 66
#  [26] `--path` continua valendo: o runner classifica a árvore apontada, não a própria
#  [27] vacuidade reconciliada: zero testes → rc 0 com `nada a rodar`; todos mortos → rc 3 e NUNCA a
#       linha de vacuidade
#  [28] sem repositório git: morto por sinal conta em SEM-VEREDITO e em NÃO-MEDIDOS, rc 3; o marcador
#       ⚠ da anotação, colhido do runner real, é distinto de ⊘; e a anotação não promete "✓ abaixo"
#  [29] propriedade: listas geradas de 0 a 6 alvos com rc em {0,1,2,126,127,130,137,143} — o rc do
#       runner é 1 se algum reprova, senão 3 se algum ficou sem veredito, senão 0; cada alvo roda 1 vez
#  [30] SENTINELA — o gate examinou exatamente 30 cenários
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$WS/template/.forge/scripts/tests/run-all.sh"
DECLARADO=30
EXAMINADOS=0
falhou=0
cen() { EXAMINADOS=$((EXAMINADOS + 1)); echo "[$1] $2"; }
_falha() { echo "FAIL [$1]: $2"; falhou=1; }
ok() { echo "OK [$1]"; }

[ -f "$SRC" ] || { echo "FAIL [0]: $SRC não existe"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "FAIL [0]: node ausente — os cenários [13] e [29] não teriam o que medir"; exit 1; }
T="$(mktemp -d "${TMPDIR:-/tmp}/forge-w247.XXXXXX")" || { echo "FAIL [0]: mktemp -d falhou"; exit 1; }
trap 'rm -rf "$T"' EXIT

sha_de() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  else sha256sum "$1" | awk '{print $1}'; fi
}

# ── bancada ──────────────────────────────────────────────────────────────────────────────────
mkbench() { # mkbench <nome> [sem-git] -> ecoa o diretório da bancada
  local b="$T/$1"
  mkdir -p "$b/.forge/scripts/tests" "$b/.forge/scripts/lib" "$b/bin" "$b/cont"
  cp "$SRC" "$b/.forge/scripts/tests/run-all.sh"
  [ "$(sha_de "$SRC")" = "$(sha_de "$b/.forge/scripts/tests/run-all.sh")" ] \
    || { echo "FAIL [0]: a cópia da bancada '$1' não é idêntica ao original" >&2; return 1; }
  # DUBLÊ NEUTRO da sentinela (LDG-0179): retrato constante, conferência sempre limpa.
  printf '%s\n' '#!/usr/bin/env bash' 'arvore_retrato() { echo dublê; }' \
    'arvore_snapshot() { echo dublê; }' 'arvore_confere() { return 0; }' \
    > "$b/.forge/scripts/lib/arvore-rastreada.sh"
  if [ "${2:-}" != "sem-git" ]; then git init -q "$b" || return 1; fi
  echo "$b"
}

alvo() { # alvo <bancada> <arquivo> <corpo> — o prólogo grava uma linha no marcador por execução
  printf '#!/usr/bin/env bash\necho x >> "%s/cont/%s"\n%s\n' "$1" "$2" "$3" > "$1/.forge/scripts/tests/$2"
}

roda() { # roda <bancada> [args...] -> OUT (arquivo) e RC
  local b="$1"; shift
  OUT="$b/saida.$(date +%s)$RANDOM.txt"
  ( cd "$b" && PATH="$b/bin:$PATH" bash "$b/.forge/scripts/tests/run-all.sh" "$@" ) > "$OUT" 2>&1
  RC=$?
}

# Linha de veredito: dois espaços, marcador (nunca começando por '-', que é o anúncio `->` e as
# listas nominais), espaço, nome, fim de linha. A anotação ⚠ tem sufixo e não casa.
marcador_de() { grep -E "^  [^ -][^ ]* $2\$" "$1" | head -1 | awk '{print $1}'; }
execucoes() { if [ -f "$1/cont/$2" ]; then wc -l < "$1/cont/$2" | tr -d ' '; else echo 0; fi; }
bloco() { # bloco <saida> <cabeçalho> — as linhas "  - x" logo após o cabeçalho
  awk -v h="$2" '$0 == h { d = 1; next } d && /^  - / { print substr($0, 5); next } d { d = 0 }' "$1"
}
parcela() { sed -n "s/^harness-tests: .* $2=\([0-9][0-9]*\).*/\1/p" "$1" | head -1; }

MARK_PASS='✓'; MARK_FAIL='✗'

# ── RUN A — um representante de cada classe ──────────────────────────────────────────────────
A="$(mkbench runA)" || exit 1
alvo "$A" a01-pass.test.sh      'echo progresso; exit 0'
alvo "$A" a02-assert.test.sh    'echo "FAIL [1]: esperado 2, obtido 3"; exit 1'
alvo "$A" a03-silent.test.sh    'set -e; echo "[1] progresso"; [ 1 -eq 2 ]'
alvo "$A" a04-kill.test.sh      'echo "[1] progresso"; kill -KILL $$'
alvo "$A" a05-term.test.sh      'echo "[1] progresso"; kill -TERM $$'
alvo "$A" a06-alarm.test.sh     'echo "[1] progresso"; kill -ALRM $$'
alvo "$A" a07-missing.test.sh   'exit 127'
alvo "$A" a08-failkill.test.sh  'echo "FAIL [2]: violação observada"; kill -KILL $$'
alvo "$A" a09-rc128.test.sh     'exit 128'
alvo "$A" a10-narra.test.sh     'echo "[4] wave-ops close: OK fecha; FAIL recusa"; kill -KILL $$'
alvo "$A" a11-indent.test.sh    'echo "      FAIL [3]: sub-alvo reprovou"; kill -KILL $$'
# instável: morre na 1ª execução; se houvesse 2ª, reprovaria com uma linha FAIL nominal
alvo "$A" a12-flaky.test.sh     'n=$(wc -l < "'"$A"'/cont/a12-flaky.test.sh" | tr -d " ")
if [ "$n" -le 1 ]; then echo "primeira-execucao"; kill -KILL $$; fi
echo "FAIL [9]: SEGUNDA-EXECUCAO"; exit 1'
printf 'import { appendFileSync } from "node:fs";\nappendFileSync("%s/cont/a13-node.test.mjs", "x\\n");\nconsole.log("[1] progresso");\nprocess.kill(process.pid, "SIGKILL");\n' "$A" \
  > "$A/.forge/scripts/tests/a13-node.test.mjs"
roda "$A"; A_OUT="$OUT"; A_RC="$RC"
MARK_UNV="$(marcador_de "$A_OUT" a04-kill.test.sh)"

cen 1 "existe um terceiro desfecho alcançável"
if [ -n "$MARK_UNV" ] && [ "$MARK_UNV" != "$MARK_PASS" ] && [ "$MARK_UNV" != "$MARK_FAIL" ]; then ok 1
else _falha 1 "alvo morto por SIGKILL recebeu '$MARK_UNV' — o runner só tem dois desfechos"; fi

cen 2 "alvo que passa → ✓"
[ "$(marcador_de "$A_OUT" a01-pass.test.sh)" = "$MARK_PASS" ] && ok 2 || _falha 2 "a01 não recebeu ✓"

cen 3 "reprovação com FAIL → ✗"
[ "$(marcador_de "$A_OUT" a02-assert.test.sh)" = "$MARK_FAIL" ] && ok 3 || _falha 3 "a02 não recebeu ✗"

cen 4 "reprovação SEM FAIL continua ✗"
[ "$(marcador_de "$A_OUT" a03-silent.test.sh)" = "$MARK_FAIL" ] && ok 4 || _falha 4 "a03 (asserção nua sob set -e) saiu de ✗ — a ausência do marcador abrandou o veredito"

SV_A="$(bloco "$A_OUT" 'SEM VEREDITO:')"
FA_A="$(bloco "$A_OUT" 'FALHARAM:')"
unv_com() { # unv_com <n> <alvo> <motivo>
  if [ "$(marcador_de "$A_OUT" "$2")" = "$MARK_UNV" ] && [ -n "$MARK_UNV" ] \
     && printf '%s\n' "$SV_A" | grep -qx "$2 ($3)" && ! printf '%s\n' "$FA_A" | grep -q "^$2"; then ok "$1"
  else _falha "$1" "$2 deveria estar sem veredito com motivo '$3' e fora de FALHARAM: — marcador '$(marcador_de "$A_OUT" "$2")'"; fi
}
cen 5 "SIGKILL → sem veredito (sinal-9)";              unv_com 5 a04-kill.test.sh sinal-9
cen 6 "SIGTERM → sem veredito (sinal-15)";             unv_com 6 a05-term.test.sh sinal-15
cen 7 "teto de tempo SIGALRM → sem veredito (sinal-14)"; unv_com 7 a06-alarm.test.sh sinal-14
cen 8 "exit 127 → sem veredito (dependencia-ausente)"; unv_com 8 a07-missing.test.sh dependencia-ausente

cen 9 "morto por sinal depois de linha FAIL → ✗"
[ "$(marcador_de "$A_OUT" a08-failkill.test.sh)" = "$MARK_FAIL" ] && printf '%s\n' "$FA_A" | grep -qx a08-failkill.test.sh \
  && ok 9 || _falha 9 "a08 escondeu uma violação observada atrás de 'sem veredito'"

cen 10 "rc 128 → ✗"
[ "$(marcador_de "$A_OUT" a09-rc128.test.sh)" = "$MARK_FAIL" ] && ok 10 || _falha 10 "rc 128 saiu de ✗"

cen 11 "linha verde que só CITA FAIL não agrava";       unv_com 11 a10-narra.test.sh sinal-9

cen 12 "linha FAIL indentada agrava"
[ "$(marcador_de "$A_OUT" a11-indent.test.sh)" = "$MARK_FAIL" ] && ok 12 || _falha 12 "a11 (reprovação indentada de sub-alvo) não agravou"

cen 13 ".test.mjs morto por SIGKILL → sem veredito";   unv_com 13 a13-node.test.mjs sinal-9

# ── RUN N — interpretador ausente: PATH montado com symlinks, sem node ──────────────────────
N="$(mkbench runN)" || exit 1
printf 'console.log("nunca roda")\n' > "$N/.forge/scripts/tests/n01-node.test.mjs"
mkdir -p "$N/binmin"
for _t in bash env dirname basename find sort git sed tail head mktemp grep rm wc cat tr printf date; do
  _p="$(command -v "$_t" 2>/dev/null || true)"
  case "$_p" in /*) ln -sf "$_p" "$N/binmin/$_t" ;; *) : ;; esac
done
PATH="$N/binmin" command -v node >/dev/null 2>&1 && { echo "FAIL [14]: node alcançável no PATH mínimo — o cenário não mediria nada"; exit 1; }
N_OUT="$N/saida.txt"
( cd "$N" && PATH="$N/binmin" bash "$N/.forge/scripts/tests/run-all.sh" ) > "$N_OUT" 2>&1; N_RC=$?
cen 14 "interpretador ausente → sem veredito (dependencia-ausente), rc 3"
_n14_blk="$(bloco "$N_OUT" 'SEM VEREDITO:')"
if [ "$(marcador_de "$N_OUT" n01-node.test.mjs)" = "$MARK_UNV" ] && grep -qx 'n01-node.test.mjs (dependencia-ausente)' <<<"$_n14_blk" && [ "$N_RC" -eq 3 ]; then ok 14
else _falha 14 "node ausente: marcador '$(marcador_de "$N_OUT" n01-node.test.mjs)', rc=$N_RC"; fi

# ── RUN E — infraestrutura do runner falhando: mktemp quebrado ───────────────────────────────
E="$(mkbench runE)" || exit 1
alvo "$E" e01-pass.test.sh 'exit 0'
printf '#!/usr/bin/env bash\nexit 1\n' > "$E/bin/mktemp"; chmod +x "$E/bin/mktemp"
roda "$E"; E_OUT="$OUT"; E_RC="$RC"
cen 15 "log não criado → sem veredito (sem-log), alvo não executado"
if [ "$(marcador_de "$E_OUT" e01-pass.test.sh)" = "$MARK_UNV" ] && bloco "$E_OUT" 'SEM VEREDITO:' | grep -qx 'e01-pass.test.sh (sem-log)' \
   && [ "$E_RC" -eq 3 ] && [ "$(execucoes "$E" e01-pass.test.sh)" = "0" ]; then ok 15
else _falha 15 "mktemp falho: marcador '$(marcador_de "$E_OUT" e01-pass.test.sh)', rc=$E_RC, execuções=$(execucoes "$E" e01-pass.test.sh)"; fi

cen 16 "cada alvo executa exatamente uma vez"
_multi=""
for f in "$A"/.forge/scripts/tests/a*; do
  n="$(execucoes "$A" "$(basename "$f")")"; [ "$n" = "1" ] || _multi="$_multi $(basename "$f")=$n"
done
[ -z "$_multi" ] && ok 16 || _falha 16 "alvos executados um número de vezes diferente de 1:$_multi — o ramo de falha reexecuta"

cen 17 "o morto na 1ª execução é relatado pela 1ª"
if [ "$(marcador_de "$A_OUT" a12-flaky.test.sh)" = "$MARK_UNV" ] && printf '%s\n' "$SV_A" | grep -qx 'a12-flaky.test.sh (sinal-9)' \
   && ! grep -q SEGUNDA-EXECUCAO "$A_OUT" && grep -q primeira-execucao "$A_OUT"; then ok 17
else _falha 17 "a12 relatado com marcador '$(marcador_de "$A_OUT" a12-flaky.test.sh)'; SEGUNDA-EXECUCAO na saída: $(grep -c SEGUNDA-EXECUCAO "$A_OUT")"; fi

# ── RUN F — varredura exaustiva de rc 0..255 ─────────────────────────────────────────────────
F="$(mkbench runF)" || exit 1
i=0
while [ "$i" -le 255 ]; do
  printf '#!/usr/bin/env bash\necho "[1] progresso"\nexit %d\n' "$i" > "$F/.forge/scripts/tests/$(printf 'f%03d' "$i").test.sh"
  i=$((i + 1))
done
roda "$F"; F_OUT="$OUT"; F_RC="$RC"
VARR='f[0-9][0-9][0-9]\.test\.sh'
F_TOT="$(grep -cE "^  [^ -][^ ]* $VARR\$" "$F_OUT")"
F_P="$(grep -cE "^  $MARK_PASS $VARR\$" "$F_OUT")"
F_F="$(grep -cE "^  $MARK_FAIL $VARR\$" "$F_OUT")"
F_U=0; [ -n "$MARK_UNV" ] && F_U="$(grep -cE "^  $MARK_UNV $VARR\$" "$F_OUT")"
cen 18 "varredura 0..255: uma classe por entrada"
[ "${F_TOT:-0}" = "256" ] && [ $((F_P + F_F + F_U)) -eq 256 ] && ok 18 \
  || _falha 18 "linhas de veredito=$F_TOT, classificadas=$((F_P + F_F + F_U)) de 256"
cen 19 "partição 1/66/189"
[ "$F_P" = "1" ] && [ "$F_U" = "66" ] && [ "$F_F" = "189" ] && ok 19 \
  || _falha 19 "partição PASS=$F_P SEM-VEREDITO=$F_U FAIL=$F_F, esperado 1/66/189"

cen 20 "o resumo publica as parcelas e a soma é o total examinado"
TOT_A="$(sed -n 's/^harness-tests: \([0-9][0-9]*\) arquivo.*/\1/p' "$A_OUT")"
P_A="$(parcela "$A_OUT" PASS)"; F_A="$(parcela "$A_OUT" FAIL)"; U_A="$(parcela "$A_OUT" SEM-VEREDITO)"
if [ -n "$TOT_A" ] && [ -n "$U_A" ] && [ "$TOT_A" = "13" ] && [ $((P_A + F_A + U_A)) -eq "$TOT_A" ]; then ok 20
else _falha 20 "resumo total='$TOT_A' PASS='$P_A' FAIL='$F_A' SEM-VEREDITO='$U_A' (esperado 13 = soma)"; fi

cen 21 "SEM VEREDITO: separado de FALHARAM:, com motivo"
_sv_n="$(printf '%s\n' "$SV_A" | grep -c ' (.*)$')"
if [ "${_sv_n:-0}" -eq "${U_A:-x}" ] 2>/dev/null && ! printf '%s\n' "$FA_A" | grep -qE 'a04|a05|a06|a07|a10|a12|a13'; then ok 21
else _falha 21 "lista SEM VEREDITO: com $_sv_n entrada(s) com motivo para parcela '$U_A'; FALHARAM: = $(printf '%s' "$FA_A" | tr '\n' ' ')"; fi

# ── RUN B / C — mapa de códigos ──────────────────────────────────────────────────────────────
B="$(mkbench runB)" || exit 1
alvo "$B" b01.test.sh 'exit 0'; alvo "$B" b02.test.sh 'exit 0'
roda "$B"; B_OUT="$OUT"; B_RC="$RC"
cen 22 "só verdes → rc 0"
[ "$B_RC" -eq 0 ] && grep -qx 'OK harness-tests' "$B_OUT" && ok 22 || _falha 22 "rc=$B_RC"

cen 23 "reprovação + sem veredito → rc 1, e SEM VEREDITO: publicado"
[ "$A_RC" -eq 1 ] && [ -n "$SV_A" ] && ok 23 || _falha 23 "rc=$A_RC; lista SEM VEREDITO: $( [ -n "$SV_A" ] && echo presente || echo AUSENTE)"

C="$(mkbench runC)" || exit 1
alvo "$C" c01.test.sh 'exit 0'; alvo "$C" c02.test.sh 'kill -TERM $$'
roda "$C"; C_OUT="$OUT"; C_RC="$RC"
cen 24 "só sem veredito → rc 3"
[ "$C_RC" -eq 3 ] && ok 24 || _falha 24 "rc=$C_RC com um verde e um morto por SIGTERM (esperado 3)"

cen 25 "contrato 64/66 intacto"
roda "$B" --opcao-que-nao-existe; R64="$RC"
roda "$B" --path "$T/nao-existe"; R66="$RC"
[ "$R64" -eq 64 ] && [ "$R66" -eq 66 ] && [ "$F_RC" -eq 1 ] && ok 25 \
  || _falha 25 "argumento desconhecido rc=$R64 (64), --path inexistente rc=$R66 (66), varredura rc=$F_RC (1)"

# ── RUN P — `--path` e vacuidade ─────────────────────────────────────────────────────────────
P="$(mkbench runP)" || exit 1
alvo "$P" p00-pass-proprio.test.sh 'exit 0'
mkdir -p "$P/outra" "$P/vazia"
printf '#!/usr/bin/env bash\necho x >> "%s/cont/p01"\nkill -KILL $$\n' "$P" > "$P/outra/p01-morto.test.sh"
roda "$P" --path "$P/outra"; PO_OUT="$OUT"; PO_RC="$RC"
roda "$P" --path "$P/vazia"; PV_OUT="$OUT"; PV_RC="$RC"
cen 26 "--path classifica a árvore apontada"
_p26_blk="$(bloco "$PO_OUT" 'SEM VEREDITO:')"
if [ "$PO_RC" -eq 3 ] && grep -qx 'p01-morto.test.sh (sinal-9)' <<<"$_p26_blk" && ! grep -q p00-pass-proprio "$PO_OUT"; then ok 26
else _falha 26 "--path: rc=$PO_RC; $(tail -3 "$PO_OUT" | tr '\n' '|')"; fi

cen 27 "vacuidade reconciliada"
if [ "$PV_RC" -eq 0 ] && grep -q 'nada a rodar' "$PV_OUT" && ! grep -q 'nada a rodar' "$PO_OUT" && ! grep -q 'nada a rodar' "$C_OUT"; then ok 27
else _falha 27 "zero testes rc=$PV_RC ('nada a rodar' $(grep -c 'nada a rodar' "$PV_OUT")x); todos mortos com linha de vacuidade $(grep -c 'nada a rodar' "$PO_OUT")x"; fi

# ── RUN S — sem repositório git ──────────────────────────────────────────────────────────────
S="$(mkbench runS sem-git)" || exit 1
alvo "$S" s01-morto.test.sh 'kill -KILL $$'
roda "$S"; S_OUT="$OUT"; S_RC="$RC"
cen 28 "sem git: SEM-VEREDITO e NÃO-MEDIDOS convivem, ⚠ ≠ ⊘"
MARK_ANOT="$(grep -E '^  [^ -][^ ]* s01-morto\.test\.sh — ' "$S_OUT" | head -1 | awk '{print $1}')"
if [ "$S_RC" -eq 3 ] && [ "$(parcela "$S_OUT" SEM-VEREDITO)" = "1" ] && [ "$(parcela "$S_OUT" NÃO-MEDIDOS)" = "1" ] \
   && [ -n "$MARK_ANOT" ] && [ -n "$MARK_UNV" ] && [ "$MARK_ANOT" != "$MARK_UNV" ] && [ "$MARK_ANOT" != "$MARK_PASS" ] \
   && ! grep -q 'o ✓ abaixo' "$S_OUT"; then ok 28
else _falha 28 "rc=$S_RC SEM-VEREDITO='$(parcela "$S_OUT" SEM-VEREDITO)' NÃO-MEDIDOS='$(parcela "$S_OUT" NÃO-MEDIDOS)' anotação='$MARK_ANOT' terceiro='$MARK_UNV'; 'o ✓ abaixo' $(grep -c 'o ✓ abaixo' "$S_OUT")x"; fi

# ── RUN Q — propriedade sobre listas geradas ─────────────────────────────────────────────────
cen 29 "propriedade: rc = 1 se reprova, senão 3 se sem veredito, senão 0; 1 execução por alvo"
RANDOM=247
RCS=(0 1 2 126 127 130 137 143)
CASOS=40; viol=""; casos_vistos=0; tamanhos=""
q=0
while [ "$q" -lt "$CASOS" ]; do
  Q="$(mkbench "runQ$q")" || exit 1
  n=$((RANDOM % 7)); tamanhos="$tamanhos$n"
  esp=0; tem_f=0; tem_u=0; k=0
  while [ "$k" -lt "$n" ]; do
    r="${RCS[$((RANDOM % 8))]}"
    alvo "$Q" "q$k.test.sh" "exit $r"
    case "$r" in 0) ;; 126|127|130|137|143) tem_u=1 ;; *) tem_f=1 ;; esac
    k=$((k + 1))
  done
  if [ "$tem_f" -eq 1 ]; then esp=1; elif [ "$tem_u" -eq 1 ]; then esp=3; fi
  roda "$Q"
  [ "$RC" -eq "$esp" ] || viol="$viol caso$q(n=$n rc=$RC esperado=$esp)"
  k=0
  while [ "$k" -lt "$n" ]; do
    [ "$(execucoes "$Q" "q$k.test.sh")" = "1" ] || viol="$viol caso$q/q$k(execuções=$(execucoes "$Q" "q$k.test.sh"))"
    k=$((k + 1))
  done
  casos_vistos=$((casos_vistos + 1)); q=$((q + 1))
done
# o gerador tem de ter coberto o vazio e o máximo, senão a propriedade foi medida num subespaço
case "$tamanhos" in *0*) : ;; *) viol="$viol gerador-sem-lista-vazia" ;; esac
case "$tamanhos" in *6*) : ;; *) viol="$viol gerador-sem-lista-de-6" ;; esac
[ "$casos_vistos" -eq "$CASOS" ] && [ -z "$viol" ] && ok 29 || _falha 29 "$casos_vistos/$CASOS casos; violações:$viol"

cen 30 "sentinela — cenários examinados contra o denominador"
[ "$EXAMINADOS" -eq "$DECLARADO" ] && ok 30 || _falha 30 "examinou $EXAMINADOS, declarou $DECLARADO"

if [ "$falhou" -ne 0 ]; then echo "FAIL w247 — o runner do template não distingue os três estados (ver acima)"; exit 1; fi
echo "OK w247 — $EXAMINADOS/$DECLARADO cenários"
