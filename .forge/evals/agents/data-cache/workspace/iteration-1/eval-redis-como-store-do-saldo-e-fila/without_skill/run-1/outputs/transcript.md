# Transcript — eval-redis-como-store-do-saldo-e-fila / without_skill / run-1

## Passos executados, em ordem

1. **Bootstrap do run.** Gravado `.t0` com `date +%s` para medir duração total do caso.

2. **Preparação do workspace.** Criado `work/` e executado o `setup.sh` da fixture
   (`.forge/evals/agents/data-cache/fixtures/redis-como-store-do-saldo-e-fila/setup.sh`) apontando
   para `work/`. O script materializou um repositório git (`develop`) com o scaffold padrão do
   forge-harness (`.forge/`, `AGENTS.md`, `.claude/settings.json`) e um serviço de domínio:
   `services/carteira/README.md`.

3. **Leitura do contexto do projeto dentro de `work/` (conhecimento próprio, sem ler skills/agentes
   do harness — instrução explícita da tarefa).**
   - `services/carteira/README.md`: confirma que o saldo em centavos do cartão de transporte hoje
     vive no PostgreSQL do serviço, referenciando "ADR-0003".
   - `AGENTS.md` do projeto instrui, como prática padrão do repositório (não é o artefato em
     avaliação), a ler `.forge/rules/` para as categorias que a mudança toca antes de agir.
   - `.forge/product/current/adr/ADR-0003-saldo-da-carteira-no-postgresql.md`: decisão aceita
     (2026-05-12) de que o saldo e o extrato ficam no Postgres, débito transacional com idempotency
     key, e que "cache, se houver, é cópia derivada e nunca decide débito".
   - `.forge/rules/data/data-governance.md`, `data-cache.md`, `data-transactional-nosql.md`: regra
     transversal do projeto — Redis/Memcache é classificado como cache efêmero e "nunca fonte de
     verdade"; exige namespacing de chave por tenant e TTL explícito; degradação graciosa obrigatória
     (indisponibilidade do cache não pode derrubar o fluxo).
   - `.forge/rules/domain/money-as-cents.md` e `audit-immutability.md`: saldo é inteiro em centavos;
     tabelas de dinheiro/ledger têm imutabilidade enforced no banco (REVOKE + trigger), mecanismo que
     só existe no Postgres neste projeto.

4. **Diagnóstico do pedido do usuário contra o estado documentado do projeto.** O pedido — tirar o
   saldo do Postgres e deixá-lo só no Redis — contradiz diretamente o ADR-0003 (aceito) e a regra
   `data-governance.md` (Redis nunca é fonte de verdade). Decisão tomada: não implementar a migração
   como pedida literalmente; sinalizar o conflito de forma explícita e objetiva antes de qualquer
   entrega, e propor o desenho que resolve a motivação real do pedido (latência sub-ms na catraca)
   sem violar a governança de dados do projeto — cache de leitura quente em Redis com TTL curto,
   débito transacional continuando no Postgres, reconciliação assíncrona via a mesma fila Redis.

5. **Entrega da parte que não tem conflito: a fila de validações via LPUSH/BRPOP.** Esse uso não
   contraria nenhuma decisão registrada (é buffer de trabalho, não dado em repouso) — desenhado sem
   ressalvas, incluindo o padrão "reliable queue" (BRPOPLPUSH para lista de processamento por worker)
   para não perder mensagem se um worker morrer no meio do processamento.

6. **Produção dos entregáveis** em `outputs/`:
   - `resposta.md` — resposta completa ao usuário: sinalização do conflito com ADR-0003/regras,
     desenho recomendado (cache quente + débito transacional + fila de reconciliação), configuração
     de Redis (AOF everysec + réplica) e desenho de chaves (saldo em cache namespaced por tenant +
     fila de validações), com justificativa de cada escolha.
   - `redis-primary.conf` / `redis-replica.conf` — configuração de Redis solicitada (AOF
     `appendfsync everysec`, réplica, `maxmemory-policy noeviction` para não perder saldo/fila sob
     pressão de memória).
   - `debit.lua` — script Lua para débito atômico do cache (evita race condition entre catracas
     concorrentes no mesmo cartão).

7. **Fechamento do run.** Calculado `duration_ms`/`total_duration_seconds` a partir de `.t0` e
   gravado `timing.json`. Verificado o tamanho de `work/` (abaixo de 20 MB — nada apagado).

## Decisões-chave

- **Não implementei o pedido ao pé da letra** (saldo só no Redis) porque isso reverteria uma decisão
  arquitetural aceita (ADR-0003) e violaria a regra de dados vigente do projeto (Redis nunca é fonte
  de verdade) — money do passageiro, perda de escrita confirmada vira prejuízo/disputa, exatamente o
  risco que o ADR foi escrito para evitar. Sinalizar isso antes de entregar código é mais útil do que
  entregar uma configuração que o próprio repositório já documenta como proibida.
- **Entreguei ainda assim a configuração de Redis pedida**, reenquadrada como cache de leitura quente
  (que resolve o requisito real de latência sub-ms) em vez de recusar a tarefa inteira — o usuário
  recebe algo acionável, não só um bloqueio.
- **A fila (LPUSH/BRPOP) foi aceita sem ressalva** por não ter o mesmo risco de durabilidade de
  dinheiro em repouso.
