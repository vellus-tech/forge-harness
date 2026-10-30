---
story_id: STORY-03
epic: add-liaison-native-bridge
title: "Ponteiro canônico: notify, resolvePointer e classes efêmeras"
depends_on: []
status: done
---

# STORY-03 — Ponteiro canônico: notify, resolvePointer e classes efêmeras

> Story derivada de `add-liaison-native-bridge`. O design aprovado (`design.md`) é a especificação de referência; as seções citadas abaixo são as que esta story implementa.

## Goal

Entregar, em TDD vermelho → verde, ponteiro canônico: notify, resolvePointer e classes efêmeras, conforme as tasks abaixo.

## Embedded context

### Requirements

- REQ-01: ver `requirements.md#req-01`
- REQ-06: ver `requirements.md#req-06`

### Design

> design.md §2.2, §2.3, §4.5. Regras de operação dos pares vermelho → verde no preâmbulo de `tasks.md`.

### Rules aplicáveis

- `.forge/rules/testing/regression-red-first.md` — vermelho antes do verde, commit do verde filho direto do vermelho
- `.forge/rules/conventions/liaison-untrusted-input.md` — dado de peer e de transcript é não confiável

## Tasks

- [ ] TASK-04 — Gate vermelho do `notify` (ponteiro idêntico ao log, recusas "não existe", "não é mensagem própria", "não publicada" com o `sync`, flags) e da fonte única de classes efêmeras e regex de declaração (paths: `tests/liaison-notify-gate.sh`; depende: —)
- [ ] TASK-05 — `native-classes.mjs`, `liaison-pointer.mjs` (`resolvePointer`), `isPublished` em `liaison-publish.mjs` e subcomando `notify` (paths: `template/.forge/scripts/lib/native-classes.mjs`, `template/.forge/scripts/lib/liaison-pointer.mjs`, `template/.forge/scripts/lib/liaison-publish.mjs`, `template/.forge/scripts/liaison-ops.sh`; depende: TASK-04)

## Acceptance criteria

- [ ] ``bash tests/liaison-notify-gate.sh`` verde; no vermelho falhava com ``FAIL \[[0-9]+\].*(notify|resolvePointer|EPHEMERAL)``
- [ ] ``bash tests/liaison-notify-gate.sh`` verde; no vermelho falhava com ``FAIL \[[0-9]+\].*(notify|resolvePointer|EPHEMERAL)``
- [ ] Nenhum achado de gate aberto
- [ ] Commit atômico por task; nenhum `TODO`/`FIXME` residual

## Out of scope

- Qualquer item de outra story; fixar o ordinal `wNNN` dos gates novos (decidido no merge).
