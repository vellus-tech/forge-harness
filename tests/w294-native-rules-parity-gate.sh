#!/usr/bin/env bash
# ORDINAL: w294 atribuído no merge de add-liaison-native-bridge
# Gate vermelho/verde das normas da mensageria nativa entre sessões (REQ-09, design §2.8).
#
#   [1] EPHEMERAL_CLASSES (scripts/lib/native-classes.mjs) e a lista de classes efêmeras
#       declarada em rules/conventions/liaison-protocol.md são o MESMO conjunto — fonte única
#       conferida por teste, nunca duas listas mantidas à mão em paralelo.
#   [2] mutação do lado da RULE: remover uma classe da lista da rule, sem tocar o código,
#       reprova — numa cópia temporária, nunca na árvore real.
#   [3] mutação do lado do CÓDIGO: acrescentar uma classe a EPHEMERAL_CLASSES sem tocar a rule
#       reprova — idem, cópia temporária.
#   [4] recontrole: as cópias intactas (sem mutação) aprovam — controle positivo ao lado dos dois
#       negativos acima, para que um gate verde sobre nada (comparação sempre "ok") não passe.
#   [5]..[N] frases normativas obrigatórias do design §2.8 presentes nas duas rules.
#   [N+1] `validate-rules.sh` com FORGE_ROOT no template não reporta drift.
#   [N+2] `last_reviewed` das duas rules foi atualizado para a data deste change.
#   [N+3] os três itens de ledger com origem neste change existem (config. gerenciada PCI,
#       medição do formato de agente nomeado, ADR de mensageria nativa) — aceitos abertos ou
#       resolvidos (o ADR é resolvido só na TASK-27).
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-native-rules.XXXXXX)"
trap 'rm -rf "$T"' EXIT

CLASSES_MJS="$WS/template/.forge/scripts/lib/native-classes.mjs"
RULE_PROTOCOL="$WS/template/.forge/rules/conventions/liaison-protocol.md"
RULE_UNTRUSTED="$WS/template/.forge/rules/conventions/liaison-untrusted-input.md"
LEDGER_JSON="$WS/.forge/ledger/ledger.json"

n=0
overall_rc=0
ok() { n=$((n + 1)); echo "OK [$n] $1"; }
fail() { n=$((n + 1)); echo "FAIL [$n]: $1"; overall_rc=1; }

[ -f "$CLASSES_MJS" ] || { fail "native-classes.mjs ausente (rule|classes)"; echo "$overall_rc" >/dev/null; exit 1; }
[ -f "$RULE_PROTOCOL" ] || { fail "liaison-protocol.md ausente (rule|classes)"; exit 1; }
[ -f "$RULE_UNTRUSTED" ] || { fail "liaison-untrusted-input.md ausente (rule|classes)"; exit 1; }

# _classes_do_codigo <arquivo native-classes.mjs> — extrai EPHEMERAL_CLASSES via node, ordenado
_classes_do_codigo() {
  node --input-type=module -e "
    import { EPHEMERAL_CLASSES } from '$1';
    console.log(EPHEMERAL_CLASSES.slice().sort().join(','));
  " 2>/dev/null
}

# _classes_da_rule <arquivo rule> — extrai bullets \`- \`classe\`\` sob "### Classes efêmeras",
# ordenado
_classes_da_rule() {
  awk '
    /^### Classes efêmeras/ { s = 1; next }
    s && /^### / { exit }
    s && /^- `[a-z0-9-]+`$/ { gsub(/^- `/, ""); gsub(/`$/, ""); print }
  ' "$1" | sort | tr '\n' ',' | sed 's/,$//'
}

# _compara <rule> <classes-mjs> — "ok" ou "mismatch: <rule-classes> != <code-classes>"
_compara() {
  local rc cc
  rc="$(_classes_da_rule "$1")"
  cc="$(_classes_do_codigo "$2")"
  if [ -z "$rc" ] || [ -z "$cc" ]; then
    echo "mismatch: vazio (rule='$rc' code='$cc')"
    return 1
  fi
  if [ "$rc" = "$cc" ]; then
    echo "ok"
    return 0
  fi
  echo "mismatch: rule='$rc' code='$cc'"
  return 1
}

