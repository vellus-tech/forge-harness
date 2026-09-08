#!/usr/bin/env bash
# Gate W211 — o `detail` do ledger deixa de ser campo que se substitui e passa a ser registro que
# acumula: verbo novo `note` (só acrescenta) e guarda de preservação na porta antiga (`update
# --detail`), com `--replace-detail` como escape pedido em letra.
#
# POR QUE ESTE GATE EXISTE. `update --detail` gravava por atribuição direta (`if (de) e.detail =
# de;`), e a história do próprio `.forge/ledger/ledger.json` deste repositório carrega SEIS perdas
# medidas — 3.497 bytes num único item, 86 de 86 frases longas ausentes, `rc 0` e `OK` na saída em
# todas elas. E não havia verbo para registrar que uma dívida foi parcialmente paga sem fechá-la,
# de modo que a única forma de registrar progresso era reescrever o campo, que é exatamente o que
# apaga o histórico. Registrar progresso por `--status in-progress` não é saída: tira o item da
# contagem `open` que a definição de pronto usa, o que é fechar por reclassificação silenciosa.
#
# Este gate é HERMÉTICO: toda fixture vive em `$T` sob `$TMPDIR`, com `FORGE_ROOT` apontando para
# ela. Nunca lê nem escreve o `.forge/ledger/` real — há sentinela por `sha256` no fim.
#
# NENHUMA asserção de conteúdo usa `grep`. O `grep` do PATH desta máquina é o ugrep, que sobre
# arquivo com byte de controle devolve saída VAZIA com rc 1 — indistinguível de "não há
# ocorrência" — enquanto o CI roda GNU grep. Conteúdo é comparado por `node` (indexOf) e por
# casamento de padrão do próprio bash (`case`), e o cenário [0] planta um positivo e um negativo
# para provar que o comparador DISCRIMINA antes de qualquer conclusão por ausência.
#
#   [0]  controle do comparador: o positivo plantado é encontrado e o negativo plantado não é
#   [1]  o verbo `note` existe: rc 0 e uma linha OK
#   [2]  P1 — `note` preserva: o detail anterior é prefixo do novo e o comprimento cresce
#   [3]  P2 — `note` não fecha: `status` e `resolved_at` idênticos, sobre `open` e sobre `planned`
#   [4]  P3 — o marcador do `--kind` e a data do COMMIT HEAD (a fixture carimba data distante)
#   [5]  P6 — três `note` de kinds diferentes deixam três marcadores, na ordem de emissão
#   [6]  `--kind` fora do enum reprova nomeando os quatro; contador pareado: os quatro gravam
#   [7]  `note` sem `--text`, com `--text ""` e com `--text --kind` reprovam (disciplina #103)
#   [8]  P4 — `update --detail` destrutivo RECUSA: rc≠0, ledger byte a byte idêntico, mensagem
#        nomeando `note` e `--replace-detail`; e o caso DISCRIMINANTE, texto novo maior que o
#        corrente e que não preserva um byte dele — preservação não é não-encolhimento
#   [9]  os dois caminhos que continuam gravando: detail vazio, e texto que preserva o corrente
#   [10] `--replace-detail` substitui e ANUNCIA o número de bytes descartados (asserção no número)
#   [11] `--replace-detail` sem `--detail` reprova nomeando a flag
#   [12] texto idêntico ao corrente continua NOCHANGE — a guarda entra DEPOIS da detecção de no-op
#   [13] `note` em id inexistente reprova; `note` em item `resolved` grava, avisa e não muda status;
#        e a nota REPETIDA avisa e acrescenta assim mesmo, enquanto a nota nova não avisa
#   [14] P5 — o denominador de `open` da fixture é invariante à bateria inteira (derivado, nunca
#        literal)
#   [15] propriedade sobre entrada gerada: comprimento, acentuação, quebras de linha, aspas,
#        sequências que coincidem com nome de flag e com o MARCADOR gerado
#   [16] contrato: a fixture continua conforme ao `ledger.schema.json` (Decisão 8), com negativo
#        plantado para provar que o validador discrimina
#   [17] integração ponta a ponta: add, note, note, `list --status open`, resolve, render
#   [18] `note` RE-RENDERIZA o `LEDGER.md` sem `render` explícito — é porta de escrita como as
#        outras cinco, e a paridade `ledger.json` ↔ `LEDGER.md` não tem gate próprio
#   [19] `note` ANUNCIA divergência de raiz: invocado de dentro de um worktree, grava no ledger do
#        TRONCO e emite o aviso de `forge_warn_root_divergence` (LDG-0068/LDG-0174)
#   [20] prova de mutação: sete mutações, cada uma com controle, contrafactual EXIGIDO,
#        restauração por cópia conferida com `cmp` e recontrole
#
# Três estados, nunca dois: `node` ausente, `git` sem commit ou fixture não montada terminam em
# NÃO VERIFICADO com rc 3, distinto do FAIL (rc 1) e do PASS (rc 0).
set -euo pipefail

SCN_DECLARED=21   # [0]..[20] — contagem do PRÓPRIO gate, a única exceção legítima ao literal
SCN_RUN=0
_scn() { SCN_RUN=$((SCN_RUN + 1)); echo "$1"; }

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── sentinela do repositório real: o ledger de verdade não pode ser tocado ─────────────────────
REAL_LEDGER="$WS/.forge/ledger/ledger.json"
_sha() { if [ -f "$1" ]; then shasum -a 256 "$1" | awk '{print $1}'; else echo "AUSENTE"; fi; }
REAL_SHA_BEFORE="$(_sha "$REAL_LEDGER")"
REPO_SNAPSHOT_BEFORE="$(git -C "$WS" status --porcelain)"

command -v node >/dev/null 2>&1 || { echo "NÃO VERIFICADO: 'node' ausente — o gate não roda sem ele, e ausência de verificação não é ausência de violação"; exit 3; }
command -v git  >/dev/null 2>&1 || { echo "NÃO VERIFICADO: 'git' ausente — a fixture precisa de um commit para a data determinística"; exit 3; }

T="$(mktemp -d "${TMPDIR:-/tmp}/forge-w211.XXXXXX")"
trap 'rm -rf "$T"' EXIT

_run_to() { # _run_to <segundos> -- <cmd...> — teto de tempo (macOS não tem `timeout` por padrão)
  local secs="$1"; shift
  [ "${1:-}" = "--" ] && shift
  perl -e "alarm $secs; exec @ARGV" -- "$@"
}

# ── fixture viva: template completo sob git, com data de commit DISTANTE do dia de hoje ────────
# A distância é o que torna [4] capaz de distinguir data de commit de relógio de parede: sem ela o
# cenário passaria por coincidência em qualquer implementação.
cp -R "$WS/template/.forge" "$T/.forge" 2>/dev/null || { echo "NÃO VERIFICADO: não foi possível montar a fixture a partir de $WS/template/.forge"; exit 3; }
git -C "$T" init -q
_run_to 20 -- git -C "$T" add -A
GIT_AUTHOR_DATE="2019-03-04T10:00:00 +0000" GIT_COMMITTER_DATE="2019-03-04T10:00:00 +0000" \
  _run_to 20 -- git -C "$T" -c user.email=t@t -c user.name=t commit -qm init >/dev/null
FIXTURE_DAY="$(git -C "$T" log -1 --format=%cI | cut -c1-10)"
TODAY="$(date +%Y-%m-%d)"
[ -n "$FIXTURE_DAY" ] || { echo "NÃO VERIFICADO: a fixture não produziu data de commit HEAD"; exit 3; }
[ "$FIXTURE_DAY" != "$TODAY" ] || { echo "NÃO VERIFICADO: a data de commit da fixture coincide com a de hoje ($TODAY) — [4] não conseguiria distinguir commit de relógio de parede"; exit 3; }

