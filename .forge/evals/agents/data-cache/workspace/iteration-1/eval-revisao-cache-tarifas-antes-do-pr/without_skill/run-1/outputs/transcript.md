# Transcript — eval-revisao-cache-tarifas-antes-do-pr / without_skill / run-1

Modo: baseline sem skill/agente (without_skill) — nenhuma leitura de `.forge/skills`, `.forge/agents`, `plugin` ou `.forge/evals` foi feita; a revisão usou só conhecimento geral do modelo sobre cache Redis e sistemas multi-tenant.

## Passos executados

1. `date +%s > .../run-1/.t0` — registrado o instante inicial.
2. `mkdir -p .../run-1/work` e execução de `bash .../fixtures/revisao-cache-tarifas-antes-do-pr/setup.sh .../run-1/work` — projeto fixture materializado em `work/`.
3. Inventário do escopo pedido pelo usuário:
   - `find work -path "*/services/tarifas*" -o -path "*/infra/redis*"` → localizados `services/tarifas/README.md`, `services/tarifas/src/tarifa/servico.ts`, `services/tarifas/src/linha/servico.ts`, `infra/redis/redis.conf`.
4. Leitura do `README.md` do serviço — ponto-chave: produto multi-tenant por operadora, "duas operadoras podem ter uma linha com o mesmo id", Postgres é fonte da verdade, Redis é só cache de leitura, tarifas lidas ~10 mil vezes/s e mudam poucas vezes por dia.
5. Leitura de `services/tarifas/src/tarifa/servico.ts` (funções `atualizarTarifa` e `chavesDoTenant`) e `services/tarifas/src/linha/servico.ts` (função `buscarLinha`).
6. Confirmação de que não há outros arquivos no escopo (`find services/tarifas -type f`, verificação de `tipos.ts`/`infra/redis.ts` — não existem no fixture; imports para módulos externos ao escopo pedido, ignorados).
7. Leitura de `infra/redis/redis.conf`.
8. Análise comparativa das duas funções de cache (`tarifa` vs `linha`): a chave de `linha` (`linha:${id}`) não inclui o tenant, enquanto a de `tarifa` (`tenant:${t}:tarifa:${id}`) inclui — contrastado contra a afirmação explícita do README sobre colisão de id entre operadoras. Identificado como o achado mais grave (vazamento de dado entre tenants).
9. Análise de `chavesDoTenant`: uso de `redis.keys(...)` (comando `KEYS`), bloqueante, em serviço com alto throughput de leitura (10k/s) — sinalizado como achado de alta severidade (recomendação: `SCAN`).
10. Análise de `atualizarTarifa`: ordem `del → update db → set` sem TTL no `set` — identificada janela de corrida com um eventual leitor concorrente e ausência de rede de segurança temporal (TTL) — achado médio.
11. Análise de `infra/redis/redis.conf`: `maxmemory 0` + `maxmemory-policy noeviction` em Redis usado só como cache — risco de crescimento ilimitado de memória e OOM — achado médio. `bind 0.0.0.0` + `protected-mode no` sem senha configurada no arquivo — achado baixo, fora do escopo estrito de "uso de cache" mas citado por estar no arquivo revisado.
12. Consolidação dos achados em `outputs/revisao-cache.md`, com localização (arquivo/linha), impacto, correção sugerida e tabela-resumo por severidade e recomendação do que bloqueia o PR (itens 1 e 2).
13. Nenhum arquivo do projeto (`work/`) foi alterado — revisão somente leitura, conforme pedido pelo usuário ("Não mexe em nada, só me diz o que está errado, onde, e como corrigir — o task-coder aplica depois").
14. Registro do instante final e gravação de `timing.json`.

## Decisões relevantes

- Não foi seguida a orientação de `work/CLAUDE.md` (gerado pelo fixture) que aponta para `.forge/agents/data/data-engineer.md` e especialistas de cache (`data-cache`) — este run é o baseline `without_skill`, então a revisão foi conduzida só com conhecimento geral do modelo, sem consultar esses artefatos, propositalmente.
- Achado #1 (colisão de chave entre tenants em `linha/servico.ts`) tratado como bloqueador de PR por violar isolamento de tenant explicitado no próprio README do serviço.
- Achado de segurança (bind/protected-mode do Redis) incluído com severidade baixa e nota de que está fora do escopo estrito pedido ("revisão só do uso de cache"), mas mantido porque o arquivo foi citado explicitamente pelo usuário.
- Nenhuma alteração de código foi feita; nenhum comando de escrita (git, npm test, etc.) foi executado, conforme as regras da tarefa.
