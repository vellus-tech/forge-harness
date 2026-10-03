#!/usr/bin/env python3
# scan-native-controls.py <src_dir>
# A4 — scanner determinístico ADVISORY (nunca bloqueia, exit sempre 0) que distingue controle
# nativo do browser DOMADO de NÃO DOMADO, por análise de árvore e nunca por regex sobre o texto.
#
# Parser (decisão): JSX/TSX é lido pela AST do @babel/parser, chamado via Node pelo helper
# scan-native-controls-ast.mjs ao lado deste arquivo — escolhido porque é um arquivo único sem
# dependência em runtime e com API estável, enquanto o pacote `typescript` 7 deixou de expor o
# createSourceFile; o harness o declara só como devDependency (o gate precisa dele) e, no consumidor,
# o helper o resolve a partir do projeto escaneado. .vue/.svelte/.html são lidos pelo
# html.parser da stdlib (tags, atributos, <style> e <script>), e os imports dos blocos <script>
# pelo mesmo helper. CSS (arquivo irmão, <style> JSX ou de SFC) é lido por um tokenizador próprio
# que respeita comentários, strings e aninhamento SCSS (`&` resolvido contra o seletor pai).
#
# Controle nativo: <input type=file|color|date|time|datetime-local|month|week|range|checkbox|radio>,
# <select>, <textarea>, <input type={dinâmico}> e componente com type nativo literal. É DOMADO só se:
#   (1) está DENTRO de um elemento cujo nome vem de import de caminho com 'design-system' — um
#       ancestral na árvore que o contém pelos filhos (irmão, atributo ou texto não envolvem) —, ou
#       o próprio elemento é esse componente; ou
#   (2) um escape de aparência real alcança o controle: regra de CSS do arquivo irmão com o nome do
#       componente (X.css/X.module.css/.scss/.less para X.tsx), de <style> do próprio arquivo, ou o
#       style inline do controle. Pseudo-elemento do tipo (::-webkit-color-swatch,
#       ::file-selector-button, ::-webkit-file-upload-button, ::-webkit-slider-thumb...) cujo
#       composto-sujeito não tem outra tag, classe fora do controle, id, atributo alheio nem
#       pseudo-classe; ou propriedade (appearance/-webkit-appearance/-moz-appearance: none para
#       checkbox, radio, select e textarea; accent-color para checkbox e radio) numa regra cujo
#       sujeito é a tag do controle, classe usada nele ou [type=<tipo>], sem pseudo-elemento nem
#       pseudo-classe.
# Tudo o mais: WARN. Arquivo que o parser não lê (erro de sintaxe, Node ou @babel/parser
# ausente): WARN "não analisado", nunca OK.
#
# Limites conhecidos: JSX montado por função, variável ou string em outro ponto não é seguido (o
# controle fica sem envoltório → WARN); classes só contam quando estáticas (className literal,
# styles.x, styles["x"]) — clsx(...) e template com expressão não domesticam; os compostos
# ancestrais do seletor (`.wrap` em `.wrap .sw`) não são confrontados com o DOM real; .sass
# (sintaxe indentada) não tem regras legíveis; o envolvimento em .vue/.svelte só conta com
# fechamento explícito da tag do DS.
import json
import pathlib
import shutil
import subprocess
import sys
from html.parser import HTMLParser

HELPER = pathlib.Path(__file__).with_name("scan-native-controls-ast.mjs")

INPUT_TYPES = {
    "file", "color", "date", "time", "datetime-local", "month", "week", "range", "checkbox", "radio",
}
_PICKER = {"-webkit-calendar-picker-indicator"}
# tipo de controle -> pseudo-elementos (normalizados) que domam o chrome nativo
TAME_PSEUDOS = {
    "file": {"file-selector-button", "-webkit-file-upload-button"},
    "color": {"-webkit-color-swatch", "-webkit-color-swatch-wrapper", "-moz-color-swatch"},
    "date": _PICKER, "time": _PICKER, "datetime-local": _PICKER, "month": _PICKER, "week": _PICKER,
    "range": {"-webkit-slider-thumb", "-moz-range-thumb"},
    "select": {"picker(select)"},
    "textarea": {"-webkit-resizer"},
}
APPEARANCE = ("appearance", "webkitappearance", "mozappearance")
INERT = {"", "auto", "initial", "unset", "inherit", "revert", "revert-layer"}


