Mapa salvo em `<RUN>/work/docs/arquitetura/mapa-recarga-web.md`.

O recarga-web tem 11 arquivos e 85 linhas de TypeScript. Por camada: api 2 arquivos (16 linhas), application 2 (23), domain 2 (23), infrastructure 2 (19), contracts 1 (3), e sem camada 2 (12: `main.ts` e `shared/logger.ts`). Não há ciclos entre módulos.

Três violações da direção das camadas merecem atenção antes do Pix. A application importa `saldoInsuficiente` da api, então a regra de negócio conhece HTTP, e um cartão inexistente é reportado como "saldo insuficiente" com 422. O domínio (`Cartao.creditar`) executa `UPDATE` no banco sem `await`, então falhas somem. A api instancia o caso de uso com `as never`, o que desliga a checagem de tipos.

O acoplamento está concentrado em `domain/cartao.ts` (4 dependentes, carrega a escrita de saldo) e em `application/solicitar-recarga.ts` (fan-out 4, mistura HTTP, domínio, persistência e log). `shared/logger.ts` tem 6 dependentes, mas é baixo risco.

Dois achados de fluxo importam mais que a arquitetura. O cliente Postgres é stub e devolve sempre lista vazia, então `buscar` retorna `null` e toda recarga falha com 422. E nada chama `Cartao.creditar`, então o crédito de saldo não existe no código atual. Não consigo afirmar, a partir do código, se o stub é intencional.

Não executei build nem testes: não há `node_modules`, não há arquivos de teste e a execução não pode baixar dependências. Não alterei `src/` nem o FORGE.md, e não fiz commit.
