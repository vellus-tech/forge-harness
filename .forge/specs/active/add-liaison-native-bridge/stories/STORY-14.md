---
story_id: STORY-14
epic: add-liaison-native-bridge
title: "spec-delta e suíte completa"
depends_on: [STORY-01, STORY-02, STORY-06, STORY-09, STORY-11, STORY-12, STORY-13]
status: todo
---

# STORY-14 — spec-delta e suíte completa

> Story derivada de `add-liaison-native-bridge`. O design aprovado (`design.md`) é a especificação de referência; as seções citadas abaixo são as que esta story implementa.

## Goal

Entregar, em TDD vermelho → verde, spec-delta e suíte completa, conforme as tasks abaixo.

## Embedded context

### Requirements

- NFR-03: ver `requirements.md#nfr-03`
- REQ-01: ver `requirements.md#req-01`
- REQ-12: ver `requirements.md#req-12`

### Design

> design.md §9. Regras de operação dos pares vermelho → verde no preâmbulo de `tasks.md`.

### Rules aplicáveis

- `.forge/rules/testing/regression-red-first.md` — vermelho antes do verde, commit do verde filho direto do vermelho
- `.forge/rules/conventions/liaison-untrusted-input.md` — dado de peer e de transcript é não confiável

## Tasks

- [ ] TASK-26 — `spec-delta.yaml` real do change (requisitos novos da capacidade `forge-harness-template`) e suíte completa verde, rodada sem outro gate em paralelo (paths: `.forge/specs/active/add-liaison-native-bridge/spec-delta.yaml`; depende: TASK-02, TASK-03, TASK-11, TASK-17, TASK-21, TASK-23, TASK-25)

## Acceptance criteria

- [ ] ``FORGE_ROOT="$(pwd)" bash template/.forge/scripts/validate-spec.sh add-liaison-native-bridge && bash tests/run-all.sh`` verde; no vermelho falhava com ``(FAIL|placeholder)``
- [ ] Nenhum achado de gate aberto
- [ ] Commit atômico por task; nenhum `TODO`/`FIXME` residual

## Out of scope

- Qualquer item de outra story; fixar o ordinal `wNNN` dos gates novos (decidido no merge).
