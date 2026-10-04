Revisei hotfix/extrato-portador contra main. Veredito: não dá para mergear ainda.

Corrigi direto nos arquivos, sem commit:
- SQL injection em ExtratoController.cs (FromSqlRaw com interpolação virou FromSqlInterpolated).
- PAN e CPF removidos do log.
- Credenciais AWS removidas de appsettings.json. O SDK passa a usar a cadeia padrão (variáveis de ambiente ou papel IAM).
- IAmazonS3 como singleton em Program.cs, no lugar de um cliente por requisição.
- Chave do S3 com GUID, para não sobrescrever extrato no mesmo segundo.

Bloqueiam o merge e dependem de decisão sua ou da operação:
1. O endpoint não tem autenticação nem autorização.
2. O número do cartão vai na query string da URL. Corrigir muda o contrato.
3. O JSON exportado para o S3 leva PAN e CPF em texto claro. Confirmar criptografia (SSE-KMS), Block Public Access e retenção, ou mascarar o PAN.
4. A chave AKIA que estava em appsettings.json (commit a76b214) precisa ser confirmada como fixture. Se for real, rotacionar e limpar o histórico.

Outros pontos: o baseline de build está reprovado (falta Directory.Build.props, .editorconfig e CPM). Sugiro corrigir depois do hotfix, em branch separada. O scan de clean code ficou limpo após as correções.

Não consegui rodar dotnet build: não há obj/ e a restauração exige rede. Compile antes do merge.

Atenção: o working tree do branch mostra cerca de 200 arquivos de .forge/ e .claude/ como deletados. Não mexi neles. Revise antes de commitar, para não apagar o harness por engano.

Arquivos: review/dotnet-review.json e review/resumo.md no projeto.
