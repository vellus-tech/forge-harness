# PRD - Axis Validação

**Versão:** v1.2 · **Data:** 2026-08-10

## Objetivos

| Código | Objetivo |
|---|---|
| PRD-01 | Validar o embarque na catraca com cartão EMV aberto (contactless) ou QR Code em menos de 1 segundo percebido pelo passageiro. |
| PRD-02 | Compensar diariamente (D+1) os valores entre as operadoras de ônibus da região metropolitana. |
| PRD-03 | Permitir ao passageiro consultar o extrato das próprias viagens no app. |

## Restrições

- Operação em conformidade com PCI DSS 4.0.1: o PAN nunca é armazenado pela Axis fora do gateway de tokenização.
- Integração temporal de 60 minutos entre linhas (segunda viagem sem cobrança).
