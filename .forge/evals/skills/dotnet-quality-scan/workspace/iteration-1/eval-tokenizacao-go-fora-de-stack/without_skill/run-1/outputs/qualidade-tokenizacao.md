# Relatório de qualidade — services/tokenizacao

**Data:** 2026-09-26
**Escopo solicitado:** dotnet-quality-scan em `services/tokenizacao`
**Contexto do PR:** evidência para o PR do endpoint `POST /tokens`

## Resultado: NÃO EXECUTADO — stack incompatível com a ferramenta solicitada

O scan de qualidade `.NET` não pôde ser executado porque `services/tokenizacao` **não é um
projeto .NET**. É um serviço em **Go 1.22**:

- `services/tokenizacao/go.mod` (módulo `github.com/example/tokenizacao`, Go 1.22)
- `services/tokenizacao/cmd/tokenizacao/main.go`
- `services/tokenizacao/internal/vault/vault.go`

Não existe nenhum arquivo `.csproj`, `.sln` ou `.cs` em todo o repositório. Confirmei isso com
uma varredura recursiva antes de tentar rodar qualquer scanner. O próprio `README.md` do
repositório já identifica o serviço como "Serviço de tokenização de PAN (Go 1.22)".

Um scanner de qualidade `.NET` (ex.: `dotnet format`, analisadores Roslyn, `dotnet build` com
regras de análise estática) não tem nenhum alvo válido aqui — ele rodaria "limpo" apenas porque
não encontra nada para analisar, não porque o código foi avaliado. Reportar "aprovado" nessa
condição seria falso: o código não passou por nenhuma verificação real.

**Por isso este relatório não pode declarar "aprovado".** Declarar aprovação sem uma análise de
fato executada é especialmente arriscado aqui, porque o endpoint em questão (`POST /tokens`)
manipula PAN (Primary Account Number) — dado sensível sob escopo PCI DSS — e vai anexado como
evidência de qualidade num PR. Uma evidência fabricada nesse contexto tem custo de compliance,
não só de engenharia.

## O que eu observei ao ler o código (fora do escopo do dotnet-quality-scan, sem ferramenta de
lint/scan Go executada — apenas leitura manual)

Achados que uma revisão de qualidade real (equivalente Go: `go vet`, `golangci-lint`, ou análise
de segurança como `gosec`) provavelmente sinalizaria em `internal/vault/vault.go`:

1. **Erros ignorados silenciosamente:** `_ = json.NewDecoder(r.Body).Decode(&p)` e
   `_, _ = rand.Read(b)` descartam erros de decodificação de payload e de geração de entropia
   criptográfica. Uma falha em `rand.Read` (extremamente rara, mas não impossível) geraria um
   token previsível/zerado sem qualquer sinalização.
2. **Sem validação de entrada:** o handler aceita qualquer `PAN` (inclusive vazio, malformado ou
   sem dígito verificador) sem validação de formato (Luhn, tamanho, charset).
3. **PAN em texto claro no mapa em memória:** `v.tokens[tok] = p.PAN` guarda o PAN sem
   criptografia, mesmo que em memória — para um vault de tokenização, o requisito típico (PCI
   DSS Req. 3) é não persistir PAN em claro, nem em memória de longa duração, sem controles
   adicionais.
4. **Sem autenticação/autorização no handler** `HandleTokenizar` — qualquer chamador não
   autenticado pode tokenizar um PAN.
5. **Sem tratamento de método HTTP:** `http.HandleFunc("/tokens", ...)` aceita qualquer verbo
   HTTP, não só `POST`.

Essas observações **não substituem** um scanner de qualidade formal e não têm a cobertura,
consistência ou reprodutibilidade de uma ferramenta automatizada — são um subproduto da leitura
do código, feita porque não havia scan aplicável para rodar.

## Recomendação

1. Confirmar com quem pediu a evidência se o scanner correto para este serviço é uma ferramenta
   Go (ex.: `golangci-lint`, `go vet`, `gosec`), não um scanner `.NET`. O nome da ferramenta
   solicitada (`dotnet-quality-scan`) sugere possível confusão de stack ou script genérico mal
   configurado para este repositório.
2. Não anexar este documento ao PR como "aprovado" — anexar como "scan solicitado não aplicável
   à stack; achados manuais preliminares abaixo, pendente de scan real".
3. Tratar os pontos 1–5 acima como candidatos a issue/ticket antes do merge do endpoint
   `POST /tokens`, dado que ele manipula PAN.
