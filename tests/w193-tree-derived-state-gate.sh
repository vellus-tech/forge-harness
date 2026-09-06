#!/usr/bin/env bash
# Gate W193 — estado derivado da PRÓPRIA árvore numa operação de visão global (LDG-0067, LDG-0068).
#
# Uma decisão tomada a partir do que ESTA árvore de trabalho por acaso contém, quando a resposta
# correta depende do que outras árvores, branches ou clones contêm. Duas instâncias, mesma causa e
# mesma fixture — duas árvores que discordam:
#
#   LDG-0067: quem escolhe o próximo ordinal `wNNN` olha `ls tests/*-gate.sh` da própria árvore.
#             Duas branches paralelas escolhem o mesmo número e um dos dois arquivos perde a
#             identidade no merge — aconteceu duas vezes na rodada de 2026-09-04. NÃO é a mesma
#             decisão do id de ledger: o ledger tem UM arquivo físico que vive no tronco e
#             serializa por construção (`--git-common-dir`); ordinais são N arquivos que vivem POR
#             BRANCH, sem autoridade compartilhada onde escrever. Não há para onde transferir a
#             decisão — a saída é derivar do tronco REMOTO e detectar a colisão quando ela ainda
#             assim ocorrer.
#   LDG-0068: `ledger-ops.sh` resolve ROOT por `--git-common-dir`, então uma invocação feita de
#             dentro de uma worktree grava no ledger do TRONCO, que pode estar noutra branch — e
#             nada avisa. O comportamento NÃO muda (é norma escrita em
#             rules/conventions/machinery-propagation.md, e mudá-lo faria toda branch que toca o
#             ledger colidir no merge por construção). Muda a VISIBILIDADE.
#
#   [1]  dois arquivos com o mesmo ordinal: o detector reprova nomeando o ordinal
#   [2]  árvore sem colisão passa, com contador de quantos ordinais examinou
#   [3]  o próprio tests/ do harness passa (sem constante fixa de contagem: ela envelhece no
#        commit seguinte ao próprio)
#   [4]  o helper de próximo ordinal, com um remoto que já tem w200, devolve w201 mesmo que a
#        árvore local não tenha w200
#   [5]  sem remoto acessível, o helper devolve um número E DIZ que o derivou só da árvore local
#   [6]  ledger-ops add de dentro de uma worktree, sem FORGE_ROOT, escreve no tronco E O ANUNCIA
#        com o caminho absoluto
#   [7]  ledger-ops add com FORGE_ROOT na worktree NÃO emite o aviso — o aviso é sobre
#        divergência, não sobre worktree (pareado com sinal positivo: a entrada nasce no ledger
#        da worktree, e é isso que se confere)
#   [8]  ledger-ops list (porta de LEITURA) não emite aviso nenhum
#   [9]  propriedade: para as CINCO portas de escrita, ROOT != repositório do invocador implica
#        aviso; ROOT == repositório do invocador implica ausência de aviso
#   [10] mutação: remover o aviso do lib faz [6] e [9] reprovarem nas cinco portas DE UMA VEZ —
#        prova que há UM sítio, não quatro
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORD="$WS/template/.forge/scripts/gate-ordinal.sh"
T="$(mktemp -d /tmp/forge-w193.XXXXXX)"
T="$(cd "$T" && pwd -P)"
trap 'rm -rf "$T"' EXIT

_run_to() { local s="$1"; shift; [ "${1:-}" = "--" ] && shift; perl -e "alarm $s; exec @ARGV" -- "$@"; }

[ -f "$ORD" ] || { echo "FAIL [0]: $ORD não existe — o helper de ordinal de gate não foi entregue"; exit 1; }

mkgates() { # mkgates <dir> <nome...>
  local d="$1"; shift
  mkdir -p "$d"
  local g
  for g in "$@"; do printf '#!/usr/bin/env bash\necho %s\n' "$g" > "$d/$g.sh"; done
}

echo "[1] dois arquivos com o mesmo ordinal: o detector reprova nomeando o ordinal"
mkgates "$T/c1" w198-alfa-gate w199-beta-gate w200-a-gate w200-b-gate
out1="$(bash "$ORD" check --path "$T/c1" 2>&1)"; rc1=$?
[ "$rc1" -ne 0 ] || { echo "FAIL [1]: colisão de ordinal não reprovou — saída: $out1"; exit 1; }
grep -q "w200" <<<"$out1" || { echo "FAIL [1]: a reprovação não nomeia o ordinal colidido — saída: $out1"; exit 1; }
grep -q "w200-a-gate" <<<"$out1" && grep -q "w200-b-gate" <<<"$out1" \
  || { echo "FAIL [1]: a reprovação não nomeia os DOIS arquivos em colisão — saída: $out1"; exit 1; }
