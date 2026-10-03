#!/usr/bin/env bash
# Gate W-frontend — skill frontend-ui-review: o scanner de token fantasma (A1, o gate mais
# importante) é o núcleo executável. Exercita o comportamento real, não só a presença.
#   [1] fixture COM token fantasma → exit 1 e reporta o token não definido
#   [2] fixture SEM fantasma (tudo definido) → exit 0
#   [3] allowlist suprime token injetado em runtime → exit 0
#   [4] artefatos presentes: SKILL.md (name correto), scanner, convenções 10-12 na rule, fiação no agent
#   [5] A4/#140 — controle nativo DOMADO (pseudo-elemento correto no CSS irmão) → OK
#   [6] A4/#140 — mesmo tipo de controle CRU (sem o pseudo) → WARN (contrafactual de [5])
#   [7] A4/#140 — PBT-lite: tipo × presença do pseudo × encapsulamento no DS → OK sse um escapa presente
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN="$WS/template/.forge/skills/frontend-ui-review/scripts/scan-phantom-tokens.py"
SCAN_NATIVE="$WS/template/.forge/skills/frontend-ui-review/scripts/scan-native-controls.py"
T="$(mktemp -d /tmp/forge-fe.XXXXXX)"
trap 'rm -rf "$T"' EXIT

command -v python3 >/dev/null 2>&1 || { echo "SKIP (python3 ausente)"; echo "PASS w96-frontend-ui-review-gate"; exit 0; }
[ -f "$SCAN" ] || { echo "FAIL (scanner ausente: $SCAN)"; exit 1; }
[ -f "$SCAN_NATIVE" ] || { echo "FAIL (scanner de controles nativos ausente: $SCAN_NATIVE)"; exit 1; }

# tokens definidos
printf ':root {\n  --surface-0: #fff;\n  --color-primary-500: #0051E6;\n}\n' > "$T/tokens.css"
mkdir -p "$T/src"

echo "[1] fixture com token fantasma → FAIL"
# --surface-0 definido (ok), --surface-1 NUNCA definido (fantasma)
printf '.card { background: var(--surface-0); color: var(--surface-1); }\n' > "$T/src/Card.module.css"
set +e
out="$(python3 "$SCAN" "$T/tokens.css" "$T/src")"; rc=$?
set -e
[ "$rc" -eq 1 ] || { echo "FAIL [1] (esperava exit 1, veio $rc)"; exit 1; }
grep -q 'PHANTOM --surface-1' <<<"$out" || { echo "FAIL [1] (não reportou --surface-1)"; exit 1; }
grep -q 'PHANTOM --surface-0' <<<"$out" && { echo "FAIL [1] (marcou token DEFINIDO como fantasma)"; exit 1; }
echo "OK [1]"

echo "[2] fixture sem fantasma → OK"
printf '.card { background: var(--surface-0); color: var(--color-primary-500); }\n' > "$T/src/Card.module.css"
set +e
python3 "$SCAN" "$T/tokens.css" "$T/src" >/dev/null; rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "FAIL [2] (esperava exit 0, veio $rc)"; exit 1; }
echo "OK [2]"

echo "[2b] token com maiúscula/underscore definido+referenciado → NÃO é fantasma"
# custom properties são case-sensitive; a regex precisa aceitar [A-Za-z0-9_-]. src isolado.
mkdir -p "$T/src2"
printf ':root { --gap-Large: 24px; --fontSize_base: 16px; }\n' > "$T/tokens2.css"
printf '.box { gap: var(--gap-Large); font-size: var(--fontSize_base); }\n' > "$T/src2/Box.module.css"
set +e
out2="$(python3 "$SCAN" "$T/tokens2.css" "$T/src2")"; rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "FAIL [2b] (token maiúsculo definido virou falso-positivo, exit $rc): $out2"; exit 1; }
echo "OK [2b]"

echo "[3] allowlist suprime token injetado em runtime → OK"
printf '.bar { width: var(--progress); background: var(--surface-0); }\n' > "$T/src/Bar.module.css"
set +e
python3 "$SCAN" "$T/tokens.css" "$T/src" "--progress" >/dev/null; rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "FAIL [3] (allowlist não suprimiu --progress, exit $rc)"; exit 1; }
# sem allowlist, --progress é fantasma → exit 1 (prova que a allowlist é que suprimiu)
set +e
python3 "$SCAN" "$T/tokens.css" "$T/src" >/dev/null; rc=$?
set -e
[ "$rc" -eq 1 ] || { echo "FAIL [3] (--progress deveria ser fantasma sem allowlist)"; exit 1; }
echo "OK [3]"

