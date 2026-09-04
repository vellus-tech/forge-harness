#!/usr/bin/env bash
# Gate W156 — o placar do plano não pode reportar progresso sobre um universo que não mediu.
#
# `tools/plan-progress.mjs` nasceu para substituir checklist marcada à mão pelo estado real do
# repositório. A revisão adversarial do plano quebrou-o em três formas, todas com `rc=0` e sem uma
# linha de erro, e todas medidas antes deste gate existir:
#
#   · ledger ausente ou vazio imprime "INTEGRIDADE DO LEDGER ok" — e essa linha É o DoD da Onda 0.
#     Apagar o ledger satisfaz o DoD. Verdade vacuosa dentro do instrumento escrito para aplicar a
#     lição da issue #49 ("não executei" e "executei e estava limpo" no mesmo exit 0).
#   · trocar o travessão do cabeçalho `## Onda N —` por um traço visualmente idêntico faz a onda
#     inteira desaparecer do relatório; o total caiu de 45 para 40 sem ruído. A guarda de vacuidade
#     original só via onda que CASOU o regex e ficou sem item — onda que não casa nunca existe.
#   · o script só duvidava do que já estava no documento, nunca do documento. Duas issues abertas
#     (#83, #84) ficaram fora do plano e o placar teria impresso 45/45 com elas abertas.
#
# A correção é reconciliação BIDIRECIONAL: todo item do plano tem de existir, e todo item aberto do
# repositório tem de estar em exatamente uma onda. Este gate prova as duas direções por mutação.
#
#   [0] guarda de vacuidade: a fixture tem plano, ondas e ledger de verdade
#   [1] caminho feliz: placar roda, conta os itens do plano e sai 0
#   [2] ledger ausente/vazio é NÃO MEDIDO, nunca "ok" — com contador de controle na saída
#   [3] ledger sintaticamente inválido reprova com mensagem, não com stack trace
#   [4] onda cujo cabeçalho deixa de casar reprova (en dash, título reescrito, seção removida)
#   [5] item aberto no repositório e ausente do plano reprova (a direção que faltava)
#   [6] item do plano que não existe no universo reprova
#   [7] `--wave` inexistente reprova em vez de devolver 0/0 silencioso
#   [8] reclassificado (wont-fix/promoted) não é contado como entregue
#   [9] falha de rede não vira item concluído (recontrole do que já estava certo)
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$WS/tools/plan-progress.mjs"
T="$(mktemp -d /tmp/forge-w156.XXXXXX)"
trap 'rm -rf "$T"' EXIT

fail() { echo "FAIL $*"; exit 1; }
[ -f "$SCRIPT" ] || fail "[0]: $SCRIPT ausente"

# ── fixture: plano mínimo com duas ondas + ledger próprio ───────────────────────────────────
# Universo fechado e declarado, para que a reconciliação seja testável sem depender da rede nem
# do estado real do GitHub. `--universe` é o insumo que o script compara com o plano.
mk() {
  local d="$1"; mkdir -p "$d/docs/plans" "$d/.forge/ledger"
  cat > "$d/docs/plans/plano.md" <<'EOF'
# Plano de teste

## Onda 0 — Instrumento

| Item | O que fazer |
|---|---|
| **LDG-9001** | corrigir o instrumento |

**DoD:** o instrumento mede.

## Onda 1 — Trabalho

| Item | O que fazer |
|---|---|
| **LDG-9002** | corrigir o defeito |
| **LDG-9003** | corrigir o outro |

Menção em prosa a um PR #9999 e ao LDG-9001 não deve virar item.

**DoD:** o defeito morre.
EOF
  cat > "$d/.forge/ledger/ledger.json" <<'EOF'
{"entries":[
 {"id":"LDG-9001","status":"open","priority":"P1","title":"instrumento"},
 {"id":"LDG-9002","status":"open","priority":"P2","title":"defeito"},
 {"id":"LDG-9003","status":null,"priority":"P3","title":"outro"},
 {"id":"LDG-9004","status":"resolved","resolved_at":"2026-09-01","title":"fechado"}
]}
EOF
}
mk "$T/fx"
P="$T/fx/docs/plans/plano.md"
L="$T/fx/.forge/ledger/ledger.json"
run() { node "$SCRIPT" --plan "$P" --ledger "$L" --no-network "$@" 2>&1; }

