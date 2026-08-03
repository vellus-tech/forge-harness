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
//   Passa 2 — compõe transitivamente a partir de cada OWNER RAIZ, acumulando prefixo, até
//             esgotar. Cada folha vira uma rota com a cadeia que a produziu.
//
// ── Absoluto × relativo: a distinção que faz a composição fechar ────────────────────────────
// `MapX(this WebApplication app)` recebe a RAIZ da aplicação: um grupo aberto sobre `app` vale
// `/x` seja quem for que chame `MapX`. `MapY(this RouteGroupBuilder group)` recebe um grupo já
// prefixado: as rotas dele só têm path depois que se sabe QUEM o invocou. Tratar os dois iguais
// é o que fazia um subgrupo aberto dentro de um produtor relativo perder o prefixo do chamador
// e sair como `/invoices/{id}` no lugar de `/internal/v1/invoices/{id}`.
//
// ── Silêncio é proibido, e path inventado é pior que ausente ────────────────────────────────
// Duas invariantes, nesta ordem:
//   1. O que o scanner viu e não resolveu vira `unresolved` — nunca é descartado. Prefixo
//      irresolúvel que some faz o cruzamento passar por vacuidade, que é a mesma falha de
//      pré-requisito-ausente-vira-verde que o harness proíbe em todo gate.
//   2. Rota cujo prefixo o scanner não conseguiu compor NÃO é emitida com o path parcial. Um
//      path parcial não existe em runtime nenhum, e o SUR-01 — que bloqueia — daria veredito
//      confiante sobre ele. Ausente o SUR-02 acusa; inventado ninguém acusa.
import { readFileSync } from 'node:fs';
import { relative } from 'node:path';
import { collect, DEFAULT_SKIP } from './source-scan.mjs';

export const ROUTE_EXTS = new Set(['.cs', '.java', '.kt', '.ts', '.js', '.mjs', '.py', '.go']);

const HTTP_VERBS = ['get', 'post', 'put', 'delete', 'patch', 'head', 'options'];

