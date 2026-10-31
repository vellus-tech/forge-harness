---
story_id: STORY-02
epic: add-unified-knowledge-search
title: CLI lexical, avaliador e guardas do caminho lexical
depends_on: [STORY-01]
status: in_progress
---

# STORY-02 — CLI lexical, avaliador e guardas do caminho lexical

> Story auto-contida derivada de `add-unified-knowledge-search`. Ver também `../epic_context.md`.

## Goal

Entregar `kb.sh` e `kb-cli.mjs` no modo lexical (build, query, status, saída explicável, reconstrução automática, `--lexical`, `--top`, erros de uso, carga dinâmica da camada semântica pela raiz de estado) o avaliador `kb.sh eval` com o conjunto de avaliação versionado, e as guardas do caminho lexical: estáticos (imports, provedores de LLM, programas do `kb.sh`), `git` substituto, bloqueio de rede (permissões do Node e interceptador `--require` com pontos de estrangulamento) e canário de controle positivo.

## Embedded context

### Requirements

- REQ-02: reconstrução automática com aviso em stderr; `status` atual/defasado/ausente.
- REQ-04: primeira linha `modo: ...`; `--json` objeto único com `mode`, `mode_reason`, `rebuilt`, pesos, links, rerank, results; trecho neutralizado ≤ 240; default 8, `--top` 1..50.
- REQ-08: erros de uso com exit != 0 e mensagem de uso; `--lexical` não carrega o runtime.
- REQ-09 (lexical) e NFR-03: nenhum subcomando acessa a rede; só `git rev-parse`; zero-dep do caminho lexical.
- REQ-11: `kb.sh eval` (bm25, lexical, semântico quando houver), métricas por documento, consulta sem relevante é erro, aviso de fragmento largo, calibração e holdout cópias literais da evidência.

### Design

> §2.2/§2.2.1 (raízes, canais de saída, formato `--json`), §2.4 (regravação da impressão rápida), §2.11 (eval e erros de uso).

## Tasks

- [X] TASK-04 — `kb.sh` e `kb-cli.mjs` (paths: `template/.forge/scripts/kb.sh`, `template/.forge/scripts/lib/kb-cli.mjs`, `template/.forge/scripts/lib/untrusted-render.mjs`, `tests/w287-kb-cli-gate.sh`; depende: TASK-02, TASK-03)
- [X] TASK-05 — `kb.sh eval`, conjunto de avaliação e guardas lexicais (paths: `template/.forge/scripts/lib/kb-cli.mjs`, `tests/fixtures/kb/{semantic-env.sh,serve.mjs,no-network.cjs,net-canary.mjs,fake-git.sh}`, `tests/w289-kb-eval-gate.sh`, `tests/w288-kb-offline-lexical-gate.sh`; depende: TASK-04)

## Acceptance criteria

- [ ] `w287`, `w288` e `w289` passam numa raiz em `/tmp` sem `node_modules` acima; vermelho de cada task provado.
