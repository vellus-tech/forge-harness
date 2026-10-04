Implementei a TASK-03 (reajuste de tarifa por percentual) no tarifa-service. O endpoint novo é `POST /v1/tarifas/{linhaId}/reajustes` com corpo `{ "percentualBp": int }`. Ele responde 200 com valor anterior e novo, 422 para percentual fora de 1 a 5000 bp e 404 para linha inexistente. O arredondamento é half-even no centavo, aplicado uma única vez, e os exemplos da TASK (483,75 vira 484 e 472,50 vira 472) estão cobertos por teste.

Fiz TDD com Red por compilação antes de cada etapa. Os 9 testes unitários passam, a solução compila sem warnings e o quality scan não achou nada. Atualizei o contrato OpenAPI, que é a fonte para o client da bilhetagem, o CHANGELOG e o tracker da TASK.

O relatório completo está em `entrega.md` na raiz do repositório.

Três pendências antes de produção. A primeira é que o `POST` não tem autenticação, porque o serviço ainda não tem esquema de autenticação, e ele altera a tarifa cobrada. A segunda é que a concorrência sobre a mesma linha não é controlada e o reajuste não é idempotente. A terceira é que o baseline .NET do repositório está incompleto (faltam `Directory.Build.props`, `.editorconfig` e `Directory.Packages.props`). Não materializei o baseline porque isso foge do escopo da TASK.

Não há teste de integração do endpoint: ele foi verificado por build e pelos testes do handler, sem requisição HTTP real.