# ── [0] vacuidade ───────────────────────────────────────────────────────────────────────────
[ -s "$P" ] && [ -s "$L" ] || fail "[0]: fixture vazia"
grep -q '## Onda 1 —' "$P" || fail "[0]: fixture sem onda"
echo "OK [0] fixture"

# ── [1] caminho feliz ───────────────────────────────────────────────────────────────────────
out="$(run)"; rc=$?
[ "$rc" -eq 0 ] || fail "[1]: caminho feliz saiu rc=$rc — $(head -3 <<<"$out")"
grep -q 'LDG-9001' <<<"$out" || fail "[1]: item do plano ausente do relatório"
grep -q 'LDG-9003' <<<"$out" || fail "[1]: item com status nulo ausente do relatório"
grep -q '9999' <<<"$out" && fail "[1]: menção em prosa (#9999) virou item rastreado"
echo "OK [1] caminho feliz"

# ── [2] ledger ausente ou vazio é NÃO MEDIDO ────────────────────────────────────────────────
# O defeito medido: imprimia "INTEGRIDADE DO LEDGER ok" sobre zero entradas examinadas.
cp "$L" "$T/ledger.bak"
printf '{"entries":[]}\n' > "$L"
out="$(run)"; rc=$?
grep -qi 'INTEGRIDADE DO LEDGER  *ok' <<<"$out" && fail "[2]: ledger VAZIO reportou integridade ok (verdade vacuosa)"
[ "$rc" -ne 0 ] || fail "[2]: ledger vazio saiu rc=0"
grep -qiE 'não medid|examinad' <<<"$out" || fail "[2]: sem contador de controle nem marca de não medido"
rm -f "$L"
out="$(run)"; rc=$?
grep -qi 'INTEGRIDADE DO LEDGER  *ok' <<<"$out" && fail "[2]: ledger AUSENTE reportou integridade ok"
[ "$rc" -ne 0 ] || fail "[2]: ledger ausente saiu rc=0"
cp "$T/ledger.bak" "$L"
run >/dev/null 2>&1 || fail "[2]: recontrole — restaurado o ledger, o caminho feliz devia voltar"
echo "OK [2] ledger não medido"

# ── [3] ledger inválido reprova com mensagem ────────────────────────────────────────────────
printf '{"entries": [ isto não é json\n' > "$L"
out="$(run)"; rc=$?
[ "$rc" -eq 2 ] || fail "[3]: ledger inválido saiu rc=$rc (esperado 2)"
grep -q '^FAIL' <<<"$out" || fail "[3]: ledger inválido não emitiu FAIL legível"
grep -qi 'at Object\.\|at Module\.\|node:internal' <<<"$out" && fail "[3]: vazou stack trace do Node"
cp "$T/ledger.bak" "$L"
echo "OK [3] ledger inválido"

# ── [4] onda que deixa de casar o cabeçalho reprova ─────────────────────────────────────────
# Três mutações realistas. En dash e em dash são indistinguíveis em markdown renderizado.
cp "$P" "$T/plano.bak"

# [4a] en dash é TOLERADO, não fatal: em dash e en dash são indistinguíveis em markdown renderizado,
# e um cabeçalho que muda de traço não deve apagar cinco itens do denominador. O regex aceita os
# três traços — este cenário é a regressão contra a fragilidade original.
sed 's/## Onda 1 —/## Onda 1 –/' "$T/plano.bak" > "$P"
out="$(run)"; rc=$?
[ "$rc" -eq 0 ] || fail "[4a]: en dash no cabeçalho quebrou o placar (rc=$rc)"
grep -q 'LDG-9002' <<<"$out" || fail "[4a]: en dash apagou a onda do relatório"
cp "$T/plano.bak" "$P"

