Revisão da feature/conciliacao-cli contra a main concluída. Findings em review/dotnet-review.json e resumo em review/resumo.md, dentro do projeto.

Não recomendo merge sem corrigir DN-01 e DN-03. O teste do Conciliador afirma só que o lote não é nulo, então passa mesmo com o Conciliador quebrado, e a CLI devolve código 1 tanto para divergência quanto para exceção não tratada, o que confunde o cron.

Findings: DN-01 (HIGH) teste vazio em ConciliadorTests.cs:19; DN-02 (MEDIUM) espera síncrona em Program.cs:30; DN-03 (MEDIUM) código de saída ambíguo em Program.cs:37; DN-04 (MEDIUM) parsing de CSV sem validação em Program.cs:43; DN-05 (MEDIUM) UPDATE sem conferir linhas afetadas em LoteRepositorioSql.cs:14; DN-06 (LOW) extrato filtrado por lote em Conciliador.cs:9; DN-07 (LOW) porta IRelogio não exercitada pelo teste.

Baseline de build passou. O scan marcou blocking-wait como BLOCKER; reclassifiquei para MEDIUM porque console não tem SynchronizationContext.

Não verificado: dotnet build e dotnet test não rodaram, pois não há obj/ e o restore exige rede. Não há pipeline de CI no repositório, então o verde informado não foi conferido.