echo "OK [1] — $(head -1 <<<"$out1")"

echo "[2] árvore sem colisão passa, com contador de quantos ordinais examinou"
mkgates "$T/c2" w198-alfa-gate w199-beta-gate w200-gama-gate
out2="$(bash "$ORD" check --path "$T/c2" 2>&1)"; rc2=$?
[ "$rc2" -eq 0 ] || { echo "FAIL [2]: árvore sem colisão reprovou — saída: $out2"; exit 1; }
grep -qE "3 ordinal|3 gate" <<<"$out2" \
  || { echo "FAIL [2]: passou sem declarar quantos ordinais examinou — 'não examinei' e 'examinei e estava limpo' colapsam. Saída: $out2"; exit 1; }
# Contrapositiva do contador: universo vazio REPROVA, nunca aprova em silêncio.
mkdir -p "$T/c2-vazio"
out2b="$(bash "$ORD" check --path "$T/c2-vazio" 2>&1)"; rc2b=$?
[ "$rc2b" -ne 0 ] || { echo "FAIL [2]: universo vazio aprovou — saída: $out2b"; exit 1; }
grep -qi "universo-vazio\|0 ordinal" <<<"$out2b" || { echo "FAIL [2]: universo vazio reprovou sem nomear o estado — saída: $out2b"; exit 1; }
echo "OK [2] — $out2"

echo "[3] o próprio tests/ do harness passa (contagem medida, nunca constante fixa)"
out3="$(bash "$ORD" check --path "$WS/tests" 2>&1)"; rc3=$?
[ "$rc3" -eq 0 ] || { echo "FAIL [3]: o tests/ do harness tem colisão de ordinal — saída: $out3"; exit 1; }
n3="$(sed -n 's/.*OK gate-ordinal — \([0-9][0-9]*\) .*/\1/p' <<<"$out3" | head -1)"
[ -n "$n3" ] && [ "$n3" -gt 50 ] \
  || { echo "FAIL [3]: contagem implausível ou ausente ('$n3') — o glob não casou o corpus real. Saída: $out3"; exit 1; }
echo "OK [3] — $out3"

# ── helper de próximo ordinal: deriva do TRONCO REMOTO ────────────────────────────────────────
echo "[4] com um remoto que já tem w200, o helper devolve w201 mesmo com a árvore local sem w200"
UP="$T/up"; mkdir -p "$UP"
git init -q "$UP" -b develop; git -C "$UP" config user.email t@t; git -C "$UP" config user.name t
mkgates "$UP/tests" w198-alfa-gate w199-beta-gate w200-remoto-gate
git -C "$UP" add -A >/dev/null; git -C "$UP" commit -q --no-verify -m "tronco com w200"
CL="$T/clone"
git clone -q "$UP" "$CL" 2>/dev/null
git -C "$CL" config user.email t@t; git -C "$CL" config user.name t
rm -f "$CL/tests/w200-remoto-gate.sh"          # a árvore LOCAL não tem w200
git -C "$CL" add -A >/dev/null; git -C "$CL" commit -q --no-verify -m "branch sem w200"
out4="$(cd "$CL" && _run_to 30 -- bash "$ORD" next --path "$CL/tests" 2>&1)"; rc4=$?
[ "$rc4" -eq 0 ] || { echo "FAIL [4]: 'next' reprovou — saída: $out4"; exit 1; }
grep -q "w201" <<<"$out4" \
  || { echo "FAIL [4]: o helper devolveu o próximo ordinal a partir da ÁRVORE LOCAL, ignorando o tronco remoto que já tem w200 — é exatamente o defeito. Saída: $out4"; exit 1; }
grep -qi "remoto\|origin" <<<"$out4" || { echo "FAIL [4]: o helper não disse de onde derivou — saída: $out4"; exit 1; }
echo "OK [4] — $out4"

