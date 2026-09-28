# Resumo — pdf_generated_at em billing-api

## O que foi entregue

- `services/billing-api/db/scripts/0003_add_invoice_pdf_generated_at.sql` — coluna `pdf_generated_at timestamptz NULL` em `invoices`, no mesmo padrão numerado/DbUp de `0001` e `0002`.
- `services/billing-api/src/Endpoints/InvoiceEndpoints.cs` — novo endpoint `GET /invoices/{id}/pdf-status`, que lê `X-Tenant-Id`, consulta `pdf_generated_at` filtrando por `id` e `tenant_id`, e devolve `{ "pdfGeneratedAt": ... }` ou 404 no envelope legado quando a fatura não existe para o tenant.

## Protocolo seguido

Segui o `capability-dispatcher`: li `capabilities.active` em `.forge/forge.yaml` (`backend-dotnet-relational`, `backend-node-postgres`) e, como a área afetada é só C#/.NET relacional, carreguei apenas `PROFILE.md` de `backend-dotnet-relational` — não abri o pack Node, que não se aplica a esta mudança.

O pack .NET sugere, para projetos novos, EF Core migrations e `ProblemDetails` (RFC 7807) para erros HTTP. O código e as ADRs existentes divergem nos dois pontos:

- **ADR-0006** fixa migrations como scripts SQL numerados aplicados por DbUp, com acesso via Dapper, e rejeita explicitamente EF Core.
- **ADR-0004** fixa o envelope de erro legado `{"error":{"code","message"}}` (via `InvoiceEndpoints.Error`), rejeitando `ProblemDetails` até a descontinuação dos apps mobile antigos.

Por regra do protocolo ("se um ADR, baseline, rule ou código existente divergir do pack, registre a divergência e siga a fonte de maior precedência; não refatore para o pack automaticamente"), a decisão foi: script SQL simples (não EF Core migration) e reuso do helper `Error()` existente (não `ProblemDetails`) na nova rota. Nenhuma refatoração do padrão existente foi feita.

Também apliquei `rules/data/schema-evolution.md`: a mudança é puramente **expand** — coluna nova, nullable, sem remover nada e sem exigir backfill — então não há passo de migrate/backfill nem de contract a planejar aqui.

## Teste — evidência pendente, não aprovada

`rules/testing/change-test-contract.md` pede, para endpoint com recurso de tenant, teste positivo e teste negativo de autorização/ownership (IDOR). O fixture não contém projeto de teste (`dotnet test`) nem infraestrutura de banco disponível nesta execução, e a tarefa pediu explicitamente para não rodar `dotnet` aqui. Não declaro esse nível de teste como aprovado — registro como pendente: falta um projeto `BillingApi.Tests` com (a) caso positivo — tenant dono lê `pdf_generated_at` corretamente, incluindo o caso `NULL` (PDF ainda não gerado); e (b) caso negativo — mesmo `id` com `X-Tenant-Id` de outro tenant deve responder 404, não vazar existência da fatura.

## Dispatch de subagentes — simulado, não executado

O prompt do harness proibiu spawn real de subagentes nesta execução. Se estivesse livre para orquestrar, teria despachado (registro completo em `outputs/subagent-dispatch.md`):

1. `task-coder` (sonnet) — implementar migration + endpoint (o que fiz eu mesmo aqui, por não poder delegar).
2. `code-evaluator` (opus, effort medium) — revisão crítica do diff contra ADR-0004/ADR-0006 antes de fechar a task.

## Por que não toquei em outra coisa

Não toquei no endpoint `GET /invoices/{id}` existente, no `.csproj`, no `Directory.Build.props`/`.editorconfig` do pack (não materializados neste fixture) nem em nenhum artefato de `.forge/product/current/` — fora do escopo pedido e vedado pelas regras do harness (baseline só é escrito por `/forge:archive`).
