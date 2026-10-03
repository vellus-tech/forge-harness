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
#   [8] A4/#140 — import sem uso, CSS alheio, appearance global, aspas simples → WARN (com positivas)
#   [9] A4/#140 — propriedade real vs pseudo inexistente, DS que ENVOLVE vs irmão, comentário não
#       domestica, seletor que não alcança o controle, linha em branco no JSX, type={"file"}, tag do
#       DS dentro de string, apóstrofo em texto JSX e controle dentro de ${...} de template literal
#   [10] A4/#140 — análise por AST: string, comentário e texto de template não são elementos JSX;
#        .vue/.html pelo html.parser; arquivo não lido pelo parser ou helper ausente → WARN não analisado
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
  out="$(python3 "$SCAN_NATIVE" "$dir")" || { echo "FAIL [${SCEN:-8}] $label (advisory deve sair 0)"; exit 1; }
  if [ "$esperado" = "OK" ]; then
    grep -q "^OK $tipo" <<<"$out" || { echo "FAIL [${SCEN:-8}] $label — esperava OK: $out"; exit 1; }
  else
    grep -q "^WARN $tipo" <<<"$out" || { echo "FAIL [${SCEN:-8}] $label — esperava WARN: $out"; exit 1; }
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

echo "[9] seletor e envolvimento reais — contrafactuais exigem WARN; casos legítimos exigem OK"
SCEN=9
# expect9 <rótulo> <tipo> <OK|WARN> <arquivo-componente> <conteúdo> [<arquivo-css> <conteúdo-css>]
n9=0
expect9() {
  local label="$1" tipo="$2" esperado="$3" dir
  n9=$((n9 + 1)); dir="$T/n9-$n9"; mkdir -p "$dir"
  printf '%b' "$5" > "$dir/$4"
  if [ "$#" -ge 7 ]; then printf '%b' "$7" > "$dir/$6"; fi
  expect_verdict "$label" "$dir" "$tipo" "$esperado"
}
CHK='export const Chk = () => <input type="checkbox" className="box" />;\n'
COL='export const P = () => <input type="color" className="sw" />;\n'
# (d) pseudo inexistente ::-webkit-appearance não é a propriedade -webkit-appearance
expect9 "(d) input::-webkit-appearance { appearance: none } -> WARN" checkbox WARN Chk.tsx "$CHK" Chk.module.css 'input::-webkit-appearance { appearance: none; }\n'
expect9 "(d) input { -webkit-appearance: none } -> OK (positiva)" checkbox OK Chk.tsx "$CHK" Chk.module.css 'input {\n  -webkit-appearance: none;\n}\n'
# B1 — DS irmão do controle no mesmo bloco não envolve; DS que envolve (ou é a tag do controle) envolve
expect9 "(B1) <Button> irmão no mesmo bloco -> WARN" color WARN C.tsx 'import { Button } from "@acme/design-system";\nexport const C = () => (\n  <div>\n    <Button>ok</Button>\n    <input type="color" />\n  </div>\n);\n'
expect9 "(B1) <Button /> autofechado antes do controle -> WARN" color WARN C.tsx 'import { Button } from "@acme/design-system";\nexport const C = () => <div><Button onClick={() => x > 1} /><input type="color" /></div>;\n'
expect9 "(B1) DS envolve o controle -> OK (positiva)" color OK C.tsx 'import { Field } from "@acme/design-system";\nexport const C = () => <Field label="Cor"><input type="color" /></Field>;\n'
expect9 "(B1) o controle é a tag do DS -> OK (positiva)" color OK C.tsx 'import { ColorInput } from "@acme/design-system";\nexport const C = () => <ColorInput type="color" />;\n'
# B2/B3 — texto em comentário (CSS ou JSX) não domestica
expect9 "(B2) /* accent-color */ no CSS -> WARN" checkbox WARN Chk.tsx "$CHK" Chk.module.css 'input { /* accent-color */ border: 0; }\n'
expect9 "(B2) /* accent-color: red */ no CSS -> WARN" checkbox WARN Chk.tsx "$CHK" Chk.module.css 'input { /* accent-color: red; */ border: 0; }\n'
expect9 "(B2) input { accent-color: x } -> OK (positiva)" checkbox OK Chk.tsx "$CHK" Chk.module.css 'input { accent-color: var(--color-primary-500); }\n'
expect9 "(B3) /* ::-webkit-color-swatch */ no CSS -> WARN" color WARN P.tsx "$COL" P.module.css '/* input::-webkit-color-swatch { border: none } */\ninput { border: 0; }\n'
expect9 "(B3) {/* ::-webkit-color-swatch */} no JSX -> WARN" color WARN P.tsx 'export const P = () => (\n  <div>\n    {/* input::-webkit-color-swatch { border: none } */}\n    <input type="color" />\n  </div>\n);\n'
expect9 "(B3) // ::-webkit-color-swatch no SCSS -> WARN" color WARN P.tsx "$COL" P.module.scss '// input::-webkit-color-swatch { border: none }\n.sw { background: url(//cdn.x/y.png); }\n'
# B4 — escape de CSS só vale se o seletor alcança o controle (tag ou classe usada no controle)
expect9 "(B4) .card { -webkit-appearance: none } -> WARN" checkbox WARN Chk.tsx "$CHK" Chk.module.css '.card { -webkit-appearance: none; }\n'
expect9 "(B4) .card::-webkit-color-swatch -> WARN" color WARN P.tsx "$COL" P.module.css '.card::-webkit-color-swatch { border: none; }\n'
expect9 "(B4) .box { -webkit-appearance: none } (classe do controle) -> OK (positiva)" checkbox OK Chk.tsx "$CHK" Chk.module.css '.box { -webkit-appearance: none; }\n'
expect9 "(B4) .wrap .sw::-webkit-color-swatch (classe do controle) -> OK (positiva)" color OK P.tsx "$COL" P.module.css '.wrap .sw::-webkit-color-swatch { border: none; }\n'
expect9 "(B4) ::-webkit-color-swatch sem tag nem classe -> OK (positiva)" color OK P.tsx "$COL" P.module.css '::-webkit-color-swatch { border: none; }\n'
# B5 — linha em branco dentro do JSX entre o DS e o controle não quebra o envolvimento
expect9 "(B5) DS envolve com linha em branco no meio -> OK" color OK C.tsx 'import { Field } from "@acme/design-system";\nexport const C = () => (\n  <Field>\n\n    <input type="color" />\n\n  </Field>\n);\n'
# B7 — type={"file"} e type={'"'"'file'"'"'} são detectados
expect9 "(B7) type={\"file\"} cru -> WARN" file WARN U.tsx 'export const U = () => <input type={"file"} />;\n'
expect9 "(B7) type={'file'} domado -> OK (positiva)" file OK U.tsx "export const U = () => <input type={'file'} />;\n" U.module.css 'input::file-selector-button { border: none; }\n'
# B6 — conteúdo de string literal não conta como tag do DS: "<DsBox>" e "</DsBox>" soltos não envolvem
expect9 "(B6) <DsBox> e </DsBox> dentro de strings não envolvem -> WARN" color WARN Brecha.tsx 'import { DsBox } from "@x/design-system";\nconst s = "<DsBox>";\nexport const C = () => <><input type="color" /></>;\nconst t = "</DsBox>";\n'
expect9 "(B6) string simples com tag do DS não envolve -> WARN" color WARN Brecha.tsx "import { DsBox } from \"@x/design-system\";\nconst s = '<DsBox>';\nexport const C = () => <><input type=\"color\" /></>;\nconst t = '</DsBox>';\n"
expect9 "(B6) template literal com tag do DS não envolve -> WARN" color WARN Brecha.tsx 'import { DsBox } from "@x/design-system";\nconst s = `<DsBox>`;\nexport const C = () => <><input type="color" /></>;\nconst t = `</DsBox>`;\n'
expect9 "(B6) DS aberto sem fechar, fechamento só em {\"</DsBox>\"} (JSX inválido) -> WARN não analisado" "não-analisado" WARN Brecha.tsx 'import { DsBox } from "@x/design-system";\nexport const C = () => <div><DsBox><input type="color" />{"</DsBox>"}</div>;\n'
# B6 positiva — uma string antes do DS não atrapalha o envolvimento real
expect9 "(B6) const s = \"x\" antes do DS que envolve -> OK (positiva)" color OK Field.tsx 'import { DsBox } from "@x/design-system";\nconst s = "x";\nexport const C = () => <DsBox><input type="color" /></DsBox>;\n'
# B8 — neutralização fail-closed: apóstrofo em texto JSX não abre string que engula o controle
expect9 "(B8) <p>Don't</p> antes do controle, sem DS -> WARN" color WARN C.tsx "export const C = () => <div><p>Don't</p><input type=\"color\" /></div>;\n"
expect9 "(B8) <p>Don't</p> antes de type='color', sem DS -> WARN" color WARN C.tsx "export const C = () => <div><p>Don't</p><input type='color' /></div>;\n"
expect9 "(B8) apóstrofos em par (Don't ... It's) em volta de type='color' -> WARN" color WARN C.tsx "export const C = () => <div><p>Don't</p><input type='color' /><p>It's</p></div>;\n"
expect9 "(B8) aspa solta sem fechamento na linha (<p>'90s</p>) -> WARN" color WARN C.tsx "export const C = () => <div><p>'90s</p><input type=\"color\" /></div>;\n"
# B9 — em template literal só o texto entre expressões é neutralizado; o conteúdo de \${...} fica cru
expect9 "(B9) controle dentro de \${...} num template -> WARN" color WARN C.tsx 'export const C = ({ on }) => <div>{`${on ? <input type="color" /> : null}`}</div>;\n'
expect9 "(B9) DS envolve o controle dentro de \${...} -> OK (positiva)" color OK C.tsx 'import { DsBox } from "@x/design-system";\nexport const C = ({ on }) => <div>{`a ${on ? <DsBox><input type="color" /></DsBox> : null} b`}</div>;\n'
echo "OK [9] — $n9 casos conferidos"