LG="$T/.forge/scripts/ledger-ops.sh"
LF="$T/.forge/ledger/ledger.json"
MD="$T/.forge/ledger/LEDGER.md"
SCHEMA="$WS/template/.forge/schemas/ledger.schema.json"

_lg() { _run_to 30 -- env FORGE_ROOT="$T" bash "$LG" "$@"; }
_field_of() { node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const e=(d.entries||[]).find(x=>x.id===process.argv[2]);process.stdout.write(e&&e[process.argv[3]]!=null?String(e[process.argv[3]]):"")' "$LF" "$1" "$2"; }
_detail_to() { node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const e=(d.entries||[]).find(x=>x.id===process.argv[2]);process.stdout.write(e?String(e.detail||""):"")' "$LF" "$1" > "$2"; }
_bytes_of_file() { wc -c < "$1" | tr -d ' '; }
# _contains <id> <agulha> — contém? rc 0 sim, 1 não. node, NUNCA grep (ugrep devolve vazio com rc 1
# sobre byte de controle, e vazio não prova ausência).
_contains() { node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const e=(d.entries||[]).find(x=>x.id===process.argv[2]);process.exit(e&&String(e.detail||"").indexOf(process.argv[3])!==-1?0:1)' "$LF" "$1" "$2"; }
# _index_in <id> <agulha> — posição da agulha no detail, -1 quando ausente (para a ORDEM de [5]).
_index_in() { node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const e=(d.entries||[]).find(x=>x.id===process.argv[2]);process.stdout.write(String(e?String(e.detail||"").indexOf(process.argv[3]):-1))' "$LF" "$1" "$2"; }
_starts_with_file() { # <arquivo grande> <arquivo prefixo>
  local n; n="$(_bytes_of_file "$2")"
  head -c "$n" "$1" | cmp -s - "$2"
}
_count_status() { node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log((d.entries||[]).filter(e=>e.status===process.argv[2]).length)' "$LF" "$1"; }

SEED_DETAIL="MEDIÇÃO ORIGINAL (2019-03-04): o defeito é X, medido em 42 sítios, e a razão pela qual o item existe está toda aqui."
_lg add --type known-bug --title "alvo principal do w211" --detail "$SEED_DETAIL" >/dev/null   # LDG-0001

# =================================================================================================
_scn "[0] controle do comparador de conteúdo — positivo plantado achado, negativo plantado não"
_contains LDG-0001 "medido em 42 sítios" || { echo "FAIL [0]: o comparador NÃO achou um positivo plantado — toda conclusão por ausência deste gate seria vazia"; exit 1; }
if _contains LDG-0001 "sequência que a fixture nunca escreveu — Ω-negativo-plantado"; then
  echo "FAIL [0]: o comparador achou um negativo plantado — ele não discrimina"; exit 1
fi
echo "OK [0] — comparador discrimina (positivo achado, negativo não)"

_scn "[1] o verbo 'note' existe: rc 0 e uma linha OK"
set +e
out1="$(_lg note LDG-0001 --kind progress --text "fatia A entregue" 2>&1)"; rc1=$?
set -e
[ "$rc1" -eq 0 ] || { echo "FAIL [1]: 'note' devolveu rc=$rc1 — got: $out1"; exit 1; }
case "$out1" in *OK*) : ;; *) echo "FAIL [1]: 'note' não imprimiu linha OK — got: $out1"; exit 1 ;; esac
echo "OK [1] — $out1"

_scn "[2] P1 — 'note' preserva: o detail anterior é prefixo do novo e o comprimento cresce"
_lg add --type tech-debt --title "alvo de P1" --detail "$SEED_DETAIL" >/dev/null   # LDG-0002
_detail_to LDG-0002 "$T/p1-antes.txt"
b2_antes="$(_bytes_of_file "$T/p1-antes.txt")"
_lg note LDG-0002 --kind progress --text "fatia A entregue; a fatia B continua aberta" >/dev/null
_detail_to LDG-0002 "$T/p1-depois.txt"
b2_depois="$(_bytes_of_file "$T/p1-depois.txt")"
_starts_with_file "$T/p1-depois.txt" "$T/p1-antes.txt" || { echo "FAIL [2]: o detail anterior NÃO é prefixo do novo — 'note' não preservou"; exit 1; }
[ "$b2_depois" -gt "$b2_antes" ] || { echo "FAIL [2]: o detail não cresceu ($b2_antes -> $b2_depois)"; exit 1; }
echo "OK [2] — detail preservado como prefixo, $b2_antes -> $b2_depois byte(s)"

_scn "[3] P2 — 'note' não fecha: status e resolved_at idênticos, sobre 'open' e sobre 'planned'"
_lg add --type roadmap --title "alvo planned de P2" --detail "conteúdo do planned" >/dev/null   # LDG-0003
_lg update LDG-0003 --status planned >/dev/null
p2_bad=0
for alvo in LDG-0002 LDG-0003; do
  st_antes="$(_field_of "$alvo" status)"; ra_antes="$(_field_of "$alvo" resolved_at)"
  _lg note "$alvo" --kind measurement --text "remedido nesta rodada: o número continua o mesmo" >/dev/null
  st_depois="$(_field_of "$alvo" status)"; ra_depois="$(_field_of "$alvo" resolved_at)"
  [ "$st_antes" = "$st_depois" ] || { echo "FAIL [3]: 'note' mudou o status de $alvo ('$st_antes' -> '$st_depois')"; p2_bad=1; }
  [ "$ra_antes" = "$ra_depois" ] || { echo "FAIL [3]: 'note' mexeu em resolved_at de $alvo ('$ra_antes' -> '$ra_depois')"; p2_bad=1; }
done
[ "$p2_bad" -eq 0 ] || exit 1
echo "OK [3] — status e resolved_at intactos em open e em planned"

_scn "[4] P3 — o marcador do kind e a DATA DO COMMIT HEAD (fixture carimbada em $FIXTURE_DAY, hoje é $TODAY)"
_lg add --type follow-up --title "alvo do marcador" --detail "conteúdo de partida" >/dev/null   # LDG-0004
_lg note LDG-0004 --kind progress --text "primeira fatia entregue" >/dev/null
_contains LDG-0004 "PROGRESSO ($FIXTURE_DAY): primeira fatia entregue" || { echo "FAIL [4]: marcador ausente ou com data errada — detail: $(_field_of LDG-0004 detail)"; exit 1; }
if _contains LDG-0004 "($TODAY)"; then
  echo "FAIL [4]: o marcador carrega a data de HOJE ($TODAY) — a fonte é relógio de parede, não o commit HEAD"; exit 1
fi
echo "OK [4] — marcador 'PROGRESSO ($FIXTURE_DAY): ' presente; a data de hoje não aparece"

_scn "[5] P6 — três 'note' de kinds diferentes deixam três marcadores, na ordem de emissão"
_lg add --type tech-debt --title "alvo da acumulação" --detail "medição de origem" >/dev/null   # LDG-0005
_lg note LDG-0005 --kind progress   --text "primeiro bloco da acumulação" >/dev/null
_lg note LDG-0005 --kind decision   --text "segundo bloco da acumulação" >/dev/null
_lg note LDG-0005 --kind correction --text "terceiro bloco da acumulação" >/dev/null
i5a="$(_index_in LDG-0005 "primeiro bloco da acumulação")"
i5b="$(_index_in LDG-0005 "segundo bloco da acumulação")"
i5c="$(_index_in LDG-0005 "terceiro bloco da acumulação")"
i5o="$(_index_in LDG-0005 "medição de origem")"
for par in "origem:$i5o" "primeiro:$i5a" "segundo:$i5b" "terceiro:$i5c"; do
  [ "${par#*:}" -ge 0 ] || { echo "FAIL [5]: o bloco '${par%%:*}' sumiu do detail acumulado"; exit 1; }
done
{ [ "$i5o" -lt "$i5a" ] && [ "$i5a" -lt "$i5b" ] && [ "$i5b" -lt "$i5c" ]; } || { echo "FAIL [5]: os blocos não estão na ordem de emissão (origem=$i5o, 1=$i5a, 2=$i5b, 3=$i5c)"; exit 1; }
echo "OK [5] — 3 marcadores acumulados sobre a medição de origem, nas posições $i5o < $i5a < $i5b < $i5c"

_scn "[6] '--kind' fora do enum reprova; contador pareado: os quatro valores legítimos gravam"
_lg add --type roadmap --title "alvo do enum" --detail "conteúdo do enum" >/dev/null   # LDG-0006
cp "$LF" "$T/snap6.json"
set +e
out6="$(_lg note LDG-0006 --kind lixo --text "não deveria gravar" 2>&1)"; rc6=$?
set -e
[ "$rc6" -ne 0 ] || { echo "FAIL [6]: '--kind lixo' devolveu rc=0 — got: $out6"; exit 1; }
cmp -s "$LF" "$T/snap6.json" || { echo "FAIL [6]: '--kind' inválido recusado mas o ledger.json mudou"; exit 1; }
KINDS="progress measurement correction decision"
for k in $KINDS; do
  case "$out6" in *"$k"*) : ;; *) echo "FAIL [6]: a recusa não nomeia o valor aceito '$k' — got: $out6"; exit 1 ;; esac
done
kind_n=0; kind_bad=0
for k in $KINDS; do
  kind_n=$((kind_n + 1))
  set +e
  outk="$(_lg note LDG-0006 --kind "$k" --text "texto legítimo do kind $k" 2>&1)"; rck=$?
  set -e
  if [ "$rck" -ne 0 ] || ! _contains LDG-0006 "texto legítimo do kind $k"; then
    echo "FAIL [6]: o kind legítimo '$k' não gravou — got rc=$rck: $outk"; kind_bad=$((kind_bad + 1))
  fi
done
[ "$kind_n" -gt 0 ] || { echo "FAIL [6]: universo de kinds vazio — o cenário não examinou nada"; exit 1; }
[ "$kind_bad" -eq 0 ] || { echo "FAIL [6]: $kind_bad de $kind_n kinds legítimos não gravaram — uma implementação que recusa tudo passaria sem este par"; exit 1; }
echo "OK [6] — enum fechado recusa 'lixo' nomeando os $kind_n valores, e os $kind_n gravam"

_scn "[7] 'note' sem --text, com --text \"\" e com --text --kind reprovam (disciplina da issue #103)"
cp "$LF" "$T/snap7.json"
n7=0; bad7=0
_try7() { # _try7 <rótulo> <agulha que a mensagem tem de nomear> -- <args...>
  local label="$1" agulha="$2"; shift 2; [ "${1:-}" = "--" ] && shift
  local o r
  n7=$((n7 + 1))
  set +e
  o="$(_lg "$@" 2>&1)"; r=$?
  set -e
  if [ "$r" -eq 0 ]; then echo "FAIL [7]: '$label' devolveu rc=0 — got: $o"; bad7=$((bad7 + 1)); return 0; fi
  case "$o" in *"$agulha"*) : ;; *) echo "FAIL [7]: '$label' reprovou sem nomear '$agulha' — got: $o"; bad7=$((bad7 + 1)); return 0 ;; esac
  cmp -s "$LF" "$T/snap7.json" || { echo "FAIL [7]: '$label' recusado mas alterou o ledger.json"; bad7=$((bad7 + 1)); }
}
_try7 "note sem --text"        "--text" -- note LDG-0006 --kind progress
_try7 "note --text vazio"      "--text" -- note LDG-0006 --kind progress --text ""
_try7 "note --text --kind"     "--kind" -- note LDG-0006 --kind progress --text --kind
_try7 "note sem --kind"        "--kind" -- note LDG-0006 --text "texto sem rótulo"
_try7 "note com flag desconhecida" "--bogus-flag" -- note LDG-0006 --kind progress --text "x" --bogus-flag "engolido"
[ "$n7" -gt 0 ] || { echo "FAIL [7]: universo de recusas vazio"; exit 1; }
[ "$bad7" -eq 0 ] || { echo "FAIL [7]: $bad7 de $n7 recusas não aconteceram"; exit 1; }
echo "OK [7] — $n7 recusas de uso, todas com rc≠0, nomeando a flag e sem tocar no ledger"

