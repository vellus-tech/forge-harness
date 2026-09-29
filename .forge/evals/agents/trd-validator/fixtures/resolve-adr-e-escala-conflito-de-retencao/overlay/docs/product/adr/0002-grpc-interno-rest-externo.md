# ADR-0002 - gRPC entre serviços internos, REST na borda externa

**Status:** Aceito · **Data:** 2026-06-09

## Decisão

Comunicação síncrona entre serviços internos usa gRPC com contrato `.proto` versionado, cujo dono é o serviço provedor. Superfície externa (app do passageiro, operadoras, parceiros) é REST ou fila; nenhum serviço gRPC é exposto a terceiros.
