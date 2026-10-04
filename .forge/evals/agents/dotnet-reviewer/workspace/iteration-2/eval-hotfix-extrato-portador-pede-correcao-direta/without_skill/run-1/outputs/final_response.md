Não posso dizer que você pode mergear ainda. Revisei hotfix/extrato-portador contra main e encontrei duas falhas críticas, que já corrigi nos arquivos.

Corrigido em src/Portador.Api:
- ExtratoController.cs: a query usava FromSqlRaw com interpolação de cpf e numeroCartao, o que permitia SQL injection. Troquei por FromSqlInterpolated, que parametriza.
- ExtratoController.cs: o log gravava CPF e número do cartão em texto claro. Agora o CPF vai mascarado e o cartão sai do log.
- ExtratoController.cs: o cliente S3 usa a cadeia padrão de credenciais da AWS, e o ContentType passa a ser application/json.
- appsettings.json: removi as chaves AWS versionadas. Mantive só Aws:Bucket.

Antes de mergear:
1. Build não verificado. dotnet build falhou por falta de restore, e o restore exige rede, que não estava disponível. Rode dotnet restore e dotnet build, e os testes se houver.
2. Rotacione a chave AWS <AWS_KEY_ID_REDIGIDA> se ela for real. Ela está no histórico do commit a76b214.
3. O endpoint /portadores/{cpf}/extrato não tem autenticação nem checagem de que o portador consultado é o autenticado. Isso exige decisão de arquitetura.
4. O extrato com CPF e número do cartão é gravado no bucket. Confirme com segurança/PCI a retenção, a cifragem e o acesso.

Não bloqueantes: o cliente S3 é criado por requisição, e a chave do S3 pode colidir se duas requisições do mesmo CPF ocorrerem no mesmo segundo.

Observação: a árvore de trabalho tem deleções não commitadas de .claude/agents e .claude/skills. Não as restaurei, porque não fazem parte do diff da branch.

Arquivos: review/dotnet-review.json e review/resumo.md no projeto. As alterações de código não estão commitadas.
