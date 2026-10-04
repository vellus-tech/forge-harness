Revisão .NET de feature/meia-tarifa-estudante contra a main: veredito CHANGES_REQUESTED. Não abra o PR para develop antes de corrigir os dois BLOCKERs e decidir sobre a autorização do endpoint.

BLOCKERs:
1. Captive dependency (Program.cs:10): DescontoService é Singleton e depende de TarifaDbContext, que é Scoped. Troque para AddScoped.
2. Bloqueio síncrono (DescontoService.cs:19): .Result sobre GetStringAsync em endpoint assíncrono. Torne o método async com CancellationToken.

HIGHs:
3. new HttpClient() por chamada (DescontoService.cs:18). Use IHttpClientFactory.
4. Matrícula sem escape na URL (DescontoService.cs:19). Valide o formato e use Uri.EscapeDataString.
5. Endpoint sem autorização (Program.cs:17). Qualquer chamador anônimo consegue enumerar se uma matrícula de estudante está ativa. Decisão humana: confirme com o dono de segurança ou por ADR. Não corrigi automaticamente.
6. Tabela inteira em memória (DescontoService.cs:22). ToList().Where() puxa todas as linhas, e First() lança exceção sem tarifa, o que vira 500.

MEDIUMs:
7. Parse do JSON do SGE por substring (DescontoService.cs:21). Use System.Text.Json.
8. Sem CancellationToken (Program.cs:17).

Baseline de build reprovado (DOTNET-BASELINE, HIGH): faltam Directory.Build.props, .editorconfig e Directory.Packages.props na raiz. É pré-existente na main, não desta branch. Trate em change separado com dotnet-baseline.sh --apply.

Os findings estão em review/dotnet-review.json e o resumo em review/resumo.md, ambos dentro de work/. Não rodei build nem testes, pois a execução não permitiu rede e o build do Tarifa.Api não foi verificado.
