#!/usr/bin/env node
// forge shared engine — api-surface. Zero-dependency.
//
// Reúne o que os ARTEFATOS declaram como superfície HTTP, para cruzar contra o que o código de
// fato expõe (route-scan.mjs). Quatro fontes possíveis, e a regra de composição é o ponto
// central deste módulo:
//
// ── União, nunca precedência-com-fallback ──────────────────────────────────────────────────
// A tentação é ordenar as fontes e usar a primeira que responder: "se tem OpenAPI, usa OpenAPI;
// senão, cai na tabela; senão, no checklist". Isso reproduz exatamente a forma do defeito que
// este trabalho existe para eliminar — a fonte menos completa silencia a mais completa, e o
// endpoint que só a tabela conhece desaparece do cruzamento porque um OpenAPI incompleto
// respondeu primeiro. Aqui todas as fontes são lidas e o resultado é a UNIÃO dos endpoints,
// com `sources[]` registrando quem declarou cada um.
//
// Precedência existe, e só para METADADO DIVERGENTE do mesmo endpoint (qual policy, qual
// resumo): `authz-map > openapi > tabela > checklist`. Precedência de metadado não some com
// endpoint nenhum — é desempate, não filtro.
import { readFileSync, existsSync, statSync } from 'node:fs';
import { relative } from 'node:path';
import { collect, DEFAULT_SKIP } from './source-scan.mjs';
import { normalizePath } from './route-scan.mjs';
import { parseYamlSubset } from './yaml-lite.mjs';

const HTTP_VERBS = ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS'];

/** Ordem de desempate de metadado. Índice menor ganha. Não filtra endpoint. */
export const SOURCE_PRECEDENCE = ['authz-map', 'openapi', 'table', 'checklist'];

function key(method, path) {
  return `${method.toUpperCase()} ${normalizePath(path)}`;
}

function upsert(map, { method, path, source, file, line, policy, summary }) {
  const k = key(method, path);
  const existing = map.get(k);
  if (!existing) {
    map.set(k, {
      method: method.toUpperCase(),
      path: normalizePath(path),
      sources: [source],
      declarations: [{ source, file, line, policy, summary }],
      policy: policy || null,
      summary: summary || null,
    });
    return;
  }
  if (!existing.sources.includes(source)) existing.sources.push(source);
  existing.declarations.push({ source, file, line, policy, summary });

  // Desempate de metadado: só substitui quando a fonte nova tem precedência maior E traz valor.
  const rank = (s) => {
    const i = SOURCE_PRECEDENCE.indexOf(s);
    return i === -1 ? SOURCE_PRECEDENCE.length : i;
  };
  const currentRank = Math.min(...existing.declarations.filter((d) => d.policy).map((d) => rank(d.source)), SOURCE_PRECEDENCE.length);
  if (policy && rank(source) <= currentRank) existing.policy = policy;
  if (summary && !existing.summary) existing.summary = summary;
}

// ── Fonte 1: authz-map (endpoint → policy) ─────────────────────────────────────────────────
// Formato aceito: YAML com lista de entradas contendo `method`/`path` (ou `endpoint: "GET /x"`).
export function fromAuthzMap(text, file = 'authz-map') {
  const out = [];
  let doc;
  try {
    doc = parseYamlSubset(text);
  } catch {
    return out;
  }
  const entries = [];
  const visit = (node) => {
    if (Array.isArray(node)) { node.forEach(visit); return; }
    if (!node || typeof node !== 'object') return;
    if (node.path || node.endpoint) entries.push(node);
    for (const v of Object.values(node)) visit(v);
  };
  visit(doc);

  for (const e of entries) {
    let method = e.method;
    let path = e.path;
    if (!path && typeof e.endpoint === 'string') {
      const m = e.endpoint.trim().match(/^([A-Za-z]+)\s+(\/\S*)$/);
      if (m) { method = m[1]; path = m[2]; }
    }
    if (!path) continue;
    const policy = e.policy || e.rule || e.permission || null;
    for (const mth of method ? [method] : HTTP_VERBS.slice(0, 1)) {
      out.push({ method: mth, path, source: 'authz-map', file, policy });
    }
  }
  return out;
}

