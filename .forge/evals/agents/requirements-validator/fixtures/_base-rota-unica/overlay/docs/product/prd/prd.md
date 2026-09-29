# PRD — Rota Única (bilhetagem metropolitana)

Versão 2.1.0 · Status: Aprovado · 2026-08-02

## Visão

A Rota Única é a plataforma de bilhetagem do consórcio metropolitano que atende três operadoras de ônibus (Viação Leste, TransNorte e Expresso Sul). O passageiro usa um cartão NFC ou QR Code no validador embarcado; o saldo fica numa carteira pré-paga recarregada por Pix.

## Objetivos

- OBJ-01: Débito de tarifa no embarque em menos de 300 ms ponta a ponta no validador.
- OBJ-02: Integração temporal de 90 minutos entre linhas do mesmo consórcio.
- OBJ-03: Bloqueio imediato de cartão perdido ou roubado pelo app.
- OBJ-04: Isolamento de dados entre as operadoras do consórcio (cada operadora é um tenant).

## Módulos

| Sigla | Módulo | Responsabilidade |
|-------|--------|------------------|
| CRT | Carteira | Saldo pré-pago, créditos e débitos |
| TRF | Tarifação | Regras de tarifa por linha, integração temporal |
| VAL | Validação | Decisão de embarque no validador |
| RCG | Recarga | Recarga via Pix |

## Fora de escopo

Bilhete magnético, gratuidade estudantil (fase 2).
