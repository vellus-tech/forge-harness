---
title: Camadas da tarifação
applies_to:
  - backend-node
priority: high
last_reviewed: 2026-07-22
---

# Camadas da tarifação

Direção permitida: `src/api` → `src/application` → `src/domain`; `src/infrastructure` → `src/domain`.

Proibido:

1. `src/domain` importar qualquer outra camada (`src/infrastructure`, `src/application`, `src/api`).
2. `src/application` importar `src/infrastructure` diretamente — a application depende de uma porta (interface) declarada em `src/domain`, e a implementação é injetada em `src/main.ts`.
