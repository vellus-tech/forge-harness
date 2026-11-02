#!/usr/bin/env bash
# Gate W285 — busca unificada (/forge:kb), índice lexical: normalização, BM25, entidades, grafo de
# links e serialização determinística (change add-unified-knowledge-search, REQ-02, REQ-03; design §2.4).
#
#   [1] normalização: acento e caixa ("decisao" casa "Decisão"); redução de sufixo ("decisões")
#   [2] BM25: documento que contém os termos raros vem antes do que só contém termo comum
#   [3] entidades: LDG-NNNN, wNNN, arquivo .sh, /forge:cmd, ADR/REQ/TASK — casamento exato, sem stem;
#       siglas genéricas em caixa alta (README, TDD, API…) não são entidade
#   [4] links: id de ledger, nome de arquivo único, change-id de spec arquivada; nome genérico
#       (proposal.md) e nome repetido não criam aresta
#   [5] índice determinístico: duas construções sobre os mesmos documentos são byte-idênticas (JSON e
#       texts.bin); o texto dos trechos fica fora do JSON e é lido por deslocamento
#   [6] o índice traz impressão digital, formato e as estruturas declaradas
#   [7] o módulo só importa node:* e módulos do próprio harness (zero-dep)
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib"
ok() { echo "OK [$1]"; }
fail() { echo "FAIL [$1] $2"; exit 1; }
js() { node --input-type=module -e "import * as X from '$LIB/kb-lexical.mjs'; import { createHash } from 'node:crypto'; const D = (id, kind, text) => ({ id, kind, text, sha256: createHash('sha256').update(text).digest('hex') }); $1"; }

js "
const idx = X.buildIndex([D('a.md', 'plan', 'A Decisão de usar o grafo nativo'), D('b.md', 'plan', 'outra coisa qualquer')]).index;
const r = X.bm25(idx, 'decisao grafo');
if (!r.length || idx.chunks[r[0][0]].doc !== 'a.md') process.exit(1);
if (X.tokenize('decisões').join() !== X.tokenize('decisão').join()) process.exit(1);
" || fail 1 "normalização incorreta"
ok 1

js "
const docs = [];
for (let i = 0; i < 20; i++) docs.push(D('c' + i + '.md', 'plan', 'harness comum texto ' + i));
docs.push(D('alvo.md', 'plan', 'harness com mutex de suite pesada'));
const idx = X.buildIndex(docs).index;
const r = X.bm25(idx, 'harness mutex pesada');
if (idx.chunks[r[0][0]].doc !== 'alvo.md') process.exit(1);
" || fail 2 "BM25 não priorizou termos raros"
ok 2

js "
const e = X.entities('ver LDG-0012, gate w283, script spec-new.sh, comando /forge:kb, ADR 0005, REQ-03 e TASK-07');
for (const want of ['ldg-0012', 'w283', 'spec-new.sh', '/forge:kb', 'adr-0005', 'req-03', 'task-07']) if (!e.includes(want)) { console.log(e); process.exit(1); }
// siglas genéricas não são entidade (emenda do REQ-03, 2026-10-31): eram a causa medida da perda do lexical
const g = X.entities('README TDD MVP GIT_DIR API CLI PCI DSS');
if (g.length) { console.log('siglas viraram entidade:', g); process.exit(1); }
// nomes genéricos de artefato e nomes de tecnologia não são entidade (LOG-001, code-evaluator PR #252):
// casavam qualquer documento chamado design.md/tasks.md/README.md/package.json ou que citasse Node.js/Next.js
const n = X.entities('ver design.md, tasks.md, README.md, CHANGELOG.md, proposal.md, package.json, Node.js 20 e Next.js');
if (n.length) { console.log('nomes genéricos viraram entidade:', n); process.exit(1); }
const idx = X.buildIndex([D('a.md', 'plan', 'trata do LDG-0012'), D('b.md', 'plan', 'trata do LDG-0013')]).index;
const r = X.entityMatch(idx, 'o que diz LDG-0012?');
if (r.length !== 1 || idx.chunks[r[0][0]].doc !== 'a.md') process.exit(1);
" || fail 3 "entidades incorretas"
ok 3

js "
const docs = [
  D('ledger:LDG-0007', 'ledger', 'LDG-0007 assinatura'),
  D('docs/plans/p.md', 'plan', 'ver LDG-0007 e o arquivo unico-plano.md e proposal.md e repetido.md e add-x'),
  D('docs/plans/unico-plano.md', 'plan', 'alvo por nome'),
  D('.forge/specs/archived/2026-01-01-add-x/proposal.md', 'archived-spec', 'spec x'),
  D('.forge/specs/archived/2026-01-02-add-y/proposal.md', 'archived-spec', 'spec y'),
  D('docs/plans/a/repetido.md', 'plan', 'r1'),
  D('docs/plans/b/repetido.md', 'plan', 'r2'),
];
const L = X.buildLinks(docs);
const n = L['docs/plans/p.md'];
for (const want of ['ledger:LDG-0007', 'docs/plans/unico-plano.md', '.forge/specs/archived/2026-01-01-add-x/proposal.md']) if (!n.includes(want)) { console.log(n); process.exit(1); }
if (n.includes('.forge/specs/archived/2026-01-02-add-y/proposal.md') || n.some((x) => x.endsWith('repetido.md'))) { console.log(n); process.exit(1); }
if (!L['ledger:LDG-0007'].includes('docs/plans/p.md')) process.exit(1);
" || fail 4 "grafo de links incorreto"
ok 4

js "
const docs = [D('a.md', 'plan', '# T\nx LDG-0001'), D('ledger:LDG-0001', 'ledger', 'LDG-0001 y')];
const b1 = X.buildIndex(docs), b2 = X.buildIndex(docs.slice());
if (X.serializeIndex(b1.index) !== X.serializeIndex(b2.index) || !b1.texts.equals(b2.texts)) process.exit(1);
if (b1.index.chunkText(0) !== '# T\nx LDG-0001') { console.log(JSON.stringify(b1.index.chunkText(0))); process.exit(1); }
if ('text' in b1.index.chunks[0]) process.exit(1);
" || fail 5 "índice não determinístico"
ok 5

js "
const idx = X.buildIndex([D('a.md', 'plan', 'x')]).index;
for (const k of ['format', 'fingerprint', 'quick_fingerprint', 'texts_sha256', 'docs', 'chunks', 'len', 'postings', 'entities', 'links']) if (!(k in idx)) { console.log(k); process.exit(1); }
if (idx.format !== X.INDEX_FORMAT || !/^[0-9a-f]{64}$/.test(idx.fingerprint)) process.exit(1);
" || fail 6 "estrutura do índice incompleta"
ok 6

bad="$(grep -E "^[[:space:]]*import .* from '" "$LIB/kb-lexical.mjs" | grep -vE "from '(node:[a-z_/]+|\./[a-z-]+\.mjs)'" || true)"
[ -z "$bad" ] || fail 7 "import fora de node:* e do harness: $bad"
ok 7

echo "PASS w310-kb-lexical (7 casos)"
