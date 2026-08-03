#!/usr/bin/env node
// forge shared engine — route-scan. Zero-dependency.
//
// Extrai as rotas HTTP que o CÓDIGO de fato expõe, para que "o contrato promete um endpoint" e
// "o endpoint existe" possam ser comparados por script em vez de por leitura.
//
// ── Por que duas passadas, e não um scan por linha ──────────────────────────────────────────
// O `scan()` de source-scan.mjs casa padrão linha a linha, e uma rota real não cabe numa linha.
// No caso que motivou este módulo, o path final nasce de três arquivos e dois saltos:
//
//     Program.cs        var g = app.MapGroup("/internal/v1/orchestrator");  g.MapOrchestratorEndpoints();
//     Endpoints.cs      static X MapOrchestratorEndpoints(this RouteGroupBuilder group) { group.MapPost("/vault/reveal", ...) }
//
// Nenhuma linha contém `/internal/v1/orchestrator/vault/reveal`. Um scanner por linha vê o
// prefixo e vê o sufixo, e nunca vê a rota — o que faz o check passar em silêncio justamente
// onde a superfície é mais difícil de auditar a olho. Daí:
//
//   Passa 1 — indexa RAÍZES (prefixo literal ancorado num símbolo), PRODUTORES (função que
//             registra rotas sobre um grupo recebido) e INVOCAÇÕES (quem chama qual produtor).
//   Passa 2 — compõe transitivamente: a partir de cada raiz, segue as invocações acumulando
//             prefixo, até esgotar. Cada folha vira uma rota com a cadeia que a produziu.
//
// ── Silêncio é proibido ────────────────────────────────────────────────────────────────────
// Invocação cujo produtor não foi encontrado NÃO é descartada: vira `unresolved`. Um prefixo
// irresolúvel que some faz o check de "código→contrato" passar por vacuidade, que é a mesma
// falha de pré-requisito-ausente-vira-verde que o harness proíbe em todo gate.
import { readFileSync } from 'node:fs';
import { relative } from 'node:path';
import { collect, DEFAULT_SKIP } from './source-scan.mjs';

export const ROUTE_EXTS = new Set(['.cs', '.java', '.kt', '.ts', '.js', '.mjs', '.py', '.go']);

const HTTP_VERBS = ['get', 'post', 'put', 'delete', 'patch', 'head', 'options'];

/**
 * Forma canônica de um path de rota, para que duas grafias do mesmo endpoint comparem iguais.
 *
 * Sem isto o cruzamento contrato↔código produz falso positivo imediato: o contrato escreve
 * `/blocks/{terminal}/{sequence}` e o código escreve `/blocks/{terminal}/{sequence:long}`, que
 * são o mesmo endpoint e strings diferentes. As três normalizações:
 *
 *   - constraint de rota some       `{sequence:long}`  → `{}`
 *   - nome de parâmetro some        `{id}` `:id` `<id>` → `{}`   (o nome é do autor, não do contrato)
 *   - barra final e barras duplas   `/a//b/`           → `/a/b`
 */
export function normalizePath(path) {
  if (typeof path !== 'string') return '';
  let p = path.trim();
  if (!p) return '';

  // Chaves: `{id}`, `{id:long}`, `{*rest}`, `{id?}` — tudo vira `{}`.
  p = p.replace(/\{[^{}]*\}/g, '{}');
  // Express/Ktor/Spring por dois-pontos: `/users/:id` → `/users/{}`.
  p = p.replace(/(^|\/):[^/]+/g, '$1{}');
  // Go chi / templates angulares: `/users/<id>` → `/users/{}`.
  p = p.replace(/<[^<>]*>/g, '{}');
  // Curinga de sufixo vira parâmetro — `*` sozinho não distingue endpoint.
  p = p.replace(/(^|\/)\*+(?=$|\/)/g, '$1{}');

  p = p.replace(/\/{2,}/g, '/');
  if (!p.startsWith('/')) p = `/${p}`;
  if (p.length > 1) p = p.replace(/\/+$/, '');
  return p;
}

