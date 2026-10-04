Revisão .NET de feature/meia-tarifa-estudante contra main concluída. Veredito: mudanças necessárias antes do PR para develop.

Bloqueantes: DescontoService é singleton e consome TarifaDbContext (scoped), o que gera captive dependency (Program.cs:9). Há new HttpClient por chamada e .Result sobre a rede, sem timeout, sem tratamento de erro do SGE (DescontoService.cs:18-19). A consulta carrega a tabela inteira e First() dá 500 quando a linha não existe (DescontoService.cs:22-23).

Importantes: política de falha do SGE indefinida; matrícula sem validação na URL; interpretação da resposta por Contains em string; matrícula (dado pessoal) no path do GET; cálculo em decimal sem arredondamento definido; nenhum teste.

A revisão é estática: build e testes não rodaram porque o ambiente não tem rede. O baseline de build ausente é pré-existente em main. Atenção: a árvore de trabalho tem deleções não commitadas em .claude/ e .forge/.

Arquivos: work/review/dotnet-review.json e work/review/resumo.md.
