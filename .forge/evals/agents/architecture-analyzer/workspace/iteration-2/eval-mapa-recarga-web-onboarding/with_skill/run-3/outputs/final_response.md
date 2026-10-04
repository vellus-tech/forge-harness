Mapa salvo em `docs/arquitetura/mapa-recarga-web.md` dentro do projeto recarga-web. Ele foi feito sobre `.forge/graph/graph.json`, sem reler o código.

O backend tem 11 arquivos e 96 LOC de TypeScript. Por camada: api 16 LOC, application 23, domain 23, infrastructure 19, contracts 3 e 12 fora da taxonomia (`main.ts` e `shared/logger.ts`).

Há duas violações proibidas pela regra de camadas. A mais relevante para o Pix é `src/domain/cartao.ts` importando `src/infrastructure/db/postgres-client.ts`, o que põe o banco dentro da entidade de cartão. A outra é `src/application/solicitar-recarga.ts` importando `src/api/http-errors.ts`. O import de `domain` para `contracts/eventos-recarga.ts` é exceção aprovada pelo ADR-0003 e não conta como violação.

O acoplamento está concentrado em `src/shared/logger.ts` (6 importadores, transversal e permitido) e em `src/domain/cartao.ts` (4 importadores, incluindo o caso de uso de recarga). Recomendo corrigir as duas violações antes de implementar o Pix, porque o Pix deve aumentar o fan-in do cartão. O grafo não tem código de Pix ainda, então isso é uma análise do terreno.

Ressalvas: `src/shared/` aparece como unknown porque `codegraph.layers` não declara essa camada. O grafo também não cobre testes nem migrations. Os resumos LLM estão stale, mas o mapa não depende deles.

Observação fora do escopo: o `git status` do projeto mostra arquivos em `.claude/agents/` marcados como deletados, que já estavam assim antes da minha escrita. Não mexi neles.
