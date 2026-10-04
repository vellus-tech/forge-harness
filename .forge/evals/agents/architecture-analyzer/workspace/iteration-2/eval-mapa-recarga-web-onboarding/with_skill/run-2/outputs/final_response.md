Mapa de arquitetura salvo em `docs/arquitetura/mapa-recarga-web.md` (dentro do projeto recarga-web).

O grafo tem 11 nós e 96 linhas de código. Camadas: api 16 LOC, application 23, domain 23, infrastructure 19, contracts 3, unknown 12 (main.ts e shared/logger.ts, sem classificação).

Há duas violações de direção confirmadas contra `.forge/rules/architecture/camadas-recarga-web.md`:
1. `domain/cartao.ts` importa `infrastructure/db/postgres-client.ts`. É a mais relevante para o Pix, porque o agregado de cartão já depende do banco.
2. `application/solicitar-recarga.ts` importa `api/http-errors.ts`. O erro HTTP vazou para o caso de uso.

As arestas de `domain` para `contracts/eventos-*` são a exceção do ADR-0003 e não contam como violação.

Acoplamento concentrado em `shared/logger.ts` (6 importadores, esperado) e em `domain/cartao.ts` (4 importadores, hub do domínio e também o nó da violação 1). `solicitar-recarga.ts` tem o maior fan-out (4) e é o caso de uso que a recarga via Pix mais provavelmente vai tocar.

Limites: a detecção de camadas é heurística e os dois nós `unknown` ficaram fora da checagem. Os resumos do grafo estão desatualizados (não usados). Não reli o código-fonte; contagens e arestas vêm do `graph.json`, recalculadas por script.
