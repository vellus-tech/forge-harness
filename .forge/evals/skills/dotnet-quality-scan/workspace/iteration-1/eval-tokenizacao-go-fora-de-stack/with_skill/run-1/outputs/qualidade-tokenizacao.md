# Relatório de qualidade — services/tokenizacao (dotnet-quality-scan)

## Veredito

**Não aplicável — skill fora de stack.** Não escrevo "aprovado" para este serviço porque a skill `dotnet-quality-scan` audita código C#/.NET, e `services/tokenizacao` é inteiramente Go. Um "aprovado" aqui atestaria uma verificação que não ocorreu, e o PR do endpoint `POST /tokens` receberia como evidência de qualidade um scan que nunca teve alvo.

## O que foi verificado

1. **Escopo (passo 1 do protocolo).** `services/tokenizacao` contém `go.mod`, `cmd/tokenizacao/main.go` e `internal/vault/vault.go`. Busquei `.cs`, `.csproj` e `.sln` em toda a árvore de trabalho: zero ocorrências.
2. **Baseline de build (passo 2).** `bash .forge/scripts/dotnet-baseline.sh --root services/tokenizacao --check` respondeu `INFO dotnet:none (nenhum .csproj/.sln ... nada a auditar)`, exit 0 — confirma que não há projeto .NET para auditar.
3. **Detecção (passo 3), executada mesmo assim para registro.** `bash .forge/skills/dotnet-quality-scan/scripts/scan.sh --root services/tokenizacao` devolveu `PASS dotnet-quality-scan (0 achados)`, com as 11 regras em `OK ... nenhuma ocorrência`. Esse verde é o resultado esperado da própria descrição da skill: um scanner baseado em regex sobre padrões de C# (`async void`, `.Result`/`.Wait()`, `new HttpClient()`, etc.) não encontra nada em arquivos `.go` porque a sintaxe não existe na linguagem-alvo — o PASS não significa "código limpo", significa "nenhum alvo .NET no diretório".

## Por que não convertido em aprovação

A própria `SKILL.md` do `dotnet-quality-scan` é explícita: "Não use... para stack que não seja .NET." Tratar o `PASS` acima como qualidade aprovada seria exatamente o erro que a skill adverte no capítulo "O que o scanner NÃO faz" — um `OK`/`PASS` sem alvo real não é "verificado e limpo", é ausência de verificação.

## Recomendação

Para revisar a qualidade de `services/tokenizacao` (Go), use uma ferramenta adequada à stack — por exemplo `go vet`, `staticcheck` ou `golangci-lint` — e não o `dotnet-quality-scan`. Se o time quiser um gate equivalente para Go (nomes genéricos, parâmetro booleano de modo, mutex global mutável, etc.), isso é um scanner novo, não uma reaplicação deste.

## Observação pontual sobre o código lido (fora do escopo da skill, mas visível na leitura)

Sem que isso substitua uma revisão de segurança formal: `internal/vault/vault.go` guarda o PAN em texto plano num mapa em memória (`v.tokens[tok] = p.PAN`), sem qualquer criptografia ou persistência — não é avaliação do `dotnet-quality-scan` (que não cobre isso) e não deveria ser levada ao PR como se fosse.
