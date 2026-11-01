---
story_id: STORY-07
epic: add-liaison-native-bridge
title: "Cadastro allow/revoke/pin e detector native containment"
depends_on: [STORY-04]
status: done
---

# STORY-07 — Cadastro allow/revoke/pin e detector native containment

> Story derivada de `add-liaison-native-bridge`. O design aprovado (`design.md`) é a especificação de referência; as seções citadas abaixo são as que esta story implementa.

## Goal

Entregar, em TDD vermelho → verde, cadastro allow/revoke/pin e detector native containment, conforme as tasks abaixo.

## Embedded context

### Requirements

- REQ-12: ver `requirements.md#req-12`

### Design

> design.md §2.7, §4.3. Regras de operação dos pares vermelho → verde no preâmbulo de `tasks.md`.

### Rules aplicáveis

- `.forge/rules/testing/regression-red-first.md` — vermelho antes do verde, commit do verde filho direto do vermelho
- `.forge/rules/conventions/liaison-untrusted-input.md` — dado de peer e de transcript é não confiável

## Tasks

- [X] TASK-12 — Gate vermelho do cadastro e do detector: recusa de `allow`/`revoke`/`pin` por cada marcador e por ancestral `claude` simulado; idempotência, revogação, reativação, formato, `--reason`; cadastro efetivo só commitado; schema; detector `native containment` nos quatro tipos e no caso sem mudança, rc 2 quando não mede; `hook-unwired` pela derivação de `preToolUseWiring` (já exportada em `sync-adapters.mjs`, sem segundo ponto de entrada — achado A-07 do analyze) com controle negativo de consumidor existente semeado inativo (nenhum achado) e por intervalo quando a fiação some do `settings.json` entre as pontas (paths: `tests/native-containment-gate.sh`; depende: TASK-07)
- [X] TASK-13 — `native-allowlist.mjs`, `native-containment.mjs`, schema `liaison-allowed-workspaces.schema.json` e subcomandos `native allow|revoke|pin|containment` (paths: `template/.forge/scripts/lib/native-allowlist.mjs`, `template/.forge/scripts/lib/native-containment.mjs`, `template/.forge/schemas/liaison-allowed-workspaces.schema.json`, `template/.forge/scripts/liaison-ops.sh`; depende: TASK-12)

## Acceptance criteria

- [X] ``bash tests/native-containment-gate.sh`` verde; no vermelho falhava com ``FAIL \[[0-9]+\].*(allow|revoke|pin|containment|hook-unwired)``
- [X] ``bash tests/native-containment-gate.sh && bash tests/w30-schemas-gate.sh && bash tests/w215-hook-wiring-derived-gate.sh`` verde; no vermelho falhava com ``FAIL \[[0-9]+\].*(allow|revoke|pin|containment|hook-unwired)``
- [X] Nenhum achado de gate aberto
- [X] Commit atômico por task; nenhum `TODO`/`FIXME` residual

## Out of scope

- Qualquer item de outra story; fixar o ordinal `wNNN` dos gates novos (decidido no merge).
