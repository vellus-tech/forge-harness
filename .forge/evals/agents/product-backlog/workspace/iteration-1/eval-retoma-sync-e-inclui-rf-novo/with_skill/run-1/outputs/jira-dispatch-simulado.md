# Despacho Jira simulado — não executado

Este run não teve acesso a um MCP Atlassian real (as tools `mcp__atlassian__*` que o agente `product-backlog` declara não estavam disponíveis neste ambiente de eval, e a regra do harness proíbe qualquer ação externa real). Nenhuma chamada abaixo foi de fato enviada ao Jira. Este arquivo registra exatamente o que o agente executaria, na ordem da Fase 4 (§7.4) da especificação, para colocar a sync em dia.

## Ordem de execução real (quando o MCP estiver disponível)

1. `mcp__atlassian__atlassianUserInfo` — confirmar autenticação.
2. `mcp__atlassian__getAccessibleAtlassianResources` — capturar `cloudId`.
3. `mcp__atlassian__getVisibleJiraProjects` — confirmar que o projeto Scrum `PLD` ainda existe (reutilizar, não recriar — já usado em EP-001/US-001..003).
4. Retry do épico que falhou por rate limit (idempotência: `product-backlog.md §5` não tem Issue Key para EP-002 — está seguro recriar):

   ```
   mcp__atlassian__createJiraIssue
   projectKey: PLD
   issuetype: Epic
   summary: "Fare Validation"
   description: "Link: docs/product/modules/fare-validation/README.md — validação embarcada de tarifas, ingestão de lotes offline, integração temporal de 60 minutos. Bounded context: fare-validation (Core)."
   labels: ["module:fare-validation", "subdomain:core"]
   customField Epic Name: "Fare Validation"
   ```
   Resultado esperado se aplicado com sucesso: nova Issue Key (ex.: `PLD-5`) — **só gravar em `product-backlog.md §5` após confirmação real do MCP**, nunca antes.

5. Para cada story de fare-validation (dependem do Epic Link acima), uma chamada `createJiraIssue` (issuetype: Story) por US-004, US-005, US-006, com `Epic Link` apontando para a Issue Key do passo 4, `labels: ["module:fare-validation", "rf:RF-00N"]` e Story Points conforme `product-backlog.md §2` (8, 8, 3).

6. Story nova incluída pelo PO nesta sessão (RF-007 / US-007, card-wallet):

   ```
   mcp__atlassian__createJiraIssue
   projectKey: PLD
   issuetype: Story
   summary: "Como passageiro, quero bloquear meu cartão perdido pelo app, para que ninguém use meu saldo"
   description: "Critérios (Given/When/Then): (1) carteira ativa + POST /api/v1/wallets/{id}/block → cartão BLOCKED, débitos recusados com CARD_BLOCKED; (2) cartão bloqueado + vínculo de cartão novo → saldo transferido integralmente. Link: docs/product/modules/card-wallet/requirements.md#rf-007"
   epicLink: PLD-1
   labels: ["module:card-wallet", "rf:RF-007"]
   storyPoints: 5
   ```
   Não requer Task Jira separada — TASK-08 em `tasks.md` é a implementação da própria story (mesmo padrão já usado para TASK-03..06: feature ligada a RF vira Story, não Task).

7. Após confirmação de todas as Issue Keys acima, atualizar `product-backlog.md §5` (mapeamento Local ↔ Jira) com os keys reais e o timestamp real da chamada — não os valores hipotéticos deste arquivo.
8. Registrar cada resultado (sucesso ou nova falha) em `docs/product/backlog/progress-tracking.md §3`, e se algo falhar novamente, manter/atualizar §2.

## Por que nada foi escrito em `product-backlog.md §5` nesta execução

A tabela de mapeamento Local ↔ Jira é a fonte auditável de "o que está realmente sincronizado". Preenchê-la com Issue Keys inventados corromperia essa fonte para qualquer execução futura que a leia para decidir idempotência (§8.2 da especificação: "se já existe Issue Key, não recrie"). Por isso EP-002, US-004, US-005, US-006 e US-007 permanecem sem entrada em §5 — continuam corretamente listados como pendência em `progress-tracking.md §2`, e serão sincronizados na próxima execução real com o MCP Atlassian disponível.