echo "[5] controle nativo DOMADO (pseudo-elemento correto no CSS irmão) → OK"
mkdir -p "$T/domado"
printf 'export const ColorPicker = () => <input type="color" />;\n' > "$T/domado/ColorPicker.tsx"
printf 'input::-webkit-color-swatch { border: none; }\n' > "$T/domado/ColorPicker.module.css"
set +e
out5="$(python3 "$SCAN_NATIVE" "$T/domado")"; rc5=$?
set -e
[ "$rc5" -eq 0 ] || { echo "FAIL [5] (advisory nunca bloqueia; esperava exit 0, veio $rc5)"; exit 1; }
grep -q '^OK color' <<<"$out5" || { echo "FAIL [5] (não reportou OK para o controle domado): $out5"; exit 1; }
grep -q '^WARN' <<<"$out5" && { echo "FAIL [5] (controle domado não deveria dar WARN): $out5"; exit 1; }
echo "OK [5]"

echo "[6] mesmo tipo de controle CRU (sem o pseudo, sem DS) → WARN (contrafactual de [5])"
mkdir -p "$T/cru"
printf 'export const ColorPickerCru = () => <input type="color" />;\n' > "$T/cru/ColorPickerCru.tsx"
printf '.wrapper { display: flex; }\n' > "$T/cru/ColorPickerCru.module.css"
set +e
out6="$(python3 "$SCAN_NATIVE" "$T/cru")"; rc6=$?
set -e
[ "$rc6" -eq 0 ] || { echo "FAIL [6] (advisory nunca bloqueia; esperava exit 0, veio $rc6)"; exit 1; }
grep -q '^WARN color' <<<"$out6" || { echo "FAIL [6] (não reportou WARN para o controle cru): $out6"; exit 1; }
grep -q '^OK color' <<<"$out6" && { echo "FAIL [6] (controle cru não deveria dar OK): $out6"; exit 1; }
echo "OK [6]"

echo "[7] PBT-lite: tipo × pseudo × encapsulamento — OK sse um dos dois escapes presente"
# combinações: (tipo, pseudo correto?, encapsulado no DS?) -> veredito esperado
casos=(
  "file|::file-selector-button|não|OK"
  "file||não|WARN"
  "range|::-webkit-slider-thumb|não|OK"
  "range||não|WARN"
  "date||sim|OK"
  "date||não|WARN"
)
i=0
for caso in "${casos[@]}"; do
  i=$((i + 1))
  IFS='|' read -r tipo pseudo encapsulado esperado <<<"$caso"
  dir="$T/pbt$i"
  mkdir -p "$dir"
  if [ "$encapsulado" = "sim" ]; then
    printf 'import { NativeDate } from "@acme/design-system";\nexport const C = () => <NativeDate><input type="%s" /></NativeDate>;\n' "$tipo" > "$dir/C.tsx"
  else
    printf 'export const C = () => <input type="%s" />;\n' "$tipo" > "$dir/C.tsx"
  fi
  if [ -n "$pseudo" ]; then
    printf 'input%s { border: none; }\n' "$pseudo" > "$dir/C.module.css"
  else
    printf '.wrapper { display: flex; }\n' > "$dir/C.module.css"
  fi
  set +e
  outp="$(python3 "$SCAN_NATIVE" "$dir")"; rcp=$?
  set -e
  [ "$rcp" -eq 0 ] || { echo "FAIL [7] caso $i (advisory nunca bloqueia; veio $rcp)"; exit 1; }
  if [ "$esperado" = "OK" ]; then
    grep -q "^OK $tipo" <<<"$outp" || { echo "FAIL [7] caso $i ($caso) — esperava OK: $outp"; exit 1; }
  else
    grep -q "^WARN $tipo" <<<"$outp" || { echo "FAIL [7] caso $i ($caso) — esperava WARN: $outp"; exit 1; }
  fi
done
echo "OK [7] — ${#casos[@]} combinações conferidas"

