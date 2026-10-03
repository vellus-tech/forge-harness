# Simulação de dispatch para o Jira (não executado)

Esta execução é um caso de eval `without_skill` rodando em ambiente restrito: nenhuma escrita externa foi realizada (regra do harness). O que segue é o que seria enviado ao projeto Scrum **PLD** via MCP Jira/Atlassian, caso a chamada real fosse autorizada.

## Épicos

| Epic | Resumo |
|---|---|
| Épico 1 | Carteira do Passageiro (card-wallet) |
| Épico 2 | Validação de Embarque (fare-validation) |

## Stories (com subtarefas técnicas mapeadas das TASK-xx)

| Story | Epic | Story points | Subtarefas (TASK de origem) |
|---|---|---|---|
| CW-1 — Scaffold da solução, schema `wallet` e outbox | Épico 1 | 5 | TASK-01, TASK-02 |
| CW-2 — Criar carteira vinculada ao CPF (RF-001) | Épico 1 | 5 | TASK-03 |
| CW-3 — Recarga via Pix (RF-002) | Épico 1 | 8 | TASK-04, TASK-05 |
| CW-4 — Consultar saldo e extrato (RF-003) | Épico 1 | 3 | TASK-06 |
| CW-5 — Testes de integração do fluxo de recarga | Épico 1 | 5 | TASK-07 |
| FV-1 — Scaffold do worker e schema `validation` | Épico 2 | 5 | TASK-01 |
| FV-2 — Cadastro de dispositivo e mTLS (RF-004) | Épico 2 | 5 | TASK-02 |
| FV-3 — Ingestão de lote idempotente (RF-004) | Épico 2 | 5 | TASK-03 |
| FV-4 — Cálculo de tarifa com integração temporal (RF-005) | Épico 2 | 8 | TASK-04 |
| FV-5 — Consumidor de `WalletDebited` (RF-005) | Épico 2 | 3 | TASK-05 |
| FV-6 — Consulta de embarques no backoffice (RF-006) | Épico 2 | 3 | TASK-06 |
| FV-7 — Painel de latência de sincronização | Épico 2 | 3 | TASK-07 |

Total: 12 stories, 58 pontos, mapeadas para as 14 TASK-xx dos dois módulos (todas usadas, nenhuma órfã).

## Links de dependência (Jira "is blocked by")

- CW-2 blocked by CW-1; CW-3 blocked by CW-2; CW-4 blocked by CW-2; CW-5 blocked by CW-3.
- FV-1 blocked by CW-1; FV-2 blocked by FV-1; FV-3 blocked by FV-2; FV-4 blocked by FV-3 e por CW-3; FV-5 blocked by FV-4; FV-6 blocked by FV-3; FV-7 blocked by FV-3.

## Sprints (Jira Scrum board do projeto PLD)

| Sprint | Início | Fim | Stories incluídas | Pontos |
|---|---|---|---|---|
| Sprint 1 | 2026-10-05 | 2026-10-16 | CW-1, CW-2, CW-3, FV-1 | 23 |
| Sprint 2 | 2026-10-19 | 2026-10-30 | CW-4, CW-5, FV-2, FV-3, FV-6 | 21 |
| Sprint 3 | 2026-11-02 | 2026-11-13 | FV-4, FV-5, FV-7 | 14 |

## Pré-condição não verificada

A tarefa afirma que o projeto Scrum **PLD** já existe no Jira. Nesta execução restrita não houve chamada real ao Jira (nem de leitura, nem de escrita) para confirmar isso — em uma execução real, o primeiro passo antes de criar qualquer épico/story seria confirmar a existência e a configuração (board Scrum, campo de story points habilitado) do projeto PLD via `mcp__jira__*`, e só then disparar as criações acima em lote.
