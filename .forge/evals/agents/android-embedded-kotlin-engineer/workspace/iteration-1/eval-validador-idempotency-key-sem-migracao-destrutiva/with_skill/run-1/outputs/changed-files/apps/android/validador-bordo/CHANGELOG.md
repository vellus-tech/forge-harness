# Changelog

## [Não publicado]

### Adicionado

- `idempotency_key` em `validation_event` (migration 3→4), enviado no payload de `ValidationSyncWorker` conforme contrato `validation-sync/v2` (REQ-SYNC-07). Eventos existentes são migrados com `idempotency_key = event_id`; a fila `PENDING` é preservada (REQ-SYNC-03) — nenhuma migração destrutiva.

## [2.3.0] - 2026-08-12

### Adicionado

- `retry_count` em `validation_event` (migration 2→3).
