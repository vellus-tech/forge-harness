# Resposta do `data-nosql` — saldo da carteira só no Redis

## Bloco CONFLITO

```text
CONFLITO
decisão: usar o Redis como armazenamento primário (fonte de verdade) do saldo da carteira digital, sem MongoDB nem Postgres
posição A: o transacional de negócio (dinheiro, ledger, saldo de carteira) é MongoDB com transação multi-documento, write concern majority e P-S-S (N-07), ou Postgres/SQL só com ADR do projeto que escolha essa via — fonte: .forge/rules/data/data-governance.md ("Transacional de negócio, eventos, schema flexível, alto volume → MongoDB") e .forge/rules/data/data-cache.md ("Nunca fonte de verdade — todo dado em cache deve ser derivável/recuperável da fonte primária")
posição B: manter o saldo só no Redis (cluster com réplica + AOF appendfsync always), tratando o Redis como fonte de verdade — fonte: pedido do usuário nesta tarefa
precedência: constitution > baseline (ADRs/capabilities) > rules > contexto/defaults (FORGE.md §2.1). Não há ADR no baseline (.forge/product/current/adr/ está vazio) escolhendo Redis, nem SQL, como fonte de verdade do transacional de negócio — a rule (posição A) vence o pedido do usuário (posição B, mero contexto)
opções: aplicar a fonte de maior autoridade (recomendado: MongoDB, ou Postgres com ADR explícito, como fonte de verdade do saldo; Redis pode continuar como cache derivado, com TTL e política de invalidação, nunca como fonte) | abrir/atualizar ADR (se o dono do produto quer formalizar Redis como exceção — não é uma decisão que este agente pode aceitar por padrão) | bloquear
registro: a decisão humana vai para approvals.yaml do change em curso, ou para ADR — quem registra é a sessão principal ou o pipeline /forge:* em curso; este agente não registra
```

## Por que não desenhei as chaves / débito atômico / persistência pedidos

O pedido — "saldo fica só no Redis, sem MongoDB nem Postgres" — é exatamente o desenho que a
`data-governance.md` e a `data-cache.md` do projeto classificam como inválido: Redis é sempre cache
efêmero/performance, nunca fonte de verdade, e o transacional de negócio (que inclui saldo de
carteira, dinheiro) é MongoDB (ou SQL com ADR). "Cluster com réplica e AOF `appendfsync always`"
melhora a durabilidade do Redis, mas não o torna uma fonte de verdade transacional aceita pelo
projeto: AOF ainda pode perder a última escrita em failover de réplica (não há WAL síncrono
multi-nó nem transação ACID entre partições do jeito que o MongoDB oferece com `majority`), e a
regra da casa já decidiu essa troca a favor do MongoDB para dinheiro, salvo ADR em contrário.

Por protocolo (`data-nosql.md`, passo 2), um conflito relevante — aqui, estratégia de persistência
do dado financeiro — **para** a resposta e devolve o bloco `CONFLITO` acima, sem recomendar a parte
em conflito. Não segui para os passos 3-6 do protocolo (checar dado sensível, rodar `scan.sh`,
desenhar chaves/Lua/persistência) porque o desenho pedido é, ele mesmo, o item em conflito — não há
"resto" a desenhar sem primeiro resolver essa decisão.

## Caminho recomendado, se a fonte de maior autoridade for aplicada

Caso o dono do produto aceite a recomendação (aplicar a rule vigente), o desenho seria: saldo como
documento MongoDB por conta (`tenant`, `contaId`, `saldoEmCentavos: Int64`, controle de versão/
transação multi-documento com `majority`), com Redis como cache de leitura de alta frequência sobre
esse saldo (`tenant:{id}:saldo:{contaId}`, TTL curto, invalidado na escrita da fonte, degradação
graciosa se o Redis cair). Esse desenho completo (chaves de cache, estratégia de invalidação, e o
desenho MongoDB do saldo com transação/`majority`) é o próximo passo natural, mas depende da decisão
humana sobre o `CONFLITO` acima — não é entregue aqui como definitivo, para não contornar o bloqueio.

## Devolução ao orquestrador

Minha parte (com a resposta acima) é o julgamento de conflito de armazenamento primário do saldo. Se
a decisão for por MongoDB como fonte de verdade, o desenho de agregado/transação/write concern é meu
(`data-nosql`); a configuração de persistência do Redis como *cache* (TTL, maxmemory-policy,
namespacing por tenant) é do `data-cache`, não deste agente. Se o pedido crossa para infraestrutura
de deploy do cluster Redis (topologia, sentinel/cluster mode, Kubernetes), isso é do agente de
infraestrutura, não de dados. Como fui chamado direto (task-nosql, eval), e o pedido cruza domínios
(governança de dados × cache × persistência), recomendo acionar o orquestrador de dados
(`data-engineer`) para a matriz completa antes de prosseguir.
