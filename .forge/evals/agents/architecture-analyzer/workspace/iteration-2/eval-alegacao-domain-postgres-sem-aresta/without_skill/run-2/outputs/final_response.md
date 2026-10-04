A violação domain → infrastructure não existe no código. Conferi no grafo e no código, e o relatório está em `docs/arquitetura/analise-tarifacao.md` (dentro do projeto).

O que os fatos mostram: nenhum arquivo de `src/domain` importa `infrastructure`, e o grafo não tem aresta `domain → infrastructure`. A única menção ao `PostgresTarifaRepository` dentro do domínio é um comentário `TODO(tarifa)` em `src/domain/tarifa.ts`, que propõe esse acesso direto. É provável que o tech lead tenha lido esse TODO como se fosse código.

O achado real é outro: `src/application/calcular-tarifa.ts` importa o repositório concreto e o instancia com `new PostgresTarifaRepository()`, sem uma porta no domínio. Isso acopla o caso de uso ao Postgres e impede testá-lo sem banco. Não registrei isso como violação de camada porque o projeto não declara a regra de camadas em `codegraph.layers`; é um desvio de inversão de dependência a ser decidido.

Para a retro, sugiro levar: "nenhuma aresta domain → infrastructure hoje; há um TODO que a introduziria, e a aplicação acopla-se ao Postgres concreto". Como próximos passos, em ordem de custo: reescrever o TODO, declarar a regra em `FORGE.md` para o grafo acusar automaticamente, e introduzir uma interface de repositório injetada na aplicação.

O mapa de camadas completo, com as arestas e a cobertura (5 de 6 nós classificados; `main.ts` ficou como não classificado, sugerido como composition root), está no relatório.
