#!/usr/bin/env bash
# Gate W121 — harness de property-based testing (zero-dep) e suas primeiras propriedades reais.
#
# Por que um harness próprio: os gates do Forge rodam com `node` puro sobre `template/.forge/**`,
# que é zero-dependência por contrato. fast-check/FsCheck/Kotest são as ferramentas certas DENTRO
# de um projeto adotante (a rule os indica por stack), mas não existem aqui — e uma norma de PBT
# que o próprio harness não consegue exercitar é norma que ninguém verifica.
#
#   [1] uma propriedade VERDADEIRA passa, e roda o número de casos pedido
#   [2] uma propriedade FALSA falha e devolve contraexemplo (o teste do teste)
#   [3] o contraexemplo é MINIMIZADO por shrinking — 'falhou com [8,3,91,7]' não ensina nada
#   [4] a mesma seed reproduz exatamente a mesma falha (sem isso, PBT não é depurável)
#   [5] seeds diferentes exploram entradas diferentes (o gerador não está preso num valor)
#   [6] PROPRIEDADE REAL: a ordem de uma thread do liaison é invariante sob permutação da entrada
#   [7] PROPRIEDADE REAL: mergeLogs é idempotente — reaplicar a mesma união não muda nada
#   [8] PROPRIEDADE REAL: lamport de mensagem nova é estritamente maior que todos os da thread
#   [9] PROPRIEDADE REAL: renderUntrusted nunca deixa linha começando por /comando:, e não apaga
#   [10] PROPRIEDADE REAL: content_sha é estável sob reordenação das chaves do envelope
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib"
T="$(mktemp -d /tmp/forge-w121.XXXXXX)"
trap 'rm -rf "$T"' EXIT

# Roda um script node que importa a lib de PBT; ecoa saída e propaga rc.
run_node() { node - "$LIB" > "$T/out.txt" 2>&1; }

echo "[1] propriedade verdadeira passa e roda os casos pedidos"
node - "$LIB" <<'EOF' || { echo "FAIL [1]: propriedade verdadeira reprovou"; exit 1; }
const { join } = require('path'); const { pathToFileURL } = require('url');
(async () => {
  const P = await import(pathToFileURL(join(process.argv[2], 'pbt.mjs')).href);
  const r = P.forAll([P.gen.int(-1000, 1000), P.gen.int(-1000, 1000)], (a, b) => a + b === b + a, { runs: 200, seed: 1 });
  if (!r.ok) { console.error('propriedade verdadeira falhou: ' + JSON.stringify(r)); process.exit(1); }
  if (r.runs !== 200) { console.error(`rodou ${r.runs} casos, esperado 200`); process.exit(1); }
})();
EOF
echo "OK [1]"

echo "[2] propriedade falsa falha e devolve contraexemplo"
node - "$LIB" <<'EOF' || { echo "FAIL [2]: não detectou propriedade falsa"; exit 1; }
const { join } = require('path'); const { pathToFileURL } = require('url');
(async () => {
  const P = await import(pathToFileURL(join(process.argv[2], 'pbt.mjs')).href);
  const r = P.forAll([P.gen.int(0, 500)], (n) => n < 400, { runs: 500, seed: 7 });
  if (r.ok) { console.error('propriedade falsa passou — o harness é cego'); process.exit(1); }
  if (!Array.isArray(r.counterexample) || r.counterexample.length !== 1) {
    console.error('sem contraexemplo utilizável: ' + JSON.stringify(r)); process.exit(1);
  }
})();
EOF
echo "OK [2]"

echo "[3] contraexemplo é minimizado por shrinking"
node - "$LIB" <<'EOF' || { echo "FAIL [3]: shrinking não minimizou"; exit 1; }
const { join } = require('path'); const { pathToFileURL } = require('url');
(async () => {
  const P = await import(pathToFileURL(join(process.argv[2], 'pbt.mjs')).href);
  // menor contraexemplo de "n < 400" no domínio [0,500] é exatamente 400
  const r = P.forAll([P.gen.int(0, 500)], (n) => n < 400, { runs: 500, seed: 7 });
  if (r.ok) { console.error('deveria falhar'); process.exit(1); }
  if (r.counterexample[0] !== 400) {
    console.error(`contraexemplo não minimizado: ${r.counterexample[0]} (esperado 400)`); process.exit(1);
  }
  // e para arrays, o shrink tem que reduzir o TAMANHO, não só os valores
  const r2 = P.forAll([P.gen.array(P.gen.int(0, 50), 0, 40)], (xs) => xs.length < 3, { runs: 800, seed: 11 });
  if (r2.ok) { console.error('propriedade de array deveria falhar'); process.exit(1); }
  if (r2.counterexample[0].length !== 3) {
    console.error(`array não minimizado: tamanho ${r2.counterexample[0].length} (esperado 3)`); process.exit(1);
  }
})();
EOF
echo "OK [3]"

