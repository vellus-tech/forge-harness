# Design — bloqueio-cartao-perda-roubo

## Decisões

1. Bloqueio grava em `cartao_bloqueio` e publica `CartaoBloqueado` v1 na exchange `cartoes.eventos` via outbox.
2. A lista de restrição (hotlist) é gerada incrementalmente a cada 2 minutos e assinada com Ed25519 antes da distribuição aos validadores (ADR-0017).
3. Transferência de saldo só após a janela de 72 h de validações offline (REQ-03).

## Contratos

- `POST /v1/cartoes/{id}/bloqueio` (REST externo, app).
- Evento `CartaoBloqueado` v1.
- Arquivo de hotlist `hotlist-delta-<seq>.bin` assinado.
