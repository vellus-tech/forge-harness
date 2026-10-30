---
story_id: STORY-04
epic: add-liaison-native-bridge
title: "Leitores de transcript, registro de sessões e workspace"
depends_on: [STORY-03]
status: todo
---

# STORY-04 — Leitores de transcript, registro de sessões e workspace

> Story derivada de `add-liaison-native-bridge`. O design aprovado (`design.md`) é a especificação de referência; as seções citadas abaixo são as que esta story implementa.

## Goal

Entregar, em TDD vermelho → verde, leitores de transcript, registro de sessões e workspace, conforme as tasks abaixo.

## Embedded context

### Requirements

- REQ-02: ver `requirements.md#req-02`
- REQ-07: ver `requirements.md#req-07`
- REQ-08: ver `requirements.md#req-08`

### Design

> design.md §2.2, §2.5 (resolução e raiz de workspace), §2.6 (leitor). Regras de operação dos pares vermelho → verde no preâmbulo de `tasks.md`.

### Rules aplicáveis

- `.forge/rules/testing/regression-red-first.md` — vermelho antes do verde, commit do verde filho direto do vermelho
- `.forge/rules/conventions/liaison-untrusted-input.md` — dado de peer e de transcript é não confiável

## Tasks

- [ ] TASK-06 — Gate vermelho dos leitores. Transcript: recepção pela tag com `from` `uds:` e `origin` só como conferência (design §2.6), fingerprints fixos da evidência b, controle embutido, candidata sem extração = instrumento quebrado, linha `api-request-shape` sozinha = nada pendente, controles negativos medidos (`origin.kind` `human`/`task-notification`/`coordinator`, `turnOrigin: "scheduled"`, `<agent-message>` com `origin.kind: "peer"`, turno humano que só cita a tag) = nada pendente, recepção sem `origin.body` extraída, formatos derivados, divergência tag × `origin` = instrumento quebrado. Registro: vivo/morto (pid e socket), ilegível, sem campo, homônimo, resolução por nome, por socket e por `sessionId` (registro da própria sessão), `/tmp` vs `/private/tmp`. Workspace: raiz (aninhado, worktree fora da árvore, home como repositório, fora de repositório), identidade (dois clones com `insteadOf`, forma scp, credencial, porta, sem remote) (paths: `tests/native-readers-gate.sh`; depende: TASK-05)
- [ ] TASK-07 — `native-transcript.mjs`, `native-registry.mjs` e `native-workspace.mjs` (paths: `template/.forge/scripts/lib/native-transcript.mjs`, `template/.forge/scripts/lib/native-registry.mjs`, `template/.forge/scripts/lib/native-workspace.mjs`; depende: TASK-06)

## Acceptance criteria

- [ ] ``bash tests/native-readers-gate.sh`` verde; no vermelho falhava com ``FAIL \[[0-9]+\].*(transcript|registry|workspace)``
- [ ] ``bash tests/native-readers-gate.sh`` verde; no vermelho falhava com ``FAIL \[[0-9]+\].*(transcript|registry|workspace)``
- [ ] Nenhum achado de gate aberto
- [ ] Commit atômico por task; nenhum `TODO`/`FIXME` residual

## Out of scope

- Qualquer item de outra story; fixar o ordinal `wNNN` dos gates novos (decidido no merge).