/** Junta prefixo e sufixo já normalizando — `join('/a/', '/b')` e `join('/a', 'b')` dão `/a/b`. */
export function joinPath(prefix, suffix) {
  const a = (prefix || '').trim();
  const b = (suffix || '').trim();
  if (!a) return normalizePath(b);
  if (!b || b === '/') return normalizePath(a);
  return normalizePath(`${a}/${b}`);
}

// ── extração de literal ────────────────────────────────────────────────────────────────────
// Aceita aspas simples, duplas, template literal sem interpolação e verbatim string do C#.
// Literal COM interpolação (`$"{x}/y"`) é deliberadamente recusado: o path depende de runtime,
// e inventar um valor produziria rota que não existe.
function literal(raw) {
  if (raw === undefined || raw === null) return null;
  const s = String(raw).trim();

  // O reconhecimento do literal e a DECISÃO sobre interpolação ficam separados de propósito. O
  // regex aceita todos os prefixos que o C# admite (`@`, `$`, `$@`, `@$`) e captura o conteúdo;
  // quem recusa é a linha abaixo, sozinha. Defesa dupla aqui foi um problema real: enquanto o
  // regex também barrava o interpolado, mutar a regra não mudava comportamento nenhum, e a
  // prova de mutação não conseguia matar a mutação — um teste que não pode falhar não é teste.
  const m = s.match(/^(@\$|\$@|[@$])?(["'`])([^"'`]*)\2$/);
  if (!m) return null;

  // Prefixo com `$` é interpolação: o valor depende de runtime, e aceitar o texto entre aspas
  // produziria uma rota que não existe — com o SUR-01 dando veredito confiante sobre ela.
  const prefixo = m[1] || '';
  if (prefixo.includes('$')) return null;

  return m[3];
}

function stripComments(text) {
  // Remove // e /* */ e # (Python) sem tentar ser um parser — o objetivo é só evitar que rota
  // comentada conte como rota exposta, que seria falso positivo caro no SUR-02.
  return text
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .split('\n')
    .map((l) => l.replace(/\/\/.*$/, '').replace(/(^|\s)#(?!\[).*$/, '$1'))
    .join('\n');
}

function lineOf(text, index) {
  return text.slice(0, index).split('\n').length;
}

// ── Passa 1: indexação por dialeto ─────────────────────────────────────────────────────────

/**
 * .NET minimal API. Três coisas a reconhecer:
 *   raiz      `var g = app.MapGroup("/x")`            → símbolo `g` ancora o prefixo `/x`
 *   produtor  `static X MapY(this RouteGroupBuilder g)` → função `MapY` registra sobre o grupo
 *   rota      `g.MapPost("/y", Handler)`               → sufixo `/y` sobre o símbolo `g`
 *   invocação `g.MapY()`                               → liga `g` a `MapY`
 */
/**
 * Extrai o corpo de um bloco `{...}` balanceado a partir da posição do `{`.
 * Devolve `{body, end}` ou `null` quando as chaves não fecham (arquivo truncado).
 */
function blockAt(text, openIndex) {
  let depth = 0;
  for (let i = openIndex; i < text.length; i += 1) {
    const c = text[i];
    if (c === '{') depth += 1;
    else if (c === '}') {
      depth -= 1;
      if (depth === 0) return { body: text.slice(openIndex + 1, i), start: openIndex + 1, end: i };
    }
  }
  return null;
}

/**
 * .NET minimal API. Reconhece raiz, produtor, rota e invocação.
 *
 * O escopo é o CORPO da função, nunca o nome do símbolo isolado: praticamente todo produtor
 * chama seu parâmetro de `group`, e indexar por nome global faria as rotas de um produtor
 * aparecerem penduradas em todos os outros — combinatória que estourou a heap na primeira
 * versão deste módulo, antes de produzir uma única rota errada em silêncio.
 */
function indexDotnetMinimal(text, file, idx) {
  const producerRe = /\b(?:public|internal|private)?\s*static\s+[\w<>,.\[\]?]+\s+(\w+)\s*\(\s*this\s+(?:IEndpointRouteBuilder|RouteGroupBuilder|WebApplication)\s+(\w+)[^)]*\)/g;
  const producerBodies = [];
  for (let m; (m = producerRe.exec(text)); ) {
    const open = text.indexOf('{', m.index + m[0].length);
    if (open === -1) continue;
    const blk = blockAt(text, open);
    if (!blk) continue;
    const scope = `${file}#${m[1]}`;
    idx.producers.set(m[1], { name: m[1], scope, param: m[2], file, line: lineOf(text, m.index) });
    producerBodies.push({ scope, param: m[2], start: blk.start, end: blk.end });
  }

  // Um índice pertence ao produtor mais interno que o contém; fora de todos, ao escopo do arquivo.
  const scopeAt = (index) => {
    let best = null;
    for (const b of producerBodies) {
      if (index > b.start && index < b.end && (!best || b.start > best.start)) best = b;
    }
    return best ? best.scope : `${file}#<top>`;
  };

  const groupRe = /(?:var|RouteGroupBuilder)\s+(\w+)\s*=\s*(\w+)\s*\.\s*MapGroup\s*\(\s*([^)]*?)\s*\)/g;
  for (let m; (m = groupRe.exec(text)); ) {
    const [, symbol, parent, rawPath] = m;
    const lit = literal(rawPath);
    const scope = scopeAt(m.index);
    if (lit === null) {
      idx.unresolved.push({ kind: 'group-path-not-literal', file, line: lineOf(text, m.index), detail: rawPath.slice(0, 60) });
      continue;
    }
    idx.groups.push({ id: `${scope}:${symbol}`, scope, symbol, parent: `${scope}:${parent}`, path: lit, file, line: lineOf(text, m.index) });
  }

  for (const verb of HTTP_VERBS) {
    const cap = verb[0].toUpperCase() + verb.slice(1);
    const re = new RegExp(`(\\w+)\\s*\\.\\s*Map${cap}\\s*\\(\\s*([^,)]*)`, 'g');
    for (let m; (m = re.exec(text)); ) {
      const lit = literal(m[2]);
      const scope = scopeAt(m.index);
      if (lit === null) {
        idx.unresolved.push({ kind: 'route-path-not-literal', file, line: lineOf(text, m.index), detail: m[2].slice(0, 60) });
        continue;
      }
      idx.routes.push({ owner: `${scope}:${m[1]}`, method: verb.toUpperCase(), path: lit, file, line: lineOf(text, m.index) });
    }
  }

  const callRe = /(\w+)\s*\.\s*(Map[A-Z]\w*)\s*\(\s*\)/g;
  for (let m; (m = callRe.exec(text)); ) {
    if (/^Map(Get|Post|Put|Delete|Patch|Head|Options|Group)$/.test(m[2])) continue;
    idx.calls.push({ owner: `${scopeAt(m.index)}:${m[1]}`, producer: m[2], file, line: lineOf(text, m.index) });
  }
}

/** .NET com atributos: `[Route("api/[controller]")]` na classe + `[HttpGet("{id}")]` no método. */
function indexDotnetAttributes(text, file, idx) {
  const classRe = /\[\s*Route\s*\(\s*([^)]*?)\s*\)\s*\][\s\S]{0,400}?\bclass\s+(\w+)/g;
  const classPrefix = new Map();
  for (let m; (m = classRe.exec(text)); ) {
    const lit = literal(m[1]);
    if (lit === null) continue;
    // `[controller]` é substituído pelo nome da classe sem o sufixo Controller.
    const resolved = lit.replace(/\[controller\]/gi, m[2].replace(/Controller$/, ''));
    classPrefix.set(m[2], resolved);
  }
  const soleClassPrefix = classPrefix.size === 1 ? [...classPrefix.values()][0] : '';

  for (const verb of HTTP_VERBS) {
    const cap = verb[0].toUpperCase() + verb.slice(1);
    const re = new RegExp(`\\[\\s*Http${cap}\\s*(?:\\(\\s*([^)]*?)\\s*\\))?\\s*\\]`, 'g');
    for (let m; (m = re.exec(text)); ) {
      const lit = m[1] === undefined ? '' : literal(m[1]);
      if (m[1] !== undefined && lit === null) {
        idx.unresolved.push({ kind: 'route-path-not-literal', file, line: lineOf(text, m.index), detail: String(m[1]).slice(0, 60) });
        continue;
      }
      idx.absolute.push({ method: verb.toUpperCase(), path: joinPath(soleClassPrefix, lit || ''), file, line: lineOf(text, m.index) });
    }
  }
}

/** Spring: `@RequestMapping("/x")` na classe + `@GetMapping("/y")` no método. */
function indexSpring(text, file, idx) {
  let prefix = '';
  const clazz = text.match(/@RequestMapping\s*\(\s*(?:value\s*=\s*)?([^)]*?)\s*\)[\s\S]{0,200}?\bclass\s+\w+/);
  if (clazz) prefix = literal(clazz[1]) || '';

  for (const verb of HTTP_VERBS) {
    const cap = verb[0].toUpperCase() + verb.slice(1);
    const re = new RegExp(`@${cap}Mapping\\s*(?:\\(\\s*(?:value\\s*=\\s*)?([^)]*?)\\s*\\))?`, 'g');
    for (let m; (m = re.exec(text)); ) {
      const lit = m[1] === undefined ? '' : literal(m[1]);
      if (m[1] !== undefined && lit === null) {
        idx.unresolved.push({ kind: 'route-path-not-literal', file, line: lineOf(text, m.index), detail: String(m[1]).slice(0, 60) });
        continue;
      }
      idx.absolute.push({ method: verb.toUpperCase(), path: joinPath(prefix, lit || ''), file, line: lineOf(text, m.index) });
    }
  }
}

/**
 * Ktor: `route("/x") { get("/y") { ... } }` — aninhamento léxico define o prefixo.
 * Rastreia profundidade de chaves para saber qual `route` ainda está aberto.
 */
function indexKtor(text, file, idx) {
  const tokens = [];
  const re = /\broute\s*\(\s*([^)]*?)\s*\)\s*\{|\b(get|post|put|delete|patch|head|options)\s*\(\s*([^)]*?)\s*\)\s*\{|\{|\}/g;
  const stack = [];
  let depth = 0;
  for (let m; (m = re.exec(text)); ) {
    if (m[0] === '{') { depth += 1; continue; }
    if (m[0] === '}') {
      depth -= 1;
      while (stack.length && stack[stack.length - 1].depth > depth) stack.pop();
      continue;
    }
    if (m[1] !== undefined) {
      const lit = literal(m[1]);
      depth += 1;
      if (lit === null) {
        idx.unresolved.push({ kind: 'group-path-not-literal', file, line: lineOf(text, m.index), detail: m[1].slice(0, 60) });
        stack.push({ path: '', depth });
      } else {
        stack.push({ path: lit, depth });
      }
      continue;
    }
    if (m[2] !== undefined) {
      const lit = literal(m[3]) ?? '';
      depth += 1;
      const prefix = stack.map((s) => s.path).join('/');
      tokens.push({ method: m[2].toUpperCase(), path: joinPath(prefix, lit), file, line: lineOf(text, m.index) });
    }
  }
  idx.absolute.push(...tokens);
}

/** Express/Fastify (`app.get('/x', h)`, `router.post(...)`) e Nest (`@Controller('x')` + `@Get('y')`). */
function indexJsHttp(text, file, idx) {
  let nestPrefix = null;
  const ctrl = text.match(/@Controller\s*\(\s*([^)]*?)\s*\)/);
  if (ctrl) nestPrefix = literal(ctrl[1]) ?? '';

  for (const verb of HTTP_VERBS) {
    const re = new RegExp(`\\b(?:app|router|server|fastify|api)\\s*\\.\\s*${verb}\\s*\\(\\s*([^,)]*)`, 'g');
    for (let m; (m = re.exec(text)); ) {
      const lit = literal(m[1]);
      if (lit === null) {
        idx.unresolved.push({ kind: 'route-path-not-literal', file, line: lineOf(text, m.index), detail: m[1].slice(0, 60) });
        continue;
      }
      idx.absolute.push({ method: verb.toUpperCase(), path: normalizePath(lit), file, line: lineOf(text, m.index) });
    }
  }

  if (nestPrefix !== null) {
    for (const verb of HTTP_VERBS) {
      const cap = verb[0].toUpperCase() + verb.slice(1);
      const re = new RegExp(`@${cap}\\s*\\(\\s*([^)]*?)\\s*\\)`, 'g');
      for (let m; (m = re.exec(text)); ) {
        const lit = m[1] === '' ? '' : literal(m[1]);
        if (m[1] !== '' && lit === null) continue;
        idx.absolute.push({ method: verb.toUpperCase(), path: joinPath(nestPrefix, lit || ''), file, line: lineOf(text, m.index) });
      }
    }
  }
}

