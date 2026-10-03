#!/usr/bin/env node
// scan-native-controls-ast.mjs <project_dir> — helper de scan-native-controls.py: lê do stdin um
// JSON [{id, code, lang, mode}] e devolve no stdout um JSON {id: resultado}. Faz a análise de
// JSX/TSX sobre a AST do @babel/parser (resolvido primeiro a partir de <project_dir>, depois a
// partir deste arquivo), nunca sobre o texto: comentário e string não são nós JSX.
//   mode "jsx"     → {ok, elements: [...], styles: [css de <style> JSX]}
//   mode "imports" → {ok, dsNames: [...]}   (bloco <script> de .vue/.svelte)
//   falha de parse ou parser ausente → {ok: false, reason}
// Um elemento está DENTRO de um componente do DS só quando um ancestral JSXElement cujo nome vem
// de import de caminho com 'design-system' o contém pelos `children` — atributo não envolve.
import { createRequire } from "node:module";
import path from "node:path";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

function loadParser(projectDir) {
  const bases = [path.join(path.resolve(projectDir), "__forge__.js"), fileURLToPath(import.meta.url)];
  for (const base of bases) {
    try {
      return createRequire(base)("@babel/parser");
    } catch {
      /* tenta a próxima base */
    }
  }
  return null;
}

function pluginsFor(lang) {
  if (lang === "ts") return ["typescript", "decorators-legacy"];
  if (lang === "tsx") return ["jsx", "typescript", "decorators-legacy"];
  return ["jsx", "decorators-legacy"]; // js, jsx
}

function dsNamesOf(ast) {
  const names = new Set();
  for (const node of ast.program.body) {
    if (node.type !== "ImportDeclaration" || node.importKind === "type") continue;
    if (!String(node.source.value).includes("design-system")) continue;
    for (const spec of node.specifiers) {
      if (spec.importKind === "type") continue;
      names.add(spec.local.name);
    }
  }
  return names;
}

// nome da tag e identificador raiz (`DS.Field` → raiz `DS`); intrínseco = minúscula sem ponto
function tagInfo(nameNode) {
  if (nameNode.type === "JSXIdentifier") {
    const n = nameNode.name;
    return { name: n, root: n, intrinsic: /^[a-z]/.test(n) };
  }
  if (nameNode.type === "JSXMemberExpression") {
    let obj = nameNode;
    const parts = [];
    while (obj.type === "JSXMemberExpression") {
      parts.unshift(obj.property.name);
      obj = obj.object;
    }
    parts.unshift(obj.name);
    return { name: parts.join("."), root: obj.name, intrinsic: false };
  }
  return { name: `${nameNode.namespace.name}:${nameNode.name.name}`, root: "", intrinsic: true };
}

// valor estático de uma expressão (string ou template sem expressões); undefined se dinâmico
function staticString(expr) {
  if (!expr) return undefined;
  if (expr.type === "StringLiteral") return expr.value;
  if (expr.type === "TemplateLiteral" && expr.expressions.length === 0) return expr.quasis[0].value.cooked;
  return undefined;
}

function attrValue(attr) {
  // {kind: "literal", value} | {kind: "dynamic"} | {kind: "empty"}
  const v = attr.value;
  if (v == null) return { kind: "empty" };
  if (v.type === "StringLiteral") return { kind: "literal", value: v.value };
  if (v.type === "JSXExpressionContainer") {
    const s = staticString(v.expression);
    if (s !== undefined) return { kind: "literal", value: s };
  }
  return { kind: "dynamic" };
}

// classes estaticamente conhecidas: "a b", {"a b"}, {`a b`}, {styles.a}, {styles["a"]}
function classesOf(attr) {
  const v = attr.value;
  if (v == null) return [];
  if (v.type === "StringLiteral") return v.value.split(/\s+/).filter(Boolean);
  if (v.type !== "JSXExpressionContainer") return [];
  const e = v.expression;
  const s = staticString(e);
  if (s !== undefined) return s.split(/\s+/).filter(Boolean);
  if (e.type === "MemberExpression" && e.object.type === "Identifier") {
    if (!e.computed && e.property.type === "Identifier") return [e.property.name];
    if (e.computed && e.property.type === "StringLiteral") return [e.property.value];
  }
  return [];
}

