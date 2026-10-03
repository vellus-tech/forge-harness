#!/usr/bin/env python3
# scan-native-controls.py <src_dir>
# A4 — scanner determinístico ADVISORY (nunca bloqueia, exit sempre 0) que distingue controle
# nativo do browser DOMADO de NÃO DOMADO. A receita antiga (`rg 'type="color"...' | grep -v
# design-system`) casava o atributo sozinho, sem olhar o CSS irmão — poder discriminante zero,
# sempre WARN, mesmo quando o pseudo-elemento correto já estilizava o chrome nativo.
#
# Reconhece os DOIS escapes da regra 12 de rules/frontend/design-system.md:
#   (1) domesticação no CSS do PRÓPRIO componente — X.css/X.module.css (ou .scss/.sass/.less) de
#       mesmo nome para X.tsx, ou o próprio arquivo (CSS-in-JS / <style> embutido). Só conta uma
#       REGRA cujo seletor ALCANÇA o controle: o sujeito do seletor (último composto) é a tag do
#       controle (`input`/`select`) ou uma classe usada na própria tag do controle. Para
#       pseudo-elemento específico do tipo (::-webkit-color-swatch etc.), sujeito sem tag nem
#       classe (`::x`, `[type=color]::x`, `&::x`) também conta, porque o pseudo só existe naquele
#       controle. Propriedade (accent-color, -webkit-appearance, appearance: none) conta só como
#       propriedade REAL no corpo da regra, nunca como substring de seletor ou de comentário.
#   (2) encapsulamento em componente do design system — um identificador importado de caminho com
#       'design-system' ENVOLVE o controle: elemento aberto antes e fechado depois dele, ou o
#       próprio controle é a tag do componente (`<DsInput type="color" />`). Coexistir no mesmo
#       bloco (irmão) não conta.
# Comentários CSS e JS/TSX (`/* */`, `//`, `<!-- -->`) são removidos antes de qualquer busca.
# Se um dos dois escapes está presente para aquele tipo de controle: OK. Senão: WARN.
#
# Limites conhecidos (heurística por regex, não parser): o envolvimento é contado por pares de
# tags na mesma ordem textual do arquivo — JSX gerado por função/variável em outro ponto do
# arquivo não é seguido; aninhamento de CSS (SCSS `&`) aceita o sujeito `&::pseudo` sem resolver
# o pai; `appearance: none` sem prefixo não domestica checkbox/radio (só a forma -webkit- e
# accent-color); seletores com combinador dentro de `:not(...)`/`:is(...)` podem ter o sujeito
# mal recortado; `type` vindo de variável (`type={tipo}`) não é detectado.
import re
import sys
import pathlib

# tipo de controle -> pseudo-elementos que provam domesticação (regra 12 + chrome nativo real).
TAME_PSEUDOS = {
    "file": [r"::file-selector-button"],
    "color": [r"::-webkit-color-swatch", r"::-moz-color-swatch"],
    "date": [r"::-webkit-calendar-picker-indicator"],
    "time": [r"::-webkit-calendar-picker-indicator"],
    "range": [r"::-webkit-slider-thumb", r"::-moz-range-thumb"],
    "select": [r"::-webkit-select", r"::picker\(select\)"],
}
# tipo de controle -> PROPRIEDADES reais (no corpo da regra) que provam domesticação. accent-color
# é a via moderna de estilizar checkbox/radio; -webkit-appearance a legada. A propriedade exige
# início de declaração (início do corpo, espaço, `{` ou `;`) antes e `:` depois — nunca casa o
# pseudo inexistente `::-webkit-appearance` nem `appearance` dentro de outro identificador.
_DECL = r"(?:^|(?<=[\s{;]))"
TAME_PROPS = {
    "checkbox": [_DECL + r"accent-color\s*:", _DECL + r"-webkit-appearance\s*:"],
    "radio": [_DECL + r"accent-color\s*:", _DECL + r"-webkit-appearance\s*:"],
    "select": [_DECL + r"(?:-webkit-|-moz-)?appearance\s*:\s*none\b"],
}

RULE_RE = re.compile(r"([^{}]+)\{([^{}]*)\}")
# type="x", type='x', type={"x"}, type={'x'}
CONTROL_RE = re.compile(
    r"type=\{?\s*[\"'](file|color|date|time|range|checkbox|radio)[\"']\s*\}?|(<select\b)"
)
CSS_EXTS = (".css", ".scss", ".sass", ".less")
COMMENT_RE = re.compile(r"/\*.*?\*/|<!--.*?-->|(?<![:(\"'\w\\])//[^\n]*", re.S)


def strip_comments(text: str) -> str:
    # troca cada comentário pelas suas quebras de linha — preserva a numeração das linhas
    return COMMENT_RE.sub(lambda m: "\n" * m.group(0).count("\n"), text)


def control_type_from_match(m: "re.Match") -> str:
    return m.group(1) if m.group(1) else "select"


def control_tag(control_type: str) -> str:
    return "select" if control_type == "select" else "input"


def sibling_css_texts(file_path: pathlib.Path) -> list[str]:
    # só CSS com o nome do componente: X.css ou X.module.css (ou equivalente) para X.tsx
    stem = file_path.stem
    names = {stem + ext for ext in CSS_EXTS} | {stem + ".module" + ext for ext in CSS_EXTS}
    texts = []
    for sib in file_path.parent.iterdir():
        if sib.is_file() and sib.name in names:
            texts.append(strip_comments(sib.read_text(errors="ignore")))
    return texts


