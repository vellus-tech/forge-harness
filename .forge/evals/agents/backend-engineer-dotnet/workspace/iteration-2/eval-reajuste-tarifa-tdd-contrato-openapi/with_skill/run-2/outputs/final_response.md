OK

Implementei a TASK-03 (reajuste de tarifa por percentual) no tarifa-service, seguindo REQ-004, DD-001 e DD-002. O relatório completo está em `<RUN>/work/entrega.md`.

Teste primeiro: os exemplos da TASK-03 (430 com 1250 bp dá 484; 420 com 1250 bp dá 472 por half-even) e a faixa 1 a 5000 bp foram escritos antes e falharam. Depois da implementação, a suíte passou a 6 de 6, com build sem erros e sem avisos.

O endpoint novo é `POST /v1/tarifas/{linhaId}/reajustes`, com 200, 404 e 422. O contrato OpenAPI e o CHANGELOG foram atualizados.

Pendências:
- O endpoint não foi testado por HTTP. Não há teste de API e a política do ambiente proíbe rede. Recomendo testes de API antes de liberar para a bilhetagem.
- O repositório in-memory não tem como cadastrar tarifas, então o endpoint só responde 404 até existir cadastro. Isso precisa ser resolvido antes de uso real.
- `dotnet-baseline.sh --check` reprova: faltam `Directory.Build.props`, `.editorconfig` e `Directory.Packages.props`. Não apliquei `--apply`, porque isso cria arquivos fora do escopo; a decisão é sua.
- Não fiz commit e não marquei a TASK-03 como concluída no tracker.