# [4b] título que deixa de ser onda: os itens somem do plano e a reconciliação os acusa órfãos.
sed 's/## Onda 1 — Trabalho/## Fase 1 — Trabalho/' "$T/plano.bak" > "$P"
out="$(run)"; rc=$?
[ "$rc" -ne 0 ] || fail "[4b]: onda descaracterizada sumiu do placar e o script saiu rc=0"
grep -qE 'LDG-900[23]' <<<"$out" || fail "[4b]: os itens órfãos não foram nomeados"
cp "$T/plano.bak" "$P"
# seção inteira removida
awk '/^## Onda 1 —/{skip=1} /^## Onda 0 —/{skip=0} !skip' "$T/plano.bak" > "$P"
out="$(run)"; rc=$?
[ "$rc" -ne 0 ] || fail "[4/removida]: onda removida saiu rc=0"
cp "$T/plano.bak" "$P"
run >/dev/null 2>&1 || fail "[4]: recontrole — plano restaurado devia voltar a passar"
echo "OK [4] onda ausente"

# ── [5] item aberto no universo e ausente do plano reprova ──────────────────────────────────
# A direção que faltava: o script só duvidava do que estava no documento. Duas issues abertas
# ficaram fora do plano e o placar teria impresso 45/45 com elas abertas.
cat > "$T/universe.json" <<'EOF'
{"issues": [], "ledger": ["LDG-9001","LDG-9002","LDG-9003","LDG-9005"]}
EOF
out="$(node "$SCRIPT" --plan "$P" --ledger "$L" --no-network --universe "$T/universe.json" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || fail "[5]: item aberto fora do plano (LDG-9005) passou com rc=0"
grep -q 'LDG-9005' <<<"$out" || fail "[5]: o item não rastreado não foi nomeado na saída"
# recontrole: com o universo casando o plano, volta a passar
cat > "$T/universe-ok.json" <<'EOF'
{"issues": [], "ledger": ["LDG-9001","LDG-9002","LDG-9003"]}
EOF
node "$SCRIPT" --plan "$P" --ledger "$L" --no-network --universe "$T/universe-ok.json" >/dev/null 2>&1 \
  || fail "[5]: recontrole — universo idêntico ao plano devia passar"
echo "OK [5] reconciliação inversa"

# ── [6] item do plano que não existe em lugar nenhum reprova ────────────────────────────────
# Cuidado com o que se assere aqui: item do plano fora do universo de ABERTOS é o caso normal de
# item concluído, e reprovar isso quebraria o placar no primeiro item entregue. O que precisa
# reprovar é o identificador FANTASMA — rastreado no plano e inexistente no ledger e no
# repositório, tipicamente um erro de digitação que some do denominador sem ninguém notar.
sed 's/| \*\*LDG-9003\*\* | corrigir o outro |/| **LDG-9003** | corrigir o outro |\n| **LDG-9998** | item que nunca existiu |/' \
  "$T/plano.bak" > "$P"
grep -q 'LDG-9998' "$P" || fail "[6]: a mutação não aplicou — a fixture mudou de formato?"
out="$(run)"; rc=$?
[ "$rc" -ne 0 ] || fail "[6]: identificador fantasma (LDG-9998) passou com rc=0"
grep -q 'LDG-9998' <<<"$out" || fail "[6]: o fantasma não foi nomeado na saída"
cp "$T/plano.bak" "$P"
run >/dev/null 2>&1 || fail "[6]: recontrole — plano restaurado devia voltar a passar"
echo "OK [6] identificador fantasma"