echo "[10] análise por AST — texto de string, comentário e template não é elemento JSX"
SCEN=10
n9_antes=$n9
# (a) apóstrofo em texto JSX abre "string" que engole o type='color' -> o controle continua visto
expect9 "(a) <p>'Oi</p><input type='color' /> sem DS -> WARN" color WARN C.tsx "export const C = () => <div><p>'Oi</p><input type='color' /></div>;\n"
# (b) linha deixada crua por aspa solta não pode reativar tag do DS dentro de {\"...\"}
expect9 "(b) {\"<DsBox>\"} com '90s na linha, controle fora do DS -> WARN" color WARN C.tsx 'import { DsBox } from "@x/design-system";\nexport const C = () => <div><p>'"'"'90s</p>{"<DsBox>"}<input type="color" />{"</DsBox>"}</div>;\n'
# (c) controle dentro de ${} de um template: o texto do template não é elemento do DS
expect9 "(c) controle dentro de \${} entre <DsBox> e </DsBox> de template -> WARN" color WARN C.tsx 'import { DsBox } from "@x/design-system";\nexport const C = () => <div className={`<DsBox> ${<input type="color" />} </DsBox>`} />;\n'
# (d) DS que envolve o controle, com string (e apóstrofo) antes -> OK
expect9 "(d) DS envolve o controle, string antes -> OK (positiva)" color OK C.tsx 'import { DsBox } from "@x/design-system";\nconst aviso = "Oi, '"'"'90s";\nexport const C = () => <DsBox>{"texto"}<input type="color" /></DsBox>;\n'
# (e) DS irmão do controle no mesmo bloco (autofechado com espaço) -> WARN
expect9 "(e) <DsBox / > irmão e outro DsBox depois -> WARN" color WARN C.tsx 'import { DsBox } from "@x/design-system";\nexport const C = () => <div><DsBox / ><input type="color" /><DsBox>x</DsBox></div>;\n'
# (f) escape em comentário JS ou em string do próprio arquivo não domestica
expect9 "(f) escape em comentário // colado a palavra -> WARN" color WARN C.tsx 'export const C = () => <input type="color" />;\nconst n = 1//input::-webkit-color-swatch { border: none }\n'
expect9 "(f) escape em string literal do TSX -> WARN" color WARN C.tsx 'const doc = "input::-webkit-color-swatch { border: none }";\nexport const C = () => <input type="color" />;\n'
expect9 "(f) escape em comentário CSS do arquivo irmão -> WARN" color WARN P.tsx "$COL" P.module.css '.sw { border: 0; }\n/* .sw::-webkit-color-swatch { border: none } */\n'
# (g) "/*" e "*/" dentro de strings não formam comentário que esconda o controle
expect9 "(g) controle entre strings \"/*\" e \"*/\" -> WARN" color WARN C.tsx 'const a = "/*";\nexport const C = () => <input type="color" />;\nconst b = "*/";\n'
# positivas que o parser precisa manter: <style> JSX do próprio componente e escape de CSS aninhado
expect9 "(h) <style> JSX com escape no seletor do controle -> OK (positiva)" color OK C.tsx 'export const C = () => <div><style>{`.sw::-webkit-color-swatch { border: none; }`}</style><input type="color" className="sw" /></div>;\n'
expect9 "(h) SCSS aninhado &::pseudo resolvido para a classe do controle -> OK (positiva)" color OK P.tsx "$COL" P.module.scss '.sw {\n  border: 0;\n  &::-webkit-color-swatch { border: none; }\n}\n'
expect9 "(h) SCSS aninhado em classe alheia -> WARN" color WARN P.tsx "$COL" P.module.scss '.card {\n  &::-webkit-color-swatch { border: none; }\n}\n'
# arquivo que o parser não lê: nunca OK
expect9 "(i) TSX com erro de sintaxe -> WARN não analisado" "não-analisado" WARN C.tsx 'import { DsBox } from "@x/design-system";\nexport const C = () => <DsBox><input type="color" /></DsBox;\n'
# .vue/.html pelo html.parser: envolvimento real, irmão, <style> do SFC e comentário HTML
expect9 "(j) .vue: DS envolve o controle -> OK (positiva)" color OK F.vue '<script setup lang="ts">\nimport DsField from "@x/design-system/DsField.vue";\n</script>\n<template>\n  <DsField><input type="color" /></DsField>\n</template>\n'
expect9 "(j) .vue: DS irmão do controle -> WARN" color WARN F.vue '<script setup lang="ts">\nimport DsField from "@x/design-system/DsField.vue";\n</script>\n<template>\n  <div><DsField /><input type="color" /></div>\n</template>\n'
expect9 "(j) .vue: <style scoped> com escape na classe do controle -> OK (positiva)" color OK F.vue '<template>\n  <input type="color" class="sw" />\n</template>\n<style scoped lang="scss">\n.sw { &::-webkit-color-swatch { border: none; } }\n</style>\n'
expect9 "(j) .html: escape só em comentário HTML -> WARN" color WARN i.html '<!-- <style>input::-webkit-color-swatch { border: none }</style> -->\n<input type="color">\n'
# helper de AST ausente: o arquivo fica "não analisado", nunca OK
mkdir -p "$T/semhelper/scripts" "$T/semhelper/src"
cp "$SCAN_NATIVE" "$T/semhelper/scripts/"
printf 'import { DsBox } from "@x/design-system";\nexport const C = () => <DsBox><input type="color" /></DsBox>;\n' > "$T/semhelper/src/C.tsx"
outsh="$(python3 "$T/semhelper/scripts/scan-native-controls.py" "$T/semhelper/src")" || { echo "FAIL [10] (k) advisory deve sair 0"; exit 1; }
grep -q '^WARN não-analisado' <<<"$outsh" || { echo "FAIL [10] (k) helper ausente deveria dar WARN não analisado: $outsh"; exit 1; }
grep -q '^OK color' <<<"$outsh" && { echo "FAIL [10] (k) helper ausente não pode dar OK: $outsh"; exit 1; }
echo "  ok (k) helper de AST ausente -> WARN não analisado"
echo "OK [10] — $((n9 - n9_antes + 1)) casos conferidos"

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
