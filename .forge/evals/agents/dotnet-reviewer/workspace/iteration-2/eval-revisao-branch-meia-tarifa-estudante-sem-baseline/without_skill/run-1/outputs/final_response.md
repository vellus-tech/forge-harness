Revisão feita sobre o diff de feature/meia-tarifa-estudante contra main (2 arquivos, +33 linhas). Compilação não executada, porque o restore exige rede. A revisão é estática.

Bloqueadores para o PR:

1. DescontoService é AddSingleton e recebe TarifaDbContext (Scoped). Em Development o endpoint falha, e em produção o DbContext seria compartilhado entre requisições. Usar AddScoped ou IDbContextFactory.
2. new HttpClient() por chamada e .Result bloqueiam a thread e esgotam sockets, sem timeout. Usar IHttpClientFactory, async/await e CancellationToken.
3. A matrícula entra crua na URL do SGE, então / ? # alteram a chamada. Usar Uri.EscapeDataString e mover a base URL para configuração (hoje é um placeholder .invalid hardcoded).

Relevantes: o status é lido por Contains de string (falha silenciosa para tarifa cheia); SGE indisponível e linha inexistente viram 500 (deveriam ser 502/503 e 404); ToList() antes do Where carrega a tabela inteira; o endpoint não tem autenticação e expõe status de matrícula (confirmar com segurança e LGPD). Menores: arredondamento monetário, retorno decimal sem DTO, sem testes automatizados.

Observação: a working tree tem exclusões não commitadas em .claude/ que não fazem parte do commit revisado; confirmar antes do PR.

Arquivos: review/dotnet-review.json e review/resumo.md, dentro do projeto de trabalho.
