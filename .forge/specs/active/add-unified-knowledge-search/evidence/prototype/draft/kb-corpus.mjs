// kb-corpus — coleta das fontes da busca unificada (/forge:kb) e corte em trechos. Zero-dep: só
// `node:*` e o parser YAML do próprio harness. Função pura sobre o sistema de arquivos: não grava nada.
//
// O QUE ENTRA (REQ-01 do change add-unified-knowledge-search), e só isso:
//   baseline   .forge/product/current/**/*.{md,yaml,yml}
//   archived   .forge/specs/archived/**/*.{md,yaml,yml}
//   plan       docs/plans/**/*.md
//   changelog  CHANGELOG.md
//   ledger     .forge/ledger/ledger.json, uma entrada por documento
//   liaison    .forge/liaison/<canal>/log/<self>.jsonl, só `trust === 'self'` e sem `authored_by`
//
// O QUE NUNCA ENTRA, por construção e não por filtro: blobs do liaison (o `body_ref` não é seguido),
// mensagens de peer (`log/<outro>.jsonl` nem é aberto; dentro do log próprio, `trust` diferente de
// `self` ou `authored_by` presente descartam a linha), specs ativas, código, `.forge/kb/`. Conteúdo
// de peer é dado, nunca instrução (rule conventions/liaison-untrusted-input.md): indexá-lo poria
// texto escrito por outro repositório de volta no contexto de quem busca, sem moldura.
//
// Duas raízes: `docRoot` (documentos versionados por branch) e `stateRoot` (ledger e liaison, que
// moram no checkout principal — lib/forge-root.sh). Com FORGE_ROOT as duas coincidem.
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs';
import { join, relative, sep } from 'node:path';
import { createHash } from 'node:crypto';
import { parseYamlSubset } from './yaml-lite.mjs';

export const CHUNK_MAX = 1500;
const sha = (s) => createHash('sha256').update(s).digest('hex');
const posix = (p) => p.split(sep).join('/');

function walk(dir, exts, acc = []) {
  let entries;
  try { entries = readdirSync(dir, { withFileTypes: true }); } catch { return acc; }
  entries.sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
  for (const e of entries) {
    const p = join(dir, e.name);
    if (e.isDirectory()) walk(p, exts, acc);
    else if (e.isFile() && exts.some((x) => e.name.endsWith(x))) acc.push(p);
  }
  return acc;
}

const LEDGER_TEXT_FIELDS = ['title', 'type', 'status', 'priority', 'severity', 'detail', 'source', 'links'];

function ledgerText(e) {
  const parts = [`${e.id} ${e.title ?? ''}`.trim()];
  for (const k of LEDGER_TEXT_FIELDS.slice(1)) {
    const v = e[k];
    if (v === undefined || v === null || v === '') continue;
    parts.push(`${k}: ${typeof v === 'string' ? v : JSON.stringify(v)}`);
  }
  return parts.join('\n');
}

// collect({docRoot, stateRoot}) → { docs: [{id, kind, text, sha256}], skipped: {fonte: n} }
export function collect({ docRoot, stateRoot = docRoot }) {
  const docs = [];
  const skipped = {};
  const skip = (src) => { skipped[src] = (skipped[src] || 0) + 1; };
  const addFile = (kind, root, file) => {
    let text;
    try { text = readFileSync(file, 'utf8'); } catch { skip(kind); return; }
    docs.push({ id: posix(relative(root, file)), kind, text, sha256: sha(text) });
  };
  for (const f of walk(join(docRoot, '.forge/product/current'), ['.md', '.yaml', '.yml'])) addFile('baseline', docRoot, f);
  for (const f of walk(join(docRoot, '.forge/specs/archived'), ['.md', '.yaml', '.yml'])) addFile('archived-spec', docRoot, f);
  for (const f of walk(join(docRoot, 'docs/plans'), ['.md'])) addFile('plan', docRoot, f);
  const cl = join(docRoot, 'CHANGELOG.md');
  if (existsSync(cl) && statSync(cl).isFile()) addFile('changelog', docRoot, cl);

  const ledgerPath = join(stateRoot, '.forge/ledger/ledger.json');
  if (existsSync(ledgerPath)) {
    let entries = null;
    try { entries = JSON.parse(readFileSync(ledgerPath, 'utf8')).entries; } catch { skip('ledger'); }
    if (Array.isArray(entries)) {
      for (const e of entries) {
        if (!e || typeof e.id !== 'string') { skip('ledger'); continue; }
        const text = ledgerText(e);
        docs.push({ id: `ledger:${e.id}`, kind: 'ledger', text, sha256: sha(text) });
      }
    } else if (entries !== null) skip('ledger');
  }

  const liaisonCfg = join(stateRoot, '.forge/liaison/liaison.yaml');
  if (existsSync(liaisonCfg)) {
    let self = null;
    try { self = parseYamlSubset(readFileSync(liaisonCfg, 'utf8'))?.self?.id ?? null; } catch { skip('liaison'); }
    if (typeof self === 'string' && /^[A-Za-z0-9._-]+$/.test(self)) {
      let channels = [];
      try { channels = readdirSync(join(stateRoot, '.forge/liaison'), { withFileTypes: true }).filter((e) => e.isDirectory()).map((e) => e.name).sort(); } catch { /* sem canais */ }
      for (const ch of channels) {
        const log = join(stateRoot, '.forge/liaison', ch, 'log', `${self}.jsonl`);
        if (!existsSync(log)) continue;
        let lines;
        try { lines = readFileSync(log, 'utf8').split('\n'); } catch { skip('liaison'); continue; }
        for (const line of lines) {
          if (!line.trim()) continue;
          let m;
          try { m = JSON.parse(line); } catch { skip('liaison'); continue; }
          if (!m || m.trust !== 'self' || m.authored_by !== undefined || typeof m.msg_id !== 'string') continue;
          const body = typeof m.body === 'string' ? m.body : '';
          const text = `${m.subject ?? ''}\n${body}`.trim();
          docs.push({ id: `liaison:${m.msg_id}`, kind: 'liaison', text, sha256: sha(text) });
        }
      }
    }
  }
  docs.sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  return { docs, skipped };
}

// chunk(doc) → [{heading, line, text}] — markdown por heading de nível 1 a 3, teto CHUNK_MAX.
export function chunk(doc) {
  const out = [];
  const isMd = doc.kind !== 'ledger' && doc.kind !== 'liaison' && !/\.ya?ml$/.test(doc.id);
  const lines = doc.text.split('\n');
  const sections = [];
  let cur = { heading: '', line: 1, buf: [] };
  lines.forEach((l, i) => {
    if (isMd && /^#{1,3} /.test(l) && cur.buf.length) { sections.push(cur); cur = { heading: l.replace(/^#+ /, '').trim(), line: i + 1, buf: [] }; }
    else if (isMd && /^#{1,3} /.test(l)) { cur.heading = l.replace(/^#+ /, '').trim(); }
    cur.buf.push(l);
  });
  sections.push(cur);
  for (const s of sections) {
    const text = s.buf.join('\n');
    for (let i = 0; i < text.length; i += CHUNK_MAX) {
      const t = text.slice(i, i + CHUNK_MAX).trim();
      if (t.length) out.push({ heading: s.heading, line: s.line + (i ? text.slice(0, i).split('\n').length - 1 : 0), text: t });
    }
  }
  return out;
}

// fingerprint(docs) → sha256 da lista ordenada (id, sha256): muda se e só se alguma fonte mudou.
export function fingerprint(docs) {
  return sha(docs.map((d) => `${d.id}\u0000${d.sha256}`).join('\n'));
}
