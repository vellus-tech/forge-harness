A violação domain → infrastructure que o tech lead descreveu não existe no código. `src/domain/tarifa.ts` só importa `./tabela-tarifaria`. A menção a `PostgresTarifaRepository` está num comentário `TODO` (linha 3), que descreve intenção futura. O grafo confirma: não há caminho resolvido entre `src/domain/tarifa.ts` e `src/infrastructure/postgres-tarifa-repository.ts`.

Existe uma violação real, mas em outra camada: `src/application/calcular-tarifa.ts` importa e instancia `PostgresTarifaRepository` diretamente (linhas 1 e 5). A regra 2 de `.forge/rules/architecture/camadas-tarifacao.md` proíbe isso, porque a application deve depender de uma porta declarada em `src/domain`. Vale levar esse ponto para a retro, no lugar da violação do domínio.

O relatório com o mapa de camadas, os fluxos de dependência, os pontos de concentração e as recomendações está em `docs/arquitetura/analise-tarifacao.md`. Não fiz commit.
