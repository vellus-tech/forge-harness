---
story_id: STORY-08
epic: add-liaison-native-bridge
title: "Gancho de saída: classificação de destino e segredo"
depends_on: [STORY-03, STORY-04, STORY-07]
status: todo
---

# STORY-08 — Gancho de saída: classificação de destino e segredo

> Story derivada de `add-liaison-native-bridge`. O design aprovado (`design.md`) é a especificação de referência; as seções citadas abaixo são as que esta story implementa.

## Goal

Entregar, em TDD vermelho → verde, gancho de saída: classificação de destino e segredo, conforme as tasks abaixo.

## Embedded context

### Requirements

- NFR-02: ver `requirements.md#nfr-02`
- REQ-04: ver `requirements.md#req-04`
- REQ-05: ver `requirements.md#req-05`

### Design

> design.md §2.5 etapas 1 a 4. Regras de operação dos pares vermelho → verde no preâmbulo de `tasks.md`.

### Rules aplicáveis

- `.forge/rules/testing/regression-red-first.md` — vermelho antes do verde, commit do verde filho direto do vermelho
- `.forge/rules/conventions/liaison-untrusted-input.md` — dado de peer e de transcript é não confiável

## Tasks

- [ ] TASK-14 — Gate vermelho do gancho de saída, parte 1 (classificação e segredo): os payloads da evidência a com os vereditos do REQ-05 (`main`, agentId, nome com registro único, `uds:`, só aviso de ociosidade, `[ref]`, nome sem registro com e sem `Agent` nomeado no transcript, nome de sessão igual a `Agent` nomeado, `*`/vírgula/quebra de linha, `recipient_kind` desconhecido); cada família de `SECRET_PATTERNS` → exit 2 sem eco; segredo em campo aninhado e em array; payload vazio, malformado e sem corpo → exit 2; teste de leitor único que altera um padrão de `secret-scan.mjs` e vê `send` e gancho mudarem juntos. Para destino de sessão com corpo limpo, o gate observa a classificação por uma saída que não depende das etapas 5 e 6 (a função de classificação exportada pelo módulo, ou o mesmo payload com segredo dando exit 2 pelo segredo), porque o exit final desses casos muda quando a TASK-17 entra (paths: `tests/native-send-guard-gate.sh`; depende: TASK-05, TASK-07, TASK-13)
- [ ] TASK-15 — `native-send-guard.mjs` (etapas 1 a 4) e `hooks/pre-tool-use/guard-cross-session-send.sh`; o estado intermediário (destino de sessão sem contenção nem destino declarado) nunca é fiado nem publicado, porque a linha do manifesto só entra na TASK-19 e a branch não é publicada antes do fim do change (paths: `template/.forge/scripts/lib/native-send-guard.mjs`, `template/.forge/hooks/pre-tool-use/guard-cross-session-send.sh`; depende: TASK-14)

## Acceptance criteria

- [ ] ``bash tests/native-send-guard-gate.sh`` verde; no vermelho falhava com ``FAIL \[[0-9]+\].*(guard|gancho|recipient|secret)``
- [ ] ``bash tests/native-send-guard-gate.sh && bash tests/w113-liaison-enforce-gate.sh`` verde; no vermelho falhava com ``FAIL \[[0-9]+\].*(guard|gancho|recipient|secret)``
- [ ] Nenhum achado de gate aberto
- [ ] Commit atômico por task; nenhum `TODO`/`FIXME` residual

## Out of scope

- Qualquer item de outra story; fixar o ordinal `wNNN` dos gates novos (decidido no merge).
