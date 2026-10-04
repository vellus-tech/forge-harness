Não mergear ainda. O hotfix/extrato-portador tem três pontos que bloqueiam o merge, e dois deles precisam de decisão sua.

Já corrigi nos arquivos (sem commit, para você revisar antes de commitar):
- SQL injection em `ExtratoController.cs`: o `FromSqlRaw` com interpolação virou `FromSql` com interpolação, que gera parâmetros.
- Credenciais AWS removidas de `appsettings.json`. O cliente S3 agora usa a cadeia padrão do SDK (variáveis de ambiente, perfil ou role).
- CPF e número do cartão saíram da mensagem de log.

Build do projeto passou (0 avisos, 0 erros) e o scan de clean code passou de 1 achado para 0.

Bloqueios para o merge:
1. O endpoint `GET portadores/{cpf}/extrato` não tem autenticação nem autorização. Qualquer chamador consulta o extrato de qualquer CPF. Precisa definir o esquema (JWT do portador, mTLS ou gateway) e vincular o CPF ao chamador.
2. A chave AWS `<AWS_KEY_ID_REDIGIDA>` está no commit a76b214 e permanece no histórico. O valor parece fixture, mas confirme que nunca foi real ou rotacione. Reescreva o histórico só se o branch ainda não foi publicado.
3. O JSON enviado ao S3 leva CPF e número do cartão em texto claro. Defina quais campos a operação precisa, mascare o cartão e habilite SSE-KMS no bucket.

Outros pontos:
- O número do cartão vai na query string, o que o deixa em logs de proxy e gateway.
- O baseline de build (`dotnet-baseline.sh --check`) reprova por falta de `Directory.Build.props`, `Directory.Packages.props` e `.editorconfig`. Não apliquei o `--apply` neste hotfix: ele instala analisadores que exigem rede e ativa warnings como erro no repositório inteiro. Recomendo PR separado.
- Nenhum teste cobre o endpoint.

Arquivos: `review/dotnet-review.json` (findings) e `review/resumo.md` (veredito), dentro do worktree de review.
