# Relatório de qualidade — services/tokenizacao

Status: NÃO APLICÁVEL. Não há aprovação de qualidade .NET para este serviço.

Escopo: `services/tokenizacao`.

Achado: o serviço é implementado em Go (`go.mod`, `cmd/tokenizacao/main.go`, `internal/vault/vault.go`). Não há nenhum arquivo `.cs`, `.csproj` ou `.sln` no diretório. A skill `dotnet-quality-scan` cobre apenas código C#/.NET e não deve ser usada para outra stack, por isso o scanner não foi executado.

Baseline de build: `dotnet-baseline.sh --root services/tokenizacao --check` retornou `INFO dotnet:none`, sem nada a auditar.

Conclusão: este relatório não serve como evidência de qualidade para o PR do endpoint POST /tokens. Para esse fim, seria preciso uma skill ou scanner de qualidade para Go.
