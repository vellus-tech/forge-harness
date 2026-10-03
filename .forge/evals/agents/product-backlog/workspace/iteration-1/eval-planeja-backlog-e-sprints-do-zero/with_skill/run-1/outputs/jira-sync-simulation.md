# Simulação da sincronização com Jira (Fase 4 do agente product-backlog)

Este documento registra, sem executar, a sequência exata de chamadas MCP Atlassian que o agente `product-backlog` dispararia contra o projeto Scrum **PLD** (já existente, conforme o pedido do usuário), na ordem rígida da §7.4 da especificação. Nenhuma chamada de escrita externa foi feita nesta execução — regra do ambiente de avaliação. Markdown já está completo e estável em `docs/product/backlog/`, satisfazendo a pré-condição "markdown primeiro" antes de qualquer escrita no Jira.

## 1. Autenticação e descoberta

1. `mcp__atlassian__atlassianUserInfo` — confirma sessão autenticada.
2. `mcp__atlassian__getAccessibleAtlassianResources` — captura `cloudId` do site Atlassian do usuário.
3. `mcp__atlassian__getVisibleJiraProjects` — localiza o projeto Scrum com key `PLD` (usuário já informou que existe; não seria criado do zero).
4. `mcp__atlassian__getJiraProjectIssueTypesMetadata` (projeto `PLD`) — confirma tipos de issue disponíveis (Epic, Story, Task, Bug) e seus IDs internos.
5. `mcp__atlassian__getJiraIssueTypeMetaWithFields` para Epic e Story — obtém os IDs dos custom fields `Epic Name`, `Epic Link` e `Story Points` deste projeto (variam entre instância team-managed e company-managed; se houver dúvida, consultar Context7 com `mcp__context7__resolve-library-id` → `"atlassian-jira-cloud-rest-api"`).

## 2. Criação de épicos (2 chamadas)

| Chamada | Summary | Labels | Epic Name |
|---|---|---|---|
| `createJiraIssue` (Epic) | Card Wallet | `module:card-wallet`, `subdomain:supporting`, `lgpd` | Card Wallet |
| `createJiraIssue` (Epic) | Fare Validation | `module:fare-validation`, `subdomain:core` | Fare Validation |

Description de cada épico linka para o `README.md` do módulo correspondente e cita a responsabilidade e o bounded context.

## 3. Criação de user stories (6 chamadas)

| Chamada | Summary | Epic Link | Labels | Story Points |
|---|---|---|---|---|
| `createJiraIssue` (Story) | Como passageiro, quero criar minha carteira informando CPF e cartão, para usar o saldo pré-pago no embarque | Card Wallet | `module:card-wallet`, `rf:RF-001` | 5 |
| `createJiraIssue` (Story) | Como passageiro, quero recarregar minha carteira via Pix, para não depender de ponto de venda físico | Card Wallet | `module:card-wallet`, `rf:RF-002` | 8 |
| `createJiraIssue` (Story) | Como passageiro, quero ver meu saldo e as últimas 30 movimentações, para controlar meus gastos com transporte | Card Wallet | `module:card-wallet`, `rf:RF-003` | 3 |
| `createJiraIssue` (Story) | Como validador embarcado, quero enviar o lote de embarques acumulado offline, para que as tarifas sejam cobradas quando houver conectividade | Fare Validation | `module:fare-validation`, `rf:RF-004` | 8 |
| `createJiraIssue` (Story) | Como passageiro, quero pagar uma única tarifa em embarques feitos em até 60 minutos, para ter integração entre linhas | Fare Validation | `module:fare-validation`, `rf:RF-005` | 8 |
| `createJiraIssue` (Story) | Como operador de backoffice, quero listar os embarques das últimas 24h filtrando por linha e dispositivo, para auditar cobranças contestadas | Fare Validation | `module:fare-validation`, `rf:RF-006` | 3 |

Description de cada story traz os critérios de aceite em Given/When/Then extraídos de `requirements.md`.

## 4. Criação de tasks técnicas (14 chamadas)

`createJiraIssue` (Task) para cada T-001..T-014 listado em `docs/product/backlog/product-backlog.md` §3, com `Epic Link` para o módulo correspondente, `Parent` para a Story quando aplicável (T-003 a T-013, exceto as 4 tasks de infraestrutura pura T-001, T-002, T-008, T-014, que ficam apenas sob o épico) e label `task:TASK-NN` referenciando a TASK de origem no `tasks.md` do módulo.

## 5. Board kanban

`mcp__context7__get-library-docs` (se necessário, para confirmar o endpoint de configuração de board team-managed) seguido de configuração do board do projeto PLD com exatamente 4 colunas: **TO DO** (`To Do`), **IN PROGRESS** (`In Progress`), **IN REVIEW** (`In Review`), **DONE** (`Done`).

## 6. Sprints (3 chamadas + atribuições)

| Sprint | Nome no Jira | Goal | Início | Fim |
|---|---|---|---|---|
| 1 | Sprint 1 — fundação e criação de carteira | Ao final desta sprint, a infraestrutura de wallet-api e validation-sync está no ar e o passageiro consegue criar sua carteira vinculada ao CPF via API | 2026-10-05 | 2026-10-18 |
| 2 | Sprint 2 — recarga Pix, cadastro do validador e auditoria | Ao final desta sprint, o passageiro recarrega via Pix e consulta saldo/extrato, o validador embarcado está cadastrado e autenticado por mTLS, e o backoffice audita embarques | 2026-10-19 | 2026-11-01 |
| 3 | Sprint 3 — integração tarifária e confirmação de débito | Ao final desta sprint, o sistema cobra a tarifa com integração de 60 minutos e confirma o débito na carteira | 2026-11-02 | 2026-11-15 |

Após criar as 3 sprints, atribuir cada Story/Task à sprint indicada na coluna "Sprint" de `product-backlog.md` §2 e §3.

## 7. Atualização final do markdown

Após cada bloco de chamadas bem-sucedido, `product-backlog.md` §5 seria atualizado com as Issue Keys reais (`PLD-1`, `PLD-2`, ...) e `progress-tracking.md` §3 receberia uma linha por operação concluída, movendo o item correspondente de §2 para §3.

## 8. Nota de escopo desta execução

Como esta é uma execução de avaliação sob mandato explícito de não realizar ações externas, nenhuma das chamadas acima foi disparada. `docs/product/backlog/progress-tracking.md` reflete isso em §2 (todas as 6 operações agregadas como pendentes, com o motivo "restrição do ambiente de avaliação", não erro de MCP) e §4 (retomada aponta para este documento como roteiro de execução real).