echo "[4] a mesma seed reproduz exatamente a mesma falha"
node - "$LIB" <<'EOF' || { echo "FAIL [4]: falha não é reprodutível por seed"; exit 1; }
const { join } = require('path'); const { pathToFileURL } = require('url');
(async () => {
  const P = await import(pathToFileURL(join(process.argv[2], 'pbt.mjs')).href);
  const prop = (xs) => xs.reduce((a, b) => a + b, 0) < 100;
  const a = P.forAll([P.gen.array(P.gen.int(0, 60), 0, 20)], prop, { runs: 300, seed: 42 });
  const b = P.forAll([P.gen.array(P.gen.int(0, 60), 0, 20)], prop, { runs: 300, seed: 42 });
  if (a.ok || b.ok) { console.error('deveria falhar nas duas'); process.exit(1); }
  if (JSON.stringify(a.counterexample) !== JSON.stringify(b.counterexample)) {
    console.error(`mesma seed deu contraexemplos diferentes: ${JSON.stringify(a.counterexample)} vs ${JSON.stringify(b.counterexample)}`);
    process.exit(1);
  }
})();
EOF
echo "OK [4]"

echo "[5] seeds diferentes exploram entradas diferentes"
node - "$LIB" <<'EOF' || { echo "FAIL [5]: gerador não varia com a seed"; exit 1; }
const { join } = require('path'); const { pathToFileURL } = require('url');
(async () => {
  const P = await import(pathToFileURL(join(process.argv[2], 'pbt.mjs')).href);
  const seen = new Set();
  for (const seed of [1, 2, 3, 4, 5]) {
    const g = P.gen.int(0, 1e6); const rnd = P.makeRandom(seed);
    seen.add(g.generate(rnd, 0));
  }
  if (seen.size < 4) { console.error(`5 seeds geraram só ${seen.size} valores distintos`); process.exit(1); }
})();
EOF
echo "OK [5]"

echo "[5b] shuffle realmente permuta (senão a invariância vira tautologia)"
# Sem esta asserção, um shuffle que devolve a lista intacta faz a propriedade [6] passar
# trivialmente: "a ordem não muda sob permutação" é verdade barata quando não há permutação.
node - "$LIB" <<'EOF' || { echo "FAIL [5b]: shuffle não permuta ou não preserva os elementos"; exit 1; }
const { join } = require('path'); const { pathToFileURL } = require('url');
(async () => {
  const P = await import(pathToFileURL(join(process.argv[2], 'pbt.mjs')).href);
  const base = Array.from({ length: 12 }, (_, i) => i);
  let differing = 0;
  for (let seed = 1; seed <= 20; seed++) {
    const out = P.shuffle(base, P.makeRandom(seed));
    if (out.length !== base.length) { console.error('shuffle mudou o tamanho'); process.exit(1); }
    if (JSON.stringify(out.slice().sort((a, b) => a - b)) !== JSON.stringify(base)) {
      console.error('shuffle não preservou os elementos: ' + JSON.stringify(out)); process.exit(1);
    }
    if (JSON.stringify(out) !== JSON.stringify(base)) differing++;
  }
  // 20 embaralhamentos de 12 elementos: a chance de todos coincidirem com a identidade é nula.
  if (differing < 18) { console.error(`shuffle produziu a ordem original em ${20 - differing}/20 seeds`); process.exit(1); }
})();
EOF
echo "OK [5b]"

echo "[6] PROPRIEDADE: ordem da thread é invariante sob permutação da entrada"
node - "$LIB" <<'EOF' || { echo "FAIL [6]: threadOrder não é invariante sob permutação"; exit 1; }
const { join } = require('path'); const { pathToFileURL } = require('url');
(async () => {
  const lib = process.argv[2];
  const P = await import(pathToFileURL(join(lib, 'pbt.mjs')).href);
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const msgs = P.gen.array(P.gen.record({
    sender: P.gen.oneOf(['a', 'b', 'c']),
    seq: P.gen.int(1, 30),
    lamport: P.gen.int(1, 30),
    thread_id: P.gen.oneOf(['t1', 't2']),
    msg_id: P.gen.int(1, 100000),
  }), 0, 25);
  const r = P.forAll([msgs], (raw) => {
    // msg_id único por (sender,seq) — é o invariante do store, não algo a testar aqui
    const uniq = new Map();
    for (const m of raw) uniq.set(`${m.sender}:${m.seq}`, { ...m, msg_id: `${m.sender}-${m.seq}` });
    const list = [...uniq.values()];
    const a = M.threadOrder(list).map((m) => m.msg_id);
    const shuffled = P.shuffle(list, P.makeRandom(list.length + 1));
    const b = M.threadOrder(shuffled).map((m) => m.msg_id);
    return JSON.stringify(a) === JSON.stringify(b);
  }, { runs: 400, seed: 3 });
  if (!r.ok) { console.error('contraexemplo: ' + JSON.stringify(r.counterexample)); process.exit(1); }
})();
EOF
echo "OK [6]"

