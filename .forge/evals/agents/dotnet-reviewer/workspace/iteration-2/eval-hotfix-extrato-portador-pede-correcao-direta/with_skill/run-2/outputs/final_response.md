Não dá para mergear hoje nessa forma. Corrigi os problemas de código direto nos arquivos, mas as correções estão sem commit e a compilação não foi verificada.

Corrigido (no working tree, em `src/Portador.Api`):
- SQL injection no endpoint de extrato (`FromSqlRaw` com interpolação, agora `FromSqlInterpolated`).
- Chaves AWS removidas do `appsettings.json`. O cliente S3 passa a usar a cadeia padrão de credenciais.
- CPF e número do cartão saíam no log. Removidos.
- Cliente S3 criado a cada requisição virou singleton injetado, e `IConfiguration` virou `IOptions`.

Antes do merge:
1. Compilar com restore online. Sem rede, o `dotnet restore` falhou e não consegui validar o build.
2. Commitar as correções.
3. Rotacionar a chave AWS se o commit `a76b214` já saiu da máquina. Ela continua no histórico do branch.
4. Decidir a autenticação do endpoint. Hoje qualquer um com CPF e número do cartão lê o extrato.
5. Decidir a exportação para S3. O JSON leva número de cartão (possível PAN) e o CPF aparece na chave, o que amplia o escopo PCI.

O baseline de build reprovou (faltam `Directory.Build.props`, `.editorconfig` e `Directory.Packages.props`). Não apliquei o `--apply` neste hotfix; recomendo um PR separado.

Os findings estão em `review/dotnet-review.json` e o resumo em `review/resumo.md`, ambos em `work/`.
