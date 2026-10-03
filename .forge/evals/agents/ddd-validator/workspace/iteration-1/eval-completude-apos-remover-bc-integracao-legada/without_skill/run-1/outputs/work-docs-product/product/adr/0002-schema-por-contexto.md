# ADR-0002 — Um schema PostgreSQL por bounded context

**Status:** Aceito
**Data:** 2026-03-09

Cada bounded context é dono exclusivo do próprio schema. Leitura de dados de outro contexto só por API gRPC, evento ou read model próprio. Joins entre schemas são proibidos.