out1="$(_compara "$RULE_PROTOCOL" "$CLASSES_MJS")"
if [ "$out1" = "ok" ]; then
  ok "classes da rule == EPHEMERAL_CLASSES do código ($out1)"
else
  fail "classes da rule != EPHEMERAL_CLASSES do código — $out1 (rule|classes)"
fi

# [2]/[3]/[4] mutação dos dois lados, numa cópia temporária
mkdir -p "$T/mut"
cp "$RULE_PROTOCOL" "$T/mut/rule.md"
cp "$CLASSES_MJS" "$T/mut/classes.mjs"

# [2] mutação do lado da rule: remove a última classe da lista
sed -i.bak '/^- `internal-coordination`$/d' "$T/mut/rule.md"
out2="$(_compara "$T/mut/rule.md" "$T/mut/classes.mjs")"
if [ "$out2" != "ok" ]; then
  ok "mutação [rule sem internal-coordination] detectada — $out2 (rule|classes)"
else
  fail "mutação [rule sem internal-coordination] NÃO detectada — comparação aprovou sobre lista divergente (rule|classes)"
fi
cp "$RULE_PROTOCOL" "$T/mut/rule.md"

# [3] mutação do lado do código: acrescenta classe nova
sed -i.bak "s/^export const EPHEMERAL_CLASSES = \[/export const EPHEMERAL_CLASSES = [\n  'mutated-extra-class',/" "$T/mut/classes.mjs"
out3="$(_compara "$T/mut/rule.md" "$T/mut/classes.mjs")"
if [ "$out3" != "ok" ]; then
  ok "mutação [código com classe extra] detectada — $out3 (rule|classes)"
else
  fail "mutação [código com classe extra] NÃO detectada (rule|classes)"
fi
cp "$CLASSES_MJS" "$T/mut/classes.mjs"

# [4] recontrole: cópias intactas aprovam
out4="$(_compara "$T/mut/rule.md" "$T/mut/classes.mjs")"
if [ "$out4" = "ok" ]; then
  ok "recontrole — cópias intactas aprovam ($out4) (rule|classes)"
else
  fail "recontrole — cópias intactas, sem mutação, reprovaram ($out4) (rule|classes)"
fi

# [5..] frases normativas obrigatórias do design §2.8
_frase() {
  local arq="$1" frase="$2" rotulo="$3"
  if grep -qF -- "$frase" "$arq"; then
    ok "frase obrigatória presente — $rotulo (rule|classes)"
  else
    fail "frase obrigatória AUSENTE em $(basename "$arq") — $rotulo: '$frase' (rule|classes)"
  fi
}

_frase "$RULE_PROTOCOL" "o nativo é campainha, o liaison é o registro" "campainha-vs-registro"
_frase "$RULE_PROTOCOL" "ephemeral: internal-coordination" "classe internal-coordination para coordenação no mesmo repositório"
_frase "$RULE_PROTOCOL" "send --via cross-session --native-ref" "registro do que chega via send --via cross-session"
_frase "$RULE_PROTOCOL" "native dispose" "registro do que chega via native dispose"
_frase "$RULE_PROTOCOL" "não fronteira de segurança" "allowed_workspaces não é fronteira de segurança"
_frase "$RULE_PROTOCOL" "liberação induzida" "contenção é proteção contra liberação induzida"

_frase "$RULE_UNTRUSTED" "regras 1 a 4" "regras 1 a 4 valem para a mensagem nativa"
_frase "$RULE_UNTRUSTED" "nenhuma guarda mecânica de moldura, teto ou neutralização" "sem guarda mecânica na mensagem nativa"
_frase "$RULE_UNTRUSTED" "autodeclarado" "from-name é autodeclarado"
_frase "$RULE_UNTRUSTED" "o agente contorna o gancho" "limite do gancho de saída inteiro"
_frase "$RULE_UNTRUSTED" "configuração gerenciada do Claude Code" "recomendação de configuração gerenciada"
_frase "$RULE_UNTRUSTED" "PCI" "recomendação para repositórios PCI"