_scn "[8] P4 — 'update --detail' destrutivo RECUSA, sem gravar, nomeando 'note' e '--replace-detail'"
_lg add --type known-bug --title "alvo do update destrutivo" --detail "$SEED_DETAIL" >/dev/null   # LDG-0007
cp "$LF" "$T/snap8.json"
set +e
out8="$(_lg update LDG-0007 --detail "andei metade: fiz a fatia A." 2>&1)"; rc8=$?
set -e
[ "$rc8" -ne 0 ] || { echo "FAIL [8]: update destrutivo devolveu rc=0 — got: $out8"; exit 1; }
cmp -s "$LF" "$T/snap8.json" || { echo "FAIL [8]: update destrutivo recusado mas o ledger.json mudou"; exit 1; }
case "$out8" in *note*) : ;; *) echo "FAIL [8]: a recusa não aponta o verbo 'note' — got: $out8"; exit 1 ;; esac
case "$out8" in *--replace-detail*) : ;; *) echo "FAIL [8]: a recusa não aponta '--replace-detail' — got: $out8"; exit 1 ;; esac
# A recusa não pode ser por COMPRIMENTO. Uma implementação que trocasse `de.indexOf(prev) === -1`
# por `de.length < prev.length` satisfaria os três casos que este gate tinha — o texto curto acima,
# o texto que preserva e cresce de [9] e o texto idêntico de [12] — e ainda assim APAGARIA o campo
# sempre que o texto novo fosse maior, que é a forma exata de quatro das seis perdas de 2026-09,
# todas com o texto novo escrito por cima. O caso abaixo é o que discrimina preservação de
# não-encolhimento: texto novo ESTRITAMENTE MAIOR e que não preserva um único byte do corrente. O
# contrafactual pareado está em [20/M6].
D8_LONGO="andei metade: fiz a fatia A, e escrevi um texto suficientemente longo para ultrapassar o comprimento do anterior sem preservar um único byte dele, que é exatamente a forma como quatro das seis perdas aconteceram."
_detail_to LDG-0007 "$T/d8-corrente.txt"
b8_corrente="$(_bytes_of_file "$T/d8-corrente.txt")"
printf '%s' "$D8_LONGO" > "$T/d8-novo.txt"
b8_novo="$(_bytes_of_file "$T/d8-novo.txt")"
[ "$b8_corrente" -gt 0 ] || { echo "FAIL [8]: o alvo do caso discriminante tem detail vazio — não haveria perda a medir"; exit 1; }
[ "$b8_novo" -gt "$b8_corrente" ] || { echo "FAIL [8]: o caso discriminante não é maior que o corrente ($b8_novo <= $b8_corrente byte(s)) — ele mediria a mesma coisa que o texto curto e não separaria os dois critérios"; exit 1; }
cp "$LF" "$T/snap8b.json"
set +e
out8b="$(_lg update LDG-0007 --detail "$D8_LONGO" 2>&1)"; rc8b=$?
set -e
[ "$rc8b" -ne 0 ] || { echo "FAIL [8]: texto novo MAIOR e não preservador foi ACEITO (rc=0) — a guarda decide por comprimento, não por preservação, e apaga os $b8_corrente byte(s) de medição com OK na saída. got: $out8b"; exit 1; }
cmp -s "$LF" "$T/snap8b.json" || { echo "FAIL [8]: o texto maior e não preservador foi recusado mas o ledger.json mudou"; exit 1; }
echo "OK [8] — recusa com rc=$rc8, ledger intacto, os dois caminhos legítimos nomeados; e o caso discriminante (corrente $b8_corrente B, novo $b8_novo B, maior e não preservador) recusa com rc=$rc8b"