def _appearance_none(decls: dict) -> bool:
    return any(decls.get(p) == "none" for p in APPEARANCE)


def _accent(decls: dict) -> bool:
    return "accentcolor" in decls and decls["accentcolor"] not in INERT


TAME_PROPS = {
    "checkbox": lambda d: _appearance_none(d) or _accent(d),
    "radio": lambda d: _appearance_none(d) or _accent(d),
    "select": _appearance_none,
    "textarea": _appearance_none,
}
CSS_EXTS = (".css", ".scss", ".sass", ".less")
JSX_LANG = {".tsx": "tsx", ".ts": "ts", ".jsx": "jsx", ".js": "jsx"}
MARKUP_EXTS = (".vue", ".svelte", ".html")
VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr", "param"}


# ---------------------------------------------------------------- CSS (tokenizador, não regex)
def _norm_prop(prop: str) -> str:
    return prop.strip().lower().replace("-", "")


def parse_decls(chunks) -> dict:
    out = {}
    for chunk in chunks:
        if ":" not in chunk:
            continue
        prop, val = chunk.split(":", 1)
        prop = prop.strip()
        if not prop or any(ch.isspace() or ch in "{}&" for ch in prop):
            continue
        val = val.strip().lower()
        if val.endswith("!important"):
            val = val[: -len("!important")].strip()
        out[_norm_prop(prop)] = val
    return out


def split_top(text: str, seps: str) -> list:
    # divide em `seps` fora de (), [] e strings
    parts, buf, depth, quote = [], [], 0, ""
    for ch in text:
        if quote:
            buf.append(ch)
            if ch == quote:
                quote = ""
            continue
        if ch in "\"'":
            quote = ch
        elif ch in "([":
            depth += 1
        elif ch in ")]":
            depth = max(0, depth - 1)
        elif ch in seps and depth == 0:
            parts.append("".join(buf))
            buf = []
            continue
        buf.append(ch)
    parts.append("".join(buf))
    return parts


def _resolve(prelude: str, parents: list) -> list:
    parts = [p.strip() for p in split_top(prelude, ",") if p.strip()]
    if not parents:
        return [p.replace("&", "") for p in parts]
    out = []
    for parent in parents:
        for p in parts:
            out.append(p.replace("&", parent) if "&" in p else f"{parent} {p}")
    return out


_KEEP_AT = {"media", "supports", "layer", "container", "document", "scope"}


def parse_css(text: str, line_comments: bool) -> list:
    """[(seletores resolvidos, declarações)] — comentários e strings nunca viram regra."""
    rules = []
    n = len(text)
    pos = [0]

    def block(parents):
        buf, chunks, paren = [], [], 0
        while pos[0] < n:
            i = pos[0]
            c = text[i]
            if text.startswith("/*", i):
                end = text.find("*/", i + 2)
                pos[0] = n if end < 0 else end + 2
                continue
            if line_comments and paren == 0 and text.startswith("//", i):
                end = text.find("\n", i)
                pos[0] = n if end < 0 else end
                continue
            if c in "\"'":
                j = i + 1
                while j < n and text[j] not in (c, "\n"):
                    j += 2 if text[j] == "\\" else 1
                buf.append(text[i : j + 1])
                pos[0] = j + 1
                continue
            if text.startswith("#{", i):  # interpolação SCSS: nunca abre bloco
                end = text.find("}", i)
                end = n - 1 if end < 0 else end
                buf.append(text[i : end + 1])
                pos[0] = end + 1
                continue
            pos[0] = i + 1
            if c == "(":
                paren += 1
            elif c == ")":
                paren = max(0, paren - 1)
            elif c == ";" and paren == 0:
                chunks.append("".join(buf))
                buf = []
                continue
            elif c == "{":
                prelude = "".join(buf).strip()
                buf = []
                if prelude.startswith("@"):
                    name = prelude[1:].split(None, 1)[0].lower() if len(prelude) > 1 else ""
                    child = parents if name in _KEEP_AT else None
                    decls = block(child)
                    if child:  # @media dentro de regra aninhada: declarações valem para o pai
                        rules.append((child, decls))
                elif parents is None or not prelude:
                    block(None)
                else:
                    sels = _resolve(prelude, parents)
                    rules.append((sels, block(sels)))
                continue
            elif c == "}":
                chunks.append("".join(buf))
                return parse_decls(chunks)
            buf.append(c)
        chunks.append("".join(buf))
        return parse_decls(chunks)

    while pos[0] < n:
        block([])
    return rules


