---
story_id: STORY-12
epic: add-liaison-native-bridge
title: "Normas das rules, itens de ledger e ADR"
depends_on: [STORY-03]
status: done
---

# STORY-12 — Normas das rules, itens de ledger e ADR

> Story derivada de `add-liaison-native-bridge`. O design aprovado (`design.md`) é a especificação de referência; as seções citadas abaixo são as que esta story implementa.

## Goal

Entregar, em TDD vermelho → verde, normas das rules e itens de ledger, conforme as tasks abaixo.

## Embedded context

### Requirements

- REQ-09: ver `requirements.md#req-09`

### Design

> design.md §2.8, §10. Regras de operação dos pares vermelho → verde no preâmbulo de `tasks.md`.

### Rules aplicáveis

- `.forge/rules/testing/regression-red-first.md` — vermelho antes do verde, commit do verde filho direto do vermelho
- `.forge/rules/conventions/liaison-untrusted-input.md` — dado de peer e de transcript é não confiável

## Tasks

- [X] TASK-22 — Gate vermelho das normas: classes da rule = `EPHEMERAL_CLASSES` com mutação dos dois lados; frases normativas obrigatórias do design §2.8; `validate-rules.sh` com `FORGE_ROOT` no template; `last_reviewed` atualizado; itens de ledger com origem no change (configuração gerenciada PCI; medição do formato de agente nomeado; ADR "mensageria nativa é sinalização" sugerida no design §10) (paths: `tests/native-rules-parity-gate.sh`; depende: TASK-05)
- [X] TASK-23 — `liaison-protocol.md` e `liaison-untrusted-input.md` atualizadas e os três itens de ledger abertos (paths: `template/.forge/rules/conventions/liaison-protocol.md`, `template/.forge/rules/conventions/liaison-untrusted-input.md`, `.forge/ledger/`; depende: TASK-22)
- [X] TASK-27 — ADR "Mensageria nativa entre sessões é sinalização; o registro durável é o liaison" no baseline, com índice atualizado e item de ledger resolvido (paths: `.forge/product/current/adr/`, `.forge/ledger/`; depende: TASK-23)

## Acceptance criteria

- [ ] ``bash tests/native-rules-parity-gate.sh`` verde; no vermelho falhava com ``FAIL \[[0-9]+\].*(rule|classes|ledger|last_reviewed)``
- [ ] ``bash tests/native-rules-parity-gate.sh`` verde; no vermelho falhava com ``FAIL \[[0-9]+\].*(rule|classes|ledger|last_reviewed)``
- [ ] ADR presente no índice `.forge/product/current/adr/README.md` e `validate-spec` OK
- [ ] Nenhum achado de gate aberto
- [ ] Commit atômico por task; nenhum `TODO`/`FIXME` residual

## Out of scope

- Qualquer item de outra story; fixar o ordinal `wNNN` dos gates novos (decidido no merge).
