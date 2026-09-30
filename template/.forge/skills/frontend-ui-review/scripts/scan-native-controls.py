#!/usr/bin/env python3
# scan-native-controls.py <src_dir>
# A4 — scanner determinístico ADVISORY (nunca bloqueia, exit sempre 0) que distingue controle
# nativo do browser DOMADO de NÃO DOMADO. A receita antiga (`rg 'type="color"...' | grep -v
# design-system`) casava o atributo sozinho, sem olhar o CSS irmão — poder discriminante zero,
# sempre WARN, mesmo quando o pseudo-elemento correto já estilizava o chrome nativo.
#
# Reconhece os DOIS escapes da regra 12 de rules/frontend/design-system.md:
#   (1) pseudo-elemento domado no CSS do PRÓPRIO componente — qualquer arquivo de estilo (.css,
#       .scss, .less, .module.css) no MESMO diretório do arquivo que usa o controle, ou o próprio
#       arquivo (CSS-in-JS / <style> embutido), contendo o pseudo-elemento correspondente ao tipo.
#   (2) encapsulamento em componente do design system — o arquivo referencia 'design-system'
#       (import de pacote, path, ou nome de componente do DS) perto do uso do controle.
# Se um dos dois escapes está presente para aquele tipo de controle: OK. Senão: WARN.
import re
import sys
import pathlib

# tipo de controle -> pseudo-elementos/propriedades que provam domesticação (regra 12 + chrome
# nativo real de cada tipo). accent-color é a via moderna (não-vendor-prefixed) de estilizar
# checkbox/radio, por isso conta como domado ao lado do ::-webkit-appearance legado.
TAME_PATTERNS = {
    "file": [r"::file-selector-button"],
    "color": [r"::-webkit-color-swatch", r"::-moz-color-swatch"],
    "date": [r"::-webkit-calendar-picker-indicator"],
    "time": [r"::-webkit-calendar-picker-indicator"],
    "range": [r"::-webkit-slider-thumb", r"::-moz-range-thumb"],
    "checkbox": [r"accent-color", r"::-webkit-appearance"],
    "radio": [r"accent-color", r"::-webkit-appearance"],
    "select": [r"::-webkit-select", r"::picker\(select\)", r"appearance:\s*none"],
}

CONTROL_RE = re.compile(r'type="(file|color|date|time|range|checkbox|radio)"|(<select\b)')
CSS_EXTS = (".css", ".scss", ".sass", ".less")


def control_type_from_match(m: "re.Match") -> str:
    return m.group(1) if m.group(1) else "select"


def sibling_css_texts(file_path: pathlib.Path) -> list[str]:
    texts = []
    for sib in file_path.parent.iterdir():
        if sib.is_file() and sib.suffix in CSS_EXTS:
            texts.append(sib.read_text(errors="ignore"))
    return texts


def is_tamed(control_type: str, own_text: str, sibling_texts: list[str]) -> bool:
    patterns = TAME_PATTERNS.get(control_type, [])
    haystacks = [own_text] + sibling_texts
    for pat in patterns:
        for hay in haystacks:
            if re.search(pat, hay):
                return True
    return False


def is_encapsulated(own_text: str) -> bool:
    return bool(re.search(r"design-system", own_text, re.IGNORECASE))


def main() -> int:
    if len(sys.argv) < 2:
        print("uso: scan-native-controls.py <src_dir>")
        return 2

    src = pathlib.Path(sys.argv[1])
    if not src.exists():
        print(f"FAIL: src_dir não encontrado: {src}")
        return 2

    exts = (".tsx", ".ts", ".jsx", ".js", ".vue", ".svelte", ".html")
    ok_count = 0
    warn_count = 0

    for p in sorted(src.rglob("*")):
        if not (p.is_file() and p.suffix in exts):
            continue
        text = p.read_text(errors="ignore")
        siblings = None
        for lineno, line in enumerate(text.splitlines(), start=1):
            for m in CONTROL_RE.finditer(line):
                ctype = control_type_from_match(m)
                if siblings is None:
                    siblings = sibling_css_texts(p)
                tamed = is_tamed(ctype, text, siblings)
                encapsulated = is_encapsulated(text)
                if tamed or encapsulated:
                    ok_count += 1
                    motivo = "pseudo-elemento domado" if tamed else "encapsulado em componente do DS"
                    print(f"OK {ctype}  {p}:{lineno}  ({motivo})")
                else:
                    warn_count += 1
                    print(f"WARN {ctype}  {p}:{lineno}  (sem pseudo-elemento domado nem encapsulamento no DS)")

    total = ok_count + warn_count
    if total == 0:
        print("OK controles-nativos: nenhum controle nativo encontrado")
    elif warn_count == 0:
        print(f"OK controles-nativos: {ok_count} controle(s), todos domados/encapsulados")
    else:
        print(f"WARN controles nativos: {warn_count} de {total} controle(s) sem domesticação nem encapsulamento")

    # advisory: nunca bloqueia — a metade bloqueante mora no gate opt-in do consumidor.
    return 0


if __name__ == "__main__":
    sys.exit(main())
