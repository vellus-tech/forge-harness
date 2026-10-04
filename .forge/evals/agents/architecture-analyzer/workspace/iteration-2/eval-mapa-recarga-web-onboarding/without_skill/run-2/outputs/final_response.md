Mapa salvo em `work/docs/arquitetura/mapa-recarga-web.md`.

Resumo: 11 arquivos e 85 linhas em api, application, domain, contracts, infrastructure, shared e uma raiz de composição (main.ts). Duas violações da regra camadas-recarga-web.md: `domain/cartao.ts` importa o cliente de banco e faz UPDATE sem await; `application/solicitar-recarga.ts` importa erro HTTP da camada de API, e cartão inexistente recebe 422 de saldo insuficiente. O acoplamento se concentra em `shared/logger.ts` (6 importadores), `domain/cartao.ts` (4) e `postgres-client.ts` (dois caminhos de acesso ao banco).

Ponto crítico para o Pix: o fluxo atual gera o evento `RecargaSolicitada` e não o consome nem persiste; `Cartao.creditar` não tem chamador; não há código de Pix. A decisão de onde o crédito acontece precisa ser tomada antes da integração.

Limitações: não rodei build nem testes (sem dependências e sem suíte em src/); não consegui reproduzir os fingerprints do grafo, então usei leitura direta do código para conferir as 19 arestas.
