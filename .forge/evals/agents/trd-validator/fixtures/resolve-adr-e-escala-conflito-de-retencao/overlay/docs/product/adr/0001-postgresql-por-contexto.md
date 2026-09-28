# ADR-0001 - PostgreSQL com um banco por bounded context

**Status:** Aceito · **Data:** 2026-06-02

## Decisão

Cada bounded context tem seu próprio banco PostgreSQL; nenhum serviço lê ou escreve no banco de outro contexto. Consumo de dados alheios somente por API ou evento.
