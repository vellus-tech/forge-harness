---
story_id: STORY-01
epic: add-liaison-native-bridge
title: "Paridade de envelope cross-session e compatibilidade v0.18.0"
depends_on: []
status: done
---

# STORY-01 — Paridade de envelope cross-session e compatibilidade v0.18.0

> Story derivada de `add-liaison-native-bridge`. O design aprovado (`design.md`) é a especificação de referência; as seções citadas abaixo são as que esta story implementa.

## Goal

Entregar, em TDD vermelho → verde, paridade de envelope cross-session e compatibilidade v0.18.0, conforme as tasks abaixo.

## Embedded context

### Requirements

- REQ-02: ver `requirements.md#req-02`

### Design

> design.md §4.1, §4.2. Regras de operação dos pares vermelho → verde no preâmbulo de `tasks.md`.

### Rules aplicáveis

- `.forge/rules/testing/regression-red-first.md` — vermelho antes do verde, commit do verde filho direto do vermelho
- `.forge/rules/conventions/liaison-untrusted-input.md` — dado de peer e de transcript é não confiável

## Tasks

- [ ] TASK-01 — Gate vermelho de paridade de envelope e compatibilidade com peer v0.18.0 (tag ausente → FAIL "não verificável") (paths: `tests/liaison-envelope-parity-gate.sh`; depende: —)
- [ ] TASK-02 — Schema e `validateEnvelope` aceitam `via: cross-session` e `cross_session` com as mesmas regras (paths: `template/.forge/schemas/liaison-message.schema.json`, `template/.forge/scripts/lib/liaison-merge.mjs`; depende: TASK-01)

## Acceptance criteria

- [ ] ``bash tests/liaison-envelope-parity-gate.sh`` verde; no vermelho falhava com ``FAIL \[[0-9]+\].*(via|cross_session|cross-session)``
- [ ] ``bash tests/liaison-envelope-parity-gate.sh && bash tests/w197-normative-text-parity-gate.sh`` verde; no vermelho falhava com ``FAIL \[[0-9]+\].*(via|cross_session|cross-session)``
- [ ] Nenhum achado de gate aberto
- [ ] Commit atômico por task; nenhum `TODO`/`FIXME` residual

## Out of scope

- Qualquer item de outra story; fixar o ordinal `wNNN` dos gates novos (decidido no merge).
