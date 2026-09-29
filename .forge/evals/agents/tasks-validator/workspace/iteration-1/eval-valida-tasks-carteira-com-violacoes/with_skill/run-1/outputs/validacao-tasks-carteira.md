# Validação do tasks.md

## Resultado

Status: Reprovado

Resumo:
- Total de achados BLOCKER: 5
- Total de achados HIGH: 2
- Total de achados MEDIUM: 2
- Total de achados LOW: 0

## Veredito

O `tasks.md` v1.0.0 do módulo Carteira deriva, na maior parte, corretamente do `requirements.md` v1.2.0 e do `design.md` v0.4.0 — formato de TASK, ondas, coverage gates e critérios de encerramento seguem o padrão esperado. No entanto há cinco achados BLOCKER que impedem a distribuição das TASKs na sprint de segunda-feira: uma propriedade aprovada (PBT-02) sem TASK correspondente, o Status Geral divergente da lista de Tarefas (TASK-06 ausente), um ciclo de dependência entre TASK-04 e TASK-05, uma TASK de domínio que inverte Red→Green (implementação antes do teste) e uma orientação explícita de push direto em `main`, que contraria o ADR-0003. O plano não pode seguir para execução sem retorno ao `tasks-writer`.

## Achados

### [BLOCKER-01] PBT-02 (idempotência do crédito) sem TASK correspondente

**Local:** Matriz de Rastreabilidade (linhas 157-168) e TASK-04 (linhas 98-116)
**Problema:** `requirements.md` define `PBT-02 — Idempotência do crédito de recarga` (aplicar o mesmo `txid` N vezes credita o valor exatamente uma vez). A Matriz de Rastreabilidade só cobre PBT-01; PBT-02 não aparece em nenhuma linha. A TASK-04, que implementa o crédito via webhook Pix e cita `DD-002` (idempotência pela tabela `recarga_processada`), só tem subtasks para o caminho feliz (4.1 credita e grava outbox) — não há subtask de propriedade que repita o mesmo `txid` N vezes e verifique crédito único.
**Impacto:** Propriedade crítica de segurança financeira (evitar crédito duplicado em reenvio de webhook do PSP) fica sem teste de propriedade formal; o risco descrito na própria seção "Riscos de Execução" (webhook pode reenviar a confirmação) não tem verificação automatizada correspondente.
**Correção recomendada:** Adicionar subtask Red em TASK-04 (ex.: "4.0 Red: PBT-02 — aplicar o mesmo `txid` N vezes credita exatamente uma vez, usando gerador de repetição") antes da subtask 4.2, e incluir a linha `PBT-02 | TASK-04 | OK` na Matriz de Rastreabilidade.

### [BLOCKER-02] RNF 2 (mascaramento de PII em logs) sem TASK

**Local:** Matriz de Rastreabilidade (linhas 157-168); nenhuma TASK trata logs/observabilidade
**Problema:** `requirements.md` define `RNF 2 — Proteção de PII em logs` (CPF nunca em claro; máscara `***.***.***-NN`) e o `design.md` cita explicitamente um "enricher de mascaramento de CPF/e-mail (RNF 2)" na seção de Observabilidade e segurança. Nenhuma das seis TASKs implementa ou testa esse enricher; RNF 2 não aparece na Matriz de Rastreabilidade.
**Impacto:** Requisito não-funcional de proteção de dados pessoais aprovado fica sem execução planejada — risco de vazamento de CPF em logs em produção, o que é um problema de compliance (LGPD) e de segurança, não apenas de qualidade.
**Correção recomendada:** Criar uma TASK dedicada (ex.: TASK-07 — Enricher de mascaramento de PII em logs, Onda 3, Camada Infrastructure/Observability) com subtask Red (teste que garante que CPF/e-mail nunca aparecem em claro no log estruturado) antes do Green, e adicionar `RNF 2 | TASK-07 | OK` na matriz.

### [BLOCKER-03] Status Geral divergente da seção de Tarefas — TASK-06 ausente

**Local:** Status Geral (linhas 21-29) vs. seção Tarefas, TASK-06 (linhas 137-155)
**Problema:** A tabela "Status Geral" lista apenas TASK-01 a TASK-05. A TASK-06 ("Consulta de saldo"), que existe integralmente na seção "Tarefas" com branch, worktree, subtasks e critérios de aceite, não aparece no Status Geral.
**Impacto:** Divergência entre o índice de acompanhamento e o plano real — qualquer agente ou humano que use o Status Geral para distribuir trabalho na sprint (o próprio objetivo desta validação) vai ignorar TASK-06, deixando a Onda 3 incompleta e Req 2/RNF 1 sem execução visível no board.
**Correção recomendada:** Adicionar a linha `| TASK-06 | Consulta de saldo | Onda 3 | \`feat/carteira/06-consulta-saldo\` | [ ] |` ao Status Geral, mantendo consistência com o README (que já declara "6 TASKs").

