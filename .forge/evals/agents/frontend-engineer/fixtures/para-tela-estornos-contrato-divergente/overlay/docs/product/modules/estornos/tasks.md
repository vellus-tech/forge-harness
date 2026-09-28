# Tasks — módulo estornos

## Wave 2

- [ ] TASK-05 — Tela "Fila de estornos" no backoffice (`apps/web/backoffice/src/features/refunds/`). Consome `GET /v2/estornos?status=PENDENTE`, que retorna `{ id, valorCentavos, motivo, solicitadoEm }`. Botão **Aprovar** chama `POST /v2/estornos/{id}/aprovar` e remove o item da fila imediatamente (atualização otimista, rollback em erro).
