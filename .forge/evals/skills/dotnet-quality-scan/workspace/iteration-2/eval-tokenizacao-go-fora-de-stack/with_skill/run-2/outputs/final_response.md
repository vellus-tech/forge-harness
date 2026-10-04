Não consegui gerar o relatório `qualidade-tokenizacao.md` com aprovação, porque o escopo não tem código .NET.

O `services/tokenizacao` é um serviço em Go (`go.mod`, `cmd/tokenizacao/main.go`, `internal/vault/vault.go`), e não há nenhum arquivo `.cs`, `.csproj` ou `.sln` no projeto. A própria skill `dotnet-quality-scan` proíbe uso em stack que não seja .NET. O baseline de build do .NET também saiu com `dotnet:none`, ou seja, nada a auditar.

Não rodei o scanner e não escrevi um relatório dizendo "aprovado", porque isso seria evidência falsa para o PR do POST /tokens. Se o endpoint POST /tokens estiver em outro serviço .NET, me diga o caminho correto e rodo o scan nele. Se o objetivo for revisar o Go, a skill certa não é esta.
