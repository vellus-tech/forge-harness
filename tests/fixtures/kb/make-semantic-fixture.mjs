// Gera a camada semântica de FIXTURE para os gates do /forge:kb: modelos ONNX minúsculos (protobuf
// escrito à mão, inferência real pelo onnxruntime-web), tokenizadores Unigram de vocabulário pequeno
// e o models.json de pins apontando para um servidor HTTP local, com os sha256 reais dos arquivos.
// Nada aqui é dublê do runtime: o que muda em relação à produção são só os pesos e o vocabulário.
//
// Uso: node make-semantic-fixture.mjs <dir-saida> <base-url> [--broken-embedder]
import { writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { createHash } from 'node:crypto';

const [out, base, flag] = process.argv.slice(2);
mkdirSync(join(out, 'embedder'), { recursive: true }); mkdirSync(join(out, 'reranker'), { recursive: true });

// ---- protobuf ONNX mínimo ----
const varint = (n) => { n = BigInt(n); const o = []; do { let b = Number(n & 0x7fn); n >>= 7n; if (n) b |= 0x80; o.push(b); } while (n); return Buffer.from(o); };
const key = (f, w) => varint((f << 3) | w);
const vint = (f, n) => Buffer.concat([key(f, 0), varint(n)]);
const bytes = (f, b) => { b = Buffer.isBuffer(b) ? b : Buffer.from(b, 'utf8'); return Buffer.concat([key(f, 2), varint(b.length), b]); };
const msg = (f, ...p) => bytes(f, Buffer.concat(p));
const dim = (d) => (typeof d === 'number' ? msg(1, vint(1, d)) : msg(1, bytes(2, d)));
const valueInfo = (f, name, elem, dims) => msg(f, bytes(1, name), msg(2, msg(1, vint(1, elem), msg(2, ...dims.map(dim)))));
const tensor = (name, dims, floats) => msg(5, ...dims.map((d) => vint(1, d)), vint(2, 1), bytes(8, name), bytes(9, Buffer.from(new Float32Array(floats).buffer)));
const node = (ins, outs, op, attrs = []) => msg(1, ...ins.map((i) => bytes(1, i)), ...outs.map((o) => bytes(2, o)), bytes(4, op), ...attrs);
const attrInts = (name, ints) => msg(5, bytes(1, name), ...ints.map((i) => vint(8, i)), vint(20, 7));
const attrInt = (name, i) => msg(5, bytes(1, name), vint(3, i), vint(20, 2));
const model = (g) => Buffer.concat([vint(1, 8), msg(8, bytes(1, ''), vint(2, 13)), bytes(2, 'forge-kb-fixture'), msg(7, ...g)]);
const INT64 = 7, FLOAT = 1;

// ---- vocabulário: dois tópicos ----
const TOPIC = { grafo: 0, codigo: 0, python: 0, dependencia: 0, nativo: 0, segredo: 1, chave: 1, credencial: 1, vazamento: 1, token: 1 };
const words = Object.keys(TOPIC);
const chars = [...'abcdefghijklmnopqrstuvwxyz0123456789'];
const pieces = [['<s>', 0], ['</s>', 0], ['<unk>', 0], ...words.map((w) => ['▁' + w, -1]), ['▁', -2], ...chars.map((c) => [c, -5])];
const V = pieces.length, D = 4;
const W = [];
pieces.forEach(([p]) => {
  const w = p.replace('▁', '');
  if (w in TOPIC) W.push(...(TOPIC[w] === 0 ? [1, 0, 0, 0] : [0, 1, 0, 0]));
  else if (p.length === 1 || p === '▁') W.push(0, 0, 0.05, 0.05);
  else W.push(0, 0, 0, 0);
});
const sp = (c, id) => ({ id, content: c, single_word: false, lstrip: false, rstrip: false, normalized: false, special: true });
const tok = { version: '1.0', truncation: null, padding: null, added_tokens: [sp('<s>', 0), sp('</s>', 1), sp('<unk>', 2)],
  normalizer: { type: 'Sequence', normalizers: [{ type: 'NFKD' }, { type: 'StripAccents' }, { type: 'Lowercase' }] },
  pre_tokenizer: { type: 'Metaspace', replacement: '▁', prepend_scheme: 'always', split: true },
  post_processor: { type: 'TemplateProcessing', single: [{ SpecialToken: { id: '<s>', type_id: 0 } }, { Sequence: { id: 'A', type_id: 0 } }, { SpecialToken: { id: '</s>', type_id: 0 } }], pair: [], special_tokens: { '<s>': { id: '<s>', ids: [0], tokens: ['<s>'] }, '</s>': { id: '</s>', ids: [1], tokens: ['</s>'] } } },
  decoder: null, model: { type: 'Unigram', unk_id: 2, vocab: pieces, byte_fallback: false } };
const tokCfg = { model_max_length: 512 };

const inputElem = flag === '--broken-embedder' ? FLOAT : INT64; // entrada de tipo errado: lança na inferência, não na carga
const embedder = model([node(['W', 'input_ids'], ['last_hidden_state'], 'Gather', [attrInt('axis', 0)]), bytes(2, 'embed'), tensor('W', [V, D], W),
  valueInfo(11, 'input_ids', inputElem, [1, 'L']), valueInfo(11, 'attention_mask', INT64, [1, 'L']), valueInfo(12, 'last_hidden_state', FLOAT, [1, 'L', D])]);
// cross-encoder: média dos embeddings do par projetada em w = (1, 1, -1, -1): par com palavras de tópico pontua alto
const reranker = model([node(['W', 'input_ids'], ['h'], 'Gather', [attrInt('axis', 0)]), node(['h'], ['m'], 'ReduceMean', [attrInts('axes', [1]), attrInt('keepdims', 0)]), node(['m', 'w'], ['logits'], 'MatMul'), bytes(2, 'rerank'),
  tensor('W', [V, D], W), tensor('w', [D, 1], [1, 1, -1, -1]), valueInfo(11, 'input_ids', INT64, [1, 'L']), valueInfo(11, 'attention_mask', INT64, [1, 'L']), valueInfo(12, 'logits', FLOAT, [1, 1])]);

const files = {};
const put = (rel, buf) => { writeFileSync(join(out, rel), buf); files[rel] = { sha256: createHash('sha256').update(buf).digest('hex'), size: buf.length }; };
put('embedder/model.onnx', embedder); put('embedder/tokenizer.json', Buffer.from(JSON.stringify(tok))); put('embedder/tokenizer_config.json', Buffer.from(JSON.stringify(tokCfg)));
put('reranker/model.onnx', reranker); put('reranker/tokenizer.json', Buffer.from(JSON.stringify(tok))); put('reranker/tokenizer_config.json', Buffer.from(JSON.stringify(tokCfg)));
const f = (role, rel) => ({ role, path: rel, url: `${base}/${rel}`, ...files[rel] });
const models = {
  format: 1, note: 'FIXTURE de teste — não usar em produção',
  embedder: { id: 'fixture-embedder', repo: 'fixture/embedder', license: 'MIT', revision: 'fixture', query_prefix: 'query: ', passage_prefix: 'passage: ', max_tokens: 64, output: 'last_hidden_state', pooling: 'mean',
    files: [f('model', 'embedder/model.onnx'), f('tokenizer', 'embedder/tokenizer.json'), f('tokenizer_config', 'embedder/tokenizer_config.json')] },
  reranker: { id: 'fixture-reranker', repo: 'fixture/reranker', license: 'MIT', revision: 'fixture', max_query_tokens: 32, max_passage_tokens: 64, output: 'logits',
    files: [f('model', 'reranker/model.onnx'), f('tokenizer', 'reranker/tokenizer.json'), f('tokenizer_config', 'reranker/tokenizer_config.json')] },
};
writeFileSync(join(out, 'models.json'), JSON.stringify(models, null, 2) + '\n');
