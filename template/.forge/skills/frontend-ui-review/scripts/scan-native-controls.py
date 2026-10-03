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
#   (2) encapsulamento em componente do design system — um componente importado de um caminho
#       com 'design-system' é USADO no mesmo bloco (trecho contíguo de linhas não vazias) do controle.
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
    "checkbox": [r"accent-color", r"-webkit-appearance"],
    "radio": [r"accent-color", r"-webkit-appearance"],
    "select": [r"::-webkit-select", r"::picker\(select\)"],
}

# appearance: none em <select> só domestica quando o seletor da regra alcança o select
# (tag select ou classe usada no controle). Num seletor global não domestica nada.
APPEARANCE_NONE_RE = re.compile(r"appearance\s*:\s*none")
RULE_RE = re.compile(r"([^{}]+)\{([^{}]*)\}")

CONTROL_RE = re.compile(r"type=[\"'](file|color|date|time|range|checkbox|radio)[\"']|(<select\b)")
CSS_EXTS = (".css", ".scss", ".sass", ".less")


def control_type_from_match(m: "re.Match") -> str:
    return m.group(1) if m.group(1) else "select"


def sibling_css_texts(file_path: pathlib.Path) -> list[str]:
    # só CSS com o nome do componente: X.css ou X.module.css (ou equivalente) para X.tsx
    stem = file_path.stem
    names = {stem + ext for ext in CSS_EXTS} | {stem + ".module" + ext for ext in CSS_EXTS}
    texts = []
    for sib in file_path.parent.iterdir():
        if sib.is_file() and sib.name in names:
            texts.append(sib.read_text(errors="ignore"))
    return texts


def _selector_reaches_control(selector: str, classes: set[str]) -> bool:
    if re.search(r"(?<![\w.#-])select(?![\w-])", selector):
        return True
    return any(re.search(r"\." + re.escape(c) + r"(?![\w-])", selector) for c in classes)


def select_appearance_tamed(haystack: str, classes: set[str]) -> bool:
    for m in RULE_RE.finditer(haystack):
        selector, body = m.group(1), m.group(2)
        if not APPEARANCE_NONE_RE.search(body):
            continue
        if any(_selector_reaches_control(part, classes) for part in selector.split(",")):
            return True
    return False


def is_tamed(control_type: str, own_text: str, sibling_texts: list[str], classes: set[str]) -> bool:
    haystacks = [own_text] + sibling_texts
    for pat in TAME_PATTERNS.get(control_type, []):
        if any(re.search(pat, hay) for hay in haystacks):
            return True
    if control_type == "select":
        return any(select_appearance_tamed(hay, classes) for hay in haystacks)
    return False


def design_system_names(text: str) -> set[str]:
    # identificadores importados de qualquer caminho que contenha 'design-system'
    names = set()
    for m in re.finditer(r"import\s+([^;]*?)\s+from\s+[\"'][^\"']*design-system[^\"']*[\"']", text):
        for ident in re.findall(r"[A-Za-z_]\w*", m.group(1)):
            if ident not in ("as", "type", "from", "import"):
                names.add(ident)
    return names


def block_at(lines: list[str], idx: int) -> str:
    # bloco = trecho contíguo de linhas não vazias que contém a linha do controle
    start = idx
    while start > 0 and lines[start - 1].strip():
        start -= 1
    end = idx
    while end + 1 < len(lines) and lines[end + 1].strip():
        end += 1
    return "\n".join(lines[start:end + 1])


def classes_in(block: str) -> set[str]:
    found: set[str] = set()
    for m in re.finditer(r"class(?:Name)?=\{?\s*[\"'`]([^\"'`]*)", block):
        found.update(m.group(1).split())
    found.update(re.findall(r"styles\.(\w+)", block))
    found.update(re.findall(r"styles\[[\"'](\w+)[\"']\]", block))
    return found


def is_encapsulated(block: str, ds_names: set[str]) -> bool:
    # encapsulado = componente do DS importado E usado no mesmo bloco (ou na linha) do controle
    return any(re.search(r"<" + re.escape(n) + r"(?![\w])", block) for n in ds_names)


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
        lines = text.splitlines()
        siblings = None
        ds_names = design_system_names(text)
        for lineno, line in enumerate(lines, start=1):
            for m in CONTROL_RE.finditer(line):
                ctype = control_type_from_match(m)
                if siblings is None:
                    siblings = sibling_css_texts(p)
                block = block_at(lines, lineno - 1)
                tamed = is_tamed(ctype, text, siblings, classes_in(block))
                encapsulated = is_encapsulated(block, ds_names)
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
