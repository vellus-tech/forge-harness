## Resumo

Recarga do cartão de transporte via Pix dinâmico: cobrança com txid único, webhook do PSP
idempotente (PBT-02), crédito só após confirmação e expiração em 30 minutos.

## Escopo (onda 2)

- TASK-05 — Gerar cobrança Pix dinâmica com txid único
- TASK-06 — Webhook de confirmação do PSP idempotente por txid (Req 2.2, PBT-02)
- TASK-07 — Creditar saldo após confirmação
- TASK-08 — Expirar cobrança após 30 minutos

## Ajuste desta rodada (pedido do code-evaluator)

O code-evaluator apontou que o webhook do PSP aceitava requisições sem validar a assinatura.
Correção aplicada no commit `142544b`:

- Novo arquivo `services/recarga/pix/assinatura.go` com `AssinaturaValida(cabecalho string) bool`.
- O handler do webhook (TASK-06) passa a rejeitar qualquer chamada cujo cabeçalho de assinatura
  não atenda ao formato esperado, antes de processar o payload ou tocar em idempotência por
  `txid`.

## Como testar

1. Enviar webhook simulado do PSP sem o cabeçalho de assinatura → esperar rejeição (4xx).
2. Enviar webhook com assinatura válida e `txid` já processado → esperar idempotência (sem
   novo crédito).
3. Enviar webhook com assinatura válida e `txid` novo → esperar crédito único no saldo do
   cartão.

## Pendências conhecidas

- Sync do Jira (REC-21..REC-24 → `In Review`) segue falhando nesta rodada: MCP do Atlassian não
  disponível no ambiente. Retry documentado em `docs/product/modules/recarga/PROGRESS-TRACKING.md`.
- Após aprovação (`APPROVED` do code-evaluator) e merge, o próximo passo automático é
  `/forge:deploy-wave recarga dev`.
