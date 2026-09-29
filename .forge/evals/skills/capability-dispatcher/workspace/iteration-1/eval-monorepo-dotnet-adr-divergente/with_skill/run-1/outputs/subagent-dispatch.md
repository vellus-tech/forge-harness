# Despacho de subagentes (simulado, não executado)

O harness proibiu spawn real de subagentes/Task tool nesta execução. Este arquivo registra o que
seria despachado se a orquestração estivesse livre, conforme instruído.

## 1. task-coder
- Modelo: sonnet
- Prompt resumido: "No services/billing-api, adicionar coluna pdf_generated_at (timestamptz NULL)
  via script SQL numerado seguindo o padrão de 0001/0002 (DbUp, ADR-0006), e endpoint
  GET /invoices/{id}/pdf-status que lê X-Tenant-Id e devolve o timestamp ou 404 no envelope de
  erro legado (ADR-0004) quando a fatura não existe para o tenant. Não usar EF Core nem
  ProblemDetails — ambos divergem de ADR aceita neste repositório."
- Por que não foi despachado de fato: mandato explícito da tarefa para não spawnar; implementação
  feita diretamente por mim nesta sessão.

## 2. code-evaluator
- Modelo: opus, effort medium
- Prompt resumido: "Revisar o diff de services/billing-api (migration 0003 + endpoint
  /invoices/{id}/pdf-status) contra ADR-0004 e ADR-0006: confirmar que não introduz EF Core nem
  ProblemDetails, que a migration é puramente expand (schema-evolution.md), e que a resposta 404
  não vaza existência de fatura de outro tenant (IDOR)."
- Por que não foi despachado de fato: mandato explícito da tarefa para não spawnar.

## Item não coberto por delegação nem por mim
- Teste de integração positivo/negativo do endpoint (change-test-contract.md) — não há projeto de
  teste no fixture nem autorização para rodar dotnet nesta execução. Registrado como pendência em
  outputs/summary.md, não fabricado.
