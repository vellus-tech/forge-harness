# Runbook — payment

## Variáveis de ambiente

| Variável | Descrição |
|---|---|
| `PAYMENT_DB` | Connection string do PostgreSQL do serviço. |
| `LEDGER_DB` | Connection string de leitura do banco do ledger. |
| `PAYMENT_ACQUIRER_TIMEOUT_MS` | Timeout, em milissegundos, da chamada ao adquirente de cartão. Default `3000`. |

O timeout da chamada ao adquirente é configurável via `PAYMENT_ACQUIRER_TIMEOUT_MS`.