def _read_ident(s: str, i: int):
    j = i
    while j < len(s):
        ch = s[j]
        if ch == "\\" and j + 1 < len(s):
            j += 2
            continue
        if ch.isalnum() or ch in "-_" or ord(ch) > 127:
            j += 1
            continue
        break
    return s[i:j].replace("\\", ""), j


def _read_group(s: str, i: int, open_ch: str, close_ch: str):
    # s[i] == open_ch → (conteúdo, índice após o fechamento) respeitando aninhamento e strings
    depth, quote, j = 0, "", i
    while j < len(s):
        ch = s[j]
        if quote:
            if ch == quote:
                quote = ""
        elif ch in "\"'":
            quote = ch
        elif ch == open_ch:
            depth += 1
        elif ch == close_ch:
            depth -= 1
            if depth == 0:
                return s[i + 1 : j], j + 1
        j += 1
    return None, len(s)


def subject_compound(selector: str) -> str:
    pieces = [p for p in split_top(selector, " \t\n>+~") if p.strip()]
    return pieces[-1].strip() if pieces else ""


def parse_compound(comp: str):
    """composto → dict, ou None quando algo não é reconhecido (fail-closed)."""
    info = {"element": None, "classes": set(), "ids": False, "attrs": [], "pclasses": 0, "pelement": None}
    i = 0
    if comp.startswith("*"):
        info["element"] = "*"
        i = 1
    elif comp and (comp[0].isalpha() or comp[0] in "-_"):
        name, i = _read_ident(comp, 0)
        info["element"] = name.lower()
    while i < len(comp):
        ch = comp[i]
        if ch == "." or ch == "#":
            name, j = _read_ident(comp, i + 1)
            if not name:
                return None
            if ch == ".":
                info["classes"].add(name)
            else:
                info["ids"] = True
            i = j
        elif ch == "[":
            inner, i = _read_group(comp, i, "[", "]")
            if inner is None:
                return None
            info["attrs"].append(inner.strip())
        elif comp.startswith("::", i):
            if info["pelement"] is not None:
                return None
            name, j = _read_ident(comp, i + 2)
            if j < len(comp) and comp[j] == "(":
                arg, j = _read_group(comp, j, "(", ")")
                name = f"{name}({(arg or '').strip()})"
            info["pelement"] = name.lower()
            i = j
        elif ch == ":":
            _, j = _read_ident(comp, i + 1)
            if j < len(comp) and comp[j] == "(":
                _, j = _read_group(comp, j, "(", ")")
            info["pclasses"] += 1
            i = j
        else:
            return None
    return info


def _type_attr_matches(attr: str, ctype: str):
    # [type=color], [type="color"], [type='color' i] → True; [type^=c], [data-x] → False
    if "=" not in attr:
        return False
    name, value = attr.split("=", 1)
    name = name.strip().lower()
    if not name or name[-1] in "~|^$*" or name != "type":
        return False
    value = value.strip()
    if value[-2:].lower() in (" i", " s"):
        value = value[:-2].strip()
    value = value.strip("\"'").lower()
    return value == ctype


def reaches(comp, ctrl: dict, kind: str) -> bool:
    if comp is None or comp["ids"]:
        return False
    if comp["element"] not in (None, "*", ctrl["tag"]):
        return False
    if not comp["classes"] <= ctrl["classes"]:
        return False
    if not all(_type_attr_matches(a, ctrl["type"]) for a in comp["attrs"]):
        return False
    if comp["pclasses"]:
        return False  # :hover, :checked... domam só um estado
    if kind == "pseudo":
        return comp["pelement"] in TAME_PSEUDOS.get(ctrl["type"], set())
    if comp["pelement"] is not None:
        return False  # declaração vale para o pseudo-elemento, não para o controle
    return comp["element"] == ctrl["tag"] or bool(comp["classes"]) or bool(comp["attrs"])