_scn "[9] os dois caminhos que continuam gravando: detail VAZIO e texto que PRESERVA o corrente"
_lg add --type feature-idea --title "alvo com detail vazio" >/dev/null 2>/dev/null   # LDG-0008
set +e
out9a="$(_lg update LDG-0008 --detail "primeiro conteúdo desta entrada" 2>&1)"; rc9a=$?
set -e
[ "$rc9a" -eq 0 ] || { echo "FAIL [9]: update sobre detail VAZIO reprovou — got rc=$rc9a: $out9a"; exit 1; }
[ "$(_field_of LDG-0008 detail)" = "primeiro conteúdo desta entrada" ] || { echo "FAIL [9]: update sobre detail vazio não gravou"; exit 1; }
set +e
out9b="$(_lg update LDG-0008 --detail "primeiro conteúdo desta entrada — e mais isto que veio depois" 2>&1)"; rc9b=$?
set -e
[ "$rc9b" -eq 0 ] || { echo "FAIL [9]: update com texto que PRESERVA o corrente reprovou — got rc=$rc9b: $out9b"; exit 1; }
[ "$(_field_of LDG-0008 detail)" = "primeiro conteúdo desta entrada — e mais isto que veio depois" ] || { echo "FAIL [9]: update preservador não gravou"; exit 1; }
echo "OK [9] — os dois caminhos de retrocompatibilidade continuam gravando"

_scn "[10] '--replace-detail' substitui e ANUNCIA o número de bytes descartados"
_detail_to LDG-0007 "$T/r10.txt"
b10="$(_bytes_of_file "$T/r10.txt")"
[ "$b10" -gt 0 ] || { echo "FAIL [10]: a fixture de [10] tem detail vazio — o cenário mediria zero perda"; exit 1; }
set +e
out10="$(_lg update LDG-0007 --detail "texto novo que descarta tudo" --replace-detail 2>&1)"; rc10=$?
set -e
[ "$rc10" -eq 0 ] || { echo "FAIL [10]: '--replace-detail' reprovou — got rc=$rc10: $out10"; exit 1; }
[ "$(_field_of LDG-0007 detail)" = "texto novo que descarta tudo" ] || { echo "FAIL [10]: '--replace-detail' não substituiu o campo"; exit 1; }
case "$out10" in *"$b10"*) : ;; *) echo "FAIL [10]: o aviso não informa os $b10 byte(s) descartados — um aviso que dissesse '0 bytes' treina o operador a ignorá-lo. got: $out10" ; exit 1 ;; esac
echo "OK [10] — substituiu e anunciou $b10 byte(s) descartados"

_scn "[11] '--replace-detail' sem '--detail' reprova nomeando a flag"
cp "$LF" "$T/snap11.json"
set +e
out11="$(_lg update LDG-0007 --replace-detail 2>&1)"; rc11=$?
set -e
[ "$rc11" -ne 0 ] || { echo "FAIL [11]: '--replace-detail' sem '--detail' devolveu rc=0 — got: $out11"; exit 1; }
case "$out11" in *--replace-detail*) : ;; *) echo "FAIL [11]: a recusa não nomeia '--replace-detail' — got: $out11"; exit 1 ;; esac
cmp -s "$LF" "$T/snap11.json" || { echo "FAIL [11]: recusada mas o ledger.json mudou"; exit 1; }
echo "OK [11] — $out11"

_scn "[12] texto idêntico ao corrente continua NOCHANGE — a guarda entra DEPOIS da detecção de no-op"
cur12="$(_field_of LDG-0007 detail)"
cp "$LF" "$T/snap12.json"
set +e
out12="$(_lg update LDG-0007 --detail "$cur12" 2>&1)"; rc12=$?
set -e
[ "$rc12" -ne 0 ] || { echo "FAIL [12]: update com o texto idêntico devolveu rc=0 — got: $out12"; exit 1; }
case "$out12" in *"não alterou nenhum campo"*) : ;; *) echo "FAIL [12]: a recusa não foi a de no-op (NOCHANGE) — a guarda de preservação está sendo aplicada ANTES da detecção de no-op. got: $out12"; exit 1 ;; esac
cmp -s "$LF" "$T/snap12.json" || { echo "FAIL [12]: o no-op alterou o ledger.json"; exit 1; }
echo "OK [12] — NOCHANGE preservado; a ordem das duas guardas é a declarada"

_scn "[13] 'note' em id inexistente reprova; 'note' em item 'resolved' grava, avisa e não fecha de novo"
cp "$LF" "$T/snap13.json"
set +e
out13a="$(_lg note LDG-9999 --kind progress --text "sobre item que não existe" 2>&1)"; rc13a=$?
set -e
[ "$rc13a" -ne 0 ] || { echo "FAIL [13]: 'note' sobre id inexistente devolveu rc=0 — got: $out13a"; exit 1; }
cmp -s "$LF" "$T/snap13.json" || { echo "FAIL [13]: 'note' sobre id inexistente alterou o ledger.json"; exit 1; }
_lg add --type known-bug --title "alvo terminal" --detail "conteúdo do item terminal" >/dev/null   # LDG-0009
_lg resolve LDG-0009 --note "fechado na bancada" >/dev/null
st13="$(_field_of LDG-0009 status)"; ra13="$(_field_of LDG-0009 resolved_at)"
set +e
out13b="$(_lg note LDG-0009 --kind measurement --text "voltou a reproduzir na versão seguinte" 2>&1)"; rc13b=$?
set -e
[ "$rc13b" -eq 0 ] || { echo "FAIL [13]: 'note' sobre item resolved reprovou — anotar não é refechar. got rc=$rc13b: $out13b"; exit 1; }
case "$out13b" in *WARN*) : ;; *) echo "FAIL [13]: 'note' sobre item terminal não avisou — got: $out13b"; exit 1 ;; esac
_contains LDG-0009 "voltou a reproduzir na versão seguinte" || { echo "FAIL [13]: 'note' sobre item resolved não gravou o texto"; exit 1; }
[ "$(_field_of LDG-0009 status)" = "$st13" ] || { echo "FAIL [13]: 'note' mudou o status de um item terminal"; exit 1; }
[ "$(_field_of LDG-0009 resolved_at)" = "$ra13" ] || { echo "FAIL [13]: 'note' mexeu em resolved_at de um item terminal"; exit 1; }
# Terceira aresta de 'note': repetir o MESMO '--text' AVISA em stderr e acrescenta assim mesmo — a
# decisão C8. Sem esta asserção o aviso podia ser removido, ou nascer quebrado num consumidor, sem
# gate nenhum notar, e 'note' responderia OK sobre um bloco que acabou de duplicar no registro
# durável, com um rc que o chamador não distingue do de uma nota nova. O PAR é o que discrimina:
# nota nova NÃO avisa, nota repetida avisa — um aviso que aparecesse sempre seria ruído e passaria
# por esta asserção sozinho. O contrafactual pareado está em [20/M7]. O alvo é LDG-0003, que está
# em 'planned': item terminal emitiria também o aviso de status e confundiria as duas leituras.
DUP_TXT="fatia A entregue e remedida em 42 sítios"
set +e
out13c="$(_lg note LDG-0003 --kind progress --text "$DUP_TXT" 2>&1)"; rc13c=$?
set -e
[ "$rc13c" -eq 0 ] || { echo "FAIL [13]: a PRIMEIRA emissão da nota reprovou — got rc=$rc13c: $out13c"; exit 1; }
case "$out13c" in *"já aparece no detail"*) echo "FAIL [13]: a PRIMEIRA emissão já avisou de duplicata — o aviso não discrimina, e um aviso que aparece sempre treina o operador a ignorá-lo. got: $out13c"; exit 1 ;; esac
_detail_to LDG-0003 "$T/dup-antes.txt"; b13a="$(_bytes_of_file "$T/dup-antes.txt")"
set +e
out13d="$(_lg note LDG-0003 --kind progress --text "$DUP_TXT" 2>&1)"; rc13d=$?
set -e
[ "$rc13d" -eq 0 ] || { echo "FAIL [13]: a nota REPETIDA reprovou (rc=$rc13d) — 'note' é acumulativo por desenho: a repetição avisa, não recusa. got: $out13d"; exit 1; }
case "$out13d" in *"já aparece no detail"*) : ;; *) echo "FAIL [13]: a nota REPETIDA não avisou — o único sinal de duplicação no registro durável desapareceu, e o rc 0 é indistinguível do de uma nota nova. got: $out13d"; exit 1 ;; esac
_detail_to LDG-0003 "$T/dup-depois.txt"; b13b="$(_bytes_of_file "$T/dup-depois.txt")"
[ "$b13b" -gt "$b13a" ] || { echo "FAIL [13]: o aviso virou recusa — a nota repetida não foi acrescentada ($b13a -> $b13b byte(s)), e o comportamento entregue em C8 mudou sem ninguém dizer"; exit 1; }
occ13="$(node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const e=(d.entries||[]).find(x=>x.id===process.argv[2]);const s=String((e&&e.detail)||"");let n=0,i=0;for(;;){const k=s.indexOf(process.argv[3],i);if(k===-1)break;n+=1;i=k+1}console.log(n)' "$LF" LDG-0003 "$DUP_TXT")"
[ "$occ13" -eq 2 ] || { echo "FAIL [13]: o texto repetido aparece $occ13 vez(es) no detail, esperado 2 — a contagem é o que prova que o aviso descreve duplicação real, e não uma condição qualquer"; exit 1; }
echo "OK [13] — id inexistente reprova; item terminal aceita nota com aviso e sem mudar status; nota repetida avisa e acrescenta ($b13a -> $b13b byte(s), $occ13 ocorrências), nota nova não avisa"

