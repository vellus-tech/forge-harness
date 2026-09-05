#!/usr/bin/env bash
# Gate W197 — texto normativo que o código contradiz (LDG-0101, LDG-0102, peça documental da #82).
#
# Os três compartilham o padrão de correção: corrigir o texto **e** fiar o check que impede a
# próxima deriva. Corrigir só o texto entrega o mesmo item de novo em três meses, e é o que o
# histórico deste repositório mostra ter acontecido com LDG-0102.
#
#   [1] a `Versão` da tabela de topo de contracts/*.md casa a ÚLTIMA ENTRADA DE VERSÃO do
#       changelog do próprio documento
#   [2] a `Data` idem — comparada com a data da última entrada de VERSÃO (`Versão N.M`), NUNCA
#       com a última linha da seção. Medido: a última LINHA de claude-adapter-contract.md é a
#       decisão de gate W0.3, datada 2026-06-10, idêntica à tabela de topo — implementado como
#       "última linha", este cenário aprovaria antes e depois da correção
#   [3] propriedade: para todo .md de contracts/ com tabela de topo e seção de changelog, as
#       duas casam. O universo é `contracts/` NA RAIZ do repositório (template/.forge/contracts/
#       tem só stages/*.yaml, e varrê-lo faria o contador de controle reprovar por vazio)
#   [4] envelope com body E body_ref reprova no schema por ajv, como já reprova em validateEnvelope
#   [5] envelope sem body e sem body_ref passa nos dois — e a DESCRIÇÃO do schema diz isso
#   [6] `phase:`, `pre-deploy` e `post-deploy` aparecem em ao menos uma rule E no FORGE.md do
#       template. O predicado casa `phase:` como CHAVE, nunca `phase` como substring: medido, há
#       duas ocorrências de "phase" dentro da palavra "phases" em prosa sobre scale-adaptive
#       levels, e um `grep -q phase` produziria falso verde nesse terço
#   [7] commands/waves/wave.md não descreve runtime.gates como lista plana
#   [8] contador de controle: zero documento examinado reprova
#   [9] mutação: alterar a Versão do contrato para um valor arbitrário faz [1] reprovar
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w197.XXXXXX)"
trap 'rm -rf "$T"' EXIT

# Universo: `contracts/` na RAIZ. Documentado aqui porque o outro candidato
# (template/.forge/contracts/) contém apenas stages/*.yaml — varrê-lo daria universo vazio, e o
# contador de controle [8] reprovaria, corretamente.
CONTRACTS="$WS/contracts"

# _topo <arquivo> <campo> — valor da tabela de topo `| **Campo** | valor |`
_topo() { sed -n "s/^| \*\*$2\*\* | \(.*\) |$/\1/p" "$1" | head -1; }
# _ultima_versao <arquivo> — "N.M<TAB>YYYY-MM-DD" da última entrada que declara `Versão N.M`
_ultima_versao() {
  awk '
    /Vers(ã|a)o [0-9]+\.[0-9]+/ {
      v = ""; d = ""
      if (match($0, /Vers(ã|a)o [0-9]+\.[0-9]+/)) { v = substr($0, RSTART, RLENGTH); sub(/^Vers(ã|a)o /, "", v) }
      if (match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}/)) { d = substr($0, RSTART, RLENGTH) }
      if (v != "") { lv = v; ld = d }
    }
    END { if (lv != "") printf "%s\t%s\n", lv, ld }
  ' "$1"
}