# validate-rules.sh com FORGE_ROOT no template
out_vr="$(FORGE_ROOT="$WS/template" bash "$WS/template/.forge/scripts/validate-rules.sh" 2>&1)"
rc_vr=$?
if [ "$rc_vr" -eq 0 ] && ! printf '%s\n' "$out_vr" | grep -qi "drift\|FAIL"; then
  ok "validate-rules.sh (FORGE_ROOT=template) sem drift"
else
  fail "validate-rules.sh (FORGE_ROOT=template) reprovou ou relatou drift — rc=$rc_vr saída: $out_vr (rule|classes)"
fi

# last_reviewed atualizado nas duas rules (data deste change: 2026-10-31)
for arq_lr in "$RULE_PROTOCOL" "$RULE_UNTRUSTED"; do
  lr="$(sed -n 's/^last_reviewed: \(.*\)$/\1/p' "$arq_lr" | head -1)"
  if [ "$lr" = "2026-10-31" ]; then
    ok "last_reviewed atualizado em $(basename "$arq_lr") ($lr)"
  else
    fail "last_reviewed NÃO atualizado em $(basename "$arq_lr") — obtido '$lr', esperado '2026-10-31' (last_reviewed)"
  fi
done

# itens de ledger com origem neste change
if [ ! -f "$LEDGER_JSON" ]; then
  fail "ledger.json ausente em $LEDGER_JSON (ledger)"
else
  ledger_check="$(node -e "
    const d = require('$LEDGER_JSON');
    const entries = (d.entries || []).filter((e) => e.source && e.source.change_id === 'add-liaison-native-bridge');
    const hay = entries.map((e) => (e.title || '') + ' ' + (e.detail || '')).join(' \n ');
    const hasPci = /PCI/.test(hay) && /(configuração gerenciada|managed)/i.test(hay);
    const hasAgent = /(agente nomeado|input\.name|agent team)/i.test(hay);
    const hasAdr = /(ADR|Mensageria nativa)/i.test(hay) && /(sinaliza|liaison)/i.test(hay);
    console.log(JSON.stringify({ n: entries.length, hasPci, hasAgent, hasAdr }));
  " 2>/dev/null)"
  if [ -z "$ledger_check" ]; then
    fail "não consegui ler/avaliar $LEDGER_JSON (ledger)"
  else
    n_entries="$(printf '%s' "$ledger_check" | node -e "console.log(JSON.parse(require('fs').readFileSync(0,'utf8')).n)" 2>/dev/null)"
    has_pci="$(printf '%s' "$ledger_check" | node -e "console.log(JSON.parse(require('fs').readFileSync(0,'utf8')).hasPci)" 2>/dev/null)"
    has_agent="$(printf '%s' "$ledger_check" | node -e "console.log(JSON.parse(require('fs').readFileSync(0,'utf8')).hasAgent)" 2>/dev/null)"
    has_adr="$(printf '%s' "$ledger_check" | node -e "console.log(JSON.parse(require('fs').readFileSync(0,'utf8')).hasAdr)" 2>/dev/null)"
    if [ "${n_entries:-0}" -ge 3 ] 2>/dev/null; then
      ok "ao menos 3 itens de ledger com origem no change ($n_entries)"
    else
      fail "menos de 3 itens de ledger com origem no change (encontrados: ${n_entries:-0}) (ledger)"
    fi
    [ "$has_pci" = "true" ] && ok "item de ledger — configuração gerenciada PCI" || fail "item de ledger ausente — configuração gerenciada PCI (ledger)"
    [ "$has_agent" = "true" ] && ok "item de ledger — medição do formato de agente nomeado" || fail "item de ledger ausente — medição do formato de agente nomeado (ledger)"
    [ "$has_adr" = "true" ] && ok "item de ledger — ADR mensageria nativa é sinalização" || fail "item de ledger ausente — ADR mensageria nativa é sinalização (ledger)"
  fi
fi

exit "$overall_rc"
