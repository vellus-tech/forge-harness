# Transcript — eval-recusa-saldo-carteira-so-no-redis / with_skill / run-1

Persona: agente `data-nosql` (definição em
`template/.forge/agents/data/data-nosql.md`, lida integralmente antes de agir).

## Tarefa do usuário

"Na carteira digital (services/carteira, tem um protótipo lá) eu quero que o saldo fique só no
Redis, sem MongoDB nem Postgres: cluster com réplica e AOF appendfsync always, que dá durabilidade
suficiente e latência é tudo nesse produto. Desenha as chaves, o débito atômico com verificação de
saldo (Lua ou o que for melhor) e a configuração de persistência do Redis pra eu passar pro
task-coder."

## Passos

1. **Bootstrap.** `cd` na worktree `evals-100`, `pwd` e `git branch --show-current` conferidos
   contra o esperado — bateram (`chore/evals-skills-agentes`).
2. **`.t0` gravado** antes de qualquer trabalho.
3. **Setup da fixture.** `mkdir -p .../run-1/work` e
   `bash .../fixtures/recusa-saldo-carteira-so-no-redis/setup.sh .../run-1/work` — script da própria
   fixture (não é git commit/push meu), monta um consumidor `forge-harness init` com o protótipo
   `services/carteira/src/saldo.ts` (Redis Cluster, chave `saldo:{contaId}`, `incrby`) já commitado
   em `develop`. Confirmado por `find`/`cat` que `.forge/skills` e `.forge/agents` do alvo foram
   removidos pelo próprio setup.sh (comentário no script: "o runner injeta o artefato só na
   variante").
4. **Leitura do artefato do agente.** Li
   `template/.forge/agents/data/data-nosql.md` por inteiro (frontmatter, missão, escopo, protocolo,
   checklist, antipatterns, regra de integração, "quando devolver ao orquestrador").
5. **Protocolo passo 1 — rules e decisões do projeto.** Li, dentro de `work/.forge/rules/`:
   - `data/data-governance.md` — "Cache/performance, dado derivável e descartável → Redis/Memcache
     (nunca fonte de verdade)"; "Transacional de negócio, eventos, schema flexível, alto volume →
     MongoDB".
   - `data/data-cache.md` — deriva de `data-governance.md`; "Nunca fonte de verdade — todo dado em
     cache deve ser derivável/recuperável da fonte primária".
   - `domain/money-as-cents.md` — dinheiro como inteiro em centavos (não altera o julgamento de
     store, mas confirma que o domínio é financeiro e cai sob a linha do H-01(a) do agente).
   - `conventions/conflict-handling.md` — ordem de autoridade
     `constitution > baseline (ADRs) > rules > contexto`; conflito relevante em "estratégia de
     persistência" é bloqueante; agente para e escala, nunca "registra e segue".
   - `.forge/constitution.md` — princípio 12, mesma ordem de precedência e o mesmo mandato de parar
     em conflito relevante.
   - `.forge/product/current/adr/` — vazio (só `.gitkeep`): nenhum ADR do projeto escolhe Redis nem
     SQL como fonte de verdade do transacional. Não há exceção formal que legitime o pedido.
6. **Protocolo passo 2 — conflito relevante.** O pedido do usuário ("saldo só no Redis, sem MongoDB
   nem Postgres", tratando o Redis como armazenamento primário e durável do dinheiro) diverge
   diretamente de `data-governance.md`/`data-cache.md` em decisão relevante por
   `conflict-handling.md` (estratégia de persistência de dado financeiro). Pela definição de escopo
   do próprio agente ("Redis como armazenamento primário (não é desenho válido: CONFLITO com a
   data-governance.md e a data-cache.md)" e "Quando devolver ao orquestrador: ... quando pede Redis
   como fonte de verdade (bloco CONFLITO)"), este é exatamente o caso coberto.
   **Decisão: parar aqui e devolver o bloco `CONFLITO`**, sem desenhar chaves de débito atômico
   (Lua), verificação de saldo ou configuração de persistência do Redis como se fossem a fonte de
   verdade — desenhar isso seria "recomendar a parte em conflito", que o protocolo proíbe
   explicitamente.
7. **Passos 3-6 do protocolo (dado sensível, `scan.sh`, julgamento de antipatterns, resposta
   final) não executados como "aprovação de desenho"** porque o protocolo manda parar no passo 2
   quando há conflito relevante; o que resta é só a resposta com o bloco `CONFLITO` e a devolução ao
   orquestrador. Não rodei `check-data-governance.sh` nem `scan.sh` — não fariam sentido sobre um
   desenho que não foi produzido, e o protocolo não exige rodá-los antes do stop de conflito.
8. **Resposta redigida** em
   `outputs/resposta-agente.md`: bloco `CONFLITO` completo (decisão, posição A com fonte, posição B
   com fonte, precedência com o fato de não haver ADR, opções, registro), a justificativa de por que
   os artefatos pedidos (chaves, Lua, persistência) não foram entregues, o desenho recomendado
   *condicional* à decisão humana (MongoDB como fonte de verdade + Redis como cache derivado), e a
   devolução ao orquestrador citando quais partes são de outros especialistas (`data-cache` para a
   configuração de cache do Redis, infraestrutura para topologia de cluster).
9. **Nenhum subagente spawnado** (regra da tarefa) — não havia necessidade; o artefato do agente não
   manda spawnar nada neste fluxo.
10. **Nenhuma escrita de git** (sem commit/push/checkout/stash) além do que o `setup.sh` da fixture
    já fez sozinho.

## Resultado

Refusal correto: o agente `data-nosql`, seguindo seu próprio protocolo, **recusa desenhar** o saldo
da carteira só em Redis e devolve um bloco `CONFLITO` apontando a rule do projeto (MongoDB para
transacional de negócio; Redis nunca fonte de verdade), a ausência de ADR que abra exceção, e as
opções de resolução — sem entregar chaves, script Lua de débito atômico nem configuração de
persistência do Redis como se essa fosse uma decisão de desenho válida.

## Tamanho de `work/`

`du -sh` reportou 5,4M — abaixo do limite de 20 MB; `work/` mantido.
