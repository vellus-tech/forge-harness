// kb-semantic — camada semântica da busca unificada (/forge:kb): embeddings densos e re-rank por
// cross-encoder, locais. Carregada só por import() dinâmico (kb-cli.mjs), quando
// `.forge/kb/semantic/installed.json` existe e `--lexical` não foi pedido. Nunca lança para o CLI na
// carga: devolve {ok:false, reason} e o CLI cai para o modo lexical com o motivo.
//
// O runtime (onnxruntime-web, WASM, sem binário nativo) e o tokenizador (@huggingface/tokenizers, JS
// puro) vêm EXCLUSIVAMENTE de `.forge/kb/semantic/runtime/node_modules/`, instalados por
// `kb.sh semantic install` a partir dos pins (lib/kb-pins/). A resolução normal de pacote subiria a
// árvore e poderia carregar um pacote do projeto-alvo ou do próprio harness, sem versão fixada e fora
// da varredura de binário nativo — por isso todo caminho resolvido é conferido contra esse diretório.
//
// Nenhuma rede: só `node:fs`, `node:path`, `node:crypto`, `node:module`, `node:url`.
import { readFileSync, writeFileSync, existsSync, readdirSync, statSync, openSync, readSync, closeSync, mkdirSync, renameSync } from 'node:fs';
import { join, resolve, sep, dirname } from 'node:path';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';

const sha256File = (p) => createHash('sha256').update(readFileSync(p)).digest('hex');
const sha256 = (s) => createHash('sha256').update(s).digest('hex');
const SAVE_EVERY = 200;

// ---------- varredura de binário nativo ----------
const NATIVE_EXT = /\.(node|dylib|so|dll)$/i;
const NATIVE_MAGIC = ['feedface', 'feedfacf', 'cefaedfe', 'cffaedfe', 'cafebabe', 'bebafeca', '7f454c46', '4d5a'];
export function findNative(dir) {
  const hits = [];
  const walk = (d) => {
    let es; try { es = readdirSync(d, { withFileTypes: true }); } catch { return; }
    for (const e of es) {
      const p = join(d, e.name);
      if (e.isDirectory()) { walk(p); continue; }
      if (!e.isFile()) continue;
      if (NATIVE_EXT.test(e.name) || /\.so\.\d/.test(e.name)) { hits.push(p); continue; }
      let fd; const b = Buffer.alloc(4);
      try { fd = openSync(p, 'r'); const n = readSync(fd, b, 0, 4, 0); if (n >= 2) { const hx = b.subarray(0, n).toString('hex'); if (NATIVE_MAGIC.some((m) => hx.startsWith(m))) hits.push(p); } } catch { /* ilegível: ignora */ } finally { if (fd !== undefined) closeSync(fd); }
    }
  };
  walk(dir);
  return hits.sort();
}

// ---------- integridade ----------
export function pinsHash(pinsDir) {
  return sha256(readFileSync(join(pinsDir, 'package-lock.json')) + '\u0000' + readFileSync(join(pinsDir, 'models.json')));
}

