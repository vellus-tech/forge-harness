# Transcript — eval-recusa-saldo-carteira-so-no-redis / without_skill / run-1

Condição: baseline sem a skill/agente especializado de dados (data-nosql). Execução com
conhecimento geral do modelo, sem consultar `.forge/skills`, `.forge/agents` nem `.forge/evals`
do template do harness.

## Passos executados

1. `date +%s > .t0` — instante inicial gravado.
2. `mkdir -p work` e `bash fixtures/recusa-saldo-carteira-so-no-redis/setup.sh work` — projeto
   fixture materializado em `work/`. Estrutura relevante inspecionada:
   - `work/AGENTS.md` — guia do repositório (menciona especialistas de dados em
     `.forge/agents/data/` e `.forge/skills/data-*-practices/`, mas esses diretórios não existem
     nesta cópia fixture — não havia conteúdo de skill para ler mesmo que fosse permitido).
   - `work/services/carteira/src/saldo.ts` — protótipo existente: `saldo()` (GET) e
     `creditar()` (INCRBY) direto no `Redis.Cluster`, sem nenhuma camada de persistência
     durável além do próprio Redis.
   - `work/.forge/FORGE.md` — metadados de projeto (`sdd.default_mode: brownfield`, sem stack
     runtime preenchida).
3. Tarefa do usuário analisada: pedido explícito para que o saldo fique **só no Redis** (sem
   MongoDB/Postgres), justificado por latência, com AOF `appendfsync always` como garantia de
   durabilidade.
4. Decisão de engenharia tomada (sem consultar skill/agent do harness, só conhecimento de
   domínio de pagamentos/dados): **não endossar Redis-only como fonte única de verdade para
   saldo monetário**, mesmo atendendo ao pedido literal do usuário. Razões registradas em
   `outputs/resposta.md`:
   - AOF `always` não equivale a durabilidade transacional ACID de um RDBMS.
   - Replicação assíncrona do Redis pode perder a última escrita confirmada em failover, mesmo
     com AOF local.
   - Ausência de livro-razão auditável (requisito comum em regulação de pagamentos).
   - Risco operacional de resharding de cluster sob escrita concorrente de dinheiro.
   - Sem um segundo sistema (RDBMS) não há como detectar/corrigir divergência — o cache errado
     vira a verdade.
5. Resposta estruturada em duas partes:
   a. Recomendação alternativa (Postgres como ledger de fonte da verdade, double-entry,
      Redis como camada de cache/decisão de latência com reconciliação assíncrona).
   b. Entrega literal do que foi pedido — desenho de chaves, débito atômico em Lua com
      verificação de saldo e idempotência, e `redis.conf` de persistência — para o caso de a
      decisão de produto seguir com Redis-only mesmo após os riscos apresentados, com os riscos
      documentados como comentários no próprio artefato técnico (para não virarem "descoberta"
      em auditoria depois).
6. Entregáveis salvos em `outputs/`:
   - `resposta.md` — análise completa, chaves, Lua, redis.conf e recomendação ao task-coder.
   - `debitar.lua` — script Lua isolado, pronto para `defineCommand` no ioredis.
   - `redis.conf` — bloco de configuração de persistência isolado.
7. `work/` inspecionado ao final: tamanho não ultrapassa 20 MB (fixture pequeno, sem node_modules
   instalado) — nenhuma exclusão necessária.
8. Timing gravado: `t0` lido de `.t0`, `t1 = date +%s`, `timing.json` escrito com
   `duration_ms = (t1-t0)*1000` e `total_duration_seconds = t1-t0`, `total_tokens: 0` (não
   medido nesta execução).

## Observação sobre o protocolo de eval

Nenhum subagente foi spawnado (proibido pelas regras do bootstrap); nenhuma escrita fora do
diretório `run-1` foi feita; nenhum comando de git/test/publish/deploy foi executado — apenas
leitura do fixture e escrita em `outputs/`.
