---
story_id: STORY-13
epic: add-liaison-native-bridge
title: "Documentação operacional"
depends_on: [STORY-11]
status: done
---

# STORY-13 — Documentação operacional

> Story derivada de `add-liaison-native-bridge`. O design aprovado (`design.md`) é a especificação de referência; as seções citadas abaixo são as que esta story implementa.

## Goal

Entregar, em TDD vermelho → verde, documentação operacional, conforme as tasks abaixo.

## Embedded context

### Requirements

- REQ-10: ver `requirements.md#req-10`
- REQ-11: ver `requirements.md#req-11`

### Design

> design.md §4.5, §5. Regras de operação dos pares vermelho → verde no preâmbulo de `tasks.md`.

### Rules aplicáveis

- `.forge/rules/testing/regression-red-first.md` — vermelho antes do verde, commit do verde filho direto do vermelho
- `.forge/rules/conventions/liaison-untrusted-input.md` — dado de peer e de transcript é não confiável

## Tasks

- [X] TASK-24 — Gate vermelho de documentação: `argument-hint` com os subcomandos novos; flags do bloco de protocolo = flags aceitas do script por subcomando novo ou alterado; `send` cross-session sem flags de origem; `slash-commands.md`; `CHANGELOG.md` com o passo de armar; `upgrade.md` template e plugin; ponteiro na primeira linha documentado (paths: `tests/native-docs-gate.sh`; depende: TASK-21)
- [X] TASK-25 — Documentação: `/forge:liaison` (template e plugin), `upgrade.md` (template e plugin), `docs/refer/slash-commands.md`, inventário de gates e scripts, `CHANGELOG.md` `[Unreleased]`, badge do `README.md` (paths: `template/.forge/commands/harness/liaison.md`, `template/.forge/commands/harness/upgrade.md`, `plugin/forge/commands/liaison.md`, `plugin/forge/commands/upgrade.md`, `docs/`, `CHANGELOG.md`, `README.md`; depende: TASK-24)

## Acceptance criteria

- [ ] ``bash tests/native-docs-gate.sh`` verde; no vermelho falhava com ``FAIL \[[0-9]+\].*(argument-hint|flags|CHANGELOG|slash-commands|upgrade)``
- [ ] ``bash tests/native-docs-gate.sh && bash tests/w200-readme-inventory-gate.sh && bash tests/plugin-sync-gate.sh`` verde; no vermelho falhava com ``FAIL \[[0-9]+\].*(argument-hint|flags|CHANGELOG|slash-commands|upgrade)``
- [ ] Nenhum achado de gate aberto
- [ ] Commit atômico por task; nenhum `TODO`/`FIXME` residual

## Out of scope

- Qualquer item de outra story; fixar o ordinal `wNNN` dos gates novos (decidido no merge).