// verify(semDir, pinsDir, {fullHash}) → {ok, reason?, installed, models}
export function verify(semDir, pinsDir, { fullHash = true } = {}) {
  let installed;
  try { installed = JSON.parse(readFileSync(join(semDir, 'installed.json'), 'utf8')); } catch { return { ok: false, reason: 'installed.json ilegível' }; }
  let models;
  try { models = JSON.parse(readFileSync(join(pinsDir, 'models.json'), 'utf8')); } catch { return { ok: false, reason: 'pins ilegíveis (models.json)' }; }
  try { if (installed.pins_sha256 !== pinsHash(pinsDir)) return { ok: false, reason: 'pins mudaram desde a instalação — rode kb.sh semantic install' }; } catch { return { ok: false, reason: 'pins ilegíveis' }; }
  const native = findNative(semDir);
  if (native.length) return { ok: false, reason: `binário nativo encontrado: ${native[0].slice(semDir.length + 1)}` };
  // pacotes do runtime: presentes, dentro de runtime/node_modules, na versão do lockfile
  const runtimeDir = join(semDir, 'runtime');
  let lock;
  try { lock = JSON.parse(readFileSync(join(pinsDir, 'package-lock.json'), 'utf8')); } catch { return { ok: false, reason: 'pins ilegíveis (package-lock.json)' }; }
  for (const [key, meta] of Object.entries(lock.packages || {})) {
    if (!key) continue;
    const pj = join(runtimeDir, key, 'package.json');
    let v; try { v = JSON.parse(readFileSync(pj, 'utf8')).version; } catch { return { ok: false, reason: `pacote do runtime faltando: ${key.replace(/^node_modules\//, '')}` }; }
    if (v !== meta.version) return { ok: false, reason: `pacote do runtime em versão divergente: ${key.replace(/^node_modules\//, '')} ${v} (pin ${meta.version})` };
  }
  // modelos: presença, tamanho e sha256 (memorizado por path+size+mtime)
  const memoPath = join(semDir, 'verified.json');
  let memo = {}; try { memo = JSON.parse(readFileSync(memoPath, 'utf8')); } catch { memo = {}; }
  let memoChanged = false;
  for (const role of ['embedder', 'reranker']) {
    for (const f of models[role]?.files || []) {
      const p = join(semDir, 'models', f.path);
      let st; try { st = statSync(p); } catch { return { ok: false, reason: `arquivo de modelo faltando: ${f.path}` }; }
      if (st.size !== f.size) return { ok: false, reason: `arquivo de modelo com tamanho divergente: ${f.path}` };
      const key = `${f.path}|${st.size}|${st.mtimeMs}`;
      if (memo[f.path] === `${key}|${f.sha256}` && !fullHash) continue;
      if (memo[f.path] === `${key}|${f.sha256}`) continue;
      if (sha256File(p) !== f.sha256) return { ok: false, reason: `sha256 divergente: ${f.path}` };
      memo[f.path] = `${key}|${f.sha256}`; memoChanged = true;
    }
  }
  if (memoChanged) { try { writeFileSync(memoPath, JSON.stringify(memo, null, 2) + '\n'); } catch { /* memo é otimização */ } }
  return { ok: true, installed, models };
}

// Resolve um pacote SÓ dentro de runtime/node_modules.
function resolveInside(runtimeDir, spec) {
  const req = createRequire(join(runtimeDir, 'package.json'));
  const p = req.resolve(spec);
  const root = resolve(runtimeDir, 'node_modules') + sep;
  if (!resolve(p).startsWith(root)) throw new Error(`pacote do runtime faltando: ${spec} (resolvido fora de runtime/node_modules)`);
  return p;
}

// ---------- carga ----------
export async function loadSemantic(semDir, pinsDir) {
  const v = verify(semDir, pinsDir);
  if (!v.ok) return { ok: false, reason: v.reason };
  const runtimeDir = join(semDir, 'runtime');
  let ort, Tokenizer;
  try {
    ort = await import(pathToFileURL(resolveInside(runtimeDir, 'onnxruntime-web')).href);
    ort = ort.InferenceSession ? ort : ort.default;
    const tk = await import(pathToFileURL(resolveInside(runtimeDir, '@huggingface/tokenizers')).href);
    Tokenizer = tk.Tokenizer ?? tk.default?.Tokenizer;
    if (!ort?.InferenceSession || !Tokenizer) throw new Error('API do runtime inesperada');
  } catch (e) { return { ok: false, reason: String(e.message || e).split('\n')[0] }; }
  try {
    const mdir = join(semDir, 'models');
    const mk = async (role) => {
      const cfg = v.models[role];
      const file = (r) => join(mdir, cfg.files.find((f) => f.role === r).path);
      const tok = new Tokenizer(JSON.parse(readFileSync(file('tokenizer'), 'utf8')), JSON.parse(readFileSync(file('tokenizer_config'), 'utf8')));
      const session = await ort.InferenceSession.create(new Uint8Array(readFileSync(file('model'))), { executionProviders: ['wasm'] });
      return { cfg, tok, session };
    };
    const emb = await mk('embedder');
    const rr = await mk('reranker');
    return { ok: true, semantic: makeSemantic(ort, emb, rr, semDir, v.models) };
  } catch (e) { return { ok: false, reason: String(e.message || e).split('\n')[0] }; }
}

