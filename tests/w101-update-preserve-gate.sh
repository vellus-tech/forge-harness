#!/usr/bin/env bash
# Gate W101 — `forge update` preserva customizações locais em rules/agents/skills (issue #16):
#   [1] rule customizada ANTES do 1º update (sem lock) → preservada por fallback conservador,
#       reportada como "preservados"; rule local nova (fora do template) intacta;
#       machinery.lock escrito com hashes do TEMPLATE
#   [2] com lock: rule NÃO customizada + template muda → sobrescrita (upgrade limpo via lock)
#   [3] com lock: rule customizada + template muda → PRESERVADA (nunca revertida)
#   [4] script (maquinaria própria) com fix local → sobrescrito COM aviso de drift
#   [5] dry-run marca "= <rel> (preservado — customização local)" e não escreve
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w101.XXXXXX)"
trap 'rm -rf "$T"' EXIT

git -C "$T" init -q
git -C "$T" config user.email "fixture@test"
git -C "$T" config user.name "fixture"

node "$WS/bin/forge.mjs" init --target "$T" --slug demo --name Demo --desc t --yes --no-plugin >"$T/init.log" 2>&1 \
  || { echo "FAIL (init falhou)"; cat "$T/init.log"; exit 1; }

RULE=".forge/rules/architecture/clean-architecture.md"
RULE_REL="rules/architecture/clean-architecture.md"

echo "[1] customização pré-lock preservada + lock escrito"
printf '\n> **Diretiva do owner (fixture):** camada de domínio nunca importa infraestrutura.\n' >> "$T/$RULE"
SHA_CUSTOM="$(shasum -a 256 "$T/$RULE" | cut -d' ' -f1)"
mkdir -p "$T/.forge/rules/domain"
printf '# regra local do projeto — não existe no template\n' > "$T/.forge/rules/domain/regra-local.md"
node "$WS/bin/forge.mjs" update --target "$T" --no-plugin --source "$WS/template/.forge" >"$T/up1.log" 2>&1 \
  || { echo "FAIL (update 1 falhou)"; cat "$T/up1.log"; exit 1; }
[ "$(shasum -a 256 "$T/$RULE" | cut -d' ' -f1)" = "$SHA_CUSTOM" ] \
  || { echo "FAIL [1]: customização da rule foi sobrescrita (issue #16 regrediu)"; exit 1; }
grep -q "= $RULE_REL" "$T/up1.log" || { echo "FAIL [1]: preservação não reportada"; grep -i preserv "$T/up1.log"; exit 1; }
[ -f "$T/.forge/rules/domain/regra-local.md" ] || { echo "FAIL [1]: rule local nova sumiu"; exit 1; }
LOCK="$T/.forge/cache/machinery.lock"
[ -f "$LOCK" ] || { echo "FAIL [1]: machinery.lock não escrito"; exit 1; }
# o lock registra o hash do TEMPLATE (não do arquivo local customizado)
SHA_TPL="$(shasum -a 256 "$WS/template/.forge/$RULE_REL" | cut -d' ' -f1)"
grep -q "^$SHA_TPL  $RULE_REL\$" "$LOCK" || { echo "FAIL [1]: lock não registra hash do template para a rule"; exit 1; }
echo "OK [1]"

echo "[2] upgrade limpo via lock: rule intocada + template novo → sobrescreve"
SRC2="$T/src2"; cp -R "$WS/template/.forge" "$SRC2"
printf '\n<!-- template v2: parágrafo novo -->\n' >> "$SRC2/rules/architecture/ddd.md"
node "$WS/bin/forge.mjs" update --target "$T" --no-plugin --no-backup --source "$SRC2" >"$T/up2.log" 2>&1 \
  || { echo "FAIL (update 2 falhou)"; cat "$T/up2.log"; exit 1; }
grep -q 'template v2' "$T/.forge/rules/architecture/ddd.md" \
  || { echo "FAIL [2]: rule não-customizada não recebeu o template novo (lock quebrou o upgrade limpo)"; exit 1; }
echo "OK [2]"

