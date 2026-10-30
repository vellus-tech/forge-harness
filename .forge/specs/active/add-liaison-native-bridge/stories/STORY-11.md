---
story_id: STORY-11
epic: add-liaison-native-bridge
title: "Detector fiado em pre-push, doctor, prepare-pr, ship e yolo"
depends_on: [STORY-07, STORY-10]
status: todo
---

# STORY-11 — Detector fiado em pre-push, doctor, prepare-pr, ship e yolo

> Story derivada de `add-liaison-native-bridge`. O design aprovado (`design.md`) é a especificação de referência; as seções citadas abaixo são as que esta story implementa.

## Goal

Entregar, em TDD vermelho → verde, detector fiado em pre-push, doctor, prepare-pr, ship e yolo, conforme as tasks abaixo.

## Embedded context

### Requirements

- REQ-12: ver `requirements.md#req-12`

### Design

> design.md §2.7 (pontos de chamada e merge humano). Regras de operação dos pares vermelho → verde no preâmbulo de `tasks.md`.

### Rules aplicáveis

- `.forge/rules/testing/regression-red-first.md` — vermelho antes do verde, commit do verde filho direto do vermelho
- `.forge/rules/conventions/liaison-untrusted-input.md` — dado de peer e de transcript é não confiável

## Tasks

- [ ] TASK-20 — Gate vermelho dos pontos de detecção: pre-push lista as mudanças do intervalo sem bloquear; doctor reporta os quatro tipos, os avisos de cruzamento de participantes e os avisos extras (gancho inativo, `self_identity` ausente, `disableAllHooks`, sobreposição de settings, edição não commitada, cadastro do `HEAD` diferente do upstream); cenário do revisor (recusa do CLI, edição direta + push visível nos três pontos); gate de texto: `prepare-pr.md` e `ship.md` (template e plugin) invocam o detector, e `ship.md` (template e plugin), `yolo-gate.md` e `autonomy-yolo.md` exigem merge humano com mudança de contenção (paths: `tests/native-containment-wiring-gate.sh`; depende: TASK-13, TASK-19)
- [ ] TASK-21 — Detector fiado em `hooks/git/pre-push`, `doctor.sh`, `prepare-pr.md`, `ship.md`, `doctor.md`, `yolo-gate.md`, `autonomy-yolo.md` e cópias do plugin (paths: `template/.forge/hooks/git/pre-push`, `template/.forge/scripts/doctor.sh`, `template/.forge/commands/harness/prepare-pr.md`, `template/.forge/commands/git/ship.md`, `template/.forge/commands/harness/doctor.md`, `template/.forge/agents/review/yolo-gate.md`, `template/.forge/rules/conventions/autonomy-yolo.md`, `plugin/forge/commands/`; depende: TASK-20)

## Acceptance criteria

- [ ] ``bash tests/native-containment-wiring-gate.sh`` verde; no vermelho falhava com ``FAIL \[[0-9]+\].*(pre-push|doctor|prepare-pr|ship|yolo)``
- [ ] ``bash tests/native-containment-wiring-gate.sh && bash tests/plugin-sync-gate.sh`` verde; no vermelho falhava com ``FAIL \[[0-9]+\].*(pre-push|doctor|prepare-pr|ship|yolo)``
- [ ] Nenhum achado de gate aberto
- [ ] Commit atômico por task; nenhum `TODO`/`FIXME` residual

## Out of scope

- Qualquer item de outra story; fixar o ordinal `wNNN` dos gates novos (decidido no merge).
