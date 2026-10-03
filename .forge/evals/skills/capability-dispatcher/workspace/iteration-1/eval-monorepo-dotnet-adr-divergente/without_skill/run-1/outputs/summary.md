# Resumo — pdf_generated_at + GET /invoices/{id}/pdf-status

## O que segui e por quê

Explorei `services/billing-api` antes de escrever qualquer código. Encontrei duas ADRs que divergem dos defaults usuais de um pack .NET, e ambas restringem as opções aqui:

- **ADR-0006** (migrations por scripts SQL numerados aplicados via DbUp, acesso a dados por Dapper, EF Core rejeitado). Por isso a nova coluna entrou como script SQL versionado (`0003_add_invoice_pdf_generated_at.sql`, seguindo o padrão `NNNN_<descricao>.sql` de `0001`/`0002`), não como migration do EF Core, e a leitura no endpoint usa Dapper, não um DbContext.
- **ADR-0004** (envelope de erro HTTP legado `{"error":{"code","message"}}` para clientes mobile antigos, `ProblemDetails` rejeitado). Por isso o 404 do novo endpoint reusa `InvoiceEndpoints.Error(...)`, o mesmo helper já usado no `GET /invoices/{id}`, em vez de `Results.Problem`/`ProblemDetails`.

Decisões de implementação:

- Coluna `pdf_generated_at timestamptz NULL` em `invoices` — nullable porque a fatura existe antes do PDF ser gerado; sem coluna nova não há sinal de "ainda não gerado".
- `GET /invoices/{id}/pdf-status` fica no mesmo `InvoiceEndpoints.Map`, ao lado do endpoint existente, mantendo o mesmo padrão de leitura do header `X-Tenant-Id` do `HttpContext` e de filtro por `tenant_id` na query (isolamento multi-tenant já estabelecido pelo endpoint irmão).
- Como a coluna é nullable, `pdf_generated_at IS NULL` sozinho não diferencia "fatura não existe" de "fatura existe mas PDF ainda não foi gerado". Adicionei uma segunda checagem (`EXISTS`) só quando o valor lido é nulo, para decidir entre 404 e `200` com `pdfGeneratedAt: null`. Alternativa descartada: fazer só uma query e tratar "não encontrado" como equivalente a "PDF não gerado" — rejeitei porque a tarefa pede 404 explícito quando a fatura não existe para o tenant, e confundir os dois casos esconderia um bug de tenant/id errado atrás de uma resposta 200.
- Resposta de sucesso é `{"pdfGeneratedAt": <timestamp|null>}` — não achei um contrato de resposta de sucesso pré-existente no fixture para seguir à risca (só o formato de erro está fixado pela ADR-0004), então usei camelCase (padrão ASP.NET minimal API / System.Text.Json default) e um envelope mínimo com o nome do campo pedido.

## O que não fiz

- Não rodei `dotnet build`/`dotnet test` (instrução explícita da tarefa: "não precisa rodar dotnet aqui").
- Não criei/editei `Program.cs` — o fixture não tem esse arquivo; não inventei fiação de composition root que não existia no baseline para não introduzir código não solicitado fora do escopo mostrado.
- Não toquei em `web/checkout` (Node/TS) — fora do escopo pedido (billing-api).
