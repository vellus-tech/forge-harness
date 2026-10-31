// Gera modelos ONNX minúsculos (protobuf escrito à mão) para testar a inferência real do onnxruntime-web.
const varint = (n) => { n = BigInt(n); const out = []; do { let b = Number(n & 0x7fn); n >>= 7n; if (n) b |= 0x80; out.push(b); } while (n); return Buffer.from(out); };
const key = (f, w) => varint((f << 3) | w);
const vint = (f, n) => Buffer.concat([key(f, 0), varint(n)]);
const bytes = (f, b) => { b = Buffer.isBuffer(b) ? b : Buffer.from(b, 'utf8'); return Buffer.concat([key(f, 2), varint(b.length), b]); };
const msg = (f, ...parts) => bytes(f, Buffer.concat(parts));
const dim = (d) => (typeof d === 'number' ? msg(1, vint(1, d)) : msg(1, bytes(2, d)));
const valueInfo = (f, name, elem, dims) => msg(f, bytes(1, name), msg(2, msg(1, vint(1, elem), msg(2, ...dims.map(dim)))));
const tensor = (name, dims, floats) => msg(5, ...dims.map((d) => vint(1, d)), vint(2, 1), bytes(8, name), bytes(9, Buffer.from(new Float32Array(floats).buffer)));
const node = (inputs, outputs, op, attrs = []) => msg(1, ...inputs.map((i) => bytes(1, i)), ...outputs.map((o) => bytes(2, o)), bytes(4, op), ...attrs);
const attrInts = (name, ints) => msg(5, bytes(1, name), ...ints.map((i) => vint(8, i)), vint(20, 7));
const attrInt = (name, i) => msg(5, bytes(1, name), vint(3, i), vint(20, 2));
const model = (graph) => Buffer.concat([vint(1, 8), msg(8, bytes(1, ''), vint(2, 13)), bytes(2, 'forge-kb-fixture'), msg(7, ...graph)]);
const INT64 = 7, FLOAT = 1;

// embedder: input_ids[1,L] -> Gather(W) -> last_hidden_state[1,L,D]
export function embedModel(W, V, D) {
  return model([node(['W', 'input_ids'], ['last_hidden_state'], 'Gather', [attrInt('axis', 0)]), bytes(2, 'embed'), tensor('W', [V, D], W),
    valueInfo(11, 'input_ids', INT64, [1, 'L']), valueInfo(11, 'attention_mask', INT64, [1, 'L']), valueInfo(12, 'last_hidden_state', FLOAT, [1, 'L', D])]);
}
// cross-encoder: Gather(W) -> ReduceMean(axis1) -> MatMul(w) -> logits[1,1]
export function rerankModel(W, V, D, w) {
  return model([node(['W', 'input_ids'], ['h'], 'Gather', [attrInt('axis', 0)]), node(['h'], ['m'], 'ReduceMean', [attrInts('axes', [1]), attrInt('keepdims', 0)]), node(['m', 'w'], ['logits'], 'MatMul'), bytes(2, 'rerank'),
    tensor('W', [V, D], W), tensor('w', [D, 1], w), valueInfo(11, 'input_ids', INT64, [1, 'L']), valueInfo(11, 'attention_mask', INT64, [1, 'L']), valueInfo(12, 'logits', FLOAT, [1, 1])]);
}