echo "[5] sem remoto acessível, o helper devolve um número E DIZ que derivou só da árvore local"
SR="$T/semremoto"
git init -q "$SR" -b develop; git -C "$SR" config user.email t@t; git -C "$SR" config user.name t
mkgates "$SR/tests" w198-alfa-gate w199-beta-gate
git -C "$SR" add -A >/dev/null; git -C "$SR" commit -q --no-verify -m init
out5="$(cd "$SR" && _run_to 30 -- bash "$ORD" next --path "$SR/tests" 2>&1)"; rc5=$?
[ "$rc5" -eq 0 ] || { echo "FAIL [5]: 'next' sem remoto reprovou em vez de degradar — saída: $out5"; exit 1; }
grep -q "w200" <<<"$out5" || { echo "FAIL [5]: não devolveu o próximo ordinal — saída: $out5"; exit 1; }
grep -qi "só da árvore local\|apenas da árvore local\|sem remoto" <<<"$out5" \
  || { echo "FAIL [5]: degradou em SILÊNCIO — quem lê não distingue 'derivei do tronco' de 'derivei do que eu tinha à mão'. Saída: $out5"; exit 1; }
echo "OK [5] — $out5"

# ── LDG-0068: ledger-ops anuncia quando escreve num ROOT diferente do invocador ───────────────
MAIN="$T/main"; mkdir -p "$MAIN"; MAIN="$(cd "$MAIN" && pwd -P)"
cp -R "$WS/template/.forge" "$MAIN/.forge"
git init -q "$MAIN" -b main; git -C "$MAIN" config user.email t@t; git -C "$MAIN" config user.name t
git -C "$MAIN" add -A >/dev/null
_run_to 60 -- git -C "$MAIN" commit -q --no-verify -m init
WT="$MAIN/.forge/worktrees/wt1"
_run_to 60 -- git -C "$MAIN" worktree add -q -b feature/x "$WT" >/dev/null 2>&1 \
  || { echo "FAIL [6]: não consegui criar a worktree da fixture"; exit 1; }
LG="$WT/.forge/scripts/ledger-ops.sh"
[ -f "$LG" ] || { echo "FAIL [6]: worktree sem ledger-ops.sh — fixture inválida"; exit 1; }

# O aviso é procurado por LINHA, nunca comparando a saída inteira: `add` sem --detail já emite o
# seu próprio WARN (issue #103), e casar a saída toda acoplaria este gate àquele.
_root_warn() { grep -c "ledger-ops: escrevendo no ledger do TRONCO" <<<"$1"; }

echo "[6] add de dentro da worktree, sem FORGE_ROOT, escreve no tronco E O ANUNCIA"
out6="$( (cd "$WT" && _run_to 60 -- bash "$LG" add --type known-bug --title "item-w193" --detail "conteúdo") 2>&1 )"
grep -q "item-w193" "$MAIN/.forge/ledger/ledger.json" 2>/dev/null \
  || { echo "FAIL [6]: o item não nasceu no ledger do TRONCO — a fixture não reproduz o cenário. Saída: $out6"; exit 1; }
[ "$(_root_warn "$out6")" -ge 1 ] \
  || { echo "FAIL [6]: escreveu no ledger do TRONCO em SILÊNCIO — quem opera de dentro de uma worktree não sabe onde o registro caiu. Saída: $out6"; exit 1; }
grep -q "$MAIN" <<<"$out6" || { echo "FAIL [6]: o aviso não traz o caminho ABSOLUTO do ROOT resolvido — saída: $out6"; exit 1; }
echo "OK [6] — $(grep 'TRONCO' <<<"$out6" | head -1)"

echo "[7] add com FORGE_ROOT na worktree NÃO emite o aviso (e a entrada nasce ali)"
out7="$( (cd "$WT" && _run_to 60 -- env FORGE_ROOT="$WT" bash "$LG" add --type known-bug --title "item-wt" --detail "conteúdo") 2>&1 )"
# Sinal POSITIVO pareado: sem ele, "não avisou" seria satisfeito por um harness sem aviso algum.
grep -q "item-wt" "$WT/.forge/ledger/ledger.json" 2>/dev/null \
  || { echo "FAIL [7]: com FORGE_ROOT na worktree a entrada não nasceu ali — saída: $out7"; exit 1; }
[ "$(_root_warn "$out7")" -eq 0 ] \
  || { echo "FAIL [7]: avisou divergência onde ROOT == repositório do invocador — o aviso é sobre DIVERGÊNCIA, não sobre worktree. Saída: $out7"; exit 1; }
echo "OK [7] — entrada em $WT, sem aviso"

