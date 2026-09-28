# Epic context — bloqueio-cartao-perda-roubo

> Gerado por epic-context agent. Leitura rápida — não substitui os artefatos originais.

## Objetivo

Permitir que o titular bloqueie no app, de forma imediata, o cartão perdido ou roubado e receba o saldo na segunda via, eliminando a espera de 22 minutos no SAC.

## Decisões de design

- Bloqueio grava `cartao_bloqueio` e publica `CartaoBloqueado` via outbox → stories de hotlist e saldo consomem o evento, não o endpoint.
- Hotlist incremental a cada 2 min, assinada com Ed25519 → story de hotlist precisa da chave de assinatura do cofre.
- Transferência de saldo só após janela de 72 h → story de segunda via depende da conciliação offline.

## Contratos externos

- `POST /v1/cartoes/{id}/bloqueio` — bloqueio pelo app com step-up.
- `CartaoBloqueado` v1 — evento na exchange `cartoes.eventos`.
- `hotlist-delta-<seq>.bin` — delta assinado distribuído aos validadores.

## ADRs

- ADR-0017 — Assinatura Ed25519 da hotlist distribuída.

## Rules

- `.forge/rules/architecture/security-and-secrets.md` — chave de assinatura da hotlist vem do cofre.

## Invariantes críticas

- Bloqueio chega aos validadores em até 5 minutos.
- Saldo só é transferido após 72 h do bloqueio.