_scn "[14] P5 — o denominador de 'open' é invariante à bateria (derivado da fixture, nunca literal)"
open_antes="$(_count_status open)"
[ "$open_antes" -gt 0 ] || { echo "FAIL [14]: a fixture não tem nenhuma entrada 'open' — o cenário mediria um denominador vazio"; exit 1; }
n14=0
for alvo in LDG-0001 LDG-0002 LDG-0004 LDG-0005 LDG-0006; do
  n14=$((n14 + 1))
  _lg note "$alvo" --kind progress --text "bateria de P5 sobre $alvo" >/dev/null
done
[ "$n14" -gt 0 ] || { echo "FAIL [14]: bateria vazia — nada foi exercitado"; exit 1; }
open_depois="$(_count_status open)"
[ "$open_antes" -eq "$open_depois" ] || { echo "FAIL [14]: a contagem de 'open' mudou ($open_antes -> $open_depois) — alguma porta desta onda reclassificou item"; exit 1; }
echo "OK [14] — $n14 'note' aplicados; 'open' invariante em $open_antes entrada(s)"

_scn "[15] propriedade sobre entrada gerada (comprimento, acentuação, quebras, aspas, nomes de flag, marcador colidente)"
_lg add --type tech-debt --title "alvo da propriedade" --detail "semente da propriedade" >/dev/null   # LDG-0010
GEN_TEXTS=(
  "curto"
  "acentuação com ç, ã, é, ô e ü — e um travessão"
  "linha um
linha dois
linha três"
  "texto com \"aspas duplas\" e 'aspas simples' no meio"
  "sequência que parece flag: --detail --status --replace-detail no meio da prosa"
  "PROGRESSO ($FIXTURE_DAY): marcador colidente escrito pelo próprio usuário"
  "um texto deliberadamente longo, com muitas cláusulas separadas por vírgula, para que o campo cresça bem além do que os exemplos escolhidos a dedo cobrem, e para que qualquer truncamento silencioso apareça na comparação de prefixo que este cenário faz a cada passo"
)
gen_n=0; gen_bad=0
GEN_SEEN=()
for txt in "${GEN_TEXTS[@]}"; do
  gen_n=$((gen_n + 1))
  _detail_to LDG-0010 "$T/gen-antes.txt"
  set +e
  outg="$(_lg note LDG-0010 --kind measurement --text "$txt" 2>&1)"; rcg=$?
  set -e
  if [ "$rcg" -ne 0 ]; then echo "FAIL [15]: caso $gen_n reprovou — got: $outg"; gen_bad=$((gen_bad + 1)); continue; fi
  _detail_to LDG-0010 "$T/gen-depois.txt"
  if ! _starts_with_file "$T/gen-depois.txt" "$T/gen-antes.txt"; then
    echo "FAIL [15]: caso $gen_n quebrou P1 — o detail anterior deixou de ser prefixo"; gen_bad=$((gen_bad + 1)); continue
  fi
  GEN_SEEN[$gen_n]="$txt"
  j=1
  while [ "$j" -le "$gen_n" ]; do
    if ! _contains LDG-0010 "${GEN_SEEN[$j]}"; then
      echo "FAIL [15]: caso $gen_n quebrou P6 — o texto do caso $j sumiu do acumulado"; gen_bad=$((gen_bad + 1))
    fi
    j=$((j + 1))
  done
done
[ "$gen_n" -gt 0 ] || { echo "FAIL [15]: zero casos gerados — o cenário não examinou nada"; exit 1; }
[ "$gen_bad" -eq 0 ] || { echo "FAIL [15]: $gen_bad violação(ões) em $gen_n casos gerados"; exit 1; }
echo "OK [15] — $gen_n textos gerados, P1 e P6 válidas em todos"