// ── Fonte 2: OpenAPI ───────────────────────────────────────────────────────────────────────
// Lê o bloco `paths:` sem exigir parser completo — só o que interessa ao cruzamento.
export function fromOpenApi(text, file = 'openapi') {
  const out = [];
  const lines = text.split('\n');
  let inPaths = false;
  let pathsIndent = -1;
  let currentPath = null;
  let currentIndent = -1;

  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];
    if (!line.trim() || line.trim().startsWith('#')) continue;
    const indent = line.length - line.trimStart().length;

    if (/^paths\s*:\s*$/.test(line.trim())) { inPaths = true; pathsIndent = indent; continue; }
    if (!inPaths) continue;
    if (indent <= pathsIndent && line.trim() && !/^paths\s*:/.test(line.trim())) { inPaths = false; continue; }

    const pathMatch = line.trim().match(/^["']?(\/[^"':]*)["']?\s*:\s*$/);
    if (pathMatch && (currentIndent === -1 || indent <= currentIndent)) {
      currentPath = pathMatch[1];
      currentIndent = indent;
      continue;
    }
    if (!currentPath) continue;

    const verbMatch = line.trim().match(/^(get|post|put|delete|patch|head|options)\s*:\s*$/i);
    if (verbMatch && indent > currentIndent) {
      let summary = null;
      for (let j = i + 1; j < Math.min(i + 6, lines.length); j += 1) {
        const sm = lines[j].trim().match(/^summary\s*:\s*(.+)$/);
        if (sm) { summary = sm[1].replace(/^["']|["']$/g, ''); break; }
      }
      out.push({ method: verbMatch[1].toUpperCase(), path: currentPath, source: 'openapi', file, line: i + 1, summary });
    }
  }
  return out;
}

// ── Fonte 3: tabela endpoint → ação → recurso → policy (markdown do REQ-13) ────────────────
export function fromPolicyTable(text, file = 'requirements.md') {
  const out = [];
  const lines = text.split('\n');
  for (let i = 0; i < lines.length; i += 1) {
    const row = lines[i];
    if (!row.trim().startsWith('|')) continue;
    const cells = row.split('|').map((c) => c.trim()).filter((c, idx, arr) => !(idx === 0 && !c) && !(idx === arr.length - 1 && !c));
    if (cells.length < 2) continue;
    if (/^-{2,}$/.test(cells[0].replace(/[:\s]/g, '-'))) continue;

    // Primeira célula no formato `GET /path` ou `` `GET /path` ``.
    const m = cells[0].replace(/`/g, '').trim().match(/^([A-Za-z]+)\s+(\/\S*)$/);
    if (!m || !HTTP_VERBS.includes(m[1].toUpperCase())) continue;
    const policy = cells.find((c, idx) => idx > 0 && /policy|permiss|scope/i.test(c)) || cells[cells.length - 1] || null;
    out.push({ method: m[1], path: m[2], source: 'table', file, line: i + 1, policy: policy && policy !== '—' ? policy : null });
  }
  return out;
}

// ── Fonte 4: Checklist de cobertura de superfície ──────────────────────────────────────────
export function fromChecklist(text, file = 'requirements.md') {
  const out = [];
  const lines = text.split('\n');
  const start = lines.findIndex((l) => /^#{1,6}\s*Checklist de cobertura de superf[íi]cie\b/i.test(l));
  if (start === -1) return out;

  for (let i = start + 1; i < lines.length; i += 1) {
    if (/^#{1,6}\s/.test(lines[i])) break;
    const row = lines[i];
    if (!row.trim().startsWith('|')) continue;
    const cells = row.split('|').map((c) => c.trim());
    // Coluna "Superfície" é a terceira do template; procura verbo+path em qualquer célula, porque
    // o preenchimento real varia ("POST /x", "endpoint POST /x", "`POST /x` no orquestrador").
    for (const cell of cells) {
      const m = cell.replace(/`/g, '').match(/\b(GET|POST|PUT|DELETE|PATCH|HEAD|OPTIONS)\s+(\/\S*)/i);
      if (!m) continue;
      out.push({ method: m[1], path: m[2].replace(/[.,;)]+$/, ''), source: 'checklist', file, line: i + 1 });
      break;
    }
  }
  return out;
}

// ── Coleta ─────────────────────────────────────────────────────────────────────────────────

function readIf(file) {
  try {
    if (!existsSync(file) || statSync(file).isDirectory()) return null;
    return readFileSync(file, 'utf8');
  } catch {
    return null;
  }
}

/**
 * Une as quatro fontes num único conjunto de endpoints declarados.
 *
 * @param {object} opts
 * @param {string[]} opts.contractPaths  diretórios/arquivos de contrato (OpenAPI)
 * @param {string[]} opts.specPaths      arquivos de spec (tabela de policy, checklist)
 * @param {string[]} opts.authzPaths     arquivos de authz-map
 * @param {string}   opts.root           raiz para relativizar os paths reportados
 * @returns {{endpoints: Array, bySource: object}}
 */
