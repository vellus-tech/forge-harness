# Validação do tasks.md

## Resultado

Status: Reprovado

Resumo:
- Total de achados BLOCKER: 1
- Total de achados HIGH: 0
- Total de achados MEDIUM: 0
- Total de achados LOW: 0

## Veredito

`docs/product/modules/validacao/tasks.md` tem 3.966 linhas (280 TASKs, uma por linha de ônibus do consórcio), acima do limite de 3.000 linhas definido na Regra Especial de Tamanho. Por essa regra, a revisão detalhada de conteúdo (rastreabilidade Req/RNF/PBT/DD, Status Geral, ondas, TDD-first, coverage gates, critérios de aceite/encerramento etc.) fica bloqueada nesta passada — revisar item a item um arquivo desse tamanho não é confiável e o próprio tamanho já indica plano pouco executável. O achado abaixo é o único emitido nesta rodada; ele é suficiente, isolado, para reprovar o plano e devolver ao `tasks-writer`.

## Achados

### [BLOCKER-01] tasks.md acima de 3.000 linhas — revisão detalhada bloqueada

**Local:** arquivo inteiro — `docs/product/modules/validacao/tasks.md` (3.966 linhas, 280 TASKs, uma por linha de ônibus do consórcio).
**Problema:** o documento excede o limite de 3.000 linhas da Regra Especial de Tamanho. O padrão "uma TASK por linha de ônibus" gera 280 blocos quase idênticos no mesmo arquivo, o que é sintoma de granularidade de dado (linha de ônibus) tratada como granularidade de execução (TASK), não de decomposição por onda de implementação.
**Impacto:** documento praticamente impossível de acompanhar em PR ou checkpoint; alto risco de divergência entre Status Geral, matriz de rastreabilidade e o corpo de TASKs conforme o arquivo evolui; dificulta revisão humana e de agente; a "paralelização por dev pega uma linha" citada pelo usuário não exige uma TASK-arquivo por linha — pode ser resolvida como itens de uma única TASK parametrizada por dados, ou por poucas TASKs em lote.
**Correção recomendada:** o `tasks-writer` deve decompor o plano, mantendo `tasks.md` como índice e matriz de rastreabilidade, com o detalhamento em arquivos auxiliares por onda:

```text
docs/product/modules/validacao/tasks.md
docs/product/modules/validacao/tasks/wave-01-bootstrap.md
docs/product/modules/validacao/tasks/wave-02-domain.md
docs/product/modules/validacao/tasks/wave-03-application.md
docs/product/modules/validacao/tasks/wave-04-infrastructure.md
docs/product/modules/validacao/tasks/wave-05-api-contracts.md
docs/product/modules/validacao/tasks/wave-06-hardening.md
```

Adicionalmente — e isto é uma recomendação de desenho de plano, não um achado de conteúdo verificado nesta passada, já que a revisão detalhada está bloqueada — vale reconsiderar se 280 TASKs (uma por linha) é a granularidade certa. Uma TASK de carga de tabela de tarifas, parametrizada por dado (as 280 linhas viram uma fixture/seed testada uma vez, não 280 TASKs), tende a manter a rastreabilidade com Req 2 sem inflar o arquivo, e ainda permite dividir o trabalho por onda ou por lote de linhas caso a paralelização entre devs seja o objetivo real.

## Matriz de Rastreabilidade

Não verificado — bloqueado pela Regra Especial de Tamanho (arquivo acima de 3.000 linhas). Não avaliar rastreabilidade Req/RNF/PBT/DD → TASK nesta passada evita reportar cobertura com base em amostragem parcial de um arquivo de 3.966 linhas.

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

1. Decompor `tasks.md` em índice + matriz de rastreabilidade, movendo o detalhamento de TASKs para `docs/product/modules/validacao/tasks/wave-NN-<foco>.md`, um arquivo por onda.
2. Reavaliar a granularidade "uma TASK por linha de ônibus" — considerar uma TASK parametrizada por dado (seed/fixture de tarifas testada uma vez para as 280 linhas) em vez de 280 TASKs quase idênticas, preservando a divisão de trabalho por onda/lote se a paralelização entre devs for o objetivo.
3. Depois da decomposição, resubmeter para nova rodada de validação — só então a revisão detalhada (rastreabilidade, Status Geral, TDD-first, PBTs, coverage gates, critérios de encerramento) poderá ser executada.

## Decisão para o Pipeline

- Pode seguir para execução: Não
- Requer nova execução do `tasks-writer`: Sim
- Requer ajuste no `design.md`: Não
- Requer ajuste no `requirements.md`: Não
