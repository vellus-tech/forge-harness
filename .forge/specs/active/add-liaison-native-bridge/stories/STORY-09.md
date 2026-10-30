---
story_id: STORY-09
epic: add-liaison-native-bridge
title: "Gancho de saída: contenção, origem cruzada, destino declarado e desempenho"
depends_on: [STORY-08]
status: todo
---

# STORY-09 — Gancho de saída: contenção, origem cruzada, destino declarado e desempenho

> Story derivada de `add-liaison-native-bridge`. O design aprovado (`design.md`) é a especificação de referência; as seções citadas abaixo são as que esta story implementa.

## Goal

Entregar, em TDD vermelho → verde, gancho de saída: contenção, origem cruzada, destino declarado e desempenho, conforme as tasks abaixo.

## Embedded context

### Requirements

- NFR-01: ver `requirements.md#nfr-01`
- REQ-06: ver `requirements.md#req-06`
- REQ-07: ver `requirements.md#req-07`

### Design

> design.md §2.5 etapas 5 e 6, resolução no registro, raiz de workspace. Regras de operação dos pares vermelho → verde no preâmbulo de `tasks.md`.

### Rules aplicáveis

- `.forge/rules/testing/regression-red-first.md` — vermelho antes do verde, commit do verde filho direto do vermelho
- `.forge/rules/conventions/liaison-untrusted-input.md` — dado de peer e de transcript é não confiável

## Tasks

- [ ] TASK-16 — Gate vermelho do gancho de saída, parte 2 (contenção e destino declarado) e gate de desempenho: contenção (mesmo repositório, worktree fora da árvore, aninhado, outro workspace com e sem cadastro, cadastro só não commitado, `self_identity` divergente, homônimo, sem registro, registro ilegível, pid morto, `/tmp` vs `/private/tmp`, home como repositório, dois clones com `insteadOf`, caso `forge-harness` → `payments` com exit 2 sem cadastro e exit 0 com cadastro, mensagem sem comando pronto e sem sugerir mexer em manifesto/settings); origem cruzada com o registro da própria sessão (`session_id` do payload com registro cujo workspace difere do `cwd` do payload → exit 2 "origem ambígua"; sem registro próprio → vale o `cwd` do payload); destino declarado (ponteiro válido, inexistente, de peer, não publicado, em worktree, destino não participante verificável e inconclusivo, classes válidas e inválidas, declaração fora da primeira linha, `internal-coordination` no mesmo repositório e entre repositórios, teto de 1024 bytes do texto livre, sem declaração); p95 ≤ 300 ms em 50 execuções por caso do REQ-05 sobre registro de 20 sessões (paths: `tests/native-send-guard-gate.sh`, `tests/native-send-guard-perf-gate.sh`; depende: TASK-15)
- [ ] TASK-17 — Etapas 5 e 6 de `native-send-guard.mjs` (contenção, origem cruzada, destino declarado) e caches por execução (paths: `template/.forge/scripts/lib/native-send-guard.mjs`; depende: TASK-16)

## Acceptance criteria

- [ ] ``bash tests/native-send-guard-gate.sh && bash tests/native-send-guard-perf-gate.sh`` verde; no vermelho falhava com ``FAIL \[[0-9]+\].*(contenção|workspace|ponteiro|ephemeral|origem|p95)``
- [ ] ``bash tests/native-send-guard-gate.sh && bash tests/native-send-guard-perf-gate.sh`` verde; no vermelho falhava com ``FAIL \[[0-9]+\].*(contenção|workspace|ponteiro|ephemeral|origem|p95)``
- [ ] Nenhum achado de gate aberto
- [ ] Commit atômico por task; nenhum `TODO`/`FIXME` residual

## Out of scope

- Qualquer item de outra story; fixar o ordinal `wNNN` dos gates novos (decidido no merge).