### [BLOCKER-04] Ciclo de dependência entre TASK-04 e TASK-05

**Local:** TASK-04 (linha 106, campo Depende de) e TASK-05 (linha 126, campo Depende de)
**Problema:** TASK-04 declara `Depende de: TASK-05`, e TASK-05 declara `Depende de: TASK-04`. Isso forma um ciclo direto: nenhuma das duas pode ser iniciada primeiro segundo o próprio grafo de dependências do plano.
**Impacto:** Onda 3 fica com ordem de execução impossível de resolver mecanicamente; qualquer automação de distribuição de TASKs (ou um agente de desenvolvimento seguindo o grafo) trava, e a inconsistência sugere que a direção real da dependência não foi pensada (Application normalmente depende de Infrastructure para persistir, não o inverso).
**Correção recomendada:** Romper o ciclo — manter `TASK-04 Depende de: TASK-05` (Application precisa do repositório/migration para persistir o crédito) e corrigir `TASK-05 Depende de:` para `TASK-01` (ou `Não aplicável`, já que Infrastructure só precisa do bootstrap da solução).

### [BLOCKER-05] TASK-03 inverte TDD-first — implementação antes do teste

**Local:** TASK-03, subtasks 3.1-3.2 (linhas 92-93)
**Problema:** As "Convenções de Implementação" (linha 18) e o padrão do documento exigem Red → Green → Refactor. Em TASK-03, a subtask 3.1 é "Implementar `Carteira.DebitarEmbarque` e o mapeamento para `CRT-002`" e só depois, em 3.2, vem "Escrever testes unitários de débito". É lógica de domínio (débito de tarifa com regra de saldo insuficiente) implementada antes do teste correspondente.
**Impacto:** Viola diretamente TDD-first para uma regra de negócio central (Req 3, que já tem PBT-01 exigindo saldo nunca negativo); a ordem declarada não garante que o teste falhe antes da implementação, esvaziando a garantia de que o comportamento é guiado por teste e não escrito para acomodar código já pronto.
**Correção recomendada:** Reordenar para `3.1 Red: escrever testes unitários de débito (saldo suficiente e insuficiente, incluindo CRT-002)`, `3.2 Green: implementar Carteira.DebitarEmbarque`, mantendo `3.3 Refactor`.

### [HIGH-01] Orientação de push direto em `main` na TASK-05

**Local:** TASK-05, critérios de aceite (linha 135)
**Problema:** O critério de aceite da TASK-05 termina com "commit `feat(carteira): persistencia` e push direto em `main` para liberar o time de app". Isso contraria diretamente o ADR-0003 ("Toda integração é por PR para `develop` com CI verde; push direto em `main` ou `develop` é proibido") e a própria seção "Critérios de Encerramento" do documento, que exige "PR da onda aprovado e mergeado em `develop`".
**Impacto:** Se seguido literalmente, quebra branch protection e o processo de revisão por PR definido para todo o módulo; abre precedente perigoso de bypass de CI justificado por urgência ("liberar o time de app").
**Correção recomendada:** Remover a menção a push direto em `main` do critério de aceite; alinhar TASK-05 ao mesmo padrão das demais TASKs — "branch enviada, PR aberto para `develop`, CI verde".

### [HIGH-02] Coverage gates de Security e Observability ausentes da tabela

**Local:** Coverage Gates (linhas 170-178)
**Problema:** A tabela cobre Domain, Application, Infrastructure, Api e Architecture, mas omite as linhas de Security e Observability do modelo recomendado — consistente com a ausência de TASK para o enricher de PII (BLOCKER-02) e com a falta de qualquer verificação automatizada de logs estruturados/`correlation_id` mencionados no `design.md`.
**Impacto:** Sem gate definido, não há como cobrar cobertura de teste para os cenários de segurança e observabilidade citados no design, reforçando o risco já levantado em BLOCKER-02.
**Correção recomendada:** Adicionar linhas `Security | Cobertura por cenário crítico` e `Observability | Cobertura por fluxo crítico` à tabela, e vinculá-las à nova TASK de mascaramento de PII e a uma verificação de `correlation_id`/logs estruturados.

## Achados adicionais (MEDIUM)

### [MEDIUM-01] Matriz de Rastreabilidade não lista ADR-0002

