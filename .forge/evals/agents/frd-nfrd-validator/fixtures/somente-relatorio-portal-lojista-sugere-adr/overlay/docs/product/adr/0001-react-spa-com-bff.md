# 0001 — SPA React com BFF

- **Status:** Aceito
- **Data:** 2026-08-30

## Contexto

O portal precisa de uma camada que agregue APIs internas sem expô-las ao navegador.

## Decisão

SPA React servida por um BFF que expõe REST ao navegador e fala gRPC com os serviços internos.