const clip = (ids, max) => (ids.length > max ? [...ids.slice(0, max - 1), ids[ids.length - 1]] : ids);

function feeds(ort, session, ids) {
  const L = ids.length;
  const f = { input_ids: new ort.Tensor('int64', BigInt64Array.from(ids.map((x) => BigInt(x))), [1, L]) };
  if (session.inputNames.includes('attention_mask')) f.attention_mask = new ort.Tensor('int64', new BigInt64Array(L).fill(1n), [1, L]);
  if (session.inputNames.includes('token_type_ids')) f.token_type_ids = new ort.Tensor('int64', new BigInt64Array(L), [1, L]);
  return f;
}

function makeSemantic(ort, emb, rr, semDir, models) {
  const modelId = `${models.embedder.id}@${models.embedder.files.find((f) => f.role === 'model').sha256.slice(0, 16)}`;
  async function embed(text, prefix) {
    const ids = clip(emb.tok.encode(prefix + text).ids, emb.cfg.max_tokens);
    const out = await emb.session.run(feeds(ort, emb.session, ids));
    const h = out[emb.cfg.output] || out[emb.session.outputNames[0]];
    const [, L, D] = h.dims;
    const v = new Float32Array(D);
    for (let t = 0; t < L; t++) for (let k = 0; k < D; k++) v[k] += h.data[t * D + k];
    let n = 0; for (let k = 0; k < D; k++) n += v[k] * v[k];
    n = Math.sqrt(n) || 1; for (let k = 0; k < D; k++) v[k] /= n;
    return v;
  }
  const vecFile = join(semDir, 'vectors.bin'); const vecMeta = join(semDir, 'vectors.json');
  function loadVectors() {
    try {
      const meta = JSON.parse(readFileSync(vecMeta, 'utf8'));
      if (meta.model_id !== modelId) return { dim: 0, keys: {}, data: new Float32Array(0) };
      const b = readFileSync(vecFile);
      return { dim: meta.dim, keys: meta.keys, data: new Float32Array(b.buffer, b.byteOffset, b.byteLength / 4) };
    } catch { return { dim: 0, keys: {}, data: new Float32Array(0) }; }
  }
  function saveVectors(dim, entries) {
    // entries: [[key, Float32Array]] na ordem estável das chaves
    const keys = {}; const data = new Float32Array(entries.length * dim);
    entries.forEach(([k, v], i) => { keys[k] = i; data.set(v, i * dim); });
    mkdirSync(semDir, { recursive: true });
    writeFileSync(`${vecFile}.tmp`, Buffer.from(data.buffer)); renameSync(`${vecFile}.tmp`, vecFile);
    writeFileSync(`${vecMeta}.tmp`, JSON.stringify({ format: 1, model_id: modelId, dim, keys })); renameSync(`${vecMeta}.tmp`, vecMeta);
  }
  const chunkKey = (c) => sha256(`${c.doc}\n${c.text}`);
  let cache = null;
  return {
    modelId,
    async buildVectors(idx, progress) {
      const t = Date.now();
      const old = loadVectors();
      const have = new Map(Object.entries(old.keys).map(([k, i]) => [k, old.data.subarray(i * old.dim, (i + 1) * old.dim)]));
      const want = idx.chunks.map(chunkKey);
      const wantSet = new Set(want);
      const keep = new Map([...have].filter(([k]) => wantSet.has(k)));
      const removed = have.size - keep.size;
      let computed = 0; let dim = old.dim;
      const missing = [...new Set(want)].filter((k) => !keep.has(k));
      const byKey = new Map(idx.chunks.map((c) => [chunkKey(c), c]));
      for (const k of missing) {
        const c = byKey.get(k);
        const v = await embed(`${c.doc}\n${c.text}`, emb.cfg.passage_prefix);
        dim = v.length; keep.set(k, v); computed++;
        if (computed % SAVE_EVERY === 0) { saveVectors(dim, [...keep].sort((a, b) => (a[0] < b[0] ? -1 : 1))); if (progress) progress(computed, missing.length); }
      }
      if (dim) saveVectors(dim, [...keep].sort((a, b) => (a[0] < b[0] ? -1 : 1)));
      cache = null;
      return { computed, reused: keep.size - computed, removed, ms: Date.now() - t };
    },
    async vectorSearch(idx, q) {
      if (!cache) cache = loadVectors();
      const qv = await embed(q, emb.cfg.query_prefix);
      const scores = []; let missing = 0;
      idx.chunks.forEach((c, i) => {
        const slot = cache.keys[chunkKey(c)];
        if (slot === undefined || cache.dim !== qv.length) { missing++; return; }
        let s = 0; const o = slot * cache.dim; for (let k = 0; k < cache.dim; k++) s += cache.data[o + k] * qv[k];
        scores.push([i, s]);
      });
      scores.sort((a, b) => b[1] - a[1] || a[0] - b[0]);
      const ranks = new Map();
      for (const [i, s] of scores) { const d = idx.chunks[i].doc; if (!ranks.has(d)) ranks.set(d, { rank: ranks.size + 1, chunk: i, score: s }); }
      return { ranks, missing, queryVector: qv };
    },
    // Trecho representante de um documento para o cross-encoder: o de maior similaridade vetorial
    // com a consulta (cai para o melhor trecho lexical se não houver vetor).
    representative(idx, doc, q, qv, fallback) {
      if (!cache || !qv) return fallback ?? idx.chunks.findIndex((c) => c.doc === doc);
      let best = fallback ?? -1; let bs = -Infinity;
      idx.chunks.forEach((c, i) => {
        if (c.doc !== doc) return;
        const slot = cache.keys[chunkKey(c)]; if (slot === undefined) return;
        let s = 0; const o = slot * cache.dim; for (let k = 0; k < cache.dim; k++) s += cache.data[o + k] * qv[k];
        if (s > bs) { bs = s; best = i; }
      });
      return best >= 0 ? best : idx.chunks.findIndex((c) => c.doc === doc);
    },
    async crossScore(q, passage) {
      const a = rr.tok.encode(q).ids; const b = rr.tok.encode(passage).ids;
      const qa = clip(a, rr.cfg.max_query_tokens); const pb = clip(b, rr.cfg.max_passage_tokens);
      // formato de par XLM-R: <s> A </s></s> B </s> — os dois encode() já trazem <s>…</s>
      const ids = [...qa, qa[qa.length - 1], ...pb.slice(1)];
      const out = await rr.session.run(feeds(ort, rr.session, ids));
      const o = out[rr.cfg.output] || out[rr.session.outputNames[0]];
      return Number(o.data[0]);
    },
  };
}

// status para `kb.sh semantic status`
export async function status(semDir, pinsDir) {
  const v = verify(semDir, pinsDir, { fullHash: true });
  const lines = [`camada semântica: instalada${v.ok ? ' — integridade confere' : ` — PROBLEMA: ${v.reason}`}`];
  if (v.ok) {
    lines.push(`runtime: ${Object.entries(v.installed.packages || {}).map(([k, x]) => `${k}@${x}`).join(', ')}`);
    for (const role of ['embedder', 'reranker']) lines.push(`${role}: ${v.models[role].id} (${v.models[role].repo}@${String(v.models[role].revision).slice(0, 12)})`);
  }
  return { ok: v.ok, lines };
}