**Local:** Matriz de Rastreabilidade (linhas 157-168) vs. TASK-02 (linha 70)
**Problema:** TASK-02 mapeia `ADR-0002` no seu campo "Mapeia", mas a Matriz de Rastreabilidade não tem uma linha `ADR-0002 | TASK-02`.
**Correção recomendada:** Adicionar a linha à matriz para manter rastreabilidade simétrica entre o campo de cada TASK e a matriz consolidada.

### [MEDIUM-02] `CRT-001 CarteiraNaoEncontrada` sem TASK explícita no catálogo de erros

**Local:** Catálogo de erros do `design.md` (linha 31) vs. seção Tarefas
**Problema:** `CRT-002` (TASK-03) e `CRT-003` (TASK-06) têm tratamento explícito; `CRT-001 CarteiraNaoEncontrada` (404) não aparece em nenhuma TASK ou critério de aceite, embora a consulta de saldo (TASK-06) e o débito (TASK-03) presumivelmente precisem desse caminho de erro.
**Correção recomendada:** Adicionar `CRT-001` explicitamente aos critérios de aceite/subtasks de TASK-06 (e de TASK-03/TASK-04, onde aplicável) para cobrir o caso de carteira inexistente.

## Matriz de Rastreabilidade (auditoria)

| Origem | TASKs no documento | Status |
|--------|-------|--------|
| Req 1 | TASK-04, TASK-05 | OK |
| Req 2 | TASK-06 | OK |
| Req 3 | TASK-02, TASK-03 | OK |
| RNF 1 | TASK-06 | OK |
| RNF 2 | — | Falhou (sem TASK) |
| PBT-01 | TASK-02 | OK |
| PBT-02 | — | Falhou (sem TASK) |
| DD-001 | TASK-02, TASK-03 | OK |
| DD-002 | TASK-04, TASK-05 | OK (idempotência sem PBT dedicado) |
| ADR-0001 | TASK-01 | OK |
| ADR-0002 | TASK-02 (só no campo da TASK, não na matriz) | Falhou parcial (matriz incompleta) |
| ADR-0003 | Nenhuma TASK cita; violado por TASK-05 | Falhou (TASK-05 contraria) |
| CRT-001 (catálogo de erros) | — | Falhou (sem TASK explícita) |
| CRT-002 (catálogo de erros) | TASK-03 | OK |
| CRT-003 (catálogo de erros) | TASK-06 | OK |

## Checks Executados

| Check | Resultado |
|-------|-----------|
| Tamanho até 3.000 linhas | OK (192 linhas) |
| Estrutura obrigatória | OK |
| Metadados e versionamento | OK |
| Referência a requirements/design | OK |
| Rastreabilidade completa | Falhou (PBT-02, RNF 2, matriz incompleta) |
| Status Geral sincronizado | Falhou (TASK-06 ausente) |
| Ondas de implementação | OK (com ressalva do ciclo em Onda 3) |
| Formato das TASKs | OK |
| Tamanho das TASKs/subtasks | OK |
| TDD-first | Falhou (TASK-03) |
| PBTs mapeados | Falhou (PBT-02 ausente) |
| Branch/worktree/commits | Falhou (TASK-05 orienta push direto em main) |
| Critérios de aceite | OK, exceto TASK-05 |
| Coverage gates | Falhou parcial (Security/Observability ausentes) |
| Dependências | Falhou (ciclo TASK-04↔TASK-05) |
| Segurança e observabilidade | Falhou (RNF 2 sem TASK) |
| API/eventos/persistência/erros | Falhou parcial (CRT-001 sem TASK) |
| Critérios de encerramento | OK |
| README sincronizado | OK |

## Recomendações para o tasks-writer

1. Adicionar TASK dedicada para o enricher de mascaramento de PII (RNF 2) e subtask de propriedade para PBT-02, ambas com Red antes do Green.
2. Corrigir o Status Geral incluindo TASK-06 e quebrar o ciclo de dependência TASK-04↔TASK-05 (TASK-05 deve depender de TASK-01, não de TASK-04).
3. Reordenar as subtasks de TASK-03 para Red→Green→Refactor e remover a orientação de push direto em `main` do critério de aceite de TASK-05, alinhando ao PR-para-`develop` exigido pelo ADR-0003.
4. Completar a Matriz de Rastreabilidade com ADR-0002, PBT-02, RNF 2 e CRT-001, e adicionar linhas de Security/Observability à tabela de Coverage Gates.

## Decisão para o Pipeline

- Pode seguir para execução: Não
- Requer nova execução do `tasks-writer`: Sim
- Requer ajuste no `design.md`: Não
- Requer ajuste no `requirements.md`: Não
