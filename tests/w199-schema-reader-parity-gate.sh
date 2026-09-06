#!/usr/bin/env bash
# Gate W199 — paridade entre o SCHEMA e o LEITOR CANÔNICO de runtime.gates (LDG-0159).
#
# POR QUE ESTE GATE EXISTE. A 0.11.0 publicou o eixo de fase de `runtime.gates`: a chave passou a
# aceitar block-sequence YAML com `phase:`, lida por `lib/gate-phase.mjs`, e o PR #105 documentou
# essa forma no `FORGE.md` que o adotante recebe. Mas `forge.schema.json` continuou declarando
# `runtime.gates` como `$ref: nullableString` — isto é, o schema ACEITA a forma CSV e REJEITA
# tanto a block-sequence de escalares puros quanto a mapeada. O harness lê e ensina uma forma que
# o próprio contrato reprova, e o adotante que seguir a documentação entregue reprova na validação.
#
# A PROPRIEDADE QUE ESTE GATE AFIRMA é de PARIDADE, nos dois sentidos: toda forma que o leitor
# canônico lê é aceita pelo schema, e nenhuma forma que o leitor IGNORA é aceita por ele. O
# segundo sentido não é preciosismo: `gate-phase.mjs:69` exige `item.name` e descarta em silêncio
# o item mapeado sem essa chave, então um schema que aceitasse `- id: check-x` publicaria como
# válida uma declaração que o harness joga fora sem dizer nada — que é o mesmo defeito de LDG-0159,
# invertido, dentro do change que existe para fechá-lo.
#
# AS ASSERÇÕES MEDEM `/runtime/gates`, NUNCA "o documento inteiro valida". Medido: cinco dos treze
# `FORGE.md` instalados nesta máquina já reprovam contra `forgeFrontmatter` hoje, e NENHUM por
# `gates` — quatro por `/runtime must NOT have additional properties` e o dogfood deste
# repositório por `required` ausente, porque ele é deliberadamente mínimo. Um DoD escrito como
# "estes documentos passam a validar" seria falso pela raiz antes e depois da correção, e
# empurraria quem o perseguisse a afrouxar o `required` do schema que vai para todo adotante.
#
#   [1] controle — CSV escalar e `null` são aceitos (as duas formas que já valiam)
#   [2] block-sequence de escalares puros é aceita
#   [3] forma mapeada com `name` + `phase` é aceita
#   [4] contrapositiva — forma mapeada com `id:` (que o leitor DESCARTA) é REJEITADA
#   [5] paridade com o leitor: toda forma aceita em [1]-[3] devolve gate em `gate-phase.mjs`
#   [6] retrocompatibilidade — o que validava antes continua validando (contador de controle)
#   [7] mutação — reverter o alargamento faz [2] e [3] reprovarem
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w199.XXXXXX)"
T="$(cd "$T" && pwd -P)"
trap 'rm -rf "$T"' EXIT

SCHEMA="$WS/template/.forge/schemas/forge.schema.json"
[ -f "$SCHEMA" ] || { echo "FAIL: $SCHEMA ausente"; exit 1; }

# valida <json-do-valor-de-gates> -> imprime "ok" ou a mensagem de erro de /runtime/gates
valida_gates() {
  node -e '
    const Ajv = require("ajv/dist/2020").default || require("ajv/dist/2020");
    const s = require(process.argv[1]);
    const sub = s.$defs.forgeFrontmatter.properties.runtime.properties.gates;
    const v = new Ajv({ strict: false }).compile({ ...sub, $defs: s.$defs });
    const val = JSON.parse(process.argv[2]);
    if (v(val)) { console.log("ok"); process.exit(0); }
    console.log((v.errors || [])[0]?.message || "rejeitado sem mensagem");
    process.exit(1);
  ' "$SCHEMA" "$1" 2>&1
}

echo "[1] controle — CSV escalar e null são aceitos"
r="$(valida_gates '"check-authz,check-observability"')" \
  || { echo "FAIL [1]: CSV escalar REJEITADO ($r) — o alargamento quebrou o que já valia"; exit 1; }
r="$(valida_gates 'null')" \
  || { echo "FAIL [1]: null REJEITADO ($r) — o alargamento quebrou o que já valia"; exit 1; }
echo "OK [1] — CSV escalar e null aceitos"

echo "[2] block-sequence de escalares puros é aceita"
set +e
r2="$(valida_gates '["check-authz","check-observability"]')"; rc2=$?
set -e
[ "$rc2" -eq 0 ] \
  || { echo "FAIL [2]: block-sequence de escalares REJEITADA — '$r2'. É a forma retrocompatível que a issue #82 prometeu manter válida, e o leitor canônico a lê."; exit 1; }
echo "OK [2] — block-sequence de escalares aceita"

