# Requirements — módulo sync

- REQ-SYNC-03: nenhum evento de validação `PENDING` pode ser descartado localmente antes de confirmado pelo backend (receita tarifária e antifraude dependem dele).
- REQ-SYNC-07: a partir do contrato `validation-sync/v2`, todo evento enviado carrega `idempotency_key` estável por evento; reenvios repetem a chave.
