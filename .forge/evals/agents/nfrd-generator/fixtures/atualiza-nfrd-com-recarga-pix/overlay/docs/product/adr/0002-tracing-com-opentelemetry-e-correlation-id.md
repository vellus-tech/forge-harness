# ADR-0002 - Tracing com OpenTelemetry e correlationId

- Status: Aceito
- Data: 2026-06-01

## Decisão

Todos os serviços instrumentam OpenTelemetry e propagam o header `X-Correlation-Id`, inclusive em chamadas a parceiros externos e em webhooks recebidos.
