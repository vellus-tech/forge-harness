#!/usr/bin/env bash
# Gate W6.3 — exercita o subcomando `forge update` (overlay aditivo de maquinaria):
#   [1] guarda: update num diretório SEM .forge -> exit 3
#   [2] --dry-run não escreve no disco e reporta template_version pendente
#   [3] update aplica: specs/ADR preservados byte-a-byte, runners.yaml preservado,
#       forge.yaml (template_version + adapters) atualizado corretamente, ÓRFÃO de
#       maquinaria REMOVIDO (reconciliação ao template), custom/ preservado, chave de
#       topo nova do forge.yaml (autonomy) mesclada, arquivo novo de maquinaria chega
#   [4] backup: .forge.bak-1 no primeiro run; --no-backup não cria .forge.bak-2
#   [5] doctor --report roda limpo pós-update (spec citando .claude/ não é falso-positivo)
#   [6] idempotência: um segundo --dry-run após aplicar reporta "nada a atualizar"
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w63.XXXXXX)"
trap 'rm -rf "$T"' EXIT

PKG_VERSION="$(node -e "process.stdout.write(JSON.parse(require('node:fs').readFileSync(process.argv[1],'utf8')).version)" "$WS/package.json")"

git -C "$T" init -q
git -C "$T" config user.email "fixture@test"
git -C "$T" config user.name "fixture"

echo "[0] guarda: update sem .forge instalado -> exit 3"
set +e
out="$(node "$WS/bin/forge.mjs" update --target "$T" --no-plugin 2>&1)"
rc=$?
set -e
[ "$rc" -eq 3 ] || { echo "FAIL (esperado exit 3, veio $rc)"; echo "$out"; exit 1; }
echo "OK [0] (exit 3, sugestão de init)"

echo "[1] instala o harness"
node "$WS/bin/forge.mjs" init --target "$T" --slug demo --name Demo --desc t --yes --no-plugin >"$T/init.log" 2>&1 \
  || { echo "FAIL (init falhou)"; cat "$T/init.log"; exit 1; }
[ -f "$T/.forge/forge.yaml" ]
echo "OK [1]"

echo "[2] injeta dado de produto + órfão de maquinaria + força versão antiga"
mkdir -p "$T/.forge/specs/active/demo"
cat > "$T/.forge/specs/active/demo/manifest.yaml" <<'EOF'
id: demo
scale: 2
type: feature
status: requirements-ready
EOF
cat > "$T/.forge/specs/active/demo/notes.md" <<'EOF'
# Notas

Este spec cita .claude/ no texto para checar falso-positivo do doctor.
EOF
mkdir -p "$T/.forge/product/current/adr"
cat > "$T/.forge/product/current/adr/0001-x.md" <<'EOF'
# ADR 0001

Decisão de teste.
EOF

# runners.yaml: alterna enabled: false -> true (se existir), senão anexa marca
if grep -q 'enabled: false' "$T/.forge/runners.yaml" 2>/dev/null; then
  perl -0pi -e 's/enabled: false/enabled: true/' "$T/.forge/runners.yaml"
else
  printf '\n# fixture-marker: custom-runner-flag\n' >> "$T/.forge/runners.yaml"
fi

# órfão TOMBSTONED: commands/graph/build.md está em installer/removed-files.txt (o /forge:build
# renomeado para /forge:codegraph). Deve ser REMOVIDO pelo update.
mkdir -p "$T/.forge/commands/graph"
cat > "$T/.forge/commands/graph/build.md" <<'EOF'
# comando órfão tombstoned — o template renomeou; o update deve removê-lo
EOF

# arquivo AUTORAL do consumidor sob maquinaria, NÃO tombstoned: um projeto pode legitimamente ter um
# command próprio em .forge/ (é assim que sync-adapters/plugin-build o descobrem). O update NÃO pode
# apagá-lo — a deleção é curada por tombstone, não "tudo fora do template". Esta é a invariante de
# segurança que o achado da revisão adversarial exige.
mkdir -p "$T/.forge/commands/harness"
cat > "$T/.forge/commands/harness/ZZ-autoral.md" <<'EOF'
# command autoral do consumidor — NÃO está na lista de tombstones; deve ser preservado pelo update
EOF

# customização sancionada em custom/ (NÃO é dir de maquinaria) — DEVE ser preservada
mkdir -p "$T/.forge/custom/rules"
cat > "$T/.forge/custom/rules/minha-regra.md" <<'EOF'
# regra custom do projeto — override oficial, preservado pelo update
EOF
SHA_CUSTOM_BEFORE="$(shasum -a 256 "$T/.forge/custom/rules/minha-regra.md" | cut -d' ' -f1)"