def tamed_by_css(ctrl: dict, rules: list) -> bool:
    prop_ok = TAME_PROPS.get(ctrl["type"])
    for selectors, decls in rules:
        for sel in selectors:
            comp = parse_compound(subject_compound(sel))
            if reaches(comp, ctrl, "pseudo"):
                return True
            if prop_ok and prop_ok(decls) and reaches(comp, ctrl, "prop"):
                return True
    return False


def tamed_inline(ctrl: dict) -> bool:
    prop_ok = TAME_PROPS.get(ctrl["type"])
    return bool(prop_ok and prop_ok({_norm_prop(k): str(v).strip().lower() for k, v in ctrl["style"].items()}))


def sibling_css_rules(file_path: pathlib.Path) -> list:
    # só CSS com o nome do componente: X.css ou X.module.css (ou equivalente) para X.tsx
    stem = file_path.stem
    names = {stem + ext for ext in CSS_EXTS} | {stem + ".module" + ext for ext in CSS_EXTS}
    rules = []
    for sib in sorted(file_path.parent.iterdir()):
        if sib.is_file() and sib.name in names:
            rules += parse_css(sib.read_text(errors="ignore"), sib.suffix in (".scss", ".less"))
    return rules


# ---------------------------------------------------------------- .vue / .svelte / .html
def _norm_tag(name: str) -> str:
    return name.lower().replace("-", "")


class Markup(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack, self.elements, self.styles, self.scripts = [], [], [], []
        self._raw = None

    def handle_starttag(self, tag, attrs):
        self._element(tag, attrs, False)

    def handle_startendtag(self, tag, attrs):
        self._element(tag, attrs, True)

    def _element(self, tag, attrs, selfclosing):
        a = dict(attrs)
        typ = None
        if "type" in a:
            v = a["type"] or ""
            typ = {"kind": "dynamic"} if v.startswith("{") else {"kind": "literal", "value": v}
        if ":type" in a or "v-bind:type" in a:
            typ = {"kind": "dynamic"}
        style = parse_decls((a.get("style") or "").split(";"))
        entry = {"tag": tag, "norm": _norm_tag(tag), "closed": False}
        self.elements.append({
            "line": self.getpos()[0], "tag": tag, "norm": entry["norm"], "type": typ,
            "classes": (a.get("class") or "").split(), "style": style, "wrappers": list(self.stack),
        })
        if tag in ("style", "script") and not selfclosing:
            self._raw = (tag, a, [])
        if not selfclosing and tag not in VOID:
            self.stack.append(entry)

    def handle_data(self, data):
        if self._raw:
            self._raw[2].append(data)

    def handle_endtag(self, tag):
        if self._raw and tag == self._raw[0]:
            kind, a, data = self._raw
            (self.styles if kind == "style" else self.scripts).append((a.get("lang") or "", "".join(data)))
            self._raw = None
        for idx in range(len(self.stack) - 1, -1, -1):
            if self.stack[idx]["tag"] == tag:
                self.stack[idx]["closed"] = True  # só o fechamento explícito conta
                del self.stack[idx:]
                break


# ---------------------------------------------------------------- helper Node (AST de JSX)
def run_helper(project: pathlib.Path, requests: list) -> dict:
    if not requests:
        return {}
    node = shutil.which("node")
    fail = None
    if node is None:
        fail = "Node ausente"
    else:
        try:
            proc = subprocess.run(
                [node, str(HELPER), str(project)], input=json.dumps(requests), capture_output=True,
                text=True, timeout=300,
            )
            if proc.returncode == 0:
                return json.loads(proc.stdout)
            fail = f"helper de AST falhou: {(proc.stderr.strip().splitlines() or [str(proc.returncode)])[-1]}"
        except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError) as err:
            fail = f"helper de AST falhou: {err}"
    return {r["id"]: {"ok": False, "reason": fail} for r in requests}


def control_of(el: dict):
    """(rótulo, tag do controle) para um controle nativo, ou None."""
    typ = el["type"]
    tag = el["tag"]
    if el.get("intrinsic", True) and tag in ("select", "textarea"):
        return tag, tag
    if typ is None or typ["kind"] == "empty":
        return None
    if typ["kind"] == "dynamic":
        return ("type-dinâmico", "input") if tag == "input" else None
    value = typ["value"].strip().lower()
    if value in INPUT_TYPES:
        return value, ("input" if tag == "input" else None)
    return None


