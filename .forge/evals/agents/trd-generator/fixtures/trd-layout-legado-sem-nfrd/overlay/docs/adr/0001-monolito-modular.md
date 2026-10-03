# ADR-0001 - Monólito modular com PostgreSQL

**Status:** Aceito | **Data:** 2026-06-02

## Decisão

O backend da Tarifa Aberta começa como um monólito modular (um deployable, um módulo por contexto) com um único PostgreSQL, com um schema por módulo. A extração de serviços fica para quando houver necessidade medida.
