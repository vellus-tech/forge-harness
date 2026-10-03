# ADR-0003 — gRPC entre serviços internos, REST para terceiros

- Status: Aceito
- Data: 2026-04-01

## Decisão

Comunicação síncrona interna entre serviços é gRPC com contrato `.proto` versionado no serviço dono. Superfície para terceiros (apps, parceiros, adquirentes) é sempre REST com OpenAPI 3.1; nunca expor gRPC a terceiros.