// ── Passa 2: composição transitiva ─────────────────────────────────────────────────────────

function compose(idx) {
  const routes = [];
  const unresolved = [...idx.unresolved];

  // Rotas já absolutas (atributos, Spring, Ktor, Express) entram direto — nesses dialetos o
  // prefixo é léxico e já foi resolvido na indexação.
  for (const a of idx.absolute) {
    routes.push({ method: a.method, path: normalizePath(a.path), file: a.file, line: a.line, chain: [] });
  }

  const routesByOwner = new Map();
  for (const r of idx.routes) {
    if (!routesByOwner.has(r.owner)) routesByOwner.set(r.owner, []);
    routesByOwner.get(r.owner).push(r);
  }
  const callsByOwner = new Map();
  for (const c of idx.calls) {
    if (!callsByOwner.has(c.owner)) callsByOwner.set(c.owner, []);
    callsByOwner.get(c.owner).push(c);
  }

  const groupById = new Map();
  for (const g of idx.groups) groupById.set(g.id, g);

  function prefixOf(g, seen = new Set()) {
    if (seen.has(g.id)) return normalizePath(g.path);
    seen.add(g.id);
    const parent = groupById.get(g.parent);
    return parent ? joinPath(prefixOf(parent, seen), g.path) : normalizePath(g.path);
  }

  const MAX_DEPTH = 12;
  const consumed = new Set();

  function walk(ownerId, prefix, chain, depth) {
    if (depth > MAX_DEPTH) {
      unresolved.push({ kind: 'chain-too-deep', file: chain[chain.length - 1] || '?', line: 0, detail: `cadeia excedeu ${MAX_DEPTH} saltos a partir de '${prefix}'` });
      return;
    }
    consumed.add(ownerId);

    for (const r of routesByOwner.get(ownerId) || []) {
      routes.push({ method: r.method, path: joinPath(prefix, r.path), file: r.file, line: r.line, chain: [...chain] });
    }
    for (const c of callsByOwner.get(ownerId) || []) {
      const producer = idx.producers.get(c.producer);
      if (!producer) {
        unresolved.push({
          kind: 'producer-not-found',
          file: c.file,
          line: c.line,
          detail: `${c.producer}() — nenhuma definição encontrada; o prefixo '${prefix}' fica sem sufixo conhecido`,
        });
        continue;
      }
      walk(`${producer.scope}:${producer.param}`, prefix, [...chain, c.producer], depth + 1);
    }
  }

  // Raízes: grupos cujo pai não é outro grupo conhecido (tipicamente `app`/`builder`).
  for (const g of idx.groups) {
    if (groupById.has(g.parent)) continue;
    walk(g.id, prefixOf(g), [`MapGroup(${g.path})`], 0);
  }
  // Grupos aninhados também precisam ser percorridos, com o prefixo já composto.
  for (const g of idx.groups) {
    if (!groupById.has(g.parent)) continue;
    walk(g.id, prefixOf(g), [`MapGroup(${g.path})`], 0);
  }

  // Rotas registradas fora de qualquer grupo (`app.MapGet(...)` direto no Program.cs).
  //
  // Owners que são o parâmetro de um produtor ficam de fora deste fallback, mesmo quando o
  // produtor não foi alcançado: emitir a rota sem o prefixo do grupo produziria um path que não
  // existe em lugar nenhum — `/vault/reveal` em vez de `/internal/v1/orchestrator/vault/reveal`.
  // Um path errado é pior que nenhum, porque o SUR-01 compararia contra ele e daria veredito
  // confiante sobre uma rota inventada. O caso já está reportado como `producer-never-invoked`.
  const producerOwners = new Set([...idx.producers.values()].map((p) => `${p.scope}:${p.param}`));
  for (const [owner, list] of routesByOwner) {
    if (consumed.has(owner) || groupById.has(owner) || producerOwners.has(owner)) continue;
    for (const r of list) routes.push({ method: r.method, path: normalizePath(r.path), file: r.file, line: r.line, chain: [] });
  }

  // Produtor que registra rotas e nunca é invocado: as rotas existem no código e não estão
  // penduradas em prefixo conhecido. Reportado, nunca descartado — é o caso em que o SUR-02
  // passaria por vacuidade.
  const invoked = new Set();
  for (const c of idx.calls) if (idx.producers.has(c.producer)) invoked.add(c.producer);
  for (const [name, prod] of idx.producers) {
    if (invoked.has(name)) continue;
    const owned = routesByOwner.get(`${prod.scope}:${prod.param}`) || [];
    if (owned.length === 0) continue;
    unresolved.push({
      kind: 'producer-never-invoked',
      file: prod.file,
      line: prod.line,
      detail: `${name}() registra ${owned.length} rota(s) e não é invocado por grupo nenhum — prefixo desconhecido`,
    });
  }

  return { routes, unresolved };
}