# remove o bloco autonomy do forge.yaml do projeto (simula projeto de versão anterior à feature):
# o update deve MESCLAR a chave de topo nova de volta a partir do template.
perl -0pi -e 's/\nautonomy:.*\z//s' "$T/.forge/forge.yaml"
grep -q '^autonomy:' "$T/.forge/forge.yaml" && { echo "FAIL (autonomy não foi removido do fixture)"; exit 1; }

# força template_version antiga
perl -0pi -e 's/template_version: "[^"]*"/template_version: "0.0.1-old"/' "$T/.forge/forge.yaml"
grep -q 'template_version: "0.0.1-old"' "$T/.forge/forge.yaml"

SHA_MANIFEST_BEFORE="$(shasum -a 256 "$T/.forge/specs/active/demo/manifest.yaml" | cut -d' ' -f1)"
SHA_NOTES_BEFORE="$(shasum -a 256 "$T/.forge/specs/active/demo/notes.md" | cut -d' ' -f1)"
SHA_ADR_BEFORE="$(shasum -a 256 "$T/.forge/product/current/adr/0001-x.md" | cut -d' ' -f1)"
SHA_RUNNERS_BEFORE="$(shasum -a 256 "$T/.forge/runners.yaml" | cut -d' ' -f1)"
ADAPTERS_BEFORE="$(awk '/^  adapters:/{g=1;next} g&&/^    - /{print;next} g{exit}' "$T/.forge/forge.yaml")"
echo "OK [2]"

echo "[3] --dry-run não escreve no disco"
out="$(node "$WS/bin/forge.mjs" update --target "$T" --dry-run --no-plugin)"
echo "$out" | grep -q 'template_version' || { echo "FAIL (dry-run não menciona template_version)"; echo "$out"; exit 1; }
[ "$(shasum -a 256 "$T/.forge/specs/active/demo/manifest.yaml" | cut -d' ' -f1)" = "$SHA_MANIFEST_BEFORE" ] \
  || { echo "FAIL (dry-run alterou disco: manifest.yaml)"; exit 1; }
grep -q 'template_version: "0.0.1-old"' "$T/.forge/forge.yaml" || { echo "FAIL (dry-run alterou forge.yaml)"; exit 1; }
echo "OK [3] (dry-run não escreveu; reportou template_version pendente)"

echo "[4] update aplicado (source = template do repo)"
node "$WS/bin/forge.mjs" update --target "$T" --no-plugin --source "$WS/template/.forge" >"$T/update1.log" 2>&1 \
  || { echo "FAIL (update falhou)"; cat "$T/update1.log"; exit 1; }

# [a] spec + ADR byte-idênticos
[ "$(shasum -a 256 "$T/.forge/specs/active/demo/manifest.yaml" | cut -d' ' -f1)" = "$SHA_MANIFEST_BEFORE" ] \
  || { echo "FAIL [a] (manifest.yaml não preservado)"; exit 1; }
[ "$(shasum -a 256 "$T/.forge/specs/active/demo/notes.md" | cut -d' ' -f1)" = "$SHA_NOTES_BEFORE" ] \
  || { echo "FAIL [a] (notes.md não preservado)"; exit 1; }
[ "$(shasum -a 256 "$T/.forge/product/current/adr/0001-x.md" | cut -d' ' -f1)" = "$SHA_ADR_BEFORE" ] \
  || { echo "FAIL [a] (ADR não preservado)"; exit 1; }
echo "OK [a] (spec + ADR byte-idênticos)"

# [b] runners.yaml inalterado
[ "$(shasum -a 256 "$T/.forge/runners.yaml" | cut -d' ' -f1)" = "$SHA_RUNNERS_BEFORE" ] \
  || { echo "FAIL [b] (runners.yaml foi tocado pelo update)"; exit 1; }
echo "OK [b] (runners.yaml preservado)"

# [c] forge.yaml: template_version = versão do pacote; adapters idêntico
grep -q "template_version: \"$PKG_VERSION\"" "$T/.forge/forge.yaml" \
  || { echo "FAIL [c] (template_version não bateu com package.json: $PKG_VERSION)"; grep template_version "$T/.forge/forge.yaml"; exit 1; }
ADAPTERS_AFTER="$(awk '/^  adapters:/{g=1;next} g&&/^    - /{print;next} g{exit}' "$T/.forge/forge.yaml")"
[ "$ADAPTERS_AFTER" = "$ADAPTERS_BEFORE" ] || { echo "FAIL [c] (lista adapters mudou)"; exit 1; }
echo "OK [c] (template_version + adapters corretos)"

# [d] órfão TOMBSTONED removido (fecha o buraco do overlay aditivo — /forge:build stale)
[ ! -f "$T/.forge/commands/graph/build.md" ] || { echo "FAIL [d] (órfão tombstoned sobreviveu — deveria ter sido removido)"; exit 1; }
echo "OK [d] (órfão tombstoned removido)"