def judge(el: dict, rules: list, is_ds, inside_ds: bool):
    """(veredito, rótulo, motivo) — ou None se o elemento não é controle nativo."""
    found = control_of(el)
    if found is None:
        return None
    label, ctag = found
    if is_ds:
        return "OK", label, "o próprio elemento é componente do DS"
    if inside_ds:
        return "OK", label, "encapsulado em componente do DS"
    if ctag is None:
        return "WARN", label, "componente fora do DS com type nativo"
    if label == "type-dinâmico":
        return "WARN", label, "type dinâmico: tipo não determinado, sem encapsulamento no DS"
    ctrl = {"tag": ctag, "type": label, "classes": set(el["classes"]), "style": el["style"]}
    if tamed_inline(ctrl):
        return "OK", label, "escape de aparência no style do controle"
    if tamed_by_css(ctrl, rules):
        return "OK", label, "escape de aparência no CSS que alcança o controle"
    return "WARN", label, "sem escape de aparência nem encapsulamento no DS"


def main() -> int:
    if len(sys.argv) < 2:
        print("uso: scan-native-controls.py <src_dir>")
        return 2
    src = pathlib.Path(sys.argv[1])
    if not src.exists():
        print(f"FAIL: src_dir não encontrado: {src}")
        return 2

    files, requests, markups = [], [], {}
    for p in sorted(src.rglob("*")):
        if not p.is_file() or (p.suffix not in JSX_LANG and p.suffix not in MARKUP_EXTS):
            continue
        text = p.read_text(errors="ignore")
        # filtro negativo: sem estas palavras não há tag de controle nem atributo type
        if not any(w in text for w in ("input", "select", "textarea", "type")):
            continue
        files.append(p)
        if p.suffix in JSX_LANG:
            requests.append({"id": f"jsx:{p}", "code": text, "lang": JSX_LANG[p.suffix], "mode": "jsx"})
            continue
        m = Markup()
        try:
            m.feed(text)
            m.close()
        except Exception as err:  # noqa: BLE001 — qualquer falha do parser vira "não analisado"
            markups[p] = err
            continue
        markups[p] = m
        if p.suffix != ".html":
            for k, (lang, code) in enumerate(m.scripts):
                lang = lang.lower() if lang.lower() in ("ts", "tsx") else "js"
                requests.append({"id": f"imp:{p}:{k}", "code": code, "lang": lang, "mode": "imports"})
    results = run_helper(src, requests)

    ok_count = warn_count = 0

    def report(verdict, label, where, why):
        nonlocal ok_count, warn_count
        if verdict == "OK":
            ok_count += 1
        else:
            warn_count += 1
        print(f"{verdict} {label}  {where}  ({why})")

    for p in files:
        if p.suffix in JSX_LANG:
            res = results.get(f"jsx:{p}", {"ok": False, "reason": "sem resposta do helper"})
            if not res.get("ok"):
                report("WARN", "não-analisado", p, f"não analisado: {res.get('reason')}")
                continue
            rules = sibling_css_rules(p)
            for css in res["styles"]:
                rules += parse_css(css, False)
            for el in res["elements"]:
                v = judge(el, rules, el["isDs"], el["insideDs"])
                if v:
                    report(v[0], v[1], f"{p}:{el['line']}", v[2])
            continue
        m = markups[p]
        if not isinstance(m, Markup):
            report("WARN", "não-analisado", p, f"não analisado: {m}")
            continue
        ds, ds_fail = set(), None
        for k in range(len(m.scripts)):
            res = results.get(f"imp:{p}:{k}", {"ok": False, "reason": "sem resposta do helper"})
            if res.get("ok"):
                ds |= {_norm_tag(n) for n in res["dsNames"]}
            else:
                ds_fail = res.get("reason")
        rules = sibling_css_rules(p)
        for lang, css in m.styles:
            rules += parse_css(css, lang.lower() in ("scss", "less"))
        for el in m.elements:
            el["intrinsic"] = True
            is_ds = el["norm"].split(".")[0] in ds
            inside = any(w["closed"] and w["norm"].split(".")[0] in ds for w in el["wrappers"])
            v = judge(el, rules, is_ds, inside)
            if v is None:
                continue
            if v[0] == "WARN" and ds_fail:
                v = ("WARN", v[1], f"não analisado: imports do <script> não lidos — {ds_fail}")
            report(v[0], v[1], f"{p}:{el['line']}", v[2])

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
