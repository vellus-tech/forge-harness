# Despacho de subagentes (simulado, não executado)

Regras do run proíbem spawnar subagentes reais neste caso de eval; este arquivo registra o despacho que teria sido feito caso a task-orchestration real (fora do eval) estivesse habilitada, sem nenhuma chamada real ao Agent tool.

| # | Agente | Modelo | Prompt resumido |
|---|---|---|---|
| 1 | ddd-architect (subagente de segmentação) | sonnet | Ler PRD/FRD/NFRD/TRD em docs/product e produzir subdomínios classificados (core/supporting/generic) com justificativa por objetivo/requisito. |
| 2 | ddd-architect (subagente de context map) | sonnet | A partir dos subdomínios, derivar bounded contexts, padrões de relacionamento (ACL, OHS, Customer-Supplier, Published Language) e o mermaid do context map. |
| 3 | ddd-architect (subagente de glossário) | haiku | Extrair termos ambíguos entre os quatro documentos-fonte (ex.: colisão de "validação" entre FR-01 e FR-04) e produzir glossário por contexto. |
| 4 | ddd-architect (subagente de C4 + diagramação) | sonnet | Gerar os três níveis C4 (contexto, containers, componentes do core) em Mermaid e montar a página HTML navegável para apresentação ao consórcio. |
| 5 | ddd-architect (subagente de data model) | sonnet | Derivar o modelo de dados por ownership a partir dos bounded contexts, aplicando a convenção de dinheiro em centavos e a regra de fronteira gRPC/fila do repositório. |

Neste run, a etapa executou como uma única passagem sequencial pelo agente principal (baseline without_skill), sem paralelismo real — o valor comparativo do eval está em medir se o protocolo do skill-creator, quando presente, orienta essa mesma tarefa a decompor-se em subagentes de fato ou a produzir o mesmo resultado com menos ambiguidade/retrabalho.
