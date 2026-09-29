# ADR-0005 — Serialização JSON com System.Text.Json

- Status: Aceito
- Data: 2026-03-10

## Decisão

Todos os serviços .NET serializam e desserializam JSON exclusivamente com System.Text.Json. A dependência Newtonsoft.Json é proibida em qualquer projeto novo ou existente, inclusive em Infrastructure, por divergência de tratamento de decimal e datas nos contratos de evento.