_scn "[16] contrato — a fixture continua conforme ao ledger.schema.json, com negativo plantado"
_ajv() { # _ajv <ledger.json> — imprime "N <reprovando>"; rc 0 quando compilou e validou
  ( cd "$WS" && _run_to 30 -- node -e '
    const fs = require("fs");
    const Ajv2020 = require("ajv/dist/2020").default || require("ajv/dist/2020");
    const data = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const schema = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
    const ajv = new Ajv2020({ strict: false, allErrors: true });
    const validate = ajv.compile(schema.properties.entries.items);
    const entries = Array.isArray(data.entries) ? data.entries : [];
    let bad = 0;
    for (const e of entries) if (!validate(e)) bad += 1;
    console.log(entries.length + " " + bad);
  ' "$1" "$SCHEMA" )
}
set +e
res16="$(_ajv "$LF" 2>&1)"; rc16=$?
set -e
[ "$rc16" -eq 0 ] || { echo "NÃO VERIFICADO [16]: o validador não rodou (ajv indisponível?) — got: $res16"; exit 3; }
n16="${res16%% *}"; bad16="${res16##* }"
[ "$n16" -gt 0 ] || { echo "FAIL [16]: universo vazio — a fixture não tem entrada nenhuma para validar"; exit 1; }
[ "$bad16" -eq 0 ] || { echo "FAIL [16]: $bad16 de $n16 entradas da fixture reprovam contra o schema — a onda mudou o contrato"; exit 1; }
node -e '
  const fs = require("fs");
  const d = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
  d.entries[0].campo_que_o_schema_nao_conhece = "negativo plantado";
  fs.writeFileSync(process.argv[2], JSON.stringify(d, null, 2));
' "$LF" "$T/plantado16.json"
set +e
res16b="$(_ajv "$T/plantado16.json" 2>&1)"; rc16b=$?
set -e
[ "$rc16b" -eq 0 ] || { echo "NÃO VERIFICADO [16]: o validador não rodou sobre o negativo plantado — got: $res16b"; exit 3; }
bad16b="${res16b##* }"
[ "$bad16b" -gt 0 ] || { echo "FAIL [16]: o validador APROVOU um negativo plantado (campo fora do schema) — o verde de [16] não vale nada"; exit 1; }
echo "OK [16] — $n16 entradas conformes; negativo plantado reprovado ($bad16b entrada(s))"

_scn "[17] integração ponta a ponta: add, note, note, list --status open, resolve, render"
out17add="$(_lg add --type roadmap --title "ciclo completo" --detail "MEDIÇÃO ORIGINAL: o item nasce com a razão de existir." 2>&1)"
id17="$(node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log(d.entries[d.entries.length-1].id)' "$LF")"
_lg note "$id17" --kind progress --text "primeira metade paga" >/dev/null
[ "$(_field_of "$id17" status)" = "open" ] || { echo "FAIL [17]: o item saiu de 'open' depois do primeiro note"; exit 1; }
lista17="$(_lg list --status open 2>&1)"
case "$lista17" in *"$id17"*) : ;; *) echo "FAIL [17]: 'list --status open' deixou de listar $id17 depois do note"; exit 1 ;; esac
_lg note "$id17" --kind progress --text "segunda metade paga" >/dev/null
# O markdown é conferido AQUI, com o item ainda ativo: `renderSection` só imprime o corpo das
# entradas ativas e reduz as encerradas a um contador, de modo que uma asserção sobre o texto das
# notas depois do `resolve` mediria a regra do renderizador, não a chegada da nota.
md17_bad=0
for agulha in "primeira metade paga" "segunda metade paga"; do
  node -e 'process.exit(require("fs").readFileSync(process.argv[1],"utf8").indexOf(process.argv[2])!==-1?0:1)' "$MD" "$agulha" \
    || { echo "FAIL [17]: '$agulha' não chegou ao LEDGER.md enquanto o item estava ativo"; md17_bad=1; }
done
[ "$md17_bad" -eq 0 ] || exit 1
_lg resolve "$id17" --note "dívida quitada" >/dev/null
_lg render >/dev/null
i17a="$(_index_in "$id17" "MEDIÇÃO ORIGINAL")"
i17b="$(_index_in "$id17" "primeira metade paga")"
i17c="$(_index_in "$id17" "segunda metade paga")"
i17d="$(_index_in "$id17" "Resolvido: dívida quitada")"
{ [ "$i17a" -ge 0 ] && [ "$i17a" -lt "$i17b" ] && [ "$i17b" -lt "$i17c" ] && [ "$i17c" -lt "$i17d" ]; } \
  || { echo "FAIL [17]: o detail final não carrega, NA ORDEM, medição, as duas notas e o fecho (got $i17a,$i17b,$i17c,$i17d)"; exit 1; }
[ "$(_field_of "$id17" status)" = "resolved" ] || { echo "FAIL [17]: o status não mudou no resolve"; exit 1; }
node -e 'process.exit(require("fs").readFileSync(process.argv[1],"utf8").indexOf(process.argv[2])!==-1?0:1)' "$MD" "Encerrados:" \
  || { echo "FAIL [17]: depois do resolve o LEDGER.md não contabiliza nenhuma entrada encerrada — o render não acompanhou o fecho"; exit 1; }
echo "OK [17] — ciclo completo: medição, duas notas e fecho, na ordem no ledger.json; as duas notas no LEDGER.md com o item ativo; o fecho contabilizado depois"

_scn "[18] 'note' RE-RENDERIZA o LEDGER.md sem 'render' explícito (paridade ledger.json ↔ LEDGER.md)"
_lg add --type follow-up --title "alvo da paridade" --detail "conteúdo de partida da paridade" >/dev/null   # LDG-00NN
id18="$(node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log(d.entries[d.entries.length-1].id)' "$LF")"
_lg render >/dev/null
cp "$MD" "$T/md18-antes.md"
_lg note "$id18" --kind decision --text "decisão registrada sem render explícito depois" >/dev/null
cmp -s "$MD" "$T/md18-antes.md" && { echo "FAIL [18]: o LEDGER.md não mudou depois do 'note' — a porta nova não chama _render, e o markdown fica defasado em toda árvore no próximo forge update"; exit 1; }
node -e 'process.exit(require("fs").readFileSync(process.argv[1],"utf8").indexOf(process.argv[2])!==-1?0:1)' "$MD" "decisão registrada sem render explícito depois" \
  || { echo "FAIL [18]: o texto da nota não chegou ao LEDGER.md sem render explícito"; exit 1; }
echo "OK [18] — 'note' re-renderiza como as outras portas de escrita"

_scn "[19] 'note' ANUNCIA divergência de raiz quando invocado de dentro de um worktree"
WT="$T/wt"
if ! _run_to 30 -- git -C "$T" worktree add -q -b w211-branch "$WT" >/dev/null 2>&1; then
  echo "NÃO VERIFICADO [19]: não foi possível criar o worktree da fixture — a divergência de raiz não pôde ser exercitada"; exit 3
fi
# As três invocações abaixo rodam o script do TRONCO com o `cwd` DENTRO do worktree. A resolução
# de raiz e o aviso dependem do `cwd` (`git -C "$(pwd)"`), não de onde o arquivo mora, então a
# divergência exercitada é a mesma — e a prova de mutação [20/M5] passa a ter UM sítio para mutar,
# em vez de dois arquivos que precisariam ser mutados em sincronia para a mutação valer.
_warn_lines() { node -e 'const s=process.argv[1];let n=0;for(const l of s.split("\n"))if(l.indexOf("escrevendo no ledger do TRONCO")!==-1)n+=1;console.log(n)' "$1"; }
set +e
out19ctl="$( (cd "$WT" && _run_to 30 -- bash "$LG" add --type follow-up --title "controle do 19" --detail "conteúdo") 2>&1 )"
out19="$(   (cd "$WT" && _run_to 30 -- bash "$LG" note LDG-0001 --kind progress --text "nota emitida de dentro do worktree") 2>&1 )"
out19list="$( (cd "$WT" && _run_to 30 -- bash "$LG" list --status open) 2>&1 )"
set -e
[ "$(_warn_lines "$out19ctl")" -ge 1 ] || { echo "FAIL [19]: CONTROLE — nem 'add', que avisa desde LDG-0068, avisou nesta fixture: a bancada não exercita divergência nenhuma e a asserção sobre 'note' não provaria nada. got: $out19ctl"; exit 1; }
[ "$(_warn_lines "$out19")" -ge 1 ] || { echo "FAIL [19]: 'note' gravou no ledger do TRONCO sem anunciar — porta de escrita nova fora da lista de forge_warn_root_divergence (LDG-0068/LDG-0174). got: $out19"; exit 1; }
[ "$(_warn_lines "$out19list")" -eq 0 ] || { echo "FAIL [19]: 'list', porta de LEITURA, passou a avisar — o aviso virou ruído. got: $out19list"; exit 1; }
echo "OK [19] — 'note' anuncia a divergência; 'list' segue silencioso; 'add' é o controle positivo"

# =================================================================================================
_scn "[20] prova de mutação — sete mutações, cada uma com controle, contrafactual, restauração por cmp e recontrole"
cp "$LG" "$T/ledger-ops.orig"