echo "[3] com lock: rule customizada + template novo → preservada"
printf '\n<!-- template v3: mudança que NÃO deve chegar -->\n' >> "$SRC2/rules/architecture/clean-architecture.md"
node "$WS/bin/forge.mjs" update --target "$T" --no-plugin --no-backup --source "$SRC2" >"$T/up3.log" 2>&1 \
  || { echo "FAIL (update 3 falhou)"; cat "$T/up3.log"; exit 1; }
[ "$(shasum -a 256 "$T/$RULE" | cut -d' ' -f1)" = "$SHA_CUSTOM" ] \
  || { echo "FAIL [3]: rule customizada foi revertida mesmo com lock"; exit 1; }
grep -q "= $RULE_REL" "$T/up3.log" || { echo "FAIL [3]: preservação não reportada no update 3"; exit 1; }
echo "OK [3]"

echo "[4] script com fix local → sobrescrito com WARN de drift"
printf '\n# fix local no script (deveria ser upstream)\n' >> "$T/.forge/scripts/handoff-gen.sh"
node "$WS/bin/forge.mjs" update --target "$T" --no-plugin --no-backup --source "$SRC2" >"$T/up4.log" 2>&1 \
  || { echo "FAIL (update 4 falhou)"; cat "$T/up4.log"; exit 1; }
grep -q 'fix local no script' "$T/.forge/scripts/handoff-gen.sh" && { echo "FAIL [4]: script não foi sobrescrito (scripts são maquinaria própria)"; exit 1; }
grep -q 'WARN: drift local em scripts/handoff-gen.sh' "$T/up4.log" || { echo "FAIL [4]: drift de script sobrescrito sem aviso"; grep -i drift "$T/up4.log"; exit 1; }
echo "OK [4]"

echo "[5] dry-run marca preservação e não escreve"
printf '\n<!-- template v4 -->\n' >> "$SRC2/rules/architecture/clean-architecture.md"
out="$(node "$WS/bin/forge.mjs" update --target "$T" --dry-run --no-plugin --source "$SRC2")"
echo "$out" | grep -q "= $RULE_REL (preservado — customização local)" \
  || { echo "FAIL [5]: dry-run não marcou preservação"; echo "$out" | head; exit 1; }
[ "$(shasum -a 256 "$T/$RULE" | cut -d' ' -f1)" = "$SHA_CUSTOM" ] || { echo "FAIL [5]: dry-run escreveu"; exit 1; }
echo "OK [5]"

echo "[6] tombstone respeita customização enriquecível (deleta só template intocado)"
# fonte v3 SEM as duas rules (removidas do template) + manifest sintético de tombstones
SRC3="$T/src3"; cp -R "$SRC2" "$SRC3"
rm -f "$SRC3/rules/architecture/clean-architecture.md" "$SRC3/rules/architecture/ddd.md"
cat > "$T/tombstones.txt" <<'EOF'
rules/architecture/clean-architecture.md
rules/architecture/ddd.md
EOF
FORGE_REMOVED_MANIFEST="$T/tombstones.txt" node "$WS/bin/forge.mjs" update --target "$T" --no-plugin --no-backup --source "$SRC3" >"$T/up6.log" 2>&1 \
  || { echo "FAIL (update 6 falhou)"; cat "$T/up6.log"; exit 1; }
# customizada → mantida, com aviso; intocada (hash == lock) → removida
[ -f "$T/$RULE" ] || { echo "FAIL [6]: tombstone deletou rule CUSTOMIZADA (invariante do overlay violada)"; exit 1; }
[ "$(shasum -a 256 "$T/$RULE" | cut -d' ' -f1)" = "$SHA_CUSTOM" ] || { echo "FAIL [6]: rule customizada alterada"; exit 1; }
grep -q "= $RULE_REL (tombstone pulado" "$T/up6.log" || { echo "FAIL [6]: tombstone pulado sem aviso"; grep -i tombstone "$T/up6.log"; exit 1; }
[ ! -f "$T/.forge/rules/architecture/ddd.md" ] || { echo "FAIL [6]: tombstone não removeu rule intocada (template intacto deveria sair)"; exit 1; }
echo "OK [6]"

echo "PASS w101-update-preserve-gate"