echo "[3] forma mapeada com name + phase é aceita"
set +e
r3="$(valida_gates '[{"name":"check-image-digest","phase":"pre-deploy"},{"name":"check-rollout-health","phase":"post-deploy"}]')"; rc3=$?
set -e
[ "$rc3" -eq 0 ] \
  || { echo "FAIL [3]: forma mapeada REJEITADA — '$r3'. É a forma que gate-phase.mjs lê e que o FORGE.md entregue ao adotante ENSINA."; exit 1; }
echo "OK [3] — forma mapeada aceita"

echo "[4] contrapositiva — mapeada com 'id:' (que o leitor descarta) é REJEITADA"
set +e
r4="$(valida_gates '[{"id":"check-authz","phase":"pre-deploy"}]')"; rc4=$?
set -e
[ "$rc4" -ne 0 ] \
  || { echo "FAIL [4]: o schema ACEITOU '- id: …', que gate-phase.mjs:69 descarta em silêncio por exigir item.name — publicar isso é declarar válida uma declaração que o harness joga fora"; exit 1; }
echo "OK [4] — rejeitada: $r4"

echo "[5] paridade com o leitor — toda forma aceita devolve gate em gate-phase.mjs"
mk_forge() { # mk_forge <dir> <bloco-yaml-de-gates>
  mkdir -p "$1/.forge"
  { printf -- '---\nforge_version: 1\nruntime:\n'; printf '%s\n' "$2"; printf -- '---\n'; } > "$1/.forge/FORGE.md"
}
pares=0
mk_forge "$T/csv" '  gates: check-authz,check-observability'
mk_forge "$T/seq" '  gates:
    - check-authz
    - check-observability'
mk_forge "$T/map" '  gates:
    - name: check-image-digest
      phase: pre-deploy
    - name: check-rollout-health
      phase: post-deploy'
for caso in seq map; do
  n="$(node "$WS/template/.forge/scripts/lib/gate-phase.mjs" entries "$T/$caso" 2>/dev/null | grep -c . || true)"
  [ "${n:-0}" -ge 2 ] \
    || { echo "FAIL [5]: o leitor canônico devolveu $n gate(s) para a forma '$caso', esperado >= 2 — schema e leitor não estão em paridade"; exit 1; }
  pares=$((pares + 1))
done
[ "$pares" -ge 2 ] || { echo "FAIL [5]: universo de formas VAZIO — o cenário aprovaria por vacuidade"; exit 1; }
echo "OK [5] — $pares forma(s) lidas pelo leitor e aceitas pelo schema"

echo "[6] retrocompatibilidade — o que validava antes continua validando"
antes_ok=0
for v in '"check-a"' '"check-a,check-b"' 'null' '""'; do
  if valida_gates "$v" >/dev/null 2>&1; then antes_ok=$((antes_ok + 1)); fi
done
[ "$antes_ok" -eq 4 ] \
  || { echo "FAIL [6]: apenas $antes_ok de 4 formas escalares continuam válidas — o alargamento não é aditivo puro"; exit 1; }
echo "OK [6] — 4 de 4 formas escalares preservadas"

echo "[7] mutação — reverter o alargamento faz [2] e [3] reprovarem"
cp "$SCHEMA" "$T/schema.orig"
node -e '
  const fs=require("fs");
  const s=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  s.$defs.forgeFrontmatter.properties.runtime.properties.gates = { $ref: "#/$defs/nullableString" };
  fs.writeFileSync(process.argv[1], JSON.stringify(s,null,2)+"\n");
' "$SCHEMA"
cmp -s "$SCHEMA" "$T/schema.orig" && { echo "FAIL [7]: a mutação não alterou o schema"; exit 1; }
set +e
valida_gates '["check-authz"]' >/dev/null 2>&1; rc7a=$?
valida_gates '[{"name":"check-x","phase":"pre-deploy"}]' >/dev/null 2>&1; rc7b=$?
set -e
cp "$T/schema.orig" "$SCHEMA"
cmp -s "$SCHEMA" "$T/schema.orig" || { echo "FAIL [7]: restauração do schema não bateu byte a byte"; exit 1; }
[ "$rc7a" -ne 0 ] && [ "$rc7b" -ne 0 ] \
  || { echo "FAIL [7]: com o alargamento revertido as formas continuaram válidas (rc $rc7a/$rc7b) — [2] e [3] não medem o schema"; exit 1; }
set +e
valida_gates '["check-authz"]' >/dev/null 2>&1; rc7c=$?
set -e
[ "$rc7c" -eq 0 ] || { echo "FAIL [7]: recontrole — depois da restauração a block-sequence voltou a reprovar"; exit 1; }
echo "OK [7] — revertido, [2] e [3] reprovam; restaurado, voltam a passar"

echo "PASS w199-schema-reader-parity"
