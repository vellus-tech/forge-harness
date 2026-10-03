# Tasks — módulo recargas

- [X] **TASK-01** — Migration 001 e repositório de leitura (REQ-01).
- [X] **TASK-02** — `GET /recargas/:cartaoId` com paginação por `limit` (REQ-01).
- [X] **TASK-03** — Componente `HistoricoRecargas` (REQ-01).
- [ ] **TASK-04** — Recarga avulsa ponta a ponta (REQ-02, REQ-03, REQ-04; DD-001..DD-004): contrato OpenAPI do `POST /recargas`; nova migration com `idempotency_key` único; rota + repositório com validação de faixa (100 a 50000 centavos) e idempotência; componente `NovaRecargaForm` no portal usando o client tipado, com estados de envio, erro e sucesso. TDD-first.
