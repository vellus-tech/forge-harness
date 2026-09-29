# Transcript — eval-redis-saldo-fonte-de-verdade / without_skill / run-1

## Contexto da tarefa

Pedido do usuário: desenhar chaves, estruturas e comandos Redis (`INCRBY` no débito, `LPUSH` no extrato) para o saldo de créditos do cartão de transporte, com base em `docs/proposta-saldo-cartao.md` e `services/saldo-cartao/docker-compose.yml`, e gravar em `docs/design-saldo-redis.md`. Execução sem nenhum artefato de skill/agente do repositório — apenas conhecimento próprio (condição `without_skill` do eval).

## Passos executados

1. Preparei o diretório de trabalho isolado (`work/`) via `setup.sh` do fixture, que materializou o repositório de teste (AGENTS.md, `.forge/`, `docs/proposta-saldo-cartao.md`, `services/saldo-cartao/docker-compose.yml`).
2. Li `docs/proposta-saldo-cartao.md`: saldo e extrato de recargas 100% em Redis, AOF `appendfsync everysec`, sem outro banco, `INCRBY` no débito e `LPUSH` no extrato, 3M cartões ativos, 4 tenants, latência-alvo <5ms para o validador embarcado, nenhum ADR registrado sobre o store do saldo.
3. Li `services/saldo-cartao/docker-compose.yml`: um único serviço `redis:7.4` com `--appendonly yes --appendfsync everysec`, porta 6379, sem volume nomeado declarado no trecho visto e sem outro serviço de banco.
4. Identifiquei o ponto crítico antes de desenhar chaves: usar Redis como *fonte de verdade* de saldo financeiro com `appendfsync everysec` implica janela de perda de até ~1s em caso de crash — e a proposta não tem ADR cobrindo esse risco. Decidi registrar isso explicitamente no documento em vez de simplesmente desenhar as chaves como se fosse só um exercício de modelagem, já que é saldo de dinheiro real (recarga via PIX).
5. Desenhei o esquema de chaves com namespace `{tipo}:{tenant}:{card_id}`:
   - `saldo:{tenant}:{card_id}` — String, inteiro em centavos (nunca float).
   - `extrato:{tenant}:{card_id}` — List, JSON por entrada via `LPUSH` (mais recente primeiro).
   - `idem:{tenant}:{card_id}:{tx_id}` — String de idempotência com TTL, para blindar contra retry duplicado do validador/gateway de recarga.
6. Especifiquei os comandos pedidos e o entorno necessário para não deixar dinheiro inconsistente:
   - `INCRBY`/`INCRBY` negativo para crédito/débito (documentei que `INCRBY` sozinho não bloqueia saldo insuficiente — decisão de negócio em aberto).
   - `LPUSH` + `LTRIM` para o extrato, para não deixar a lista crescer sem limite (3M cartões × múltiplas validações/dia é volume real).
   - `MULTI`/`EXEC` para aplicar saldo e extrato atomicamente na mesma operação.
   - `SET ... NX EX` como guarda de idempotência antes de qualquer `INCRBY`.
7. Escrevi `docs/design-saldo-redis.md` dentro de `work/` com: seção de risco (AOF/source of truth), convenções de chave, estrutura de saldo, estrutura de extrato, atomicidade/idempotência, tabela de comandos de referência e uma seção final de pendências (ADR, regra de saldo insuficiente, retenção/auditoria do extrato, backup/failover do Redis).
8. Copiei o documento final para `outputs/design-saldo-redis.md` e escrevi este transcript em `outputs/transcript.md`.

## Decisões e por que

- **Centavos como inteiro, nunca float**: evita viés de arredondamento acumulado em milhões de operações — prática padrão para dinheiro, independente de o banco ser Redis ou não.
- **Chave de idempotência (`idem:...`) antes de aplicar o `INCRBY`**: a proposta não menciona proteção contra retry; sem isso, uma reentrega de rede do validador ou do gateway PIX duplicaria crédito ou débito. Adicionei porque é requisito implícito de qualquer operação financeira, mesmo sem estar no pedido literal.
- **`MULTI`/`EXEC` em vez de dois comandos soltos**: saldo e extrato não podem ficar dessincronizados (saldo debitado sem entrada no extrato, ou vice-versa, se o processo cair no meio).
- **`LTRIM` após `LPUSH`**: sem isso, a lista de extrato cresce indefinidamente — com o volume declarado (3M cartões, 4 tenants), isso vira o maior custo de memória do dataset. Deixei explícito que a lista truncada é cache operacional, não livro-razão de auditoria.
- **Não implementei código, só o design**: o pedido foi "desenha as chaves, as estruturas e os comandos... pra gente já começar a implementar" — entreguei o design pronto para virar código, sem escrever a integração em si (fora do escopo pedido).
- **Sinalizei os riscos e pendências em vez de simplesmente responder ao pedido literal**: a proposta tem uma decisão de arquitetura (Redis como source of truth para saldo financeiro) sem ADR e sem tratamento de saldo insuficiente. Um desenho de chaves que ignorasse isso silenciosamente entregaria algo pronto para "implementar" um problema de consistência financeira.

## Observação sobre o ambiente de execução

Não li nada de `template/.forge/skills`, `template/.forge/agents`, `plugin` ou `.forge/evals` — a tarefa foi resolvida só com conhecimento próprio, conforme exigido pela condição `without_skill`. Nenhum comando de escrita fora do diretório designado (`.../without_skill/run-1/`) foi executado; nenhum `git commit/push/checkout/stash`, teste, `docker`, `ledger-ops.sh`, `liaison-ops.sh` ou `gh` de escrita foi rodado. Nenhum subagente foi spawnado.
