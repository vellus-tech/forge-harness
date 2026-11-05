---
story_id: STORY-07
epic: fix-graph-query-symbols-fusion
title: Regressão completa, PBT e fechamento do Red SDD
depends_on: [STORY-06]
status: done
---

# STORY-07 — Regressão completa, PBT e fechamento do Red SDD

> Story auto-contida derivada de `fix-graph-query-symbols-fusion`. Toda informação necessária para implementar
> esta story está aqui — sem precisar reler o change completo (§17.1).

## Goal

Consolidar as seis propriedades (P1-P6) já provadas Red→Verde ao longo das stories anteriores num gate formal dedicado (`tests/w345-graph-symbols-property-gate.sh`), confirmar `tests/run-all.sh` 100% verde, e fechar o Red SDD-level aberto na STORY-01 (`/forge:red replay` → `status: observed`).

## Embedded context

### Requirements

- bugfix.md §5.2/§5.3/§5.5 — regressão obrigatória completa (não listar como pendência): w41/w141/w165/graph-symbols/mdl-gen/graph-deps/graph-jvm/graph-govern/w172/w42/w43/w100/check-authz/w133 100% verdes. Fechamento do Red SDD-level: `status: pending` → `status: observed`, ancorado no cenário real `processarPedido` da TASK-01.
- design.md §5 item 2/5 — plano de rollout: `tests/run-all.sh` 100% verde incluindo toda a regressão listada; nenhum gate existente quebra; nenhum rollback especial necessário (symbols.json/.tsv não versionados, regeneram no próximo build).

### Design

- design.md DD-08 — esta task (TASK-14) não tem par vermelho/verde de comportamento próprio: quando `w345-graph-symbols-property-gate.sh` é criado, `graph-query.mjs`/`graph-symbols-extract.mjs` já implementam P1-P6 desde TASK-03/TASK-05/TASK-09 — um `import()` que resolvesse e passasse de cara não seria Red válido. Cada propriedade já foi provada Red→Verde na task correspondente (P2/P4-herança/P5 na TASK-03, P6 na TASK-05, P1/P3/P4-desempate na TASK-09) — esta story só instancia o arquivo dedicado que consolida as seis num único gate formal, com seed fixa (`FORGE_PBT_SEED`) e "teste do teste" (uma propriedade falsa plantada deliberadamente precisa reprovar com contraexemplo minimizado).
- design.md §5 item "fix_files" — antes do replay, executar um NOVO `/forge:red record` para a mesma `test_path`/`test_id`/`failure_pattern`/`base_commit`/`classification`/`reproduces` da TASK-01, substituindo só `fix_files` pela lista completa de paths de produção tocados por TASK-03 a TASK-13. Esse `record` novo reseta `status` para `pending` — o `/forge:red replay` imediatamente seguinte é o passo que fecha `status: observed`.

### Contratos / interfaces

- `evidence/red/red-evidence.json` — campo `fix_files` substituído pela lista completa; `status` transiciona `pending` → `observed` via replay.
- `tests/w345-graph-symbols-property-gate.sh` — novo gate formal, badge `gates-244→245`.

### Rules aplicáveis

- `rules/testing/property-based-testing.md` — consolidação final de P1-P6, incluindo "teste do teste" (padrão w121 [2]: mutação deliberada precisa reprovar com contraexemplo minimizado).
- `rules/testing/regression-red-first.md` — fechamento do Red SDD-level via `/forge:red replay`.

### ADRs

- ADR-0001 — sem impacto; fechamento de processo, não decisão arquitetural nova.

## Tasks

- [ ] TASK-14 — `tests/w345-graph-symbols-property-gate.sh` (P1-P6, `lib/pbt.mjs`, seed fixa) como gate de fechamento consolidado, sem Red próprio; suíte completa `tests/run-all.sh` 100% verde incluindo regressão de `bugfix.md` §5.3; badge `gates-244→245`; `/forge:red replay` da TASK-01 até `status: observed` (paths: `tests/w345-graph-symbols-property-gate.sh` novo, `evidence/red/red-evidence.json`, `README.md` badge `gates-NNN`; depende: TASK-13). Teste: `bash tests/run-all.sh`. Sem par vermelho/verde de comportamento próprio (declaração explícita, mesmo padrão de TASK-02/TASK-13). Regressão obrigatória auto-descoberta por `tests/run-all.sh`: `w41-graph-gate.sh` ([3]/[4]/[7]), `w141-codegraph-layer-map-gate.sh` [2], `w165-codegraph-scan-roots-gate.sh` [3], `graph-symbols-gate.sh`, `mdl-gen-gate.sh`, `graph-deps-gate.sh`, `graph-jvm-gate.sh`, `graph-govern-gate.sh`, `w172-impact-freshness-wiring-gate.sh`, `w42-impact-gate.sh`, `w43-c4-gate.sh`, `w100-spec-delta-pipeline-gate.sh`, `check-authz-gate.sh`, `w133-gitignore-reconcile-gate.sh`. Propriedades consolidadas: P1 completude, P2 sem duplicata, P3 metamórfica, P4 invariância sob permutação (herança+desempate), P5 invariância cosmética, P6 equivalência `.tsv`≡projeção; mais o teste do teste (mutação plantada reprova com contraexemplo minimizado).

## Acceptance criteria

- [ ] `tests/w345-graph-symbols-property-gate.sh` existe, roda P1-P6 com seed fixa (`FORGE_PBT_SEED`), e inclui o "teste do teste" (mutação deliberada reprova).
- [ ] `tests/run-all.sh` 100% verde, incluindo toda a lista de regressão obrigatória de `bugfix.md` §5.3.
- [ ] Badge `gates-NNN` do `README.md` reflete o valor real medido no momento do fechamento (confirma `243 (base) + w344 + w345`).
- [ ] Novo `/forge:red record` para a `test_path`/`test_id` da TASK-01 com `fix_files` completo (todos os paths de produção de TASK-03 a TASK-13 + docs tocados na STORY-06), seguido de `/forge:red replay` que transiciona `status: pending → observed`.
- [ ] O replay reexecuta `tests/fixtures/graph-query-symbols/red-task01/repro.sh` sobre o HEAD desta task e confirma `symbols (1):` com `processarPedido` listado.
- [ ] Nenhum achado de gate aberto; nenhum `TODO`/`FIXME` residual.

## Out of scope

- Qualquer mudança de comportamento de produção além de criar o arquivo de gate `w345` — o comportamento já foi implementado nas stories anteriores.
- Rollback/feature flag — design.md §5 item 5 confirma que não há necessidade (sem estado persistente a limpar).
