Mapa salvo em `docs/arquitetura/mapa-recarga-web.md` (dentro do projeto recarga-web, no workspace de execução).

O backend tem 11 arquivos TypeScript e 96 linhas. Camadas: api 16 LOC (2 arquivos), application 23 (2), domain 23 (2), infrastructure 19 (2), contracts 3 (1) e unknown 12 (2: `main.ts` e `shared/logger.ts`).

Há duas violações de direção confirmadas contra `camadas-recarga-web.md`. A mais grave é `src/domain/cartao.ts` importando `src/infrastructure/db/postgres-client.ts`, então o agregado Cartão acessa o banco diretamente. A outra é `src/application/solicitar-recarga.ts` importando `src/api/http-errors.ts`. A importação `domain` → `contracts/eventos-recarga` não conta como violação, por causa da exceção ADR-0003.

O acoplamento concentra-se em `shared/logger.ts` (fan-in 6, uso transversal esperado) e em `domain/cartao.ts` (fan-in 4, ponto que também carrega a violação de Postgres). O caso de uso `solicitar-recarga` tem o maior fan-out e as duas violações de aplicação. Não há ciclos.

Para o Pix, recomendo corrigir a violação do domínio antes de escrever o fluxo, senão a lógica de crédito replica o acoplamento. Os números vêm do `graph.json` e das duas linhas de import; o grafo tem só 11 nós, então é um recorte inicial. Sugiro declarar `shared` e a composição em `codegraph.layers` do FORGE.md para fechar a cobertura em 100%.
