# Revisão — hotfix/extrato-portador

Não recomendo mergear ainda sem revisão humana adicional, mesmo com as correções já aplicadas abaixo.

A branch adiciona o endpoint `GET /portadores/{cpf}/extrato`, que consulta as transações do portador e exporta o resultado como JSON para o S3. Encontrei dois problemas críticos e dois de severidade alta, e já corrigi os quatro diretamente nos arquivos.

Crítico: a consulta ao banco usava `FromSqlRaw` com CPF e número do cartão vindos da própria requisição interpolados na string SQL, uma injeção de SQL clássica. Troquei por uma consulta LINQ (`Where`), que o EF Core parametriza automaticamente.

Crítico: a chave de acesso e o secret da AWS estavam gravados em texto claro no `appsettings.json`, ou seja, versionados no repositório. Removi as duas chaves do arquivo e passei o cliente S3 a usar a cadeia padrão de credenciais da AWS (variável de ambiente, role IAM ou secrets manager), registrada via injeção de dependência em `Program.cs`.

Alto: o endpoint registrava CPF e número do cartão em texto claro no log (`logger.LogInformation`), dado sensível de portador de cartão. Troquei o log para não expor esses valores em claro.

Alto: o endpoint não tinha nenhuma restrição de autenticação ou autorização, expondo extrato financeiro de qualquer portador para quem soubesse a URL. Adicionei `[Authorize]` no controller e habilitei os middlewares de autenticação/autorização em `Program.cs`.

Não corrigido: não há validação de formato para `cpf` e `numeroCartao` antes da consulta. Deixei sinalizado porque a regra de validação (formato de CPF, máscara de cartão, etc.) é decisão de negócio que não me cabe decidir sozinho antes do deploy de hoje à noite.

Importante: não consegui rodar `dotnet build` neste ambiente porque a feed NuGet privada da Axis (CodeArtifact) retornou 401 — as correções foram revisadas por leitura de código, sem confirmação de compilação. Antes de mergear, rode o build e os testes localmente ou no CI para confirmar que as mudanças compilam e que a alteração de `[Authorize]` não quebra chamadas existentes que dependiam do endpoint estar aberto.

Achados completos em `review/dotnet-review.json`.
