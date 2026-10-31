---
story_id: STORY-10
epic: add-liaison-native-bridge
title: "Empacotamento do gancho e passo de armar"
depends_on: [STORY-09]
status: done
---

# STORY-10 — Empacotamento do gancho e passo de armar

> Story derivada de `add-liaison-native-bridge`. O design aprovado (`design.md`) é a especificação de referência; as seções citadas abaixo são as que esta story implementa.

## Goal

Entregar, em TDD vermelho → verde, empacotamento do gancho e passo de armar, conforme as tasks abaixo.

## Embedded context

### Requirements

- NFR-02: ver `requirements.md#nfr-02`
- REQ-10: ver `requirements.md#req-10`

### Design

> design.md §4.4, §5. Regras de operação dos pares vermelho → verde no preâmbulo de `tasks.md`.

### Rules aplicáveis

- `.forge/rules/testing/regression-red-first.md` — vermelho antes do verde, commit do verde filho direto do vermelho
- `.forge/rules/conventions/liaison-untrusted-input.md` — dado de peer e de transcript é não confiável

## Tasks

- [x] TASK-18 — Gate vermelho de empacotamento do gancho: linha do manifesto, fiação derivada sem literal novo em `sync-adapters.mjs`, consumidor com `settings.json` recebe inativo e nomeado, instalação nova recebe armado; passo de armar do §5 num consumidor existente mantém os quatro ganchos atuais fiados (com matcher e contrato efetivos) e arma o novo; manifesto sem marcador com só a linha nova não arma (controle); varredura de imports dos arquivos novos só `node:*`/relativos e `package.json` sem dependência nova (paths: `tests/native-hook-packaging-gate.sh`; depende: TASK-17)
- [x] TASK-19 — Linha do gancho em `hooks.manifest.default` e ajustes nos gates de manifesto existentes (paths: `template/.forge/hooks/pre-tool-use/hooks.manifest.default`; depende: TASK-18)

## Acceptance criteria

- [x] ``bash tests/native-hook-packaging-gate.sh`` verde; no vermelho falhava com ``FAIL \[[0-9]+\].*(manifest|armado|inativo|SendMessage|import)``
- [x] ``bash tests/native-hook-packaging-gate.sh && bash tests/w208-hooks-manifest-esquema-gate.sh && bash tests/w215-hook-wiring-derived-gate.sh`` verde; no vermelho falhava com ``FAIL \[[0-9]+\].*(manifest|armado|inativo|SendMessage|import)``
- [x] Nenhum achado de gate aberto
- [x] Commit atômico por task; nenhum `TODO`/`FIXME` residual

## Out of scope

- Qualquer item de outra story; fixar o ordinal `wNNN` dos gates novos (decidido no merge).
