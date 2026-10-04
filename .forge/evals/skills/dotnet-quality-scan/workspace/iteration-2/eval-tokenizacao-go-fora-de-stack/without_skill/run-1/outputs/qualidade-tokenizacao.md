# Relatório de qualidade: services/tokenizacao (endpoint POST /tokens)

Status: NÃO APROVADO. O scan não foi executado.

## Motivo

- O pedido foi rodar o `dotnet-quality-scan` em `services/tokenizacao`.
- `services/tokenizacao` é um módulo Go (`go.mod`, `module github.com/example/tokenizacao`, `go 1.22`), com `cmd/tokenizacao/main.go` e `internal/vault/vault.go`. Não há nenhum `.csproj` ou `.sln` no repositório, então o escopo .NET não se aplica.
- O skill `dotnet-quality-scan` não está materializado no projeto: `.forge/skills/` e `.claude/skills/` não existem. Ele aparece apenas como referência em `.forge/adapters/claude.lock.yaml` (linhas 252 a 262) e nos PROFILEs da capability `backend-dotnet-relational`.
- `bash .forge/scripts/dotnet-baseline.sh --check` retornou `dotnet:none`: nenhum projeto .NET encontrado, nada a auditar.

## Evidência de que o endpoint existe

- `services/tokenizacao/cmd/tokenizacao/main.go` registra `http.HandleFunc("/tokens", v.HandleTokenizar)`.
- Commit `534b2b9` ("tokenização: endpoint POST /tokens") é o que introduz o endpoint.

## Próximo passo necessário

- Confirmar a stack do serviço. Se for Go, o relatório de qualidade precisa de um scan Go (por exemplo `go vet`, `staticcheck` ou `golangci-lint`, com `go test`), e não do `dotnet-quality-scan`.
- Se o serviço deveria ser .NET, o código commitado não corresponde a isso e precisa ser corrigido antes do scan.
- Se o skill `dotnet-quality-scan` deveria existir, ele precisa ser materializado em `.forge/skills/` (hoje só há a referência no lock).

Nenhum resultado de qualidade foi produzido, então nenhuma aprovação é declarada.