def subject_compound(selector_part: str) -> str:
    # sujeito = último composto do seletor (depois do último combinador)
    pieces = [p for p in re.split(r"\s*[>+~]\s*|\s+", selector_part.strip()) if p]
    return pieces[-1] if pieces else ""


def _subject_parts(subject: str) -> tuple[str, set[str]]:
    base = re.split(r"::?", subject, maxsplit=1)[0] if not subject.startswith(":") else ""
    m = re.match(r"([A-Za-z][\w-]*)", base)
    element = m.group(1).lower() if m else ""
    classes = set(re.findall(r"\.([\w-]+)", base))
    return element, classes


def _subject_reaches(subject: str, control_type: str, classes: set[str], bare_ok: bool) -> bool:
    element, sel_classes = _subject_parts(subject)
    if element == control_tag(control_type):
        return True
    if sel_classes & classes:
        return True
    if element or sel_classes:
        return False  # outra tag ou classe que não está no controle
    if bare_ok:
        return True  # `::pseudo`, `&::pseudo`, `[type=x]::pseudo`, `*::pseudo`
    # propriedade em seletor sem tag nem classe: só com o atributo do tipo explícito
    return bool(re.search(r"\[\s*type\s*=\s*[\"']?" + control_type + r"\b", subject))


def is_tamed(control_type: str, haystacks: list[str], classes: set[str]) -> bool:
    pseudos = TAME_PSEUDOS.get(control_type, [])
    props = TAME_PROPS.get(control_type, [])
    for hay in haystacks:
        for rule in RULE_RE.finditer(hay):
            selector, body = rule.group(1), rule.group(2)
            for part in selector.split(","):
                subject = subject_compound(part)
                if not subject:
                    continue
                if any(re.search(p, subject) for p in pseudos) and _subject_reaches(
                    subject, control_type, classes, bare_ok=True
                ):
                    return True
                if any(re.search(p, body, re.M) for p in props) and _subject_reaches(
                    subject, control_type, classes, bare_ok=False
                ):
                    return True
    return False


def design_system_names(text: str) -> set[str]:
    # identificadores importados de qualquer caminho que contenha 'design-system'
    names = set()
    for m in re.finditer(r"import\s+([^;]*?)\s+from\s+[\"'][^\"']*design-system[^\"']*[\"']", text):
        for ident in re.findall(r"[A-Za-z_]\w*", m.group(1)):
            if ident not in ("as", "type", "from", "import"):
                names.add(ident)
    return names


def tag_end(text: str, start: int) -> int:
    # índice do `>` que fecha a tag aberta em `start`, respeitando chaves e aspas do JSX
    depth = 0
    quote = ""
    i = start + 1
    while i < len(text):
        ch = text[i]
        if quote:
            if ch == quote:
                quote = ""
        elif ch in "\"'`":
            quote = ch
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth = max(0, depth - 1)
        elif ch == ">" and depth == 0:
            return i
        i += 1
    return len(text) - 1


def own_tag(text: str, pos: int) -> tuple[int, str]:
    # tag que contém a posição do controle: (início, texto da tag)
    start = pos if text.startswith("<", pos) else text.rfind("<", 0, pos)
    if start < 0:
        return -1, ""
    return start, text[start:tag_end(text, start) + 1]


def classes_in(tag: str) -> set[str]:
    found: set[str] = set()
    for m in re.finditer(r"class(?:Name)?=\{?\s*[\"'`]([^\"'`]*)", tag):
        found.update(m.group(1).split())
    found.update(re.findall(r"styles\.(\w+)", tag))
    found.update(re.findall(r"styles\[[\"']([\w-]+)[\"']\]", tag))
    return found


def is_encapsulated(text: str, tag_start: int, tag_text: str, ds_names: set[str]) -> bool:
    # (a) o próprio controle é a tag do componente do DS
    m = re.match(r"<([A-Za-z_][\w.]*)", tag_text)
    if m and m.group(1) in ds_names:
        return True
    # (b) um componente do DS está ABERTO na posição do controle e é fechado depois dele
    for name in ds_names:
        esc = re.escape(name)
        depth = 0
        for t in re.finditer(r"<(/?)" + esc + r"(?![\w.-])", text[:tag_start]):
            if t.group(1):
                depth = max(0, depth - 1)
                continue
            end = tag_end(text, t.start())
            if text[end - 1] != "/":  # abertura que não se fecha sozinha
                depth += 1
        if depth > 0 and re.search(r"</" + esc + r"\s*>", text[tag_start:]):
            return True
    return False


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
        text = strip_comments(p.read_text(errors="ignore"))
        siblings = None
        ds_names = design_system_names(text)
        for m in CONTROL_RE.finditer(text):
            ctype = control_type_from_match(m)
            lineno = text.count("\n", 0, m.start()) + 1
            if siblings is None:
                siblings = sibling_css_texts(p)
            tag_start, tag_text = own_tag(text, m.start())
            tamed = is_tamed(ctype, [text] + siblings, classes_in(tag_text))
            encapsulated = tag_start >= 0 and is_encapsulated(text, tag_start, tag_text, ds_names)
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
