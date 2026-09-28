# Validação do tasks.md

## Resultado

Status: Reprovado

Resumo:
- Total de achados BLOCKER: 1
- Total de achados HIGH: 0
- Total de achados MEDIUM: 0
- Total de achados LOW: 0

## Veredito

`docs/product/modules/validacao/tasks.md` tem 3.966 linhas, acima do limite de 3.000 linhas definido pela Regra Especial de Tamanho da minha especificação. Por definição dessa regra, um arquivo acima de 3.000 linhas bloqueia a revisão detalhada de conteúdo — não faço o pente-fino TASK a TASK que foi pedido, porque o próprio tamanho do documento já é o defeito estrutural que precisa ser corrigido primeiro. Revisar 280 TASKs quase idênticas dentro de um único arquivo monolítico não é um plano executável: dificulta acompanhamento de status, aumenta risco de divergência entre matriz de rastreabilidade e lista de tarefas, e não é revisável em PR ou checkpoint gerenciável. A causa raiz aparente é a estratégia de decomposição escolhida pelo tasks-writer (uma TASK por linha de ônibus do consórcio, em vez de agrupar por onda/camada técnica), não um problema de redação de TASKs individuais.

Não avancei para os checks de conteúdo (rastreabilidade Req/RNF/PBT, TDD-first, coverage gates, Status Geral, dependências, etc.) porque a regra de tamanho os torna "Não verificado" até a decomposição ser feita e o arquivo (ou seus fragmentos) voltar a ficar dentro do limite.

## Achados

### [BLOCKER-01] tasks.md excede 3.000 linhas (Regra Especial de Tamanho)

**Local:** `docs/product/modules/validacao/tasks.md` (arquivo inteiro, 3.966 linhas)
**Problema:** O documento tem 3.966 linhas, resultado de criar uma TASK completa (com tabela de metadados e 2 subtasks) para cada uma das 280 linhas de ônibus do consórcio, em vez de tratar isso como um parâmetro de dados dentro de uma TASK genérica de carga de tarifas.
**Impacto:** Acompanhamento de status inviável em um arquivo desse tamanho, alto risco de divergência entre Status Geral e a seção de Tarefas conforme o plano evolui, PR de execução gigante e não revisável por onda, e dificuldade de manter a Matriz de Rastreabilidade coerente. A regra bloqueia qualquer aprovação enquanto o tamanho não for corrigido.
**Correção recomendada:** Decompor o plano em arquivos auxiliares por onda ou por natureza técnica, mantendo `tasks.md` como índice e matriz de rastreabilidade. Estrutura recomendada:

```text
docs/product/modules/validacao/tasks.md
docs/product/modules/validacao/tasks/wave-01-bootstrap.md
docs/product/modules/validacao/tasks/wave-02-domain.md
docs/product/modules/validacao/tasks/wave-03-application.md
docs/product/modules/validacao/tasks/wave-04-infrastructure.md
docs/product/modules/validacao/tasks/wave-05-api-contracts.md
docs/product/modules/validacao/tasks/wave-06-hardening.md
```

Além disso, reconsiderar o modelo "uma TASK por linha de ônibus": 280 TASKs quase idênticas (mesmo par de subtasks, mesma estrutura, variando apenas o número da linha) sugerem que a unidade real de trabalho é "carregar a tabela `tarifa_linha` a partir de uma fonte de dados", com uma única TASK (ou poucas, por lote) coberta por um teste parametrizado/data-driven — e não uma TASK por linha. Isso reduz o arquivo, reduz o "achatamento" da rastreabilidade (Req 2 → TASK-001..TASK-280 vira Req 2 → 1-2 TASKs) e evita 280 branches/worktrees individuais para uma tarefa essencialmente repetitiva.

## Matriz de Rastreabilidade

Não avaliada — a Regra Especial de Tamanho bloqueia a revisão detalhada antes de checar rastreabilidade Req/RNF/PBT/DD → TASK.

## Checks Executados

| Check | Resultado |
|-------|-----------|
| Tamanho até 3.000 linhas | Falhou (3.966 linhas) |
| Estrutura obrigatória | Não verificado |
| Metadados e versionamento | Não verificado |
| Referência a requirements/design | Não verificado |
| Rastreabilidade completa | Não verificado |
| Status Geral sincronizado | Não verificado |
| Ondas de implementação | Não verificado |
| Formato das TASKs | Não verificado |
| Tamanho das TASKs/subtasks | Não verificado |
| TDD-first | Não verificado |
| PBTs mapeados | Não verificado |
| Branch/worktree/commits | Não verificado |
| Critérios de aceite | Não verificado |
| Coverage gates | Não verificado |
| Dependências | Não verificado |
| Segurança e observabilidade | Não verificado |
| API/eventos/persistência/erros | Não verificado |
| Critérios de encerramento | Não verificado |
| README sincronizado | Não verificado |

## Recomendações para o tasks-writer

1. Decompor `tasks.md` em `tasks/wave-NN-<tema>.md`, mantendo o arquivo principal como índice e Matriz de Rastreabilidade (estrutura acima).
2. Substituir o padrão "uma TASK por linha de ônibus" por TASKs orientadas a incremento técnico (ex.: uma TASK de carga de tarifas com teste parametrizado cobrindo as 280 linhas via fixture/dataset), reduzindo de ~280 TASKs quase idênticas para um número pequeno e revisável.
3. Depois da decomposição, resubmeter para nova rodada de validação — só então os checks de conteúdo (rastreabilidade, TDD-first, Status Geral, coverage gates, critérios de encerramento etc.) serão executados.

## Decisão para o Pipeline

- Pode seguir para execução: Não
- Requer nova execução do `tasks-writer`: Sim
- Requer ajuste no `design.md`: Não
- Requer ajuste no `requirements.md`: Não
