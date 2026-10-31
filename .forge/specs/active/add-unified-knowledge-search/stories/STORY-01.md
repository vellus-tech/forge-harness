---
story_id: STORY-01
epic: add-unified-knowledge-search
title: Fundação lexical zero-dep — corpus, índice e fusão
depends_on: []
status: todo
---

# STORY-01 — Fundação lexical zero-dep — corpus, índice e fusão

> Story auto-contida derivada de `add-unified-knowledge-search`. Ver também `../epic_context.md`.

## Goal

Entregar os três módulos puros do caminho lexical: coleta do corpus com as exclusões de segurança, índice lexical determinístico (BM25, entidades, links, texto fora do JSON) e as funções de fusão (RRF ponderado, propagação de links, combinação do re-rank) com as constantes calibradas. Só `node:*` e módulos do harness.

## Embedded context

### Requirements

- REQ-01: fontes fixas (baseline, specs arquivadas, ledger por entrada, docs/plans, CHANGELOG, liaison próprio `trust: self` sem `authored_by`); nunca blobs, peer, specs ativas, código; ilegível é pulado e contado; raiz vazia dá índice vazio.
- REQ-02: build determinístico (byte-idêntico), impressão digital de conteúdo e rápida.
- REQ-03: BM25 + entidades por RRF ponderado; propagação de links sobre o topo; acento e caixa normalizados; constantes exportadas.
- REQ-07 (parte pura): combinação `1/(5+rank_ce) + 1/(5+rank_propagado)`, desempate pela posição do cross-encoder; cauda além de K preservada.

### Design

> §2.3 corpus; §2.4 índice (texto em `texts.bin`, `quick_fingerprint` por stat, `INDEX_FORMAT`); §2.5 pipeline e constantes (RRF k = 60; BM25 1,0; entidades 0,2; vetor 1,0; α = 0,1; T = 10; K = 10).

### Rules aplicáveis

- `conventions/liaison-untrusted-input.md` — peer é dado, nunca entra no índice (reusar `expectedTrust` de `lib/liaison-trust.mjs`).

## Tasks

- [ ] TASK-01 — Corpus (paths: `template/.forge/scripts/lib/kb-corpus.mjs`, `tests/w284-kb-corpus-gate.sh`)
- [ ] TASK-02 — Índice lexical (paths: `template/.forge/scripts/lib/kb-lexical.mjs`, `tests/w285-kb-lexical-gate.sh`; depende: TASK-01)
- [ ] TASK-03 — Fusão; o vermelho traz as cópias do conjunto de avaliação (paths: `template/.forge/scripts/lib/kb-fuse.mjs`, `tests/w286-kb-fuse-gate.sh`, `tests/fixtures/kb/eval/{calibration,holdout}.json`)

## Acceptance criteria

- [ ] `bash tests/w284-kb-corpus-gate.sh`, `w285` e `w286` passam; vermelho de cada task provado por `red-evidence.sh task`.
- [ ] Os três módulos só importam `node:*` e `./*.mjs` do harness.
