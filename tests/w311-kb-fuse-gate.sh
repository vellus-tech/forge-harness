#!/usr/bin/env bash
# Gate W286 — busca unificada (/forge:kb), fusão: RRF ponderado, propagação de links e combinação do
# re-rank como funções puras (change add-unified-knowledge-search, REQ-03, REQ-07; design §2.5, §2.6).
#
#   [1] rrf: score = Σ w_c/(k+rank), contribuição por canal exposta, empate desempatado por id
#   [2] constantes exportadas e coerentes com a calibração registrada (pesos, k, α, T, K)
#   [3] propagação: vizinho de um resultado do topo ganha contribuição de links com a origem nomeada;
#       vizinho que não estava na fusão entra; documento fora do topo T não propaga
#   [4] re-rank concordante (scores A > B > C > D) preserva [A, B, C, D]
#   [5] re-rank discordante (D primeiro, A último; nas duas ordens possíveis do meio) move D para cima
#       da 4ª posição e A para baixo da 1ª, e a ordem é exatamente a prevista pela fórmula documentada,
#       com desempate pela posição do cross-encoder
#   [6] documentos além de K mantêm a ordem do ranking propagado
#   [7] o módulo não importa nada (função pura)
#   [8] pool do re-rank = K primeiros do ranking propagado + os 3 primeiros do BM25 (RERANK_LEXICAL_EXTRA),
#       mesmo abaixo de K; sem extras, comportamento anterior
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib"
ok() { echo "OK [$1]"; }
fail() { echo "FAIL [$1] $2"; exit 1; }
js() { node --input-type=module -e "import * as F from '$LIB/kb-fuse.mjs'; $1"; }

js "
const r = F.rrf({ bm25: new Map([['a', 1], ['b', 2]]), entities: new Map([['b', 1]]) }, { bm25: 1, entities: 0.5 }, 60);
const a = r.find((x) => x.doc === 'a'), b = r.find((x) => x.doc === 'b');
const near = (x, y) => Math.abs(x - y) < 1e-12;
if (!near(a.score, 1 / 61) || !near(b.score, 1 / 62 + 0.5 / 61)) process.exit(1);
if (r[0].doc !== 'b' || !near(b.channels.entities.contribution, 0.5 / 61) || b.channels.bm25.rank !== 2) process.exit(1);
const t = F.rrf({ bm25: new Map([['z', 1]]), entities: new Map([['y', 1]]) }, { bm25: 1, entities: 1 }, 60);
if (t[0].doc !== 'y') process.exit(1);
" || fail 1 "rrf incorreto"
ok 1

js "
const w = F.WEIGHTS;
if (F.RRF_K !== 60 || w.bm25 !== 1 || w.entities !== 0.2 || typeof w.vector !== 'number' || 'links' in w) process.exit(1);
if (F.LINK_ALPHA !== 0.1 || F.LINK_TOP !== 10 || F.RERANK_K !== 10) process.exit(1);
if (!/rank_cross_encoder/.test(F.RERANK_FORMULA)) process.exit(1);
" || fail 2 "constantes divergem da calibração registrada"
ok 2

js "
const fused = [{ doc: 'a', score: 0.5, channels: {} }, { doc: 'b', score: 0.4, channels: {} }];
const links = { a: ['c'], c: ['a'], b: [] };
const p = F.propagateLinks(fused, links, 0.1, 10);
const c = p.find((x) => x.doc === 'c');
if (!c || !(c.channels.links.contribution > 0) || c.channels.links.from.join() !== 'a') process.exit(1);
if (Math.abs(c.score - 0.1 * 0.5 / Math.sqrt(1 * 1)) > 1e-12) process.exit(1);
const p2 = F.propagateLinks(fused, links, 0.1, 1);
const fusedB = [{ doc: 'a', score: 0.5, channels: {} }, { doc: 'b', score: 0.4, channels: {} }];
const p3 = F.propagateLinks(fusedB, { b: ['d'], d: ['b'], a: [] }, 0.1, 1);
if (p3.some((x) => x.doc === 'd')) process.exit(1);
" || fail 3 "propagação incorreta"
ok 3