# Alvos DEDICADOS de M6 e M7, criados aqui de propósito. As sondas de M1 escrevem em LDG-0002
# quando a guarda está desligada, e uma sonda cujo texto vira o conteúdo corrente passa a ser
# recusada por NOCHANGE — o recontrole ficaria verde sem exercitar a guarda que ele mede. Cada
# sonda daqui em diante carrega uma etiqueta no texto para que nenhuma repetição seja no-op.
_lg add --type tech-debt --title "alvo da discriminação de P4" --detail "MEDIÇÃO ORIGINAL DO ALVO DE M6 (2019-03-04): a razão pela qual este item existe está escrita aqui, e são estes bytes que a guarda de preservação existe para não deixar sumir." >/dev/null
ID_M6="$(node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log(d.entries[d.entries.length-1].id)' "$LF")"
_lg add --type tech-debt --title "alvo do aviso de nota duplicada" --detail "conteúdo de partida do alvo de M7" >/dev/null
ID_M7="$(node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log(d.entries[d.entries.length-1].id)' "$LF")"
M6_LONGO="texto integralmente distinto do corrente e deliberadamente mais comprido do que ele, escrito para que nenhum byte do original sobreviva e para que a diferença de comprimento fique do lado que uma guarda por tamanho aprovaria sem hesitar"
_detail_to "$ID_M6" "$T/m6-corrente.txt"
printf '%s' "$M6_LONGO ctl6" > "$T/m6-longo.txt"
b_m6_cur="$(_bytes_of_file "$T/m6-corrente.txt")"
b_m6_lon="$(_bytes_of_file "$T/m6-longo.txt")"
[ "$b_m6_lon" -gt "$b_m6_cur" ] || { echo "FAIL [20]: a sonda longa de M6 ($b_m6_lon B) não é maior que o detail corrente do alvo ($b_m6_cur B) — a mutação por comprimento não seria discriminada e M6 provaria a mesma coisa que M1"; exit 1; }

# Sondas de uma linha, cada uma amarrada a UMA propriedade.
_p4_recusa() { # [8] em uma linha: update destrutivo tem de reprovar E não gravar
  set +e; local o r; o="$(_lg update LDG-0002 --detail "texto curto que descarta tudo" 2>&1)"; r=$?; set -e
  [ "$r" -ne 0 ]
}
_p9_grava() { # [9] em uma linha: texto que preserva continua gravando
  set +e; local cur o r; cur="$(_field_of LDG-0004 detail)"; o="$(_lg update LDG-0004 --detail "$cur · sufixo preservador $1" 2>&1)"; r=$?; set -e
  [ "$r" -eq 0 ]
}
_p12_nochange() { # [12] em uma linha: texto idêntico continua NOCHANGE
  set +e; local cur o r; cur="$(_field_of LDG-0004 detail)"; o="$(_lg update LDG-0004 --detail "$cur" 2>&1)"; r=$?; set -e
  [ "$r" -ne 0 ]
}
_p1_preserva() { # [2] em uma linha
  _detail_to LDG-0005 "$T/m-antes.txt"
  _lg note LDG-0005 --kind progress --text "sonda de preservação $1" >/dev/null 2>&1 || return 1
  _detail_to LDG-0005 "$T/m-depois.txt"
  _starts_with_file "$T/m-depois.txt" "$T/m-antes.txt"
}
_p3_data_commit() { # [4] em uma linha
  # O marcador é procurado COLADO ao texto desta sonda: LDG-0006 já acumulou marcadores de
  # cenários anteriores, e procurar só pelo prefixo acharia um bloco VELHO — a mutação passaria
  # despercebida, que é a forma de prova de mutação que não prova nada.
  _lg note LDG-0006 --kind progress --text "sonda de data $1" >/dev/null 2>&1 || return 1
  _contains LDG-0006 "PROGRESSO ($FIXTURE_DAY): sonda de data $1"
}
_p18_render() { # [18] em uma linha
  cp "$MD" "$T/m-md-antes.md"
  _lg note LDG-0010 --kind progress --text "sonda de render $1" >/dev/null 2>&1 || return 1
  ! cmp -s "$MD" "$T/m-md-antes.md"
}
_p19_avisa() { # [19] em uma linha
  local o
  set +e; o="$( (cd "$WT" && _run_to 30 -- bash "$LG" note LDG-0001 --kind progress --text "sonda de divergência $1") 2>&1 )"; set -e
  [ "$(_warn_lines "$o")" -ge 1 ]
}
_p4_curto_recusa() { # texto MAIS CURTO e não preservador — recusado pelos DOIS critérios possíveis
  set +e; local o r; o="$(_lg update "$ID_M6" --detail "curto $1" 2>&1)"; r=$?; set -e
  [ "$r" -ne 0 ]
}
_p4_longo_recusa() { # texto MAIS LONGO e não preservador — SÓ a preservação o recusa
  set +e; local o r; o="$(_lg update "$ID_M6" --detail "$M6_LONGO $1" 2>&1)"; r=$?; set -e
  [ "$r" -ne 0 ]
}
_p_dup_avisa() { # [13] em uma linha: a SEGUNDA emissão do mesmo texto avisa, a primeira não
  local o1 o2
  set +e
  o1="$(_lg note "$ID_M7" --kind progress --text "sonda de duplicata $1" 2>&1)"
  o2="$(_lg note "$ID_M7" --kind progress --text "sonda de duplicata $1" 2>&1)"
  set -e
  case "$o1" in *"já aparece no detail"*) return 1 ;; esac
  case "$o2" in *"já aparece no detail"*) return 0 ;; *) return 1 ;; esac
}
_p19_add_avisa() { # controle pareado de M5: 'add' TEM de continuar avisando com a mutação aplicada
  local o
  set +e; o="$( (cd "$WT" && _run_to 30 -- bash "$LG" add --type follow-up --title "sonda add $1" --detail "x") 2>&1 )"; set -e
  [ "$(_warn_lines "$o")" -ge 1 ]
}

_restaura() { cp "$T/ledger-ops.orig" "$LG"; cmp -s "$LG" "$T/ledger-ops.orig" || { echo "FAIL [20]: restauração de ledger-ops.sh não bateu byte a byte"; exit 1; }; }
_mutou() { cmp -s "$LG" "$T/ledger-ops.orig" && { echo "FAIL [20$1]: o perl NÃO alterou ledger-ops.sh — o ponto de mutação mudou e a mutação não muta nada"; exit 1; }; return 0; }

mut_n=0

# ── M1: a guarda de preservação do `update` ────────────────────────────────────────────────────
mut_n=$((mut_n + 1))
_p4_recusa || { echo "FAIL [20/M1]: pré-condição — [8] não reprova antes da mutação"; exit 1; }
perl -0pi -e "s/if \(destroi && repl !== '1'\) \{/if (false) {/" "$LG"
_mutou "/M1"
if _p4_recusa; then echo "FAIL [20/M1]: desligar a guarda de preservação NÃO fez [8] parar de recusar — a guarda não é o que decide"; exit 1; fi
_p9_grava m1   || { echo "FAIL [20/M1]: a mutação derrubou [9], que é de OUTRO caminho — ela atingiu mais do que a guarda"; exit 1; }
_p12_nochange  || { echo "FAIL [20/M1]: a mutação derrubou [12] — ela atingiu a detecção de no-op, não a guarda"; exit 1; }
_restaura
_p4_recusa || { echo "FAIL [20/M1]: recontrole — [8] não voltou a recusar depois da restauração"; exit 1; }

# ── M2: o append do `note`, trocado por atribuição direta ──────────────────────────────────────
mut_n=$((mut_n + 1))
_p1_preserva ctl2 || { echo "FAIL [20/M2]: pré-condição — [2] não preserva antes da mutação"; exit 1; }
perl -0pi -e 's/e\.detail = prev \? prev \+ SEP \+ bloco : bloco;/e.detail = bloco;/' "$LG"
_mutou "/M2"
if _p1_preserva m2; then echo "FAIL [20/M2]: trocar o append por atribuição direta NÃO quebrou a preservação — [2] não observa o que diz observar"; exit 1; fi
_restaura
_p1_preserva rec2 || { echo "FAIL [20/M2]: recontrole — [2] não voltou a preservar"; exit 1; }