n_docs=0; bad=0
for f in "$CONTRACTS"/*.md; do
  [ -f "$f" ] || continue
  topo_v="$(_topo "$f" "Versão")"
  [ -n "$topo_v" ] || continue          # sem tabela de topo: fora do universo desta propriedade
  ult="$(_ultima_versao "$f")"
  [ -n "$ult" ] || continue             # sem seção de changelog: idem
  n_docs=$((n_docs + 1))
done

echo "[8] contador de controle — zero documento examinado reprova"
[ "$n_docs" -gt 0 ] || { echo "FAIL [8]: universo VAZIO em '$CONTRACTS' — os cenários abaixo aprovariam por vacuidade. Confira se o gate está varrendo a raiz e não template/.forge/contracts/ (que só tem stages/*.yaml)"; exit 1; }
# shellcheck source=/dev/null
. "$WS/template/.forge/scripts/lib/gate-universe.sh"
forge_universe_check "w197/contratos" "$n_docs" "documento(s) de contrato" "$CONTRACTS" "$WS" \
  || { echo "FAIL [8]"; exit 1; }
out8="$(forge_universe_check "w197/contratos" 0 "documento(s)" "contrapositiva" "$WS" 2>&1)"; rc8=$?
[ "$rc8" -ne 0 ] || { echo "FAIL [8]: universo vazio aprovou — $out8"; exit 1; }
echo "OK [8] — $n_docs documento(s) no universo"

echo "[1]/[2]/[3] a tabela de topo casa a última ENTRADA DE VERSÃO do changelog do próprio doc"
for f in "$CONTRACTS"/*.md; do
  [ -f "$f" ] || continue
  topo_v="$(_topo "$f" "Versão")"; [ -n "$topo_v" ] || continue
  ult="$(_ultima_versao "$f")"; [ -n "$ult" ] || continue
  ult_v="${ult%%	*}"; ult_d="${ult##*	}"
  topo_d="$(_topo "$f" "Data")"
  rel="${f#"$WS"/}"
  if [ "$topo_v" != "$ult_v" ]; then
    echo "  $rel: tabela de topo diz Versão $topo_v, e a última entrada de versão do changelog é $ult_v"
    bad=$((bad + 1))
  fi
  if [ -n "$ult_d" ] && [ "$topo_d" != "$ult_d" ]; then
    echo "  $rel: tabela de topo diz Data $topo_d, e a última entrada de versão ($ult_v) é de $ult_d"
    bad=$((bad + 1))
  fi
done
[ "$bad" -eq 0 ] || { echo "FAIL [1]/[2]/[3]: $bad divergência(s) entre tabela de topo e changelog — texto normativo que o próprio documento contradiz"; exit 1; }
echo "OK [1]/[2]/[3] — $n_docs documento(s), tabela de topo em paridade com o changelog"

echo "[9] mutação — alterar a Versão do contrato faz [1] reprovar"
MUT="$T/contrato.md"
cp "$CONTRACTS/claude-adapter-contract.md" "$MUT"
cp "$MUT" "$T/contrato.orig"
# `sed -i.bak`, nunca `sed -i ''`: o idioma do repositório (req13-affects-surfaces-gate.sh:22),
# porque `sed -i ''` quebra no runner Linux do CI.
sed -i.bak 's/^| \*\*Versão\*\* | .* |$/| **Versão** | 9.9 |/' "$MUT"
mut_v="$(_topo "$MUT" "Versão")"
[ "$mut_v" = "9.9" ] || { echo "FAIL [9]: a mutação não alterou a versão (got '$mut_v')"; exit 1; }
mut_ult="$(_ultima_versao "$MUT")"; mut_ult_v="${mut_ult%%	*}"
[ "$mut_v" != "$mut_ult_v" ] || { echo "FAIL [9]: a mutação não produziu divergência — o predicado não é o que decide"; exit 1; }
cp "$T/contrato.orig" "$MUT"
cmp -s "$MUT" "$T/contrato.orig" || { echo "FAIL [9]: restauração não bateu byte a byte (cmp)"; exit 1; }
rec_v="$(_topo "$MUT" "Versão")"; rec_ult="$(_ultima_versao "$MUT")"; rec_ult_v="${rec_ult%%	*}"
[ "$rec_v" = "$rec_ult_v" ] || { echo "FAIL [9]: recontrole — restaurado, o documento não voltou à paridade ('$rec_v' vs '$rec_ult_v')"; exit 1; }
echo "OK [9] — mutou (divergência), restaurou (cmp ok), voltou à paridade"

# ── LDG-0101: schema × validateEnvelope ──────────────────────────────────────────────────────
SCHEMA="$WS/template/.forge/schemas/liaison-message.schema.json"
echo "[4] envelope com body E body_ref reprova no SCHEMA, como já reprova em validateEnvelope"
node - "$SCHEMA" "$WS/template/.forge/scripts/lib" <<'NODEEOF'
const { readFileSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , schemaPath, lib] = process.argv;
  const schema = JSON.parse(readFileSync(schemaPath, 'utf8'));
  // A exclusão mútua que o validador COBRA tem de estar codificada no schema. Sem ela, uma
  // mensagem com os dois campos PASSA no schema e REPROVA no validador — a divergência de direção
  // oposta à registrada, e a que tem consequência real para quem valida por ajv antes de enviar.
  const clauses = JSON.stringify(schema.allOf || []);
  const hasNot = clauses.includes('"not"') && clauses.includes('body_ref') && clauses.includes('"body"');
  if (!hasNot) {
    console.error('FAIL [4]: o schema NÃO codifica a exclusão mútua body/body_ref — uma mensagem com os dois passa no schema e reprova em validateEnvelope');
    process.exit(1);
  }
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const msg = {
    msg_id: 'a-0001', channel: 'c', thread_id: 't', sender: 'a', seq: 1, lamport: 1,
    kind: 'note', requires_ack: false, subject: 's', body: 'x', body_ref: 'y',
    refs: { change_id: null, contract_files: [], commit: null },
    created_at: '2026-01-01T00:00:00Z', trust: 'self', content_sha: 'x',
  };
  const errs = M.validateEnvelope(msg);
  if (!errs.length) {
    console.error('FAIL [4]: validateEnvelope aceitou body E body_ref — o controle do cenário caiu');
    process.exit(1);
  }
  console.log('OK [4] — schema codifica a exclusão mútua; validateEnvelope: ' + errs[0]);
})();
NODEEOF
[ $? -eq 0 ] || exit 1

echo "[5] envelope SEM body e SEM body_ref passa nos dois — e a descrição do schema diz isso"
desc="$(node -e '
  const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
  process.stdout.write((s.properties.body && s.properties.body.description) || "");
' "$SCHEMA")"
case "$desc" in
  *"exatamente um dos dois é obrigatório"*)
    echo "FAIL [5]: a descrição de 'body' continua afirmando que exatamente um dos dois é obrigatório — o schema não o exige (body/body_ref não estão em required) e validateEnvelope implementa 'ambos opcionais, mutuamente exclusivos quando presentes'. Aqui quem mente é a descrição."
    exit 1 ;;
esac
grep -q '"body_ref"' <<<"$(node -e '
  const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
  process.stdout.write(JSON.stringify(s.required||[]));
' "$SCHEMA")" && { echo "FAIL [5]: body_ref virou obrigatório em required — muda o contrato em vez de descrevê-lo"; exit 1; }
node - "$SCHEMA" "$WS/template/.forge/scripts/lib" <<'NODEEOF'
const { readFileSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , schemaPath, lib] = process.argv;
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const msg = {
    msg_id: 'a-0001', channel: 'c', thread_id: 't', sender: 'a', seq: 1, lamport: 1,
    kind: 'note', requires_ack: false, subject: 's',
    refs: { change_id: null, contract_files: [], commit: null },
    created_at: '2026-01-01T00:00:00Z', trust: 'self', content_sha: 'x',
  };
  const errs = M.validateEnvelope(msg);
  const rel = errs.filter((e) => /body/i.test(e));
  if (rel.length) { console.error('FAIL [5]: validateEnvelope reprovou envelope sem body e sem body_ref: ' + rel.join('; ')); process.exit(1); }
  console.log('OK [5] — ambos ausentes passa no validador, e a descrição do schema não afirma o contrário');
})();
NODEEOF
[ $? -eq 0 ] || exit 1

# ── #82, peça documental ─────────────────────────────────────────────────────────────────────
echo "[6] phase:/pre-deploy/post-deploy aparecem em rule E no FORGE.md do template"
RULES_DIR="$WS/template/.forge/rules"
TPL_FORGE="$WS/template/.forge/templates/FORGE.md"
# `phase:` como CHAVE, nunca `phase` como substring: medido, há ocorrências de "phase" dentro de
# "phases" em prosa sobre scale-adaptive levels, e um grep solto produziria falso verde.
grep -rqE '(^|[^A-Za-z])phase:' "$RULES_DIR" \
  || { echo "FAIL [6]: nenhuma rule menciona 'phase:' como chave — a fase existe no código e não existe para quem consome o harness"; exit 1; }
for termo in 'pre-deploy' 'post-deploy'; do
  grep -rq -- "$termo" "$RULES_DIR" \
    || { echo "FAIL [6]: nenhuma rule menciona '$termo'"; exit 1; }
done
grep -qE '(^|[^A-Za-z])phase:' "$TPL_FORGE" \
  || { echo "FAIL [6]: o FORGE.md do template não mostra 'phase:' — 'gates:' segue como chave vazia sem exemplo, e o adotante não tem como saber que a forma existe"; exit 1; }
for termo in 'pre-deploy' 'post-deploy'; do
  grep -q -- "$termo" "$TPL_FORGE" || { echo "FAIL [6]: o FORGE.md do template não mostra '$termo'"; exit 1; }
done
# Contrapositiva do predicado: 'phases' em prosa NÃO satisfaz 'phase:' como chave.
printf 'texto com a palavra phases em prosa\n' > "$T/so-phases.md"
grep -qE '(^|[^A-Za-z])phase:' "$T/so-phases.md" \
  && { echo "FAIL [6]: o predicado casou 'phases' em prosa — está frouxo e produziria falso verde"; exit 1; }
echo "OK [6] — 'phase:' como chave, 'pre-deploy' e 'post-deploy' presentes em rule e no FORGE.md do template"

echo "[7] commands/waves/wave.md não descreve runtime.gates como lista plana"
WAVE="$WS/template/.forge/commands/waves/wave.md"
# Asserção sobre o que o texto AFIRMA, não sobre a substring: a correção precisa poder dizer
# "não é lista plana", e um grep solto pela expressão reprovaria a própria correção.
if grep -qi "lista plana" "$WAVE" && ! grep -qiE "n(ã|a)o (é|e) (uma )?lista plana" "$WAVE"; then
  echo "FAIL [7]: wave.md ainda descreve runtime.gates como lista plana"
  exit 1
fi
grep -qE '(^|[^A-Za-z])phase:' "$WAVE" \
  || { echo "FAIL [7]: wave.md não diz uma palavra sobre a fase — o comando que FECHA a wave é onde o operador descobre que gate de deploy não roda ali"; exit 1; }
echo "OK [7] — wave.md descreve as duas formas e nomeia a fase"

echo "PASS w197-normative-text-parity"