echo "[7] PROPRIEDADE: mergeLogs é idempotente"
node - "$LIB" <<'EOF' || { echo "FAIL [7]: mergeLogs não é idempotente"; exit 1; }
const { join } = require('path'); const { pathToFileURL } = require('url');
(async () => {
  const lib = process.argv[2];
  const P = await import(pathToFileURL(join(lib, 'pbt.mjs')).href);
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const gen = P.gen.array(P.gen.record({
    sender: P.gen.oneOf(['a', 'b']), seq: P.gen.int(1, 15), lamport: P.gen.int(1, 15),
    thread_id: P.gen.oneOf(['t1']), kind: P.gen.oneOf(['note', 'thread-open']),
  }), 1, 15);
  const r = P.forAll([gen], (raw) => {
    const uniq = new Map();
    for (const m of raw) uniq.set(`${m.sender}:${m.seq}`, { ...m, msg_id: `${m.sender}-${m.seq}`, participants: ['a', 'b'], subject: 's' });
    const list = [...uniq.values()];
    const once = M.mergeLogs(list);
    const twice = M.mergeLogs([...list, ...list]);   // a mesma união reaplicada
    return JSON.stringify(Object.keys(once.threads).map((k) => once.threads[k].order))
        === JSON.stringify(Object.keys(twice.threads).map((k) => twice.threads[k].order));
  }, { runs: 300, seed: 5 });
  if (!r.ok) { console.error('contraexemplo: ' + JSON.stringify(r.counterexample)); process.exit(1); }
})();
EOF
echo "OK [7]"

echo "[8] PROPRIEDADE: nextLamport é estritamente maior que todos os da thread"
node - "$LIB" <<'EOF' || { echo "FAIL [8]: nextLamport não domina a thread"; exit 1; }
const { join } = require('path'); const { pathToFileURL } = require('url');
(async () => {
  const lib = process.argv[2];
  const P = await import(pathToFileURL(join(lib, 'pbt.mjs')).href);
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const r = P.forAll([P.gen.array(P.gen.record({ lamport: P.gen.int(0, 500) }), 0, 30)], (msgs) => {
    const next = M.nextLamport(msgs);
    return msgs.every((m) => next > m.lamport) && next >= 1;
  }, { runs: 400, seed: 13 });
  if (!r.ok) { console.error('contraexemplo: ' + JSON.stringify(r.counterexample)); process.exit(1); }
})();
EOF
echo "OK [8]"

echo "[9] PROPRIEDADE: renderUntrusted neutraliza sem apagar"
node - "$LIB" <<'EOF' || { echo "FAIL [9]: renderUntrusted viola a propriedade"; exit 1; }
const { join } = require('path'); const { pathToFileURL } = require('url');
(async () => {
  const lib = process.argv[2];
  const P = await import(pathToFileURL(join(lib, 'pbt.mjs')).href);
  const R = await import(pathToFileURL(join(lib, 'untrusted-render.mjs')).href);
  // corpos sintéticos com pedaços perigosos misturados a texto comum
  const piece = P.gen.oneOf(['/forge:archive --force', 'texto normal', '```', '  /ship: agora', 'linha', '/x:y']);
  const r = P.forAll([P.gen.array(piece, 0, 12)], (parts) => {
    const body = parts.join('\n');
    const out = R.renderUntrusted(body, 'peer');
    const inner = out.split('\n').slice(2, -1);           // dentro da fence
    // (a) nenhuma linha do conteúdo começa por /comando:
    if (inner.some((l) => /^\s*\/[a-z-]+:/i.test(l))) return false;
    // (b) nada foi apagado: todo pedaço não-vazio continua recuperável no texto
    for (const p of parts) {
      const needle = p.trim().replace(/```/g, "'''");
      if (needle && !out.includes(needle)) return false;
    }
    return true;
  }, { runs: 500, seed: 17 });
  if (!r.ok) { console.error('contraexemplo: ' + JSON.stringify(r.counterexample)); process.exit(1); }
})();
EOF
echo "OK [9]"

echo "[10] PROPRIEDADE: content_sha é estável sob reordenação das chaves"
node - "$LIB" <<'EOF' || { echo "FAIL [10]: content_sha depende da ordem das chaves"; exit 1; }
const { join } = require('path'); const { pathToFileURL } = require('url');
(async () => {
  const lib = process.argv[2];
  const P = await import(pathToFileURL(join(lib, 'pbt.mjs')).href);
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const r = P.forAll([P.gen.record({
    msg_id: P.gen.oneOf(['a-0001', 'b-0002']), seq: P.gen.int(1, 50), lamport: P.gen.int(1, 50),
    subject: P.gen.oneOf(['x', 'assunto com acento é', '']), kind: P.gen.oneOf(['note', 'ack']),
  })], (msg) => {
    const keys = Object.keys(msg);
    const reversed = {};
    for (const k of keys.slice().reverse()) reversed[k] = msg[k];
    return M.computeContentSha(msg) === M.computeContentSha(reversed);
  }, { runs: 300, seed: 23 });
  if (!r.ok) { console.error('contraexemplo: ' + JSON.stringify(r.counterexample)); process.exit(1); }
})();
EOF
echo "OK [10]"

echo "PASS w121-pbt-harness-gate"