/** Tipos .NET que representam a RAIZ da aplicação, não um grupo já prefixado. */
const ROOT_BUILDER_TYPES = /^(WebApplication|IEndpointRouteBuilder)$/;

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
// Aceita aspas simples, duplas, template literal e verbatim string do C#. Literal COM
// interpolação é deliberadamente recusado, em QUALQUER das duas formas em que ela aparece:
//
//   prefixo da aspa   C#            `$"..."`, `$@"..."`, `@$"..."`
//   dentro da aspa    JS/TS/Kotlin  `` `${base}/users` ``, Kotlin `"$API_BASE/payments"`
//
// A segunda forma é a que mais importa na prática: prefixo em variável é o idioma padrão de
// Express, Fastify e Ktor. Aceitar o texto entre aspas produz `/${}/users`, que não é rota de
// lugar nenhum — e o SUR-01, que bloqueia, compararia o contrato contra ela.
function literal(raw) {
  if (raw === undefined || raw === null) return null;
  const s = String(raw).trim();

  // O reconhecimento do literal e a DECISÃO sobre interpolação ficam separados de propósito. O
  // regex aceita todos os prefixos que o C# admite (`@`, `$`, `$@`, `@$`) e captura o conteúdo;
  // quem recusa são as linhas abaixo, sozinhas. Defesa dupla aqui foi um problema real: enquanto
  // o regex também barrava o interpolado, mutar a regra não mudava comportamento nenhum, e a
  // prova de mutação não conseguia matar a mutação — um teste que não pode falhar não é teste.
  const m = s.match(/^(@\$|\$@|[@$])?(["'`])([^"'`]*)\2$/);
  if (!m) return null;

  const prefixo = m[1] || '';
  if (prefixo.includes('$')) return null;

  const conteudo = m[3];
  // `${...}` cobre template literal de JS/TS e interpolação de expressão do Kotlin; `$ident`
  // cobre a forma curta do Kotlin. `$5` e `$` sozinho não são interpolação e passam.
  if (/\$\{/.test(conteudo)) return null;
  if (/\$[A-Za-z_]/.test(conteudo)) return null;

  return conteudo;
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

function push(map, key, value) {
  if (!map.has(key)) map.set(key, []);
  map.get(key).push(value);
}

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
 * Classes do arquivo com o intervalo do corpo, para atribuir cada atributo à sua classe.
 *
 * Classe SEM corpo (`data class OrderDto(val id: Long)` do Kotlin, a forma dominante lá) não tem
 * `{` próprio: procurar a próxima chave acharia a de abertura da classe SEGUINTE, e as duas
 * passariam a compartilhar o mesmo intervalo. O desempate por classe mais interna daria a vitória
 * à DTO, que não tem `@RequestMapping`, e o prefixo do controller sumiria — path inventado, e
 * intermitente conforme a ordem das declarações no arquivo.
 */
function classesOf(text) {
  const decls = [];
  const re = /\bclass\s+(\w+)/g;
  for (let m; (m = re.exec(text)); ) decls.push({ name: m[1], declIndex: m.index, after: m.index + m[0].length });

  const out = [];
  decls.forEach((d, i) => {
    const limite = i + 1 < decls.length ? decls[i + 1].declIndex : text.length;
    const open = text.indexOf('{', d.after);
    if (open === -1 || open >= limite) return;
    const blk = blockAt(text, open);
    if (!blk) return;
    out.push({ name: d.name, declIndex: d.declIndex, start: blk.start, end: blk.end });
  });
  return out;
}

/**
 * Último atributo `[Nome(...)]` / `@Nome(...)` entre `from` e a declaração.
 *
 * A janela vai do fim da classe ANTERIOR até esta declaração, não um número fixo de caracteres.
 * Uma janela por contagem erra dos dois lados: curta demais, o `[Route]` de um controller com o
 * conjunto normal de atributos (`[Produces]`, `[Authorize]`, dois `[ProducesResponseType]`) cai
 * fora e o prefixo evapora; longa demais, uma classe sem `[Route]` herda o da classe anterior e
 * ganha um prefixo que não é dela.
 */
function attrBefore(text, from, to, pattern) {
  const win = text.slice(Math.max(0, from), to);
  let last = null;
  pattern.lastIndex = 0;
  for (let m; (m = pattern.exec(win)); ) last = m[1];
  pattern.lastIndex = 0;
  return last;
}

/** Encontra a classe mais interna que contém o índice. */
function containerOf(classes, index) {
  let best = null;
  for (const c of classes) {
    if (index > c.start && index < c.end && (!best || c.start > best.start)) best = c;
  }
  return best;
}

// ── Passa 1: indexação por dialeto ─────────────────────────────────────────────────────────

/**
 * Registra a cadeia `x.MapGroup("/a").MapGroup("/b")` como grupos encadeados e devolve o id do
 * último elo. Um `MapGroup` encadeado sem isto perderia todos os segmentos menos o primeiro.
 * Elo cujo path não é literal entra com `path: null` — o grupo existe, o prefixo não se sabe, e
 * a composição para ali em vez de emitir path parcial.
 */
function pushGroupChain(idx, { scope, symbol, parentId, chainSrc, file, line, truncada = false }) {
  const segs = [...chainSrc.matchAll(/\.\s*MapGroup\s*\(\s*([^)]*?)\s*\)/g)].map((x) => x[1]);
  let parent = parentId;
  segs.forEach((raw, i) => {
    const last = i === segs.length - 1;
    const id = last ? `${scope}:${symbol}` : `${scope}:${symbol}#elo${i}`;
    let lit = literal(raw);
    if (lit === null) {
      idx.unresolved.push({ kind: 'group-path-not-literal', file, line, detail: raw.slice(0, 60) });
    }
    // Cadeia com elo fora do alcance do reconhecedor: o último elo carrega a incerteza, para que
    // nenhuma rota pendurada nele saia com o prefixo pela metade.
    if (last && truncada) lit = null;
    idx.groups.push({ id, scope, symbol, parent, path: lit, file, line });
    parent = id;
  });
  return parent;
}

/**
 * .NET minimal API. Reconhece raiz, produtor, rota, invocação e cadeia fluente.
 *
 * O escopo de um símbolo é o CORPO da função, nunca o nome isolado: praticamente todo produtor
 * chama seu parâmetro de `group`, e indexar por nome global faria as rotas de um produtor
 * aparecerem penduradas em todos os outros. O índice de PRODUTORES é por nome — é assim que a
 * invocação os encontra —, mas guarda TODAS as definições homônimas: com mais de uma, o scanner
 * não sabe qual delas a invocação alcança e reporta `producer-ambiguous` em vez de escolher.
 * Escolher (o comportamento anterior, em que a última definição lida sobrescrevia as outras)
 * emitia rota cruzada entre módulos e perdia a rota real, sem nenhum diagnóstico.
 */
function indexDotnetMinimal(text, file, idx) {
  const gruposAntes = idx.groups.length;
  const rotasAntes = idx.routes.length + idx.absolute.length;
  const sitiosGrupo = (text.match(/\.\s*MapGroup\s*\(/g) || []).length;
  const sitiosVerbo = (text.match(/\.\s*Map(?:Get|Post|Put|Delete|Patch|Head|Options)\s*\(/g) || []).length;

  const producerRe = /\b(?:public|internal|private|protected)?\s*static\s+[\w<>,.\[\]?]+\s+(\w+)\s*(?:<[^<>()]*>)?\s*\(\s*(?:this\s+)?(IEndpointRouteBuilder|RouteGroupBuilder|WebApplication)\s+(\w+)[^)]*\)/g;
  const producerBodies = [];
  for (let m; (m = producerRe.exec(text)); ) {
    const open = text.indexOf('{', m.index + m[0].length);
    if (open === -1) continue;
    const blk = blockAt(text, open);
    if (!blk) continue;
    const [, name, type, param] = m;
    const scope = `${file}#${name}`;
    push(idx.producers, name, {
      name,
      scope,
      param,
      rootLike: ROOT_BUILDER_TYPES.test(type),
      file,
      line: lineOf(text, m.index),
    });
    producerBodies.push({ scope, param, start: blk.start, end: blk.end });
  }

  // Um índice pertence ao produtor mais interno que o contém; fora de todos, ao escopo do arquivo.
  const scopeAt = (index) => {
    let best = null;
    for (const b of producerBodies) {
      if (index > b.start && index < b.end && (!best || b.start > best.start)) best = b;
    }
    return best ? best.scope : `${file}#<top>`;
  };

  const CHAIN = '(?:\\s*\\.\\s*MapGroup\\s*\\(\\s*[^)]*?\\s*\\))+';

  const groupRe = new RegExp(`(?:var|RouteGroupBuilder)\\s+(\\w+)\\s*=\\s*(\\w+)(${CHAIN})([^;]*)`, 'g');
  for (let m; (m = groupRe.exec(text)); ) {
    const [, symbol, parent, chainSrc, resto] = m;
    const scope = scopeAt(m.index);
    const line = lineOf(text, m.index);
    const perdido = /\.\s*MapGroup\s*\(/.test(resto || '');
    pushGroupChain(idx, { scope, symbol, parentId: `${scope}:${parent}`, chainSrc, file, line, truncada: perdido });
  }

  // Cadeia fluente sem atribuição: `app.MapGroup("/x").MapGet("/y", H)` e
  // `app.MapGroup("/x").MapTokenEndpoints()`. Sem isto o registro é INVISÍVEL — o receptor do
  // verbo passa a ser `)`, que não casa `\w+`, e nem rota nem `unresolved` saíam.
  let fluentSeq = 0;
  for (const verb of HTTP_VERBS) {
    const cap = verb[0].toUpperCase() + verb.slice(1);
    const re = new RegExp(`\\b(\\w+)(${CHAIN})\\s*\\.\\s*Map${cap}\\s*\\(\\s*([^,)]*)`, 'g');
    for (let m; (m = re.exec(text)); ) {
      const [, recv, chainSrc, rawPath] = m;
      const scope = scopeAt(m.index);
      const line = lineOf(text, m.index);
      fluentSeq += 1;
      const ownerId = pushGroupChain(idx, { scope, symbol: `#fluente${fluentSeq}`, parentId: `${scope}:${recv}`, chainSrc, file, line });
      const lit = literal(rawPath);
      if (lit === null) {
        idx.unresolved.push({ kind: 'route-path-not-literal', file, line, detail: rawPath.slice(0, 60) });
        continue;
      }
      idx.routes.push({ owner: ownerId, method: verb.toUpperCase(), path: lit, file, line });
    }
  }
  const fluentCallRe = new RegExp(`\\b(\\w+)(${CHAIN})\\s*\\.\\s*(Map[A-Z]\\w*)\\s*\\(\\s*\\)`, 'g');
  for (let m; (m = fluentCallRe.exec(text)); ) {
    const [, recv, chainSrc, producer] = m;
    if (/^Map(Get|Post|Put|Delete|Patch|Head|Options|Group)$/.test(producer)) continue;
    const scope = scopeAt(m.index);
    const line = lineOf(text, m.index);
    fluentSeq += 1;
    const ownerId = pushGroupChain(idx, { scope, symbol: `#fluente${fluentSeq}`, parentId: `${scope}:${recv}`, chainSrc, file, line });
    idx.calls.push({ owner: ownerId, producer, file, line });
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

  const gruposVistos = idx.groups.length - gruposAntes;
  if (gruposVistos < sitiosGrupo) {
    idx.unresolved.push({
      kind: 'mapgroup-unindexed',
      file,
      line: 0,
      detail: `${sitiosGrupo - gruposVistos} chamada(s) MapGroup() que o scanner não conseguiu ancorar (elo não adjacente, receptor composto); o prefixo delas não entra em rota nenhuma`,
    });
  }
  const rotasVistas = idx.routes.length + idx.absolute.length - rotasAntes;
  const naoLiterais = idx.unresolved.filter((u) => u.file === file && u.kind === 'route-path-not-literal').length;
  if (rotasVistas + naoLiterais < sitiosVerbo) {
    idx.unresolved.push({
      kind: 'route-site-unindexed',
      file,
      line: 0,
      detail: `${sitiosVerbo - rotasVistas - naoLiterais} registro(s) de verbo HTTP que o scanner não conseguiu ancorar a um receptor conhecido`,
    });
  }
}

/**
 * .NET com atributos: `[Route("api/[controller]")]` na classe + `[HttpGet("{id}")]` no método.
 *
 * O prefixo é resolvido POR CLASSE, pela posição do atributo dentro do corpo. Usar "o prefixo do
 * arquivo, se houver exatamente um" fazia dois controllers no mesmo `.cs` descartarem os dois
 * prefixos e emitirem `/list` no lugar de `/api/alpha/list` — path inventado, sem diagnóstico.
 */
function indexDotnetAttributes(text, file, idx) {
  const classes = classesOf(text);
  const prefixes = new Map();
  classes.forEach((c, i) => {
    const desde = i > 0 ? classes[i - 1].end : 0;
    const raw = attrBefore(text, desde, c.declIndex, /\[\s*Route\s*\(\s*([^)]*?)\s*\)\s*\]/g);
    if (raw === null) { prefixes.set(c.name, { path: '', ok: true }); return; }
    const lit = literal(raw);
    if (lit === null) {
      idx.unresolved.push({ kind: 'class-route-not-literal', file, line: lineOf(text, c.declIndex), detail: raw.slice(0, 60) });
      prefixes.set(c.name, { path: '', ok: false });
      return;
    }
    // `[controller]` é substituído pelo nome da classe sem o sufixo Controller.
    prefixes.set(c.name, { path: lit.replace(/\[controller\]/gi, c.name.replace(/Controller$/, '')), ok: true });
  });

  for (const verb of HTTP_VERBS) {
    const cap = verb[0].toUpperCase() + verb.slice(1);
    const re = new RegExp(`\\[\\s*Http${cap}\\s*(?:\\(\\s*([^)]*?)\\s*\\))?\\s*\\]`, 'g');
    for (let m; (m = re.exec(text)); ) {
      const line = lineOf(text, m.index);
      const owner = containerOf(classes, m.index);
      const pref = owner ? prefixes.get(owner.name) : { path: '', ok: true };
      const lit = m[1] === undefined ? '' : literal(m[1]);
      if (m[1] !== undefined && lit === null) {
        idx.unresolved.push({ kind: 'route-path-not-literal', file, line, detail: String(m[1]).slice(0, 60) });
        continue;
      }
      if (!pref || !pref.ok) {
        idx.unresolved.push({ kind: 'route-prefix-unresolved', file, line, detail: `[Http${cap}] em classe cujo [Route] não é literal — prefixo desconhecido` });
        continue;
      }
      idx.absolute.push({ method: verb.toUpperCase(), path: joinPath(pref.path, lit || ''), file, line });
    }
  }
}

/**
 * Spring: `@RequestMapping("/x")` na classe + `@GetMapping("/y")` no método.
 *
 * Também por classe, e pelo mesmo motivo: pegar só o primeiro `@RequestMapping` do arquivo
 * aplicava o prefixo de uma classe às rotas de todas as outras. Em `.kt`, onde várias classes
 * por arquivo é a norma, isso trocava o prefixo de metade das rotas.
 */
function indexSpring(text, file, idx) {
  const classes = classesOf(text);
  const prefixes = new Map();
  classes.forEach((c, i) => {
    const desde = i > 0 ? classes[i - 1].end : 0;
    const raw = attrBefore(text, desde, c.declIndex, /@RequestMapping\s*\(\s*(?:value\s*=\s*)?([^)]*?)\s*\)/g);
    if (raw === null) { prefixes.set(c.name, { path: '', ok: true }); return; }
    const lit = literal(raw);
    if (lit === null) {
      idx.unresolved.push({ kind: 'class-route-not-literal', file, line: lineOf(text, c.declIndex), detail: raw.slice(0, 60) });
      prefixes.set(c.name, { path: '', ok: false });
      return;
    }
    prefixes.set(c.name, { path: lit, ok: true });
  });

  for (const verb of HTTP_VERBS) {
    const cap = verb[0].toUpperCase() + verb.slice(1);
    const re = new RegExp(`@${cap}Mapping\\s*(?:\\(\\s*(?:value\\s*=\\s*)?([^)]*?)\\s*\\))?`, 'g');
    for (let m; (m = re.exec(text)); ) {
      const line = lineOf(text, m.index);
      const owner = containerOf(classes, m.index);
      const pref = owner ? prefixes.get(owner.name) : { path: '', ok: true };
      const lit = m[1] === undefined ? '' : literal(m[1]);
      if (m[1] !== undefined && lit === null) {
        idx.unresolved.push({ kind: 'route-path-not-literal', file, line, detail: String(m[1]).slice(0, 60) });
        continue;
      }
      if (!pref || !pref.ok) {
        idx.unresolved.push({ kind: 'route-prefix-unresolved', file, line, detail: `@${cap}Mapping em classe cujo @RequestMapping não é literal — prefixo desconhecido` });
        continue;
      }
      idx.absolute.push({ method: verb.toUpperCase(), path: joinPath(pref.path, lit || ''), file, line });
    }
  }
}

/**
 * Ktor: `route("/x") { get("/y") { ... } }` — aninhamento léxico define o prefixo.
 * Rastreia profundidade de chaves para saber qual `route` ainda está aberto.
 *
 * Frame com prefixo irresolúvel CONTAMINA os descendentes: as rotas abaixo dele não são
 * emitidas, porque sairiam sem o prefixo — `/status` no lugar de `/{basePath}/status`.
 */
function indexKtor(text, file, idx) {
  // `route(` que o padrão principal não casa (argumento com parênteses, p.ex. `route(base())`)
  // não empilha frame nenhum, e as rotas de dentro sairiam sem prefixo. Contadas aqui para que
  // a diferença vire diagnóstico em vez de path parcial.
  const totalRoute = (text.match(/\broute\s*\(/g) || []).length;
  let casados = 0;

  const tokens = [];
  const re = /\broute\s*\(\s*([^)]*?)\s*\)\s*\{|\b(get|post|put|delete|patch|head|options)\s*\(\s*([^)]*?)\s*\)\s*\{|\b(get|post|put|delete|patch|head|options)\s*\{|\{|\}/g;
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
      casados += 1;
      const lit = literal(m[1]);
      depth += 1;
      if (lit === null) {
        idx.unresolved.push({ kind: 'group-path-not-literal', file, line: lineOf(text, m.index), detail: m[1].slice(0, 60) });
        stack.push({ path: '', depth, unresolved: true });
      } else {
        stack.push({ path: lit, depth, unresolved: false });
      }
      continue;
    }
    // `get { }` sem path: só conta dentro de um route() aberto — fora dele, `get {` é getter de
    // propriedade do Kotlin, não rota.
    if (m[4] !== undefined && stack.length === 0) { depth += 1; continue; }
    if (m[2] !== undefined || m[4] !== undefined) {
      const verbo = m[2] !== undefined ? m[2] : m[4];
      const lit = m[2] !== undefined ? (literal(m[3]) ?? '') : '';
      depth += 1;
      const line = lineOf(text, m.index);
      if (stack.some((s) => s.unresolved)) {
        idx.unresolved.push({ kind: 'route-prefix-unresolved', file, line, detail: `${verbo}('${lit}') sob route() com prefixo irresolúvel — path parcial não é emitido` });
        continue;
      }
      const prefix = stack.map((s) => s.path).join('/');
      tokens.push({ method: verbo.toUpperCase(), path: joinPath(prefix, lit), file, line });
    }
  }

  if (casados < totalRoute) {
    idx.unresolved.push({
      kind: 'ktor-route-unparsed',
      file,
      line: 0,
      detail: `${totalRoute - casados} chamada(s) route() com argumento não-literal composto; as rotas sob elas não são emitidas`,
    });
    return;
  }
  idx.absolute.push(...tokens);
}

/**
 * Express/Fastify (`app.get('/x', h)`, `router.post(...)`) e Nest (`@Controller('x')` + `@Get('y')`).
 *
 * Router montado em prefixo (`app.use('/api/v2', router)`, `fastify.register(r, { prefix })`) é
 * resolvido quando a montagem está no mesmo arquivo. Router SEM montagem conhecida não emite
 * rota: `router.post('/orders')` sozinho vale `/orders` ou `/api/v2/orders` conforme o mount, e
 * chutar o primeiro é inventar path.
 */
function indexJsHttp(text, file, idx) {
  const mounts = new Map();
  const useRe = /\b(?:app|server|router)\s*\.\s*use\s*\(\s*(['"`][^'"`]*['"`])\s*,\s*(\w+)/g;
  for (let m; (m = useRe.exec(text)); ) {
    const lit = literal(m[1]);
    if (lit !== null) mounts.set(m[2], lit);
  }
  const regRe = /\b(?:fastify|app|server)\s*\.\s*register\s*\(\s*(\w+)\s*,\s*\{[^}]*prefix\s*:\s*(['"`][^'"`]*['"`])/g;
  for (let m; (m = regRe.exec(text)); ) {
    const lit = literal(m[2]);
    if (lit !== null) mounts.set(m[1], lit);
  }

  const isRoot = (r) => /^(app|server|fastify)$/.test(r);
  const isRouter = (r) => /^(router|api|routes)$/i.test(r) || /(Router|Routes)$/.test(r);

  for (const verb of HTTP_VERBS) {
    const re = new RegExp(`\\b(\\w+)\\s*\\.\\s*${verb}\\s*\\(\\s*([^,)]*)`, 'g');
    for (let m; (m = re.exec(text)); ) {
      const recv = m[1];
      if (!isRoot(recv) && !isRouter(recv) && !mounts.has(recv)) continue;
      const line = lineOf(text, m.index);
      const lit = literal(m[2]);
      if (lit === null) {
        idx.unresolved.push({ kind: 'route-path-not-literal', file, line, detail: m[2].slice(0, 60) });
        continue;
      }
      if (!lit.startsWith('/')) continue;
      if (isRoot(recv)) {
        idx.absolute.push({ method: verb.toUpperCase(), path: normalizePath(lit), file, line });
        continue;
      }
      const mount = mounts.get(recv);
      if (mount === undefined) {
        idx.unresolved.push({
          kind: 'router-mount-unknown',
          file,
          line,
          detail: `${recv}.${verb}('${lit}') — nenhum app.use()/register() conhecido monta '${recv}'; o prefixo é desconhecido`,
        });
        continue;
      }
      idx.absolute.push({ method: verb.toUpperCase(), path: joinPath(mount, lit), file, line });
    }
  }

  const ctrl = text.match(/@Controller\s*\(\s*([^)]*?)\s*\)/);
  if (!ctrl) return;
  const nestPrefix = literal(ctrl[1]);
  if (nestPrefix === null) {
    idx.unresolved.push({ kind: 'class-route-not-literal', file, line: 1, detail: ctrl[1].slice(0, 60) });
    return;
  }
  for (const verb of HTTP_VERBS) {
    const cap = verb[0].toUpperCase() + verb.slice(1);
    const re = new RegExp(`@${cap}\\s*\\(\\s*([^)]*?)\\s*\\)`, 'g');
    for (let m; (m = re.exec(text)); ) {
      const lit = m[1] === '' ? '' : literal(m[1]);
      if (m[1] !== '' && lit === null) {
        idx.unresolved.push({ kind: 'route-path-not-literal', file, line: lineOf(text, m.index), detail: m[1].slice(0, 60) });
        continue;
      }
      idx.absolute.push({ method: verb.toUpperCase(), path: joinPath(nestPrefix, lit || ''), file, line: lineOf(text, m.index) });
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
    routes.push({ method: a.method, path: normalizePath(a.path), file: a.file, line: a.line, chain: a.chain || [] });
  }

  const routesByOwner = new Map();
  for (const r of idx.routes) push(routesByOwner, r.owner, r);
  const callsByOwner = new Map();
  for (const c of idx.calls) push(callsByOwner, c.owner, c);

  const groupById = new Map();
  for (const g of idx.groups) groupById.set(g.id, g);
  const groupsByParent = new Map();
  for (const g of idx.groups) push(groupsByParent, g.parent, g);

  const allProducers = [...idx.producers.values()].flat();
  const producerByOwner = new Map();
  for (const p of allProducers) producerByOwner.set(`${p.scope}:${p.param}`, p);

  const invokedNames = new Set();
  const ambiguousNames = new Set();
  for (const c of idx.calls) {
    const n = (idx.producers.get(c.producer) || []).length;
    if (n === 1) invokedNames.add(c.producer);
    else if (n > 1) ambiguousNames.add(c.producer);
  }

  // Um owner é RAIZ quando o prefixo dele é conhecido sem se saber quem o invocou: o `app` do
  // top-level, ou o parâmetro de um produtor que recebe a raiz da aplicação e não é invocado por
  // ninguém. O parâmetro de um produtor RELATIVO nunca é raiz — o path das rotas dele só existe
  // depois de composto com o prefixo do chamador.
  const producerByScope = new Map();
  for (const p of allProducers) producerByScope.set(p.scope, p);

  const isRootOwner = (ownerId) => {
    if (groupById.has(ownerId)) return false;
    const p = producerByOwner.get(ownerId);
    // Produtor ambíguo não é raiz: promovê-lo emitia as rotas dele CRUAS, sem o prefixo de quem o
    // invoca, bem ao lado do `producer-ambiguous` que diz não saber qual prefixo é. As duas
    // correções se anulavam.
    if (p) return p.rootLike && !invokedNames.has(p.name) && !ambiguousNames.has(p.name);
    // Owner desconhecido: só é raiz no escopo de topo do arquivo. Dentro do corpo de um produtor
    // RELATIVO, um receptor que não é o parâmetro nasceu de `group.RequireAuthorization()` ou
    // `group.WithTags()` — idioma corrente de ASP.NET — e o prefixo dele é o do chamador.
    const escopo = ownerId.slice(0, ownerId.lastIndexOf(':'));
    const dono = producerByScope.get(escopo);
    if (dono && !dono.rootLike) return false;
    return true;
  };

  const MAX_DEPTH = 12;
  const reachedGroups = new Set();
  const visitedOwners = new Set();
  const profundoReportado = new Set();

  function walk(ownerId, prefix, chain, depth, stack, originFile) {
    if (depth > MAX_DEPTH) {
      if (!profundoReportado.has(ownerId)) {
        profundoReportado.add(ownerId);
        unresolved.push({ kind: 'chain-too-deep', file: originFile, line: 0, detail: `cadeia excedeu ${MAX_DEPTH} saltos a partir de '${prefix}'` });
      }
      return;
    }
    // Sem este corte um ciclo de produtores custa b^MAX_DEPTH: cinco registradores que se
    // invocam mutuamente chegavam a alguns GB de RSS antes de terminar.
    if (stack.has(ownerId)) {
      unresolved.push({ kind: 'chain-cycle', file: originFile, line: 0, detail: `ciclo de produtores alcançando '${prefix}' — composição interrompida` });
      return;
    }
    const next = new Set(stack);
    next.add(ownerId);
    visitedOwners.add(ownerId);

    for (const r of routesByOwner.get(ownerId) || []) {
      routes.push({ method: r.method, path: joinPath(prefix, r.path), file: r.file, line: r.line, chain: [...chain] });
    }

    for (const g of groupsByParent.get(ownerId) || []) {
      reachedGroups.add(g.id);
      // Prefixo irresolúvel já foi reportado na indexação; descer aqui emitiria path parcial.
      if (g.path === null) continue;
      walk(g.id, joinPath(prefix, g.path), [...chain, `MapGroup(${g.path})`], depth + 1, next, g.file);
    }

    for (const c of callsByOwner.get(ownerId) || []) {
      const cands = idx.producers.get(c.producer) || [];
      if (cands.length === 0) {
        unresolved.push({
          kind: 'producer-not-found',
          file: c.file,
          line: c.line,
          detail: `${c.producer}() — nenhuma definição encontrada; o prefixo '${prefix}' fica sem sufixo conhecido`,
        });
        continue;
      }
      if (cands.length > 1) {
        unresolved.push({
          kind: 'producer-ambiguous',
          file: c.file,
          line: c.line,
          detail: `${c.producer}() tem ${cands.length} definições homônimas (${cands.map((p) => p.file).join(', ')}) e o scanner não sabe qual delas '${prefix}' invoca`,
        });
        continue;
      }
      const p = cands[0];
      walk(`${p.scope}:${p.param}`, prefix, [...chain, c.producer], depth + 1, next, p.file);
    }
  }

  const rootOwners = new Map();
  const noteRoot = (ownerId, file) => {
    if (!isRootOwner(ownerId)) return;
    if (!rootOwners.has(ownerId)) rootOwners.set(ownerId, file);
  };
  for (const g of idx.groups) noteRoot(g.parent, g.file);
  for (const c of idx.calls) noteRoot(c.owner, c.file);
  for (const r of idx.routes) noteRoot(r.owner, r.file);

  for (const [ownerId, file] of rootOwners) walk(ownerId, '', [], 0, new Set(), file);

  // Produtor RELATIVO que registra rotas e nunca é invocado: as rotas existem no código e não
  // estão penduradas em prefixo conhecido. Reportado, nunca descartado — é o caso em que o
  // cruzamento passaria por vacuidade.
  for (const p of allProducers) {
    if (invokedNames.has(p.name) || ambiguousNames.has(p.name)) continue;
    if (p.rootLike) continue;
    const ownerId = `${p.scope}:${p.param}`;
    const registra = (routesByOwner.get(ownerId) || []).length > 0
      || (groupsByParent.get(ownerId) || []).length > 0
      || (callsByOwner.get(ownerId) || []).length > 0;
    if (!registra) continue;
    unresolved.push({
      kind: 'producer-never-invoked',
      file: p.file,
      line: p.line,
      detail: `${p.name}() registra rotas e não é invocado por grupo nenhum — prefixo desconhecido`,
    });
  }

  for (const [owner, list] of routesByOwner) {
    if (visitedOwners.has(owner) || groupById.has(owner) || producerByOwner.has(owner)) continue;
    unresolved.push({
      kind: 'receiver-unknown',
      file: list[0].file,
      line: list[0].line,
      detail: `'${owner.slice(owner.lastIndexOf(':') + 1)}' registra ${list.length} rota(s) e não é grupo, parâmetro de produtor nem raiz — prefixo desconhecido`,
    });
  }

  // Grupo que ficou fora da travessia porque um ancestral tem prefixo irresolúvel.
  for (const g of idx.groups) {
    if (reachedGroups.has(g.id) || g.path === null) continue;
    if ((routesByOwner.get(g.id) || []).length === 0 && (groupsByParent.get(g.id) || []).length === 0) continue;
    // Produtor não alcançado já tem diagnóstico próprio; não duplica.
    if (producerByOwner.has(g.parent)) continue;
    unresolved.push({
      kind: 'group-unreachable',
      file: g.file,
      line: g.line,
      detail: `grupo '${g.path}' pende de '${g.parent.slice(g.parent.lastIndexOf(':') + 1)}', que o scanner não resolveu; as rotas dele não são emitidas`,
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
  const files = [...new Set(collect(paths, { exts, skipDirs }))];
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