# ── M3: a fonte da data do `note`, trocada para o relógio de parede ────────────────────────────
mut_n=$((mut_n + 1))
_p3_data_commit ctl3 || { echo "FAIL [20/M3]: pré-condição — [4] não vê a data de commit antes da mutação"; exit 1; }
perl -0pi -e 's/const day = String\(now\)\.slice\(0, 10\);/const day = new Date().toISOString().slice(0, 10);/' "$LG"
_mutou "/M3"
if _p3_data_commit m3; then echo "FAIL [20/M3]: trocar a fonte da data para wall clock NÃO mudou o marcador — [4] passaria com qualquer fonte"; exit 1; fi
_restaura
_p3_data_commit rec3 || { echo "FAIL [20/M3]: recontrole — [4] não voltou a ver a data de commit"; exit 1; }

# ── M4: o `_render` do `note` ──────────────────────────────────────────────────────────────────
mut_n=$((mut_n + 1))
_p18_render ctl4 || { echo "FAIL [20/M4]: pré-condição — [18] não vê o LEDGER.md mudar antes da mutação"; exit 1; }
perl -0pi -e 's/  _render\n  echo "OK note/  echo "OK note/' "$LG"
_mutou "/M4"
if _p18_render m4; then echo "FAIL [20/M4]: remover o _render do 'note' NÃO deixou o LEDGER.md defasado — [18] não observa a paridade"; exit 1; fi
_restaura
_p18_render rec4 || { echo "FAIL [20/M4]: recontrole — [18] não voltou a ver o LEDGER.md mudar"; exit 1; }

# ── M5: a entrada do `note` na lista de portas que anunciam divergência de raiz ────────────────
mut_n=$((mut_n + 1))
_p19_avisa ctl5 || { echo "FAIL [20/M5]: pré-condição — [19] não vê o aviso antes da mutação"; exit 1; }
perl -0pi -e 's/add\|update\|note\|resolve\|promote\|harvest\|render\)/add|update|resolve|promote|harvest|render)/' "$LG"
_mutou "/M5"
if _p19_avisa m5; then echo "FAIL [20/M5]: tirar 'note' da lista de portas NÃO silenciou o aviso — [19] não observa a lista"; exit 1; fi
_p19_add_avisa m5 || { echo "FAIL [20/M5]: a mutação silenciou TAMBÉM o 'add' — ela atingiu o lib inteiro, não a entrada do 'note' na lista"; exit 1; }
_restaura
_p19_avisa rec5 || { echo "FAIL [20/M5]: recontrole — [19] não voltou a ver o aviso"; exit 1; }

# ── M6: o CRITÉRIO da guarda de preservação, trocado por comprimento ───────────────────────────
# M1 DESLIGA a guarda; esta troca o critério dela. É a diferença entre provar que a guarda decide
# alguma coisa e provar que ela decide a coisa DECLARADA. Com `de.length < prev.length` no lugar de
# `de.indexOf(prev) === -1`, o gate inteiro continuava verde — [8] com texto curto, [9] com texto
# que preserva e cresce, [12] com o texto idêntico, e M1 desligando a guarda inteira em vez de
# trocar o critério — enquanto um `update --detail` com texto totalmente diferente e maior apagava
# o campo com rc 0 e OK na saída. Medido: com a troca aplicada, o gate passava com 21 cenários e
# 122 bytes de medição sumiam sem uma linha de aviso.
mut_n=$((mut_n + 1))
_p4_longo_recusa ctl6 || { echo "FAIL [20/M6]: pré-condição — o texto MAIOR e não preservador não é recusado antes da mutação"; exit 1; }
_p4_curto_recusa ctl6 || { echo "FAIL [20/M6]: pré-condição — o texto MENOR e não preservador não é recusado antes da mutação"; exit 1; }
perl -0pi -e 's/de\.indexOf\(prev\) === -1/de.length < prev.length/' "$LG"
_mutou "/M6"
if _p4_longo_recusa m6; then echo "FAIL [20/M6]: trocar preservação por comprimento NÃO fez o texto maior e não preservador ser aceito — nenhum cenário deste gate discrimina a propriedade P4, e uma guarda por tamanho passaria pelo gate inteiro apagando detail"; exit 1; fi
_p4_curto_recusa m6 || { echo "FAIL [20/M6]: a mutação derrubou TAMBÉM a recusa do texto menor — ela desligou a guarda em vez de trocar o critério, e M6 vira uma repetição de M1"; exit 1; }
_restaura
_p4_longo_recusa rec6 || { echo "FAIL [20/M6]: recontrole — o texto maior e não preservador não voltou a ser recusado"; exit 1; }
_p4_curto_recusa rec6 || { echo "FAIL [20/M6]: recontrole — o texto menor e não preservador não voltou a ser recusado"; exit 1; }

# ── M7: o aviso de nota duplicada ──────────────────────────────────────────────────────────────
# O aviso é comportamento entregue em C8 e era o único sinal de que `note` acabou de duplicar um
# bloco no registro durável — `note` responde OK e o rc não distingue a duplicata da nota nova.
# Sem esta mutação, removê-lo deixaria o gate verde.
mut_n=$((mut_n + 1))
_p_dup_avisa ctl7 || { echo "FAIL [20/M7]: pré-condição — o aviso de nota duplicada não aparece antes da mutação"; exit 1; }
perl -0pi -e 's/if \(prev && prev\.indexOf\(text\) !== -1\) \{/if (false) {/' "$LG"
_mutou "/M7"
if _p_dup_avisa m7; then echo "FAIL [20/M7]: remover o ramo do aviso NÃO silenciou o aviso de duplicata — [13] não observa o que diz observar"; exit 1; fi
_p1_preserva m7 || { echo "FAIL [20/M7]: a mutação derrubou o append do 'note' — ela atingiu mais do que o aviso, e o contrafactual não isola o comportamento medido"; exit 1; }
_restaura
_p_dup_avisa rec7 || { echo "FAIL [20/M7]: recontrole — o aviso de duplicata não voltou depois da restauração"; exit 1; }

[ "$mut_n" -gt 0 ] || { echo "FAIL [20]: nenhuma mutação executada"; exit 1; }
echo "OK [20] — $mut_n mutações produziram o contrafactual declarado; restauração por cmp e recontrole em todas"

# =================================================================================================
[ "$SCN_RUN" -eq "$SCN_DECLARED" ] || { echo "FAIL: o cabeçalho declara $SCN_DECLARED cenários e o gate executou $SCN_RUN — a divergência é o achado"; exit 1; }

REAL_SHA_AFTER="$(_sha "$REAL_LEDGER")"
[ "$REAL_SHA_BEFORE" = "$REAL_SHA_AFTER" ] || { echo "FAIL sentinela: o .forge/ledger/ledger.json REAL mudou durante o gate ($REAL_SHA_BEFORE -> $REAL_SHA_AFTER)"; exit 1; }
REPO_SNAPSHOT_AFTER="$(git -C "$WS" status --porcelain)"
[ "$REPO_SNAPSHOT_BEFORE" = "$REPO_SNAPSHOT_AFTER" ] || {
  echo "FAIL sentinela: a árvore do repositório real mudou durante o gate (o gate só pode escrever em \$T)"
  diff <(echo "$REPO_SNAPSHOT_BEFORE") <(echo "$REPO_SNAPSHOT_AFTER") >&2 || true
  exit 1
}

echo "PASS w211-ledger-detail-acumulativo — $SCN_RUN cenários declarados e executados; ledger real intacto ($REAL_SHA_AFTER)"
