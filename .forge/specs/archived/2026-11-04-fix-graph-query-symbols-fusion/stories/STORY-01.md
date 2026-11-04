---
story_id: STORY-01
epic: fix-graph-query-symbols-fusion
title: Red SDD-level do defeito original + fixtures congeladas
depends_on: []
status: done
---

# STORY-01 — Red SDD-level do defeito original + fixtures congeladas

> Story auto-contida derivada de `fix-graph-query-symbols-fusion`. Toda informação necessária para implementar
> esta story está aqui — sem precisar reler o change completo (§17.1).

## Goal

Registrar o Red SDD-level do defeito original (`graph.sh query` nunca lê `symbols.json`), ancorado num cenário real de busca por nome de símbolo que hoje falha, e capturar os snapshots/goldens congelados (motor antigo, corpus real, saída pré-mudança de `query`) que as stories seguintes vão usar como oráculo de regressão/diferencial. Nenhuma linha de produção é tocada nesta story.

## Embedded context

### Requirements

- bugfix.md §1 (comportamento atual): `graph.sh query` lê só `graph.json`, filtra `node.id`/`edge.from`/`edge.to`; nunca abre `symbols.json`. `graph-symbols.mjs` tem walk/mapa de linguagem próprios (sem `.sh`/`.go`, sem `include_paths`) — 60,8% dos nodes deste repositório (`.sh`) nunca são indexados.
- bugfix.md §5 intro / REQ-01 / REQ-05 (implícitos nesta story como pré-condição): o golden pré-mudança precisa ser capturado com o motor ATUAL, antes de qualquer edição de `graph.sh`/`graph-build.mjs`.

### Design

- design.md §2 DD-08: toda task sob `template/.forge/scripts/` segue Red-first via `isInfraPath` — commit vermelho nunca toca arquivo de produção, só teste em `tests/`; falha comportamental via `import()` dinâmico + `assert.fail` (módulo ausente) ou checagem `typeof` (export ausente). Aqui, porém, o Red SDD-level da TASK-01 é diferente: usa um fixture real (`red-task01/`) com asserção de shell que reprova de verdade hoje.
- design.md §5 item 1: snapshots do oráculo (`old-engine-snapshot.mjs`/`corpus-snapshot/`) são capturados num commit de fixture dedicado, antes da primeira task de produção.

### Contratos / interfaces

- Nenhum contrato de produção é criado ou alterado nesta story — só fixtures de teste e evidência de Red SDD-level (`evidence/red/red-evidence.json`).

### Rules aplicáveis

- `rules/testing/regression-red-first.md` — abertura do Red SDD-level via `/forge:red record` (status `pending`), fechado só na TASK-14.
- `rules/conventions/no-ai-attribution.md` — commits sem coautoria de IA.

### ADRs

- ADR-0001 (`graph-engine`, accepted) — zero-dep é inegociável; os snapshots capturados aqui (`old-engine-snapshot.mjs`) vendorizam o comportamento regex-based atual, não uma reescrita AST.

## Tasks

- [ ] TASK-01 — Registrar o Red SDD-level do defeito original, ancorado num cenário real de busca por símbolo que hoje falha com asserção de shell que de fato reprova (paths: `evidence/red/red-evidence.json`, `tests/fixtures/graph-query-symbols/red-task01/src/handlers/h1.js`, `tests/fixtures/graph-query-symbols/red-task01/repro.sh`; depende: —). Teste: `bash tests/fixtures/graph-query-symbols/red-task01/repro.sh`. Padrão de falha: string literal `FAIL [red-task01-processarPedido]`. `/forge:red record --test-path tests/fixtures/graph-query-symbols/red-task01/repro.sh --test-id red-task01-processarPedido --command "bash tests/fixtures/graph-query-symbols/red-task01/repro.sh" --failure-pattern "FAIL \[red-task01-processarPedido\]" --fix-files "template/.forge/scripts/lib/graph-query.mjs,template/.forge/scripts/graph.sh"` grava `status: pending`.
- [ ] TASK-02 — Capturar o snapshot congelado do motor antigo, corpus real (extensão neutra) e golden pré-mudança da saída de `query` sobre fixture sintética congelada (paths: `tests/fixtures/graph-query-symbols/old-engine-snapshot.mjs`, `tests/fixtures/graph-query-symbols/corpus-snapshot/*.mjs.txt`, `tests/fixtures/graph-query-symbols/corpus-snapshot-shell/*.sh.txt`, `tests/fixtures/graph-query-symbols/golden-pre-change/make-fixture.sh`, `tests/fixtures/graph-query-symbols/golden-pre-change/query-golden-pre-change.txt`; depende: TASK-01). Teste: `test -s .../old-engine-snapshot.mjs && [ -n "$(find .../corpus-snapshot -name '*.mjs.txt')" ] && [ -n "$(find .../corpus-snapshot-shell -name '*.sh.txt')" ] && test -x .../golden-pre-change/make-fixture.sh && test -s .../golden-pre-change/query-golden-pre-change.txt && bash tests/w209-varredura-cega-gate.sh && bash tests/w213-arvore-rastreada-gate.sh`. Sem par vermelho/verde de comportamento (fixture estática) — só guard de integridade.

## Acceptance criteria

- [ ] `tests/fixtures/graph-query-symbols/red-task01/repro.sh` produz `rc=1`/`FAIL [red-task01-processarPedido]` no estado atual do código (antes de qualquer correção).
- [ ] `evidence/red/red-evidence.json` grava `status: pending`, `base_commit` = HEAD desta worktree, `failure_pattern`, `fix_files` iniciais, `reproduces: bugfix.md §1`.
- [ ] `old-engine-snapshot.mjs` vendoriza as regexes `DECL`/`src.matchAll` sem masking, importável via `import()` dinâmico.
- [ ] `corpus-snapshot/*.mjs.txt` e `corpus-snapshot-shell/*.sh.txt` são cópias fiéis (extensão neutra) de `template/.forge/scripts/lib/*.mjs` e `*.sh`/hooks, neste commit.
- [ ] `golden-pre-change/make-fixture.sh <dir>` materializa fixture sintética determinística sem config; `query-golden-pre-change.txt` é capturado com o `graph.sh query` atual (pré-mudança) sobre essa fixture.
- [ ] `tests/w209-varredura-cega-gate.sh` e `tests/w213-arvore-rastreada-gate.sh` continuam `OK` com as fixtures novas.
- [ ] Nenhum arquivo de produção (`template/.forge/scripts/**`) tocado nesta story.

## Out of scope

- Qualquer edição em `graph-build.mjs`, `graph-symbols.mjs`, `graph-query.mjs` (ainda não existe), `validate-graph.mjs` ou `graph.sh` — fica para STORY-02 a STORY-05.
- Fechamento do Red SDD-level (`status: observed`) — é TASK-14/STORY-07.