js "
const s = new Map([['A', 4], ['B', 3], ['C', 2], ['D', 1]]);
const r = F.combineRerank(['A', 'B', 'C', 'D'], s, 4).map((x) => x.doc);
if (r.join() !== 'A,B,C,D') { console.log(r); process.exit(1); }
" || fail 4 "re-rank concordante alterou a ordem"
ok 4

js "
for (const mid of [['B', 'C'], ['C', 'B']]) {
const s = new Map([['D', 4], [mid[0], 3], [mid[1], 2], ['A', 1]]);
const rows = F.combineRerank(['A', 'B', 'C', 'D'], s, 4);
const r = rows.map((x) => x.doc);
const posD = r.indexOf('D') + 1, posA = r.indexOf('A') + 1;
if (!(posD < 4) || !(posA > 1)) { console.log(r); process.exit(1); }
// previsto pela fórmula: score = wce/(k+rank_ce) + 1/(k+rank_prop), desempate pela posição propagada
const k = F.RERANK_RRF_K, wce = F.RERANK_WEIGHTS.cross_encoder, wf = F.RERANK_WEIGHTS.fusion;
const ce = { D: 1, [mid[0]]: 2, [mid[1]]: 3, A: 4 }, pr = { A: 1, B: 2, C: 3, D: 4 };
const exp = ['A', 'B', 'C', 'D'].map((d) => [d, wce / (k + ce[d]) + wf / (k + pr[d])]).sort((x, y) => y[1] - x[1] || ce[x[0]] - ce[y[0]]).map((x) => x[0]);
if (r.join() !== exp.join()) { console.log(r, exp); process.exit(1); }
if (rows[0].ce_rank === undefined || rows[0].fusion_rank === undefined) process.exit(1);
}
" || fail 5 "re-rank discordante fora da fórmula"
ok 5

js "
const s = new Map([['A', 1], ['B', 2]]);
const r = F.combineRerank(['A', 'B', 'X', 'Y', 'Z'], s, 2).map((x) => x.doc);
if (r.slice(2).join() !== 'X,Y,Z') { console.log(r); process.exit(1); }
" || fail 6 "cauda além de K reordenada"
ok 6

js "
// pool do re-rank: os K primeiros do ranking propagado mais os extras (topo do BM25), mesmo que o
// extra esteja abaixo de K — é o que impede a recuperação híbrida de descartar o 1º lexical antes de o
// cross-encoder vê-lo (diagnóstico de 2026-10-31)
const fused = 'ABCDEFGHIJKL'.split('');
const s = new Map(fused.map((d, i) => [d, d === 'L' ? 100 : 50 - i]));
const sem = F.combineRerank(fused, s, 10).map((x) => x.doc);
if (sem.indexOf('L') !== 11) { console.log('sem extra, L deveria ficar na cauda', sem); process.exit(1); }
const rows = F.combineRerank(fused, s, 10, ['L']);
const r = rows.map((x) => x.doc);
const L = rows.find((x) => x.doc === 'L');
if (L.fusion_rank !== 12 || L.ce_rank !== 1) { console.log(JSON.stringify(L)); process.exit(1); }
// previsto pela fórmula sobre o pool (11 documentos), desempate pelo cross-encoder
const pool = fused.slice(0, 10).concat(['L']);
const ce = new Map([...pool].sort((a, b) => s.get(b) - s.get(a)).map((d, i) => [d, i + 1]));
const k = F.RERANK_RRF_K;
const exp = pool.map((d) => [d, 1 / (k + ce.get(d)) + 1 / (k + fused.indexOf(d) + 1)]).sort((x, y) => y[1] - x[1] || ce.get(x[0]) - ce.get(y[0])).map((x) => x[0]);
if (r.slice(0, 11).join() !== exp.join() || r[11] !== 'K') { console.log(r, exp); process.exit(1); }
if (F.RERANK_LEXICAL_EXTRA !== 3) process.exit(1);
" || fail 8 "pool do re-rank sem os extras do topo lexical"
ok 8

grep -qE '^[[:space:]]*import ' "$LIB/kb-fuse.mjs" && fail 7 "kb-fuse.mjs importa módulo (deveria ser puro)"
ok 7

echo "PASS w311-kb-fuse (8 casos)"
