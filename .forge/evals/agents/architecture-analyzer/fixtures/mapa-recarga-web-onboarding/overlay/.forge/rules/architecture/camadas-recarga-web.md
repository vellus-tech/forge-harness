---
title: Camadas do recarga-web
applies_to:
  - backend-node
priority: high
last_reviewed: 2026-08-10
---

# Camadas do recarga-web

Direção permitida das dependências (de fora para dentro): `src/api` → `src/application` → `src/domain`; `src/infrastructure` → `src/application`, `src/domain`. `src/shared` (logger) pode ser importado por qualquer camada, exceto `src/domain`.

Proibido:

1. `src/domain` importar `src/infrastructure`, `src/api` ou `src/application`.
2. `src/application` importar `src/api` ou `src/infrastructure` (use portas definidas no domínio).

Exceção aprovada (ADR-0003, 2026-06): `src/domain` PODE importar tipos de `src/contracts/eventos-*.ts`, porque os eventos publicados são o contrato público do agregado. Isso não é violação.
