# ADR-0004 — Envelope de erro HTTP legado no billing-api

Status: aceito (2025-03-10)

## Contexto
Os apps mobile de cobrança (versões ainda em campo) fazem parse de `{"error":{"code","message"}}`. Mudar o formato quebra clientes que não atualizamos.

## Decisão
Todo erro HTTP do billing-api usa o envelope `{"error":{"code","message"}}` via `InvoiceEndpoints.Error`. `ProblemDetails` (RFC 7807) foi avaliado e rejeitado até a descontinuação das versões mobile < 5.0.

## Consequências
Endpoints novos seguem o envelope. Migrar para ProblemDetails exige nova ADR.
