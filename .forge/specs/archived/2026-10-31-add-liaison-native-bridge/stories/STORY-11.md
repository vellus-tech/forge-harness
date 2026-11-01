---
story_id: STORY-11
epic: add-liaison-native-bridge
title: "Detector fiado em pre-push, doctor, prepare-pr, ship e yolo"
depends_on: [STORY-07, STORY-10]
status: done
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

- [x] TASK-20 — Gate vermelho dos pontos de detecção: pre-push lista as mudanças do intervalo sem bloquear; doctor reporta os quatro tipos, os avisos de cruzamento de participantes e os avisos extras (gancho inativo, `self_identity` ausente, `disableAllHooks`, sobreposição de settings, edição não commitada, cadastro do `HEAD` diferente do upstream); cenário do revisor (recusa do CLI, edição direta + push visível nos três pontos); gate de texto: `prepare-pr.md` e `ship.md` (template e plugin) invocam o detector, e `ship.md` (template e plugin), `yolo-gate.md` e `autonomy-yolo.md` exigem merge humano com mudança de contenção (paths: `tests/native-containment-wiring-gate.sh`; depende: TASK-13, TASK-19)
- [x] TASK-21 — Detector fiado em `hooks/git/pre-push`, `doctor.sh`, `prepare-pr.md`, `ship.md`, `doctor.md`, `yolo-gate.md`, `autonomy-yolo.md` e cópias do plugin (paths: `template/.forge/hooks/git/pre-push`, `template/.forge/scripts/doctor.sh`, `template/.forge/commands/harness/prepare-pr.md`, `template/.forge/commands/git/ship.md`, `template/.forge/commands/harness/doctor.md`, `template/.forge/agents/review/yolo-gate.md`, `template/.forge/rules/conventions/autonomy-yolo.md`, `plugin/forge/commands/`; depende: TASK-20)

## Nota de implementação (divergência aparente, não é desvio de design)

`hook-line-changed` só se mede COM intervalo (`native-containment.mjs`, `detectHookLineChanged`:
"sem intervalo este tipo não se aplica" — TASK-13, já implementado); o doctor roda SEM intervalo
(design §2.7: "o doctor roda sem intervalo"). Por isso o `doctor` nunca reporta
`hook-line-changed` isoladamente — ele cobre `allowlist-changed` (edição não commitada),
`hook-unwired` e `remote-identity-mismatch` no estado atual; `hook-line-changed` é coberto por
`pre-push` e `prepare-pr`/`ship` (que sempre chamam o detector com `--range`). Os quatro tipos,
somados, aparecem nos três pontos (REQ-12: "sendo detectada nos três pontos"), nenhum ponto
isolado precisa reportar os quatro sozinho — leitura literal do design, não reinterpretação.

## Acceptance criteria

- [x] ``bash tests/native-containment-wiring-gate.sh`` verde; no vermelho falhava com ``FAIL \[[0-9]+\].*(pre-push|doctor|prepare-pr|ship|yolo)``
- [x] ``bash tests/native-containment-wiring-gate.sh && bash tests/plugin-sync-gate.sh`` verde; no vermelho falhava com ``FAIL \[[0-9]+\].*(pre-push|doctor|prepare-pr|ship|yolo)``
- [x] Nenhum achado de gate aberto
- [x] Commit atômico por task; nenhum `TODO`/`FIXME` residual

## Out of scope

- Qualquer item de outra story; fixar o ordinal `wNNN` dos gates novos (decidido no merge).
