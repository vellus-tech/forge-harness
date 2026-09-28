# Transcript — eval-revisao-cobranca-mongodb / without_skill / run-1

Condição: baseline sem skill. Nenhum arquivo em `template/.forge/skills`, `template/.forge/agents`, `plugin` ou `.forge/evals` foi lido. Revisão feita apenas com conhecimento próprio de MongoDB/NoSQL.

## Passos executados

1. Registrei o instante inicial em `.t0` (`date +%s`).
2. Criei `work/` e rodei `fixtures/revisao-cobranca-mongodb/setup.sh work/` para materializar o projeto fixture (`services/cobranca`, `docs/contexto-cobranca.md`, mais scaffolding `.claude`/`.forge` do fixture, que não abri).
3. Explorei a árvore do serviço:
   - `find work/services/cobranca -type f` → 5 arquivos de código + `infra/mongod.conf`.
   - `find work/docs -type f` → `docs/contexto-cobranca.md`.
4. Li `docs/contexto-cobranca.md` — contexto: MongoDB 7.0, replica set 3 membros (P-S-S), multi-tenant (tenant = operadora de transporte), padrões de acesso (extrato ~1.800 req/s, listagem de faturas do backoffice, fechamento 02:00, transferência de crédito com picos concorrentes no início do mês, faturas contestadas com milhares de eventos).
5. Li o código da camada de dados, um arquivo por vez:
   - `services/cobranca/infra/mongod.conf`
   - `services/cobranca/src/repositorios/faturaRepositorio.ts`
   - `services/cobranca/src/transferencia/transferirCredito.ts`
   - `services/cobranca/src/api/extratoHandler.ts`
   - `services/cobranca/src/relatorios/fechamentoNoturno.ts`
   - `services/cobranca/test/seed.ts` (só para confirmar que é seed de teste, sem impacto em produção)
6. Analisei cada arquivo contra o contexto de uso declarado (volume, concorrência, multi-tenant, natureza financeira dos dados) e contra práticas conhecidas de MongoDB: isolamento de tenant nas queries, atomicidade de escrita de saldo em transferência concorrente, retry de transação, cobertura de índice para os padrões de acesso descritos, limite superior em filtro de data para job de fechamento diário, mismatch de tipo `string`/`ObjectId` em parâmetro de rota, writeConcern consistente para dado financeiro, array embutido sem limite para um campo que "chega a milhares" de itens, e configuração de rede/TLS do `mongod.conf`.
7. Não propus nem apliquei correção de código — apenas diagnóstico, conforme pedido.
8. Escrevi o relatório em `work/docs/revisao-nosql.md` (sumário executivo, 8 achados com arquivo/trecho/recomendação, seção do que já está correto, e prioridade sugerida antes do PR).
9. Copiei o relatório para `outputs/revisao-nosql.md` e escrevi este transcript.
10. Vou gravar `timing.json` com o intervalo entre `.t0` e o instante final, e verificar o tamanho de `work/` para decidir se apago (limite 20 MB).

## Achados reportados (resumo)

1. `buscarPorCliente` sem filtro de `tenant` — vazamento potencial entre operadoras (bloqueador).
2. `transferirCredito` nunca atualiza `saldos` e tem janela de corrida entre transferências concorrentes na mesma carteira (bloqueador); falta também retry de transação transitória.
3. `fechamentoNoturno` com filtro de data só de limite inferior — arrasta faturas de dias futuros para a conciliação (bloqueador para a correção do relatório).
4. `extratoHandler` compara `_id` (possivelmente `ObjectId`) com `req.params.id` (`string`) — risco de mismatch de tipo na rota mais quente (confirmar antes do PR).
5. Nenhum índice definido no repositório para nenhuma das consultas revisadas (alto risco de performance, especialmente no `$lookup` do extrato a 1.800 req/s).
6. Array `eventos` embutido e ilimitado em faturas que podem chegar a milhares de eventos (dívida técnica, não bloqueador).
7. `writeConcern: { w: 1 }` em `criar` fatura, inconsistente com `w: "majority"` usado na transferência (risco de durabilidade para dado financeiro).
8. `mongod.conf` sem `net.tls` e `bindIp: 0.0.0.0` — confirmar cobertura de TLS/rede fora deste arquivo.

Pontos positivos registrados: uso de `Decimal128` para valores monetários, estrutura de transação já presente na transferência, `readPreference: secondaryPreferred` no job noturno, isolamento de tenant correto em `registrarEvento`.
