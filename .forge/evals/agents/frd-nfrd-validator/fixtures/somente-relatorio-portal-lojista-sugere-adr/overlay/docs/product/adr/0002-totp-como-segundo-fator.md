# 0002 — TOTP como segundo fator

- **Status:** Aceito
- **Data:** 2026-09-02

## Contexto

O PRD exige segundo fator para o acesso do lojista.

## Decisão

Segundo fator por TOTP (RFC 6238) em aplicativo autenticador; SMS descartado por risco de SIM swap.
