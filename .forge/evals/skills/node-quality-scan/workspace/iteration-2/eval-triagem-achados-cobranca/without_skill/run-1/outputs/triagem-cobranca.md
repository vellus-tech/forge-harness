# Triagem dos achados do scan de qualidade: servico-cobranca 2.3.1

Escopo: revisão do código em `src/` e `test/` do serviço (commit `0d77001`). Nenhum código foi alterado. O relatório do scan não estava no workspace; a triagem cobre os cinco achados citados no pedido.

## Resumo

Dos cinco achados, um é defeito real e bloqueante para o release: a query de `marcarPaga` monta SQL por interpolação de string. Os outros quatro não são defeitos de comportamento. Dois merecem um item de dívida registrado (pool sem encerramento e cast `as never` no TLS), e um pede decisão sobre código sem chamador (`agendarLembrete`).

## Achado por achado

### 1. Pool do pg (`src/db/bootstrap.ts`): deixar como está

O `Pool` é criado uma vez, no import, com `max: 10`, e é o único ponto de criação, como o próprio comentário declara. O `pg` só abre conexões na primeira query, então o módulo não conecta na importação. Não há defeito de comportamento.

Ressalvas, sem bloquear o release: o pool nunca é encerrado (não há `pool.end()` em sinal de desligamento), e `config` é lido na importação. Ambos são melhorias de encerramento gracioso, não correção.

### 2. `readFileSync` (`src/boot.ts`): deixar como está, com ressalvas

A leitura síncrona acontece uma vez, antes do `listen`. Bloquear o event loop nesse ponto é o comportamento desejado, e o custo é nulo. Não é defeito.

Ressalvas reais que não são o achado em si: `key: cert` pressupõe um único PEM com certificado e chave; o `as never` esconde um erro de tipagem em vez de resolvê-lo; e o default `./certs/dev.pem` faz o serviço subir com certificado de desenvolvimento se `TLS_CERT_PATH` não for definido em produção. Esta última é a mais séria das três e merece item de dívida para exigir a variável em produção.

### 3. Interface `CobrancaRepository` com uma implementação só: deixar como está

A interface é a porta do domínio, e o domínio é o consumidor. Ela tem dois consumidores reais: a implementação `PgCobrancaRepository` e o fake em memória de `test/fakes.ts`. `rotas.ts` e `jobs/lembrete.ts` dependem só do contrato. Remover a interface acoplaria as rotas ao `pg` e quebraria o teste sem banco. Não é over-engineering.

### 4. `.then` em `src/jobs/lembrete.ts`: deixar o `.then`, decidir sobre a função

O encadeamento `.then(...).catch(...)` está correto: o `catch` também captura erro do callback do `then` e da própria `buscar`, então não há rejeição não tratada. Trocar por `async/await` seria só estilo.

O problema real é outro: `agendarLembrete` não tem nenhum chamador no código (verificado com busca em `src/` e `test/`). Ou a função é código morto, ou o agendamento ainda não foi ligado e está pendente. Isso precisa de decisão do time antes do release, mas não é defeito do `.then`.

### 5. Query em `PgCobrancaRepository.marcarPaga`: defeito real, bloqueante

A linha `UPDATE cobrancas SET status = 'paga', pago_em = now() WHERE id = '${id}'` interpola o parâmetro de rota diretamente na SQL. O `id` vem de `req.params.id` em `POST /cobrancas/:id/pagamento`, então qualquer cliente que alcance a rota controla o texto da query. Isso é SQL injection. Agravante: a rota não tem autenticação no código deste serviço.

A correção é mecânica e segue o padrão que o próprio `buscar` já usa: `WHERE id = $1` com `[id]` como parâmetro. Além disso, o mesmo método tem dois problemas de comportamento que a correção deve tratar: não verifica quantas linhas foram afetadas, então a rota responde 204 mesmo para um `id` inexistente; e não verifica a transição de status, então uma cobrança `cancelada` pode virar `paga`.

Recomendação: corrigir antes do release, com teste de regressão que envie um `id` malicioso e confirme que a query não o executa como SQL, e com teste de id inexistente.

## Fora dos cinco achados, observado na leitura

A rota `POST /cobrancas/:id/pagamento` altera estado sem autenticação nem autorização visíveis no código. Pode ser tratada na camada de gateway, mas não há evidência disso neste repositório. Vale confirmar antes do release.

Não há teste de integração com banco: `test/fakes.ts` é o único teste de apoio, e ele não exercita `PgCobrancaRepository`. Por isso a injeção acima não seria pega pela suíte atual.

## Itens para registrar como dívida (não bloqueantes)

- Encerramento gracioso do pool no sinal de desligamento.
- Tipar o TLS corretamente, sem `as never`, e exigir `TLS_CERT_PATH` em produção.
- Decidir se `agendarLembrete` será ligado a um chamador ou removido.
- Teste de integração contra banco para `PgCobrancaRepository`.
