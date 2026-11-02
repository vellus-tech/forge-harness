#!/usr/bin/env bash
# Gate — TASK-32/TASK-33 de add-liaison-handoff-baton (REQ-16, REQ-10): documentação do
# subcomando `baton` em sincronia com o código (fonte única `BATON_VERB_FLAGS`).
#   [doc-argument-hint] `baton` consta do argument-hint do /forge:liaison
#   [doc-flags-paridade] flags documentadas de cada verbo == BATON_VERB_FLAGS do script
#   [doc-rule-secao] rule liaison-protocol.md tem a seção "Bastão de dono único"
#   [doc-trabalho-sobreposto] rule cita a classe "trabalho sobreposto" e o bastão como registro
#     estruturado dela
#   [doc-opcao-c] rule descreve a publicação sem trava (tmp único, conferência, resíduo)
#   [doc-env-vars] rule cita as quatro variáveis internas
#   [doc-limites] rule cita os limites declarados (escritor de versão antiga, limpeza por
#     idade, bind mount, janela residual)
#   [doc-handoff-nota] handoff.md documenta que o snapshot não tem dono e aponta --from-handoff
#   [doc-status-marca] liaison.md registra que o status geral pode gravar a marca de publicação
#   [doc-header-stamped-at] cabeçalho de liaison-ops.sh e descrição de created_at no schema
#     citam stamped_at como a exceção
#   [doc-plugin-sync] plugin/forge/commands/{liaison,handoff}.md iguais ao template
#   [doc-slash-commands] docs/refer/slash-commands.md documenta o subcomando baton
#   [doc-validate-rules] validate-rules.sh passa com last_reviewed atualizado
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIAISON_MD="$WS/template/.forge/commands/harness/liaison.md"
HANDOFF_MD="$WS/template/.forge/commands/harness/handoff.md"
RULE="$WS/template/.forge/rules/conventions/liaison-protocol.md"
OPS="$WS/template/.forge/scripts/liaison-ops.sh"
BATON_LIB="$WS/template/.forge/scripts/lib/liaison-baton.mjs"
SCHEMA="$WS/template/.forge/schemas/liaison-message.schema.json"
SLASH="$WS/docs/refer/slash-commands.md"

fail=0

# === [doc-argument-hint] ===
if grep -q '^argument-hint:.*baton' "$LIAISON_MD" 2>/dev/null; then
  echo "OK [doc-argument-hint]: 'baton' consta do argument-hint do /forge:liaison"
else
  echo "FAIL [doc-argument-hint]: argument-hint do liaison.md não cita 'baton'"
  fail=1
fi

# === [doc-flags-paridade] ===
# Extrai BATON_VERB_FLAGS do script-fonte (JS) e compara, verbo a verbo, com o conjunto
# documentado em liaison.md (tabela "| `<verbo>` | `--flag1`, `--flag2` |").
parity_report="$(node - "$BATON_LIB" "$LIAISON_MD" <<'NODEEOF'
const fs = require('fs');
const [, , libPath, docPath] = process.argv;
const libSrc = fs.readFileSync(libPath, 'utf8');
const m = libSrc.match(/export const BATON_VERB_FLAGS = \{([\s\S]*?)\n\};/);
if (!m) { console.log('MISMATCH: BATON_VERB_FLAGS não encontrado no script'); process.exit(0); }
const real = {};
for (const line of m[1].split('\n')) {
  const mm = line.match(/^\s*(\w+):\s*\[([^\]]*)\]/);
  if (!mm) continue;
  const flags = mm[2].split(',').map((s) => s.trim().replace(/^'|'$/g, '')).filter(Boolean);
  real[mm[1]] = flags;
}
const doc = fs.readFileSync(docPath, 'utf8');
let mismatches = [];
const BT = String.fromCharCode(96);
for (const [verb, flags] of Object.entries(real)) {
  const rowRe = new RegExp('\\|\\s*' + BT + verb + BT + '\\s*\\|\\s*([^|]*)\\|');
  const rowM = doc.match(rowRe);
  if (!rowM) { mismatches.push(verb + ': sem linha documentada'); continue; }
  const docFlags = rowM[1].match(new RegExp(BT + '(--[a-z-]+)' + BT, 'g')) || [];
  const docSet = docFlags.map((s) => s.split(BT).join(''));
  const realSet = [...flags].sort();
  const docSetSorted = [...docSet].sort();
  if (JSON.stringify(realSet) !== JSON.stringify(docSetSorted)) {
    mismatches.push(verb + ': script=[' + realSet.join(',') + '] doc=[' + docSetSorted.join(',') + ']');
  }
}
if (mismatches.length) {
  console.log('MISMATCH: ' + mismatches.join(' | '));
} else {
  console.log('OK');
}
NODEEOF
)"
if [ "$parity_report" = "OK" ]; then
  echo "OK [doc-flags-paridade]: flags documentadas por verbo == BATON_VERB_FLAGS"
