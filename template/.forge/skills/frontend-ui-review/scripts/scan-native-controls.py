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
# Comentários CSS e JS/TSX (`/* */`, `//`, `<!-- -->`) são removidos e o texto literal de strings é
# neutralizado antes de qualquer busca de DS ou de controle; o valor de type/class/className continua
# lido. Só se neutraliza string de aspas simples/duplas com fechamento na mesma linha e o texto de
# template literal fora de `${...}` (as expressões ficam cruas); na dúvida o texto fica cru
# (fail-closed: prefere WARN a OK indevido). O CSS-in-JS do próprio arquivo segue valendo para
# domesticação (lido sem neutralizar).
# Se um dos dois escapes está presente para aquele tipo de controle: OK. Senão: WARN.
#
# Limites conhecidos (heurística por regex, não parser): o envolvimento é contado por pares de
# tags na mesma ordem textual do arquivo — JSX gerado por função/variável em outro ponto do
# arquivo não é seguido; aninhamento de CSS (SCSS `&`) aceita o sujeito `&::pseudo` sem resolver
# o pai; `appearance: none` sem prefixo não domestica checkbox/radio (só a forma -webkit- e
# accent-color); seletores com combinador dentro de `:not(...)`/`:is(...)` podem ter o sujeito
# mal recortado; `type` vindo de variável (`type={tipo}`) não é detectado; uma aspa de texto JSX não
# colada a palavra que fecha por coincidência na aspa de `type='x'` da mesma linha ainda esconde o
# controle, e numa linha deixada crua (aspa sem fechamento) tag do DS dentro de string volta a contar.
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


# valor de atributo type/class/className e chave de styles[...] não são neutralizados: são o que o
# scanner lê do próprio controle. Qualquer outra string literal (const s = "..." ou JSX `{"..."}`)
# vira espaços, para que um `<DsBox>` ou `</DsBox>` dentro dela não conte como tag.
_KEEP_BEFORE = re.compile(r"(?:\b(?:type|class|className)\s*=\s*\{?\s*|styles\[\s*)$")


_WORD = re.compile(r"\w")


def _opens_simple_string(text: str, i: int) -> bool:
    # aspas colada a uma palavra (`Don't`, `Users'`) nunca abre string em JS/TS: é texto
    return not (i > 0 and _WORD.match(text[i - 1]))


def _simple_string_end(text: str, i: int) -> int:
    # índice da aspa que fecha a string aberta em `i` NA MESMA LINHA, ou -1 se não houver
    quote = text[i]
    j = i + 1
    while j < len(text):
        c = text[j]
        if c == "\\":
            j += 2
            continue
        if c == "\n":
            return -1
        if c == quote:
            return j
        j += 1
    return -1


def _expr_end(text: str, i: int) -> int:
    # índice da `}` que fecha a expressão `${` iniciada antes de `i`, ou -1 se não fechar
    depth = 1
    j = i
    while j < len(text):
        c = text[j]
        if c in "\"'" and _opens_simple_string(text, j):
            k = _simple_string_end(text, j)
            if k >= 0:
                j = k + 1
                continue
        elif c == "`":
            r = _template_literal(text, j)
            if r is None:
                return -1
            j = r[0] + 1
            continue
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return j
        j += 1
    return -1


def _template_literal(text: str, i: int):
    # template aberto em `i`: (índice da crase que fecha, trechos de texto literal fora de `${...}`)
    # ou None se a crase ou alguma `${` não fechar
    spans = []
    seg = j = i + 1
    while j < len(text):
        c = text[j]
        if c == "\\":
            j += 2
            continue
        if c == "`":
            spans.append((seg, j))
            return j, spans
        if c == "$" and text.startswith("{", j + 1):
            spans.append((seg, j))
            k = _expr_end(text, j + 2)
            if k < 0:
                return None
            seg = j = k + 1
            continue
        j += 1
    return None


def neutralize_strings(text: str) -> str:
    # troca por espaços o texto literal de strings, preservando quebras de linha e o comprimento.
    # Fail-closed: na dúvida o texto fica cru (um controle visto a mais vira WARN, nunca OK).
    #   - aspas simples/duplas: só abrem string se não estiverem coladas a uma palavra e se houver
    #     a aspa de fechamento na MESMA linha; uma aspa sem fechamento deixa a linha inteira crua
    #     (apóstrofo em texto JSX como `<p>Don't</p>` nunca engole o resto da linha);
    #   - template literal: atravessa linhas, mas só o texto entre as expressões é neutralizado — o
    #     conteúdo de `${...}` (JSX inclusive) fica cru; template ou `${` sem fechamento fica cru.
    out = list(text)
    raw_lines: set[int] = set()

    def blank(a: int, b: int) -> None:
        for k in range(a, b):
            if out[k] != "\n":
                out[k] = " "

    i = 0
    while i < len(text):
        c = text[i]
        if c in "\"'":
            if not _opens_simple_string(text, i):
                i += 1
                continue
            j = _simple_string_end(text, i)
            if j < 0:
                raw_lines.add(text.rfind("\n", 0, i) + 1)
                i += 1
                continue
            if not _KEEP_BEFORE.search(text[max(0, i - 40):i]):
                blank(i + 1, j)
            i = j + 1
        elif c == "`":
            r = _template_literal(text, i)
            if r is None:
                i += 1
                continue
            end, spans = r
            if not _KEEP_BEFORE.search(text[max(0, i - 40):i]):
                for a, b in spans:
                    blank(a, b)
            i = end + 1
        else:
            i += 1
    for start in raw_lines:
        end = text.find("\n", start)
        end = len(text) if end < 0 else end
        out[start:end] = text[start:end]
    return "".join(out)


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
        raw = strip_comments(p.read_text(errors="ignore"))
        # busca de DS e de controle sobre o texto sem conteúdo de string; o CSS-in-JS continua no
        # texto cru (sem comentários), porque o pseudo-elemento domesticado pode morar num template
        text = neutralize_strings(raw)
        siblings = None
        ds_names = design_system_names(raw)  # o caminho do import é string: lê-se do texto cru
        for m in CONTROL_RE.finditer(text):
            ctype = control_type_from_match(m)
            lineno = text.count("\n", 0, m.start()) + 1
            if siblings is None:
                siblings = sibling_css_texts(p)
            tag_start, tag_text = own_tag(text, m.start())
            tamed = is_tamed(ctype, [raw] + siblings, classes_in(tag_text))
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
