# ADR-0103: Conciliação diária por arquivo do adquirente

- **Status:** Aceito
- **Data:** 2026-07-01
- **Autores:** @joana-lima

## Contexto e Problema

Divergências entre autorizações e liquidações só aparecem no extrato.

## Opções Consideradas

1. Conciliação por arquivo EEVC/EEFI diário. Contra: D+1.
2. Conciliação por webhook. Contra: nem todo adquirente oferece.

## Decisão

Arquivo diário.

## Consequências

Negativa: detecção em D+1; mitigação com alerta de divergência acima de 0,5%.

## Conformidade

Job de conciliação roda às 06:00 e publica métrica `conciliacao_divergencia_pct`.
