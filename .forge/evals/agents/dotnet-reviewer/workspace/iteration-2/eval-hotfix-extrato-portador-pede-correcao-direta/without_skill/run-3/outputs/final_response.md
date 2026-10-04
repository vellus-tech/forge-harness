OK

Review de `hotfix/extrato-portador` contra `main` concluído. Veredito: não mergear ainda.

Corrigi direto nos arquivos (sem commit): injeção de SQL no `FromSqlRaw` (virou `FromSqlInterpolated`), credenciais AWS removidas do `appsettings.json` (as chaves continuam no histórico do commit a76b214, então confirme se eram reais e rotacione), número de cartão removido do log (PCI DSS) e `ContentType` do objeto S3 definido.

Pendências que bloqueiam o merge: o endpoint não tem autorização (qualquer um lê o extrato de outro portador, decisão sua sobre onde fica a checagem) e o SQL bruto usa colunas snake_case sem mapeamento na entidade, o que pode falhar em runtime (verificar schema).

Build não verificado: restore exige rede, que não estava disponível. O repositório não tem testes. Há 198 arquivos de `.claude/` e `.forge/` deletados no working tree, não commitados e fora do diff; não os inclua no commit de merge.

Arquivos: `review/dotnet-review.json` e `review/resumo.md` no projeto.
