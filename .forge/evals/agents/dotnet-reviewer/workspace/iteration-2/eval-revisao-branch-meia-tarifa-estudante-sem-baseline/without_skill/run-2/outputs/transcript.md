# Transcrição — revisão .NET de feature/meia-tarifa-estudante

1. Inspecionei o repositório em `work/`: branch `feature/meia-tarifa-estudante`, HEAD 49e3cfe. `git status` mostra deleções não commitadas em `.claude/` e `.forge/`, fora do commit do branch.
2. `git diff main...feature/meia-tarifa-estudante --name-status`: dois arquivos, `Program.cs` (M) e `Services/DescontoService.cs` (A). 33 inserções.
3. Li `AGENTS.md` e o conteúdo do diff.
4. Li a definição do revisor a partir do HEAD (`git show HEAD:.forge/agents/code-review/dotnet-reviewer.md`), porque o arquivo não existe na árvore de trabalho. Ela define a ordem: baseline, scan e julgamento.
5. Copiei `dotnet-baseline.sh`, `scan.sh` e o clean-code-rules para `tmp/` a partir do HEAD, sem tocar na árvore de trabalho. Rodei o baseline numa primeira vez, que falhou porque o script procura `../capabilities` relativo a si mesmo. Corrigi montando os assets em `tmp/capabilities/`. Resultado: FAIL, por ausência de Directory.Build.props, .editorconfig e Directory.Packages.props na raiz. Pré-existente em main.
6. Rodei `scan.sh --root work/src --json tmp/scan.json`. Seis FOUND: quatro em `DescontoService.cs` (blocking-wait, new-httpclient), e os demais em `Legado.Relatorios/RelatorioHelper.cs`, fora do diff. Julguei cada um lendo o trecho.
7. Li o trecho de DescontoService e Program.cs com números de linha. Li regras relevantes do HEAD: `ddd.md` e `money-as-cents` (dinheiro em centavos), `observability.md` e `pii-pci-classification.md` (PII em log), `authz-pdp-pep.md` (fail-closed).
8. Confirmei que `TarifaDbContext` é registrado com `AddDbContext` (scoped) e que `DescontoService` é singleton. Isso dá captive dependency.
9. Confirmei que o sln não tem projeto de teste.
10. Decisões: veredito CHANGES_REQUESTED. Severidades alinhadas ao checklist do revisor. Escrevi TAR-012 como INFO porque é pré-existente. Não rodei build nem teste, porque restore exige rede e a política proíbe. Não modifiquei código do branch.
11. Gravei `work/review/dotnet-review.json` (12 findings, JSON validado) e `work/review/resumo.md`.