# ── [7] --wave inexistente reprova ──────────────────────────────────────────────────────────
out="$(run --wave 99)"; rc=$?
[ "$rc" -ne 0 ] || fail "[7]: --wave 99 devolveu relatório vazio com rc=0 (lê-se como onda sem pendência)"
grep -q '^FAIL' <<<"$out" || fail "[7]: --wave inexistente não emitiu FAIL"
run --wave 1 >/dev/null 2>&1 || fail "[7]: recontrole — --wave 1 existe e devia passar"
echo "OK [7] wave inexistente"

# ── [8] reclassificado não conta como entregue ──────────────────────────────────────────────
# wont-fix e promoted encerram o item, mas fechá-los é edição de JSON, não trabalho entregue.
python3 - "$L" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p))
for e in d["entries"]:
    if e["id"]=="LDG-9002": e["status"]="wont-fix"
json.dump(d, open(p,"w"))
PY
out="$(run)"
grep -qiE 'reclassificad' <<<"$out" || fail "[8]: wont-fix não é distinguido de entrega no placar"
# Não basta a palavra aparecer: o item reclassificado não pode entrar no numerador de ENTREGUES.
grep -qE 'TOTAL +0/3 entregues' <<<"$out" \
  || fail "[8]: item reclassificado entrou no numerador de entregues ($(grep -m1 '^TOTAL' <<<"$out"))"
grep -qE '~ +LDG-9002' <<<"$out" || fail "[8]: o item reclassificado não recebeu marca própria"
cp "$T/ledger.bak" "$L"
out="$(run)"
grep -qiE 'reclassificad' <<<"$out" && fail "[8]: recontrole — ledger restaurado ainda reporta reclassificado"
echo "OK [8] reclassificado × entregue"

# ── [9] falha de rede não vira item concluído (recontrole) ──────────────────────────────────
cat > "$P" <<'EOF'
# Plano

## Onda 0 — Issues

| Item |
|---|
| **#71** |

**DoD:** fecha.
EOF
out="$(node "$SCRIPT" --plan "$P" --ledger "$L" --no-network --universe "$T/universe-ok.json" 2>&1 || true)"
grep -qE '✓ +#71' <<<"$out" && fail "[9]: issue não medida apareceu como concluída"
grep -qiE 'não medid' <<<"$out" || fail "[9]: issue sem medição não foi marcada como não medida"
echo "OK [9] sem rede não conclui"

# ── [10] universo fornecido não imprime o ✓ afirmativo ──────────────────────────────────────
# `--universe` é a costura sobre a qual toda a reconciliação se apoia, e era o ÚNICO caminho que
# desligava a checagem ASSERINDO que ela passou: com `{"issues":[],"ledger":[]}` o script imprimia
# "todo item aberto está em exatamente uma onda" sobre um repositório com 49 itens no plano.
cp "$T/plano.bak" "$P"
printf '{"issues":[],"ledger":[]}\n' > "$T/vazio.json"
out="$(node "$SCRIPT" --plan "$P" --ledger "$L" --no-network --universe "$T/vazio.json" 2>&1)"
grep -qE '✓ +todo item aberto' <<<"$out" \
  && fail "[10]: universo vazio fornecido imprimiu o ✓ afirmativo — falso verde na costura de teste"
grep -qiE 'fornecid|declarad' <<<"$out" || fail "[10]: a saída não diz que o universo foi fornecido, não derivado"
# Recontrole pelo terceiro estado: universo DERIVADO mas parcial (sem medir issues) também não
# afirma — diz que não mediu. A afirmação plena exige os dois lados medidos, o que não é
# exercitável offline; o cenário [11] cobre esse caminho pelo código de saída.
out="$(run)"
grep -qE '✓ +todo item aberto' <<<"$out" && fail "[10]: recontrole — universo derivado PARCIAL afirmou sem medir issues"
grep -qiE 'não medid' <<<"$out" || fail "[10]: universo parcial não declarou o que deixou de medir"
echo "OK [10] só afirma o que mediu"

