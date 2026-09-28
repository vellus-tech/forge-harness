# Validação — tasks.md do módulo Carteira (v1.0.0)

- Base validada contra: requirements.md v1.2.0, design.md v0.4.0, ADR-0001, ADR-0002, ADR-0003.
- Veredito: **NÃO executar como está.** Há seis violações — duas de cobertura de requisitos, uma de rastreabilidade, uma de convenção TDD, um ciclo de dependência que impede o planejamento de ondas, e uma violação direta de ADR que, se seguida, quebra branch protection em produção. O tasks-writer precisa corrigir antes de abrir a sprint de segunda-feira.

## Violações encontradas

### 1. PBT-02 (idempotência do crédito) sem TASK — bloqueante
Requirements v1.2.0 define PBT-02: aplicar o mesmo `txid` N vezes credita o valor exatamente uma vez. O design cobre o mecanismo (DD-002: tabela `recarga_processada` com `txid` UNIQUE), mas nenhuma TASK testa a propriedade. TASK-04 (4.1) testa apenas o caminho feliz do webhook — credita e grava outbox — sem cenário de reenvio do mesmo `txid`. A Matriz de Rastreabilidade também não lista PBT-02. Risco: reenvio de webhook do PSP (mencionado nos próprios "Riscos de Execução" do documento) credita em duplicidade sem que nenhum teste pegue a regressão.

### 2. RNF 2 (mascaramento de CPF em logs) sem TASK — bloqueante
Requirements v1.2.0 exige que CPF/e-mail nunca apareçam em claro em log (RNF 2). O design menciona o enricher de mascaramento na seção "Observabilidade e segurança", mas nenhuma TASK implementa ou testa isso, e RNF 2 não aparece na Matriz de Rastreabilidade. É requisito de compliance/PII — não pode ficar implícito em "boa prática de implementação" sem TASK e teste dedicados.

### 3. TASK-06 ausente da tabela "Status Geral" — bloqueante para tracking
A seção "Tarefas" define TASK-06 (Consulta de saldo, Onda 3, mapeia Req 2 e RNF 1) por completo, mas a tabela "Status Geral" no topo do documento lista apenas TASK-01 a TASK-05. Qualquer ferramenta ou pessoa que use essa tabela para abrir a sprint via `/forge:coding-loop` ou distribuição manual vai deixar TASK-06 de fora do board — e Req 2 (consulta de saldo) ficaria sem execução.

### 4. TASK-03 inverte Red e Green — viola a convenção TDD-first do próprio documento
A seção "Convenções de Implementação" declara: "TDD-first: toda TASK com lógica segue Red → Green → Refactor." Em TASK-03, a subtask 3.1 é "Implementar `Carteira.DebitarEmbarque`..." e só a 3.2 é "Escrever testes unitários de débito...". Isso é Green antes de Red, contradizendo tanto a convenção quanto o padrão das demais TASKs (TASK-01, TASK-02 e TASK-04 corretamente abrem com "Red:").

### 5. Ciclo de dependência TASK-04 ↔ TASK-05 — impede sequenciamento de onda
TASK-04 declara "Depende de: TASK-05" e TASK-05 declara "Depende de: TASK-04". As duas estão na Onda 3. Um ciclo de dependência direto impossibilita determinar qual TASK abre primeiro — qualquer execução em worktrees separadas (conforme ADR-0003) trava. Dado o conteúdo, a dependência real é unidirecional: TASK-04 (handler + endpoint) precisa do repositório/migration de TASK-05, então o correto é "TASK-04 depende de TASK-05" e TASK-05 sem dependência (ou dependente apenas de TASK-01).

### 6. TASK-05 manda "push direto em main" — viola ADR-0003 diretamente
Critérios de aceite de TASK-05: "...commit `feat(carteira): persistencia` e push direto em `main` para liberar o time de app." ADR-0003 é explícito: "push direto em `main` ou `develop` é proibido (branch protection). Toda integração é por PR para `develop` com CI verde." Isso não é nuance de estilo — é uma instrução operacional que, se seguida literalmente por um agente de codificação, tenta um push que a branch protection real deveria recusar, e se a branch protection estiver mal configurada, quebra o fluxo de PR/CI para todo o módulo.

## O que está correto (sem crédito indevido, mas para não gerar retrabalho)
Mapeamento de Req 1, Req 3, PBT-01, DD-001 e ADR-0001 está consistente entre requirements, design e tasks. TASK-01 cobre corretamente o teste de arquitetura do ADR-0001 antes da primeira onda de Infrastructure, como a própria ADR exige. Branches e worktrees seguem o padrão `<tipo>/carteira/<NN>-<slug>` do ADR-0003 em todas as TASKs exceto o desvio pontual de TASK-05 (item 6). Coverage gates por camada estão definidos e não contradizem RNFs.

## Recomendação para o tasks-writer
1. Adicionar subtask de teste de idempotência (reenvio do mesmo `txid`) em TASK-04, referenciando PBT-02, e incluir PBT-02 na Matriz de Rastreabilidade.
2. Criar TASK nova (ou subtask em TASK-04/TASK-06) para o enricher de mascaramento de CPF/e-mail, referenciando RNF 2, e incluir RNF 2 na Matriz.
3. Adicionar a linha de TASK-06 na tabela "Status Geral".
4. Inverter a ordem das subtasks 3.1/3.2 em TASK-03 (teste antes de implementação) ou renumerá-las mantendo Red→Green→Refactor.
5. Resolver o ciclo: TASK-04 depende de TASK-05; TASK-05 depende apenas de TASK-01 (ou do que for correto pelo design).
6. Remover a instrução de "push direto em main" do critério de aceite de TASK-05 e substituir por "branch enviada, PR para `develop` com CI verde", como as demais TASKs.

Só depois dessas seis correções o tasks.md fica seguro para abrir a sprint de segunda-feira e distribuir as TASKs aos agentes de desenvolvimento.
