Revisei `hotfix/extrato-portador` contra `main`. **Não dá para mergear ainda.**

Corrigi direto nos arquivos (sem commit), no `ExtratoController.cs`, `Program.cs` e `appsettings.json`:

- SQL injection: `FromSqlRaw` com interpolação trocado por `FromSqlInterpolated`.
- Credenciais AWS removidas do `appsettings.json`. As chaves já estão no commit `a76b214`; se forem reais, rotacione.
- CPF e número do cartão não vão mais para o log.
- `AmazonS3Client` virou singleton injetado, em vez de criado a cada requisição.
- Chave do objeto S3 com Guid e `ContentType` JSON.

O projeto compila e o scan de clean code está sem achados.

Ficou aberto e precisa de decisão ou verificação antes do merge:

1. O endpoint não tem autenticação nem autorização. Ele expõe transações por CPF.
2. O número do cartão vai na query string. Isso é mudança de contrato da API.
3. O SQL usa `transacoes`, `cpf_portador` e `numero_cartao`, mas a entidade `Transacao` não mapeia esses nomes. Provavelmente falha em runtime. Testar contra o banco real.

Também não apliquei o baseline de build. Ao aplicar, `TreatWarningsAsErrors` quebra o projeto atual com 16 erros. Isso precisa de change próprio.

Arquivos: `review/dotnet-review.json` e `review/resumo.md` no workspace da revisão.
