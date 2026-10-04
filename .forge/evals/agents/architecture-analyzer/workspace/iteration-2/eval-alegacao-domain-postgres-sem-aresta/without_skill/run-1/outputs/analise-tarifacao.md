# Análise de arquitetura — tarifação de integração

## Sumário executivo

A análise sobre o grafo de código (`.forge/graph/graph.json`, gerado em 2026-10-04) não confirma a violação `domain → infrastructure` atribuída ao domínio de tarifação. Não há nenhuma aresta de `src/domain/tarifa.ts` para `src/infrastructure/`, e o arquivo de domínio não importa `PostgresTarifaRepository`. A única menção ao repositório no domínio é um comentário `TODO(tarifa)` que descreve uma intenção futura, não um acoplamento existente. A dependência real que cruza camadas de forma indevida é outra: a camada de aplicação instancia diretamente o repositório concreto de PostgreSQL.

## Fatos

- O grafo tem 6 nós e 6 arestas, todas resolvidas, sem dependências externas não resolvidas.
- `src/domain/tarifa.ts` tem uma única aresta de saída, para `src/domain/tabela-tarifaria.ts`.
- `src/domain/tarifa.ts` contém, nas linhas 3 e 4, apenas um comentário `TODO(tarifa)` que cita `PostgresTarifaRepository`.
- `src/application/calcular-tarifa.ts` importa `PostgresTarifaRepository` e chama `new PostgresTarifaRepository().tabelaVigente()` diretamente (linha 5).
- `src/infrastructure/postgres-tarifa-repository.ts` depende apenas de `src/domain/tabela-tarifaria.ts`.
- A busca textual por `PostgresTarifaRepository` no código retorna quatro ocorrências: a definição, o import e a chamada na camada de aplicação, e o comentário no domínio.

## Mapa de camadas

| Camada | Arquivo | Importa de |
|---|---|---|
| entrada (main) | `src/main.ts` | api |
| api | `src/api/tarifa-controller.ts` | application |
| application | `src/application/calcular-tarifa.ts` | domain, infrastructure |
| domain | `src/domain/tarifa.ts` | domain (`tabela-tarifaria.ts`) |
| domain | `src/domain/tabela-tarifaria.ts` | nenhuma |
| infrastructure | `src/infrastructure/postgres-tarifa-repository.ts` | domain (`tabela-tarifaria.ts`) |

O grafo classifica `src/main.ts` como `unknown`, o que deixa a cobertura de taxonomia em 5 de 6 nós (83,3%). Isso é uma lacuna de declaração em `codegraph.layers`, não um problema de arquitetura.

## Interpretação

O domínio está limpo em relação à infraestrutura. Ele depende só de um tipo de dado (`TabelaTarifaria`), que é o sentido de dependência esperado numa arquitetura em camadas. A suspeita do tech lead provavelmente nasce do `TODO` no próprio `tarifa.ts`, que menciona o repositório junto com a frase "para evitar passar pela application". Esse comentário descreve o caminho oposto ao que existe hoje: o código atual já passa pela application, e o TODO propõe que o domínio pule essa camada.

O problema real é de inversão de dependência. A aplicação conhece o repositório concreto de PostgreSQL, então trocar o armazenamento ou testar `calcularTarifa` sem banco exige alterar o código de aplicação. A correção usual é declarar uma porta (por exemplo, uma interface `TarifaRepository` no domínio ou na aplicação) e injetar a implementação de PostgreSQL pela `main`. Essa é uma interpretação de engenharia, não um fato do grafo.

Se o TODO for implementado, aí sim surgiria a violação `domain → infrastructure` que o tech lead descreveu, e ela deve ser barrada por regra de arquitetura antes do merge.

## Recomendação

Para a retro, o registro correto é: "não há violação domain → infrastructure hoje; há acoplamento application → infrastructure concreto em `calcular-tarifa.ts`; há um TODO no domínio que, se implementado, criaria a violação". Não recomendo abrir item de dívida como se a violação de domínio existisse. Recomendo abrir item de dívida para a inversão de dependência na aplicação e remover ou reescrever o TODO de `tarifa.ts`.

## Limitações

- A análise usa o grafo nativo, que resolve imports estáticos. Chamadas dinâmicas ou injeção por configuração não aparecem nele. A verificação complementar foi a busca textual, que cobre o caso observado.
- Os `summaries` dos nós estão marcados como desatualizados, o que não afeta esta análise de arestas.
- Não foram executados testes nem o `forge doctor`, pois o ambiente desta execução não permite rede nem instalação de dependências.