else
  echo "FAIL [doc-flags-paridade]: $parity_report"
  fail=1
fi

# === [doc-rule-secao] ===
if grep -q "Bastão de dono único" "$RULE" 2>/dev/null; then
  echo "OK [doc-rule-secao]: rule tem a seção 'Bastão de dono único'"
else
  echo "FAIL [doc-rule-secao]: rule sem a seção 'Bastão de dono único'"
  fail=1
fi

# === [doc-trabalho-sobreposto] ===
if grep -q "trabalho sobreposto" "$RULE" 2>/dev/null && grep -q "registro ESTRUTURADO\|registro estruturado" "$RULE" 2>/dev/null; then
  echo "OK [doc-trabalho-sobreposto]: rule cita a classe e o bastão como registro estruturado dela"
else
  echo "FAIL [doc-trabalho-sobreposto]: rule não liga 'trabalho sobreposto' ao bastão como registro estruturado"
  fail=1
fi

# === [doc-opcao-c] ===
if grep -qi "publicação sem trava" "$RULE" 2>/dev/null && grep -qi "resíduo" "$RULE" 2>/dev/null && grep -q "nome ÚNICO\|nome único" "$RULE" 2>/dev/null; then
  echo "OK [doc-opcao-c]: rule descreve a publicação sem trava (tmp único + conferência + resíduo)"
else
  echo "FAIL [doc-opcao-c]: rule não descreve a opção C com os termos esperados"
  fail=1
fi

# === [doc-env-vars] ===
missing_env=""
for v in FORGE_BATON_RENEW_IF_DUE FORGE_LIAISON_LOCK_WAIT_MS FORGE_LIAISON_PUSH_DEADLINE_S FORGE_LIAISON_TEST_BARRIER; do
  grep -q "$v" "$RULE" 2>/dev/null || missing_env="$missing_env $v"
done
if [ -z "$missing_env" ]; then
  echo "OK [doc-env-vars]: rule cita as quatro variáveis internas"
else
  echo "FAIL [doc-env-vars]: rule não cita:$missing_env"
  fail=1
fi

# === [doc-limites] ===
missing_lim=""
grep -qi "escritor de versão antiga" "$RULE" 2>/dev/null || missing_lim="$missing_lim escritor-de-versao-antiga"
grep -qi "limpeza por idade" "$RULE" 2>/dev/null || missing_lim="$missing_lim limpeza-por-idade"
grep -qi "bind mount" "$RULE" 2>/dev/null || missing_lim="$missing_lim bind-mount"
grep -qi "janela residual" "$RULE" 2>/dev/null || missing_lim="$missing_lim janela-residual"
if [ -z "$missing_lim" ]; then
  echo "OK [doc-limites]: rule cita os quatro limites declarados"
else
  echo "FAIL [doc-limites]: rule não cita:$missing_lim"
  fail=1
