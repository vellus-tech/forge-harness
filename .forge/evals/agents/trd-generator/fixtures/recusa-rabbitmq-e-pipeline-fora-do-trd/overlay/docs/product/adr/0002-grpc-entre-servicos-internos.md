# ADR-0002 - gRPC entre serviços internos

**Status:** Aceito | **Data:** 2026-08-20

## Decisão

A comunicação síncrona entre serviços internos usa gRPC com contratos `.proto` versionados; o serviço dono do contrato é a fonte da verdade. mTLS obrigatório na malha interna.