# [d1] SEGURANÇA: arquivo autoral do consumidor (NÃO tombstoned) preservado — a deleção é curada,
# não reconciliação cega ao template (senão apagaria trabalho real do consumidor)
[ -f "$T/.forge/commands/harness/ZZ-autoral.md" ] || { echo "FAIL [d1] (command autoral do consumidor foi apagado — deleção não é curada!)"; exit 1; }
echo "OK [d1] (arquivo autoral não-tombstoned preservado)"

# [d2] custom/ preservado byte-a-byte (a via sancionada de customização não é tocada)
[ -f "$T/.forge/custom/rules/minha-regra.md" ] || { echo "FAIL [d2] (custom/ foi removido pela reconciliação)"; exit 1; }
[ "$(shasum -a 256 "$T/.forge/custom/rules/minha-regra.md" | cut -d' ' -f1)" = "$SHA_CUSTOM_BEFORE" ] \
  || { echo "FAIL [d2] (custom/ foi alterado)"; exit 1; }
echo "OK [d2] (custom/ preservado)"

# [d3] chave de topo nova do forge.yaml mesclada de volta a partir do template
grep -q '^autonomy:' "$T/.forge/forge.yaml" || { echo "FAIL [d3] (bloco autonomy não foi mesclado no forge.yaml)"; exit 1; }
grep -qE '^  mode: hitl$' "$T/.forge/forge.yaml" || { echo "FAIL [d3] (autonomy mesclado sem o default mode: hitl)"; exit 1; }
echo "OK [d3] (chave de topo nova mesclada — merge aditivo de forge.yaml)"

# [e] arquivo novo de maquinaria chegou
[ -f "$T/.forge/commands/harness/upgrade.md" ] || { echo "FAIL [e] (upgrade.md não chegou pelo overlay)"; exit 1; }
[ -f "$T/.forge/scripts/handoff-gen.sh" ] || { echo "FAIL [e] (handoff-gen.sh não chegou pelo overlay)"; exit 1; }
echo "OK [e] (maquinaria nova aplicada)"

# [f] backup: .forge.bak-1 criado; segundo run com --no-backup não cria .bak-2
[ -d "$T/.forge.bak-1" ] || { echo "FAIL [f] (.forge.bak-1 não foi criado)"; exit 1; }
node "$WS/bin/forge.mjs" update --target "$T" --no-plugin --no-backup --source "$WS/template/.forge" >"$T/update2.log" 2>&1 \
  || { echo "FAIL (segundo update --no-backup falhou)"; cat "$T/update2.log"; exit 1; }
[ ! -d "$T/.forge.bak-2" ] || { echo "FAIL [f] (--no-backup criou backup mesmo assim)"; exit 1; }
echo "OK [f] (backup no 1º run; --no-backup pula no 2º)"

# [g] doctor --report limpo, sem falso-positivo por causa do texto ".claude/" na spec
doctor_out="$(bash "$T/.forge/scripts/doctor.sh" --report)"
echo "$doctor_out" | grep -qi 'sem refs .claude' || { echo "FAIL [g] (doctor não reportou 'sem refs .claude/' — falso-positivo?)"; echo "$doctor_out"; exit 1; }
echo "$doctor_out" | grep -qi 'sem placeholders' || { echo "FAIL [g] (doctor não reportou 'sem placeholders')"; echo "$doctor_out"; exit 1; }
echo "OK [g] (doctor limpo; spec citando .claude/ não gerou falso-positivo)"

echo "OK [4]"

echo "[5] idempotência: dry-run pós-update reporta nada a atualizar"
out="$(node "$WS/bin/forge.mjs" update --target "$T" --dry-run --no-plugin --source "$WS/template/.forge")"
echo "$out" | grep -qi 'nada a atualizar' || { echo "FAIL (dry-run pós-update não é idempotente)"; echo "$out"; exit 1; }
echo "OK [5]"

echo "[6] invariante das tombstones: nenhum path em removed-files.txt existe no template atual"
# se um tombstone existisse no template, o overlay o escreveria e a tombstone o apagaria em seguida
MANIFEST="$WS/installer/removed-files.txt"
[ -f "$MANIFEST" ] || { echo "FAIL [6] (installer/removed-files.txt ausente)"; exit 1; }
while IFS= read -r line; do
  path="${line%%#*}"; path="$(echo "$path" | xargs)"   # tira comentário + espaços
  [ -n "$path" ] || continue
  [ ! -e "$WS/template/.forge/$path" ] || { echo "FAIL [6] (tombstone '$path' AINDA existe no template — o update o escreveria e apagaria)"; exit 1; }
done < "$MANIFEST"
echo "OK [6] (todas as tombstones ausentes do template)"

echo "PASS w63-forge-update-gate"