export function collectDeclaredSurface({ contractPaths = [], specPaths = [], authzPaths = [], root = process.cwd() } = {}) {
  const map = new Map();
  const bySource = { 'authz-map': 0, openapi: 0, table: 0, checklist: 0 };
  const rel = (f) => relative(root, f) || f;

  for (const f of collect(authzPaths, { exts: new Set(['.yaml', '.yml']), skipDirs: DEFAULT_SKIP })) {
    const text = readIf(f);
    if (text === null) continue;
    for (const e of fromAuthzMap(text, rel(f))) { upsert(map, e); bySource['authz-map'] += 1; }
  }

  for (const f of collect(contractPaths, { exts: new Set(['.yaml', '.yml', '.json']), skipDirs: DEFAULT_SKIP })) {
    const text = readIf(f);
    if (text === null) continue;
    for (const e of fromOpenApi(text, rel(f))) { upsert(map, e); bySource.openapi += 1; }
  }

  for (const f of collect(specPaths, { exts: new Set(['.md']), skipDirs: DEFAULT_SKIP })) {
    const text = readIf(f);
    if (text === null) continue;
    for (const e of fromPolicyTable(text, rel(f))) { upsert(map, e); bySource.table += 1; }
    for (const e of fromChecklist(text, rel(f))) { upsert(map, e); bySource.checklist += 1; }
  }

  const endpoints = [...map.values()].sort((a, b) => (a.path === b.path ? a.method.localeCompare(b.method) : a.path.localeCompare(b.path)));
  return { endpoints, bySource };
}

/**
 * SUR-01 — contrato→código: endpoint declarado que não existe como rota. BLOQUEIA.
 * É o defeito de "a promessa vive no contrato e ninguém a implementou".
 */
export function surContractToCode(declared, routeKeySet) {
  return declared.filter((e) => !routeKeySet.has(`${e.method} ${e.path}`));
}

/**
 * SUR-02 — código→contrato: rota que existe e nenhum artefato declara. `warn` por default.
 *
 * Agregado por prefixo de grupo porque legado inteiro sem contrato produz dezenas de achados
 * idênticos, e um gate que nasce com dezenas de achados é desligado no primeiro dia. A
 * allowlist cobre infra documentada (health, métricas, swagger), que não é superfície de
 * negócio e nunca esteve em contrato.
 */
export function surCodeToContract(routes, declaredKeySet, { allowlist = [] } = {}) {
  const allow = allowlist.map((p) => (p instanceof RegExp ? p : new RegExp(p)));
  const missing = routes.filter((r) => {
    if (declaredKeySet.has(`${r.method} ${r.path}`)) return false;
    return !allow.some((re) => re.test(r.path));
  });

  // O prefixo de agregação é o do GRUPO que registrou a rota, quando o scanner o conhece — ele
  // está no primeiro elo da cadeia (`MapGroup(/internal/v1/x)`). Contar segmentos fixos seria
  // arbitrário: `/legacy/v1/a` e `/internal/v1/orchestrator/vault/reveal` têm profundidades
  // diferentes e o mesmo conceito de "um grupo". Sem cadeia (dialeto de prefixo léxico), cai
  // nos dois primeiros segmentos, que é onde a versão/área costuma estar.
  const groupOf = (r) => {
    const fromChain = (r.chain || []).find((c) => /^MapGroup\(/.test(c));
    if (fromChain) return normalizePath(fromChain.slice('MapGroup('.length, -1));
    const segs = r.path.split('/').filter(Boolean);
    return segs.length ? `/${segs.slice(0, 2).join('/')}` : r.path;
  };

  const groups = new Map();
  for (const r of missing) {
    const prefix = groupOf(r);
    if (!groups.has(prefix)) groups.set(prefix, []);
    groups.get(prefix).push(r);
  }
  return [...groups.entries()]
    .map(([prefix, list]) => ({ prefix, count: list.length, routes: list }))
    .sort((a, b) => b.count - a.count || a.prefix.localeCompare(b.prefix));
}

/** Allowlist default: infra que nunca esteve em contrato de negócio. */
export const INFRA_ALLOWLIST = [
  /^\/health(\/|$)/,
  /^\/healthz(\/|$)/,
  /^\/metrics(\/|$)/,
  /^\/swagger(\/|$)/,
  /^\/openapi(\/|$)/,
  /^\/\.well-known(\/|$)/,
  /^\/favicon\.ico$/,
];
