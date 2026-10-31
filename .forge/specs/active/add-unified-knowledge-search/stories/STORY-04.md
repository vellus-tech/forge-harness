---
story_id: STORY-04
epic: add-unified-knowledge-search
title: Superfície e ADR
depends_on: [STORY-03]
status: todo
---

# STORY-04 — Superfície e ADR

> Story auto-contida derivada de `add-unified-knowledge-search`. Ver também `../epic_context.md`.

## Goal

Expor a busca ao agente e ao operador e registrar a decisão durável: comando `/forge:kb` (com política de cloud e nota sobre alertas de SCA nos pins), remissão no `/forge:query`, `.forge/kb/` no gitignore, linha `info` do doctor pela raiz de estado, plugin regenerado, README (seção, inventário e badge), catálogo de slash commands, e as asserções de conteúdo da ADR 0004 (criada na TASK-06).

## Embedded context

### Requirements

- REQ-10: `/forge:kb` documentado; `/forge:query` cita; `.forge/kb/` no bloco gerenciado; plugin sincronizado; doctor `info`.
- REQ-05 (último critério): doctor não cria `.forge/kb/semantic` (com e sem `FORGE_ROOT`, worktree real).
- REQ-09 (último critério): `kb.md` declara que não há provedor cloud e que um futuro só existiria como opt-in explícito (PCI DSS).

### Design

> §2.9 (superfície, doctor, gitignore, ADR), §2.12.

### ADRs

- ADR 0001 — emendada pela ADR 0004 (padrão opt-in, pins na maquinaria, sem binário nativo, degradação; licença dos dados de treino).

## Tasks

- [ ] TASK-09 — Superfície e ADR (paths: `template/.forge/commands/graph/kb.md`, `template/.forge/commands/graph/query.md`, `installer/gitignore.patch`, `.gitignore`, `template/.forge/scripts/doctor.sh`, `plugin/forge/`, `README.md`, `docs/refer/slash-commands.md`, `tests/w294-kb-surface-gate.sh`; depende: TASK-08)

## Acceptance criteria

- [ ] `w294` passa; `plugin-sync-gate` e `w200-readme-inventory-gate` passam com a contagem nova.