fi

# === [doc-handoff-nota] ===
if grep -qi "não tem dono\|sem dono" "$HANDOFF_MD" 2>/dev/null && grep -q "baton offer" "$HANDOFF_MD" 2>/dev/null && grep -q "from-handoff" "$HANDOFF_MD" 2>/dev/null; then
  echo "OK [doc-handoff-nota]: handoff.md documenta que o snapshot não tem dono e aponta --from-handoff"
else
  echo "FAIL [doc-handoff-nota]: handoff.md não documenta a transferência de posse"
  fail=1
fi

# === [doc-status-marca] ===
if grep -qi "status.*GERAL" "$LIAISON_MD" 2>/dev/null && grep -q "grava\|REGRAVA" "$LIAISON_MD" 2>/dev/null && grep -q "marca" "$LIAISON_MD" 2>/dev/null; then
  echo "OK [doc-status-marca]: liaison.md registra que o status geral pode gravar a marca"
else
  echo "FAIL [doc-status-marca]: liaison.md não registra o status geral gravando a marca"
  fail=1
fi

# === [doc-header-stamped-at] ===
if grep -q "stamped_at" "$OPS" 2>/dev/null && grep -q "stamped_at" "$SCHEMA" 2>/dev/null; then
  echo "OK [doc-header-stamped-at]: cabeçalho de liaison-ops.sh e descrição de created_at no schema citam stamped_at"
else
  echo "FAIL [doc-header-stamped-at]: stamped_at ausente do cabeçalho do script ou da descrição do schema"
  fail=1
fi

# === [doc-plugin-sync] ===
if diff -q "$LIAISON_MD" "$WS/plugin/forge/commands/liaison.md" >/dev/null 2>&1 && diff -q "$HANDOFF_MD" "$WS/plugin/forge/commands/handoff.md" >/dev/null 2>&1; then
  echo "OK [doc-plugin-sync]: plugin/forge/commands/{liaison,handoff}.md iguais ao template"
else
  echo "FAIL [doc-plugin-sync]: plugin fora de sincronia com o template (rode build:plugin)"
  fail=1
fi

# === [doc-slash-commands] ===
if grep -q "forge:liaison" "$SLASH" 2>/dev/null && grep "forge:liaison" "$SLASH" 2>/dev/null | grep -q "baton"; then
  echo "OK [doc-slash-commands]: docs/refer/slash-commands.md documenta o subcomando baton"
else
  echo "FAIL [doc-slash-commands]: docs/refer/slash-commands.md não documenta o subcomando baton"
  fail=1
fi

# === [doc-validate-rules] ===
# Checagem determinística, independente do relógio de quem roda o gate (nunca compara contra a
# data corrente — um gate cuja aprovação dependesse de "hoje" quebraria sozinho no dia seguinte):
# last_reviewed é uma data válida e DIFERENTE do valor que a rule tinha antes desta rodada
# (2026-10-31 — a pre-condição real desta task).
rules_out="$(FORGE_ROOT="$WS/template" bash "$WS/template/.forge/scripts/validate-rules.sh" 2>&1)"
rules_rc=$?
last_reviewed="$(awk -F': ' '/^last_reviewed:/{print $2; exit}' "$RULE")"
PRE_TASK_DATE="2026-10-31"
if [ "$rules_rc" -eq 0 ] && printf '%s' "$last_reviewed" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' && [ "$last_reviewed" != "$PRE_TASK_DATE" ]; then
  echo "OK [doc-validate-rules]: validate-rules.sh passa e last_reviewed ($last_reviewed) foi atualizado desde $PRE_TASK_DATE"
else
  echo "FAIL [doc-validate-rules]: rc=$rules_rc last_reviewed=$last_reviewed (esperado data válida != $PRE_TASK_DATE) — $rules_out"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS — documentação do bastão (REQ-16, REQ-10)"
exit 0
