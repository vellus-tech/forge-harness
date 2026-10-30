---
story_id: STORY-06
epic: add-liaison-native-bridge
title: "Diagnóstico de cobertura native check/dispose e fiação SessionEnd/SessionStart"
depends_on: [STORY-05]
status: todo
---

# STORY-06 — Diagnóstico de cobertura native check/dispose e fiação SessionEnd/SessionStart

> Story derivada de `add-liaison-native-bridge`. O design aprovado (`design.md`) é a especificação de referência; as seções citadas abaixo são as que esta story implementa.

## Goal

Entregar, em TDD vermelho → verde, diagnóstico de cobertura native check/dispose e fiação SessionEnd/SessionStart, conforme as tasks abaixo.

## Embedded context

### Requirements

- REQ-08: ver `requirements.md#req-08`

### Design

> design.md §2.6. Regras de operação dos pares vermelho → verde no preâmbulo de `tasks.md`.

### Rules aplicáveis

- `.forge/rules/testing/regression-red-first.md` — vermelho antes do verde, commit do verde filho direto do vermelho
- `.forge/rules/conventions/liaison-untrusted-input.md` — dado de peer e de transcript é não confiável

## Tasks

- [ ] TASK-10 — Gate vermelho do diagnóstico `native check`/`native dispose` (destinação por registro e por `dispose`, classes, outro workspace e workspace desconhecido, moldura, `--session`/`--transcript`/ambiente e recusa sem sessão, persistência fora da árvore e entrega única com lista curta de relatórios, fiação de `SessionEnd` em `sync-adapters.mjs` e comportamento de `on-session-end.sh` nas quatro combinações de `handoff.auto`/`liaison.auto`, exibição no `on-session-start.sh`) (paths: `tests/native-coverage-gate.sh`; depende: TASK-09)
- [ ] TASK-11 — `native check`, `native dispose`, estado local em `<git-common-dir>/forge-native/`, fiação `SessionEnd` por `handoff.auto` OU `liaison.auto`, `on-session-end.sh` e `on-session-start.sh` (paths: `template/.forge/scripts/liaison-ops.sh`, `template/.forge/scripts/lib/sync-adapters.mjs`, `template/.forge/hooks/session/on-session-end.sh`, `template/.forge/hooks/session/on-session-start.sh`; depende: TASK-10)

## Acceptance criteria

- [ ] ``bash tests/native-coverage-gate.sh`` verde; no vermelho falhava com ``FAIL \[[0-9]+\].*(native check|dispose|SessionEnd|session-start)``
- [ ] ``bash tests/native-coverage-gate.sh && bash tests/w62-handoff-hook-gate.sh && bash tests/w215-hook-wiring-derived-gate.sh`` verde; no vermelho falhava com ``FAIL \[[0-9]+\].*(native check|dispose|SessionEnd|session-start)``
- [ ] Nenhum achado de gate aberto
- [ ] Commit atômico por task; nenhum `TODO`/`FIXME` residual

## Out of scope

- Qualquer item de outra story; fixar o ordinal `wNNN` dos gates novos (decidido no merge).