echo "[8] falsos OK da revisão #140 — contrafactuais: exigem WARN (ou OK onde o escape é legítimo)"
# expect_verdict <rótulo> <dir> <tipo> <OK|WARN>: advisory sai 0 e o veredito do tipo confere
expect_verdict() {
  local label="$1" dir="$2" tipo="$3" esperado="$4" out
  out="$(python3 "$SCAN_NATIVE" "$dir")" || { echo "FAIL [8] $label (advisory deve sair 0)"; exit 1; }
  if [ "$esperado" = "OK" ]; then
    grep -q "^OK $tipo" <<<"$out" || { echo "FAIL [8] $label — esperava OK: $out"; exit 1; }
  else
    grep -q "^WARN $tipo" <<<"$out" || { echo "FAIL [8] $label — esperava WARN: $out"; exit 1; }
  fi
  echo "  ok $label"
}
# (a) encapsulamento: import sem uso, menção solta, uso em outro bloco -> WARN; uso no mesmo bloco -> OK
mkdir -p "$T/a1" "$T/a2" "$T/a4" "$T/a3"
printf 'import { Btn } from "@acme/design-system";\nexport const C = () => <input type="color" />;\n' > "$T/a1/C.tsx"
printf '// design-system\n\nexport const C = () => <input type="color" />;\n' > "$T/a2/C.tsx"
printf 'import { Btn } from "@acme/design-system";\n\nexport const C = () => <Btn>ok</Btn>;\n\nexport const D = () => <input type="color" />;\n' > "$T/a4/D.tsx"
printf 'import { Btn } from "@acme/design-system";\nexport const C = () => <Btn><input type="color" /></Btn>;\n' > "$T/a3/C.tsx"
expect_verdict "(a) import sem uso no bloco -> WARN" "$T/a1" color WARN
expect_verdict "(a) menção 'design-system' sem import -> WARN" "$T/a2" color WARN
expect_verdict "(a) DS usado em outro bloco -> WARN" "$T/a4" color WARN
expect_verdict "(a) DS usado no mesmo bloco -> OK (positiva)" "$T/a3" color OK
# (b) CSS irmão de OUTRO componente não domestica
mkdir -p "$T/b"
printf 'export const Cru = () => <input type="color" />;\n' > "$T/b/Cru.tsx"
printf 'input::-webkit-color-swatch { border: none; }\n' > "$T/b/Outro.module.css"
expect_verdict "(b) CSS de outro componente -> WARN" "$T/b" color WARN
# (c) appearance none em seletor global, sem alcançar o select ou a classe do controle -> WARN; com a classe -> OK
mkdir -p "$T/c1" "$T/c2"
printf 'export const S = () => <select className="cru"><option>x</option></select>;\n' > "$T/c1/S.tsx"
printf '.outro { appearance: none; }\n' > "$T/c1/S.module.css"
printf 'export const S = () => <select className="cru"><option>x</option></select>;\n' > "$T/c2/S.tsx"
printf '.cru { appearance: none; }\n' > "$T/c2/S.module.css"
expect_verdict "(c) appearance none global/alheio -> WARN" "$T/c1" select WARN
expect_verdict "(c) appearance none na classe do controle -> OK (positiva)" "$T/c2" select OK
# (d) checkbox domado por -webkit-appearance (propriedade real) -> OK
mkdir -p "$T/d"
printf 'export const Chk = () => <input type="checkbox" />;\n' > "$T/d/Chk.tsx"
printf 'input { -webkit-appearance: none; }\n' > "$T/d/Chk.module.css"
expect_verdict "(d) checkbox com -webkit-appearance -> OK" "$T/d" checkbox OK
# (e) aspas simples no atributo type -> o controle é detectado e, sem domesticação, WARN
mkdir -p "$T/e"
printf "export const Q = () => <input type='color' />;\n" > "$T/e/Q.tsx"
expect_verdict "(e) aspas simples, cru -> WARN" "$T/e" color WARN
echo "OK [8] — 9 contrafactuais conferidos"

echo "[4] artefatos + fiação presentes"
SK="$WS/template/.forge/skills/frontend-ui-review/SKILL.md"
[ -f "$SK" ] || { echo "FAIL [4] (SKILL.md ausente)"; exit 1; }
grep -qE '^name: frontend-ui-review$' "$SK" || { echo "FAIL [4] (name errado no frontmatter)"; exit 1; }
DS="$WS/template/.forge/rules/frontend/design-system.md"
grep -q 'Token fantasma é proibido' "$DS" || { echo "FAIL [4] (regra 10 ausente na DS rule)"; exit 1; }
grep -q 'Sem fallback literal' "$DS" || { echo "FAIL [4] (regra 11 ausente)"; exit 1; }
grep -q 'Controle nativo do browser é domado' "$DS" || { echo "FAIL [4] (regra 12 ausente)"; exit 1; }
grep -q 'frontend-ui-review' "$WS/template/.forge/agents/engineering/frontend-engineer.md" || { echo "FAIL [4] (agent não referencia a skill)"; exit 1; }
echo "OK [4]"

echo "PASS w96-frontend-ui-review-gate"
