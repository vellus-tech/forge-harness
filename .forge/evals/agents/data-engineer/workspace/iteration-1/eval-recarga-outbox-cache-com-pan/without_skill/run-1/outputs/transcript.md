# Transcript — eval recarga-outbox-cache-com-pan / without_skill / run-1

## Contexto de execução

Caso de eval `without_skill`: nenhuma skill/agente do harness foi lida (nem `.forge/skills`, nem
`.forge/agents`, nem `plugin/`, nem `.forge/evals`) — a tarefa foi resolvida só com conhecimento
próprio do modelo sobre outbox pattern, cache invalidation e classificação de dados sensíveis
(PCI DSS / PAN).

## Passos executados

1. `date +%s > .t0` — instante inicial registrado.
2. `mkdir -p work` + `bash <fixtures>/setup.sh work` — materializou o projeto fixture dentro de
   `work/` (estrutura `.forge`/`.claude`/`AGENTS.md`/`CLAUDE.md` + `src/recarga/`).
3. Leitura de `work/src/recarga/confirmar-recarga.ts` (código-alvo apontado pelo usuário) e de
   `work/src/recarga/data-classification.json` (classificação de `numeroCartao`, `cpf`,
   `valorCentavos`) e de `work/AGENTS.md` para entender convenções do projeto (dinheiro em
   centavos inteiros, sem prefixo de tecnologia em nomes, multi-tenant).

## Leitura do código e diagnóstico

- `confirmarRecarga` faz commit no Mongo (status + saldo) dentro de uma transação, depois
  `canal.publish` no RabbitMQ **fora** da transação, depois `redis.del` da chave de cache. O
  próprio comentário no código já admite a falha ("se o pod cair aqui, o evento se perde") — é o
  sintoma relatado pelo usuário.
- Identificado um segundo problema não mencionado pelo usuário: a chave de cache
  `saldo:<sha256(cpf)>` não inclui `tenant`. Como o CPF é a mesma pessoa física possivelmente
  cadastrada em mais de uma operadora (tenant), a chave colide entre tenants — bug de isolamento
  multi-tenant, agravante do sintoma relatado (saldo errado servido pode ser de outro tenant, não
  só desatualizado).
- Identificado um terceiro problema, de classificação de dados: `data-classification.json` marca
  `numeroCartao` como `classification: pan`, `tokenization_boundary: true`, com máscara
  obrigatória. O payload publicado no RabbitMQ carrega `numeroCartao` completo — viola a política
  de mascaramento ao cruzar uma fronteira (múltiplos consumidores/retenção em disco no broker).
  Tratado como achado relevante mesmo fora do que foi perguntado, porque está no mesmo trecho de
  código revisado e é um risco de conformidade (PCI DSS) mais sério que o bug de concorrência.

## Decisões de design

- **Outbox transacional** em vez de publish direto: grava-se o evento na mesma transação Mongo
  (coleção `outbox`, `publicadoEm: null`); um processo relay separado publica no RabbitMQ e marca
  `publicadoEm`. Decisão: usar polling simples com índice em `publicadoEm`/`criadoEm` como
  baseline, mencionando Change Streams como alternativa de menor latência — não implementado em
  detalhe porque foge do escopo do código revisado.
- **Consumidor idempotente** para a invalidação de cache, porque outbox + relay é at-least-once
  (pode publicar duplicado se o processo cair entre `publish` e `updateOne`). Deduplicação por
  `eventoId` via `SET NX` no Redis.
- **TTL curto (45s) como rede de segurança**, independente do evento chegar: decisão explícita de
  não depender só de invalidação event-driven para o pior caso ("saldo errado por alguns minutos")
  — com TTL, o pior caso vira o valor do TTL configurado, não um tempo indefinido.
- **Chave de cache com tenant**: `saldo:<tenant>:<hash(cpf)>` em vez de `saldo:<hash(cpf)>`.
- **Mascaramento do PAN antes de persistir no outbox** (não só antes de publicar), porque o outbox
  também é um armazenamento persistente sujeito a leitura/retenção — mascarar cedo, na origem, é
  mais seguro do que mascarar só no ponto de publicação.
- Optou-se por manter a alteração como uma proposta de redesenho (documento + esboços de código em
  `outputs/`) em vez de aplicar diretamente sobre `work/`, já que o pedido do usuário foi "revisa
  esse fluxo e me diz como desenhar direito" — resposta é uma recomendação técnica, não um PR.

## Entregáveis produzidos

- `outputs/design-outbox-cache.md` — diagnóstico completo + redesenho (outbox, TTL, idempotência,
  chave por tenant, mascaramento de PAN) com o porquê de cada decisão.
- `outputs/confirmar-recarga.proposed.ts` — versão proposta do comando, escrevendo no outbox dentro
  da transação em vez de publicar/invalidar diretamente.
- `outputs/relay-outbox.proposed.ts` — esboço do processo relay outbox → RabbitMQ.
- `outputs/consumidor-saldo-cache.proposed.ts` — esboço do consumidor idempotente que invalida o
  cache de saldo, com TTL de rede de segurança.

## Ações NÃO executadas (fora do escopo do run)

- Nenhum `git commit`/`push`/`checkout`/`stash`.
- Nenhum `npm test`/`tests/run-all.sh`/`docker`/`ledger-ops.sh`/`liaison-ops.sh`/`gh` (escrita)/
  `npm publish`/deploy real.
- Nenhum subagente foi spawnado (não haveria motivo para isso nesta tarefa — é revisão/design de
  um único arquivo).
