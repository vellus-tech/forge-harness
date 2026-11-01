---
story_id: STORY-02
epic: add-liaison-native-bridge
title: "Checagem [10] do w113 contra invocação e conexão de sessão"
depends_on: []
status: done
---

# STORY-02 — Checagem [10] do w113 contra invocação e conexão de sessão

> Story derivada de `add-liaison-native-bridge`. O design aprovado (`design.md`) é a especificação de referência; as seções citadas abaixo são as que esta story implementa.

## Goal

Entregar, em TDD vermelho → verde, checagem [10] do w113 contra invocação e conexão de sessão, conforme as tasks abaixo.

## Embedded context

### Requirements

- REQ-01: ver `requirements.md#req-01`

### Design

> design.md §2.3. Regras de operação dos pares vermelho → verde no preâmbulo de `tasks.md`.

### Rules aplicáveis

- `.forge/rules/testing/regression-red-first.md` — vermelho antes do verde, commit do verde filho direto do vermelho
- `.forge/rules/conventions/liaison-untrusted-input.md` — dado de peer e de transcript é não confiável

## Tasks

- [ ] TASK-03 — Checagem [10] do `w113` estendida com os padrões proibidos de conexão e invocação de sessão do REQ-01, com fixture que contém cada padrão (precisa reprovar) e controle sobre a árvore real (precisa passar), sem casar `messagingSocketPath` (paths: `tests/w113-liaison-enforce-gate.sh`; depende: —)

## Acceptance criteria

- [ ] ``bash tests/w113-liaison-enforce-gate.sh`` verde; no vermelho falhava com ``FAIL \[10\]``
- [ ] Nenhum achado de gate aberto
- [ ] Commit atômico por task; nenhum `TODO`/`FIXME` residual

## Out of scope

- Qualquer item de outra story; fixar o ordinal `wNNN` dos gates novos (decidido no merge).