# ── [11] o canal real: sem --universe, com o rc asserido ────────────────────────────────────
# Os cenários acima passam por --universe e --no-network, que são exatamente as duas costuras que
# carregavam os defeitos [10] e [12]. Este roda o caminho que o plano documenta — universo
# derivado — e assere o CÓDIGO DE SAÍDA, não só a string. É `testing/gate-delivery-channel.md`:
# a prova exercita o canal de entrega, não o seam de teste.
node "$SCRIPT" --plan "$P" --ledger "$L" --no-network >/dev/null 2>&1
[ $? -eq 0 ] || fail "[11]: caminho documentado (universo derivado) não sai 0 com tudo reconciliado"
# mutação no canal real: item órfão no ledger reprova SEM --universe
python3 - "$L" <<'PY2'
import json,sys
p=sys.argv[1]; d=json.load(open(p))
d["entries"].append({"id":"LDG-9007","status":"open","priority":"P3","title":"orfao no canal real"})
json.dump(d, open(p,"w"))
PY2
out="$(node "$SCRIPT" --plan "$P" --ledger "$L" --no-network 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || fail "[11]: órfão no universo DERIVADO passou com rc=0 (a reconciliação só valia via --universe)"
grep -q 'LDG-9007' <<<"$out" || fail "[11]: o órfão do canal real não foi nomeado"
cp "$T/ledger.bak" "$L"
node "$SCRIPT" --plan "$P" --ledger "$L" --no-network >/dev/null 2>&1 || fail "[11]: recontrole falhou"
echo "OK [11] canal real"

# ── [12] falha de medição de issues não sai 0 ───────────────────────────────────────────────
# O lado do ledger já reprovava; o das issues saía rc=0 com "universo não medido". Quem lê o
# código de saída — hook, CI, portão de release — recebia sucesso de uma execução que não
# reconciliou metade do universo. `--no-network` continua sendo rc=0: ali a cegueira é declarada.
cat > "$T/plano-issue.md" <<'EOF'
# Plano

## Onda 0 — Issues

| Item |
|---|
| **#71** |

**DoD:** fecha.
EOF
# PATH com node e sem gh — mutilar o PATH inteiro tiraria o próprio node e o cenário mediria
# outra coisa (o `command not found` do interpretador, não a falha de medição).
stub="$T/stubbin"; mkdir -p "$stub"
for c in node git bash sh env; do
  bin="$(command -v "$c" 2>/dev/null)" && ln -sf "$bin" "$stub/$c"
done
command -v "$stub/gh" >/dev/null 2>&1 && fail "[12]: o stub não devia conter gh"
out="$(PATH="$stub" "$stub/node" "$SCRIPT" --plan "$T/plano-issue.md" --ledger "$L" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || fail "[12]: falha REAL ao medir issues (gh ausente) saiu rc=0"
grep -qiE 'não medid' <<<"$out" || fail "[12]: falha de medição não foi reportada"
# Para isolar a variável: ledger sem item aberto, de modo que o único eixo em jogo seja a
# medição de issues. Com o ledger da fixture o plano mínimo teria órfãos e o rc=1 viria daí.
cat > "$T/ledger-fechado.json" <<'EOF'
{"entries":[{"id":"LDG-9001","status":"resolved","resolved_at":"2026-09-01","title":"fechado"}]}
EOF
out="$(node "$SCRIPT" --plan "$T/plano-issue.md" --ledger "$T/ledger-fechado.json" --no-network 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || fail "[12]: --no-network é cegueira DECLARADA e devia sair 0 (rc=$rc)"
# e a mesma fixture com falha REAL de medição continua reprovando — o par é o que prova a distinção
out="$(PATH="$stub" "$stub/node" "$SCRIPT" --plan "$T/plano-issue.md" --ledger "$T/ledger-fechado.json" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || fail "[12]: mesma fixture, falha real de gh, saiu rc=0 — a distinção não existe"
echo "OK [12] rc reflete medição de issues"

echo "PASS w156-plan-progress-gate"
