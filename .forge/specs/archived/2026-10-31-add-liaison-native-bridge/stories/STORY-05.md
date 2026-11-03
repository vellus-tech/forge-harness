---
story_id: STORY-05
epic: add-liaison-native-bridge
title: "Registro de mensagem nativa recebida (send --via cross-session) e recusa C1"
depends_on: [STORY-01, STORY-04]
status: done
---

# STORY-05 — Registro de mensagem nativa recebida (send --via cross-session) e recusa C1

> Story derivada de `add-liaison-native-bridge`. O design aprovado (`design.md`) é a especificação de referência; as seções citadas abaixo são as que esta story implementa.

## Goal

Entregar, em TDD vermelho → verde, registro de mensagem nativa recebida (send --via cross-session) e recusa C1, conforme as tasks abaixo.

## Embedded context

### Requirements

- REQ-02: ver `requirements.md#req-02`
- REQ-03: ver `requirements.md#req-03`

### Design

> design.md §2.4, §4.1. Regras de operação dos pares vermelho → verde no preâmbulo de `tasks.md`.

### Rules aplicáveis

- `.forge/rules/testing/regression-red-first.md` — vermelho antes do verde, commit do verde filho direto do vermelho
- `.forge/rules/conventions/liaison-untrusted-input.md` — dado de peer e de transcript é não confiável

## Tasks

- [X] TASK-08 — Gate vermelho de `send --via cross-session` e da recusa C1 (flags, fingerprint ausente, instrumento quebrado, tetos, caracteres de controle, segredo nos valores extraídos e no corpo, conferência de origem com os casos diverge/não resolve/ok/peer em worktree/pid divergente de `verifiedPeerPid`, hash de `liaison.yaml`/log/blobs/cursor antes e depois, nada criado como efeito colateral, `check-liaison-acks.sh`, `inbox --show` com "origem não verificada", `render`) (paths: `tests/liaison-cross-session-record-gate.sh`; depende: TASK-02, TASK-07)
- [X] TASK-09 — `send` com `--via cross-session`, `--native-ref`, `--session`; recusa C1; conferência de origem; exibição em `inbox --show` e `render` (paths: `template/.forge/scripts/liaison-ops.sh`, `template/.forge/scripts/lib/liaison-render.mjs`; depende: TASK-08)

## Acceptance criteria

- [X] ``bash tests/liaison-cross-session-record-gate.sh`` verde; no vermelho falhava com ``FAIL \[[0-9]+\].*(cross-session|native-ref|C1|origem)``
- [X] ``bash tests/liaison-cross-session-record-gate.sh`` verde; no vermelho falhava com ``FAIL \[[0-9]+\].*(cross-session|native-ref|C1|origem)``
- [X] Nenhum achado de gate aberto
- [X] Commit atômico por task; nenhum `TODO`/`FIXME` residual

## Out of scope

- Qualquer item de outra story; fixar o ordinal `wNNN` dos gates novos (decidido no merge).