echo "[8] list (porta de LEITURA) não emite aviso nenhum"
out8="$( (cd "$WT" && _run_to 60 -- bash "$LG" list --status open) 2>&1 )"
grep -q "item-w193" <<<"$out8" \
  || { echo "FAIL [8]: 'list' de dentro da worktree não leu o ledger do tronco — a fixture não exercita a porta. Saída: $out8"; exit 1; }
[ "$(_root_warn "$out8")" -eq 0 ] \
  || { echo "FAIL [8]: porta de LEITURA emitiu o aviso de escrita. Saída: $out8"; exit 1; }
echo "OK [8] — leitura silenciosa, e leu o ledger do tronco"

echo "[9] propriedade — para as CINCO portas de escrita: ROOT != invocador implica aviso"
_prop() { # _prop -> imprime "porta rc_div rc_igual" por linha; 0 quando a propriedade vale
  local bad=0 n=0 out id
  id="$(node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log(d.entries[d.entries.length-1].id)' "$MAIN/.forge/ledger/ledger.json")"
  local porta
  for porta in add update resolve promote harvest; do
    n=$((n + 1))
    case "$porta" in
      add)     args=(add --type follow-up --title "prop-$RANDOM" --detail "x") ;;
      update)  args=(update "$id" --detail "prop $RANDOM") ;;
      resolve) args=(resolve "$id" --note "prop $RANDOM") ;;
      promote) args=(promote "$id" --to "ch-prop-$RANDOM") ;;
      harvest) args=(harvest ch-inexistente --origin close) ;;
    esac
    out="$( (cd "$WT" && _run_to 60 -- bash "$LG" "${args[@]}") 2>&1 )"
    if [ "$(_root_warn "$out")" -lt 1 ]; then
      echo "  porta '$porta' NÃO avisou com ROOT divergente"
      bad=$((bad + 1))
    fi
    out="$( (cd "$WT" && _run_to 60 -- env FORGE_ROOT="$WT" bash "$LG" "${args[@]}") 2>&1 )"
    if [ "$(_root_warn "$out")" -ne 0 ]; then
      echo "  porta '$porta' avisou com ROOT == invocador"
      bad=$((bad + 1))
    fi
  done
  [ "$n" -eq 5 ] || { echo "  matriz com $n portas, esperado 5"; bad=$((bad + 1)); }
  return "$bad"
}
prop_out="$(_prop)"; prop_rc=$?
[ "$prop_rc" -eq 0 ] || { echo "FAIL [9]: $prop_rc violação(ões) da propriedade:"; echo "$prop_out"; exit 1; }
echo "OK [9] — 5 portas de escrita, propriedade válida nas duas direções"

echo "[10] mutação — remover o aviso do LIB reprova [6] e [9] nas cinco portas de uma vez"
LIBROOT="$WT/.forge/scripts/lib/forge-root.sh"
[ -f "$LIBROOT" ] || { echo "FAIL [10]: o aviso não vive num lib único ($LIBROOT ausente) — escrevê-lo quatro vezes reinstala LDG-0014 no change que existe para combatê-la"; exit 1; }
cp "$LIBROOT" "$T/forge-root.orig"
perl -0pi -e 's/escrevendo no ledger do TRONCO/AVISO NEUTRALIZADO PELA MUTACAO/' "$LIBROOT"
cmp -s "$LIBROOT" "$T/forge-root.orig" && { echo "FAIL [10]: a mutação não alterou o lib — o ponto de mutação mudou"; exit 1; }
mut_out="$( (cd "$WT" && _run_to 60 -- bash "$LG" add --type follow-up --title "mut-$RANDOM" --detail "x") 2>&1 )"
[ "$(_root_warn "$mut_out")" -eq 0 ] || { echo "FAIL [10]: a mutação no lib não silenciou o aviso — há mais de um sítio"; exit 1; }
if _prop >/dev/null 2>&1; then
  echo "FAIL [10]: com o lib mutado, a propriedade [9] continuou valendo — o aviso não sai do lib"
  exit 1
fi
cp "$T/forge-root.orig" "$LIBROOT"
cmp -s "$LIBROOT" "$T/forge-root.orig" || { echo "FAIL [10]: restauração não bateu byte a byte (cmp)"; exit 1; }
prop_out="$(_prop)"; prop_rc=$?
[ "$prop_rc" -eq 0 ] || { echo "FAIL [10]: recontrole — a propriedade não voltou a valer:"; echo "$prop_out"; exit 1; }
echo "OK [10] — um sítio só; mutou, silenciou as cinco portas, restaurou (cmp ok), voltou"

echo "PASS w193-tree-derived-state"