// style={{ appearance: "none", WebkitAppearance: "none", accentColor: "..." }} — só pares estáticos
function styleOf(attr) {
  const out = {};
  const v = attr.value;
  if (!v || v.type !== "JSXExpressionContainer" || v.expression.type !== "ObjectExpression") return out;
  for (const p of v.expression.properties) {
    if (p.type !== "ObjectProperty" || p.computed) continue;
    const key = p.key.type === "Identifier" ? p.key.name : p.key.type === "StringLiteral" ? p.key.value : null;
    const val = staticString(p.value);
    if (key !== null && val !== undefined) out[key] = val;
  }
  return out;
}

function analyzeJsx(ast) {
  const dsNames = dsNamesOf(ast);
  const elements = [];
  const styles = [];

  function visitElement(node, wrappers) {
    const opening = node.type === "JSXElement" ? node.openingElement : null;
    if (opening) {
      const info = tagInfo(opening.name);
      const el = {
        line: opening.loc.start.line,
        tag: info.name,
        intrinsic: info.intrinsic,
        isDs: dsNames.has(info.root),
        insideDs: wrappers.some((w) => w),
        type: null,
        classes: [],
        style: {},
      };
      for (const attr of opening.attributes) {
        if (attr.type !== "JSXAttribute" || attr.name.type !== "JSXIdentifier") continue;
        const an = attr.name.name;
        if (an === "type") el.type = attrValue(attr);
        else if (an === "className" || an === "class") el.classes.push(...classesOf(attr));
        else if (an === "style") el.style = styleOf(attr);
      }
      elements.push(el);
      if (info.name === "style") {
        for (const child of node.children) {
          if (child.type === "JSXText") styles.push(child.value);
          else if (child.type === "JSXExpressionContainer") {
            const s = staticString(child.expression);
            if (s !== undefined) styles.push(s);
          }
        }
      }
      // atributos: percorridos SEM este elemento como envoltório
      walk(opening, wrappers);
      const inner = wrappers.concat([el.isDs]);
      for (const child of node.children) walk(child, inner);
      return;
    }
    // JSXFragment: não é envoltório, só repassa
    for (const child of node.children) walk(child, wrappers);
  }

  function walk(node, wrappers) {
    if (!node || typeof node.type !== "string") return;
    if (node.type === "JSXElement" || node.type === "JSXFragment") {
      visitElement(node, wrappers);
      return;
    }
    for (const key of Object.keys(node)) {
      if (key === "loc" || key === "leadingComments" || key === "trailingComments" || key === "innerComments")
        continue;
      const val = node[key];
      if (Array.isArray(val)) {
        for (const item of val) if (item && typeof item.type === "string") walk(item, wrappers);
      } else if (val && typeof val.type === "string") {
        walk(val, wrappers);
      }
    }
  }

  walk(ast.program, []);
  return { ok: true, dsNames: [...dsNames], elements, styles };
}

function main() {
  const projectDir = process.argv[2] || ".";
  const requests = JSON.parse(readFileSync(0, "utf8"));
  const parser = loadParser(projectDir);
  const results = {};
  for (const req of requests) {
    if (!parser) {
      results[req.id] = { ok: false, reason: "@babel/parser indisponível" };
      continue;
    }
    let ast;
    try {
      ast = parser.parse(req.code, {
        sourceType: "module",
        plugins: pluginsFor(req.lang),
        errorRecovery: false,
      });
    } catch (err) {
      const where = err.loc ? ` (linha ${err.loc.line})` : "";
      results[req.id] = { ok: false, reason: `erro de parse${where}: ${String(err.message).split("\n")[0]}` };
      continue;
    }
    results[req.id] = req.mode === "imports" ? { ok: true, dsNames: [...dsNamesOf(ast)] } : analyzeJsx(ast);
  }
  process.stdout.write(JSON.stringify(results));
}

main();