// ── API pública ────────────────────────────────────────────────────────────────────────────

/**
 * Varre os caminhos informados e devolve as rotas HTTP que o código expõe.
 *
 * @returns {{routes: Array, unresolved: Array}} `routes` com `{method, path, file, line, chain}`
 *          já normalizados e deduplicados; `unresolved` com tudo que o scanner viu e não
 *          conseguiu resolver — nunca vazio por omissão.
 */
export function scanRoutes(paths, { exts = ROUTE_EXTS, skipDirs = DEFAULT_SKIP, root = process.cwd() } = {}) {
  const files = collect(paths, { exts, skipDirs });
  const idx = { groups: [], producers: new Map(), routes: [], calls: [], absolute: [], unresolved: [] };

  for (const f of files) {
    const raw = readFileSync(f, 'utf8');
    const text = stripComments(raw);
    const rel = relative(root, f) || f;
    const ext = f.slice(f.lastIndexOf('.'));

    if (ext === '.cs') {
      indexDotnetMinimal(text, rel, idx);
      indexDotnetAttributes(text, rel, idx);
    } else if (ext === '.java') {
      indexSpring(text, rel, idx);
    } else if (ext === '.kt') {
      indexKtor(text, rel, idx);
      indexSpring(text, rel, idx);
    } else if (ext === '.ts' || ext === '.js' || ext === '.mjs') {
      indexJsHttp(text, rel, idx);
    }
  }

  const { routes, unresolved } = compose(idx);

  const seen = new Set();
  const deduped = [];
  for (const r of routes) {
    const key = `${r.method} ${r.path}`;
    if (seen.has(key)) continue;
    seen.add(key);
    deduped.push(r);
  }
  deduped.sort((a, b) => (a.path === b.path ? a.method.localeCompare(b.method) : a.path.localeCompare(b.path)));

  return { routes: deduped, unresolved };
}

/** Conjunto `MÉTODO path` das rotas, para cruzamento com o contrato. */
export function routeKeys(routes) {
  return new Set(routes.map((r) => `${r.method} ${r.path}`));
}
