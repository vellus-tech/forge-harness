# Revisão de qualidade — branch `feature/recarga-pix`

Escopo: os arquivos tocados por esta branch em relação a `main` — `src/Recarga/Recarga.Api/Controllers/RecargaController.cs`, `src/Recarga/Recarga.Api/Domain/RecargaPix.cs`, `src/Recarga/Recarga.Api/Domain/SaldoService.cs`, `src/Recarga/Recarga.Api/Infra/PixGatewayClient.cs`, `src/Recarga/Recarga.Seed/Program.cs` e `src/Recarga/Recarga.Seed/Recarga.Seed.csproj`. Nada fora desse diff foi revisado. Nenhuma correção foi aplicada — este documento é só o relatório para decisão antes do PR.

## Resumo executivo

O baseline de build do monorepo passa (`TreatWarningsAsErrors`, `AnalysisMode` e `.editorconfig` já materializados na raiz), então a revisão abaixo cobre o que o compilador não reprova. A branch tem três achados que eu trataria como bloqueadores antes do PR: injeção de SQL parametrizando `cartaoId` por interpolação, um `catch` vazio que esconde falha real de cobrança Pix atrás de uma resposta `202 Accepted`, e chamadas bloqueantes (`.Result`/`.Wait()`) no caminho síncrono do controller e do gateway. Os demais achados são reais mas de risco menor, e um deles (interface com implementação única) é discutível dado o tamanho da mudança.

## 1. Baseline de build

`bash .forge/scripts/dotnet-baseline.sh --root . --check` — `PASS`. `Directory.Build.props`, `.editorconfig` e `Directory.Packages.props` já existem na raiz do monorepo com `TreatWarningsAsErrors`, `AnalysisMode`, `EnforceCodeStyleInBuild` e severidade de `IDE1006` ligados em build. Isso significa que o que segue abaixo é julgamento de intenção, não estilo que o compilador já pegaria.

## 2. Detecção determinística (`dotnet-quality-scan/scripts/scan.sh --root src/Recarga`)

Uma linha por regra, na ordem em que o scanner roda.

- `OK async-void [HIGH]` — nenhuma ocorrência.
- `FOUND blocking-wait [BLOCKER]` — 3 ocorrências.
- `FOUND new-httpclient [HIGH]` — 1 ocorrência.
- `OK region [MEDIUM]` — nenhuma ocorrência.
- `OK generic-name [MEDIUM]` — nenhuma ocorrência.
- `OK bool-param [MEDIUM]` — nenhuma ocorrência.
- `FOUND empty-catch [HIGH]` — 1 ocorrência.
- `FOUND datetime-now [MEDIUM]` — 1 ocorrência.
- `FOUND sql-interpolation [BLOCKER]` — 1 ocorrência.
- `OK mutable-static [HIGH]` — nenhuma ocorrência.
- `FOUND single-impl-interface [MEDIUM]` — 1 ocorrência (`ISaldoService`).

## 3. Julgamento por achado

### sql-interpolation `[BLOCKER]` — `Recarga.Api/Infra/PixGatewayClient.cs:20`

```
return _db.Recargas.FromSqlRaw($"SELECT * FROM recargas WHERE cartao_id = '{cartaoId}'").ToList();
```

`cartaoId` chega pela rota (`{cartaoId}/pix` no controller) e é interpolado direto na string SQL — é injeção clássica, e o dado é entrada externa, não constante interna. Não há exceção legítima aqui: a correção é `FromSql($"...")` (variante interpolada do EF Core, que parametriza automaticamente) ou um parâmetro explícito. Eu não deixaria essa branch ir para `develop` com esse método assim.

### empty-catch `[HIGH]` — `Recarga.Api/Controllers/RecargaController.cs:29`

```
try { _pix.RegistrarCobranca(recarga); }
catch { }
return Accepted(recarga);
```

Se `RegistrarCobranca` falhar — inclusive por causa do `.Wait()` que já pode lançar `AggregateException` do HTTP para o PSP — o controller engole o erro e devolve `202 Accepted` do mesmo jeito. O cliente vê "cobrança aceita" quando a cobrança pode não ter saído. Isso não é só qualidade de código, é risco de negócio numa branch de cobrança Pix: o usuário acha que recarregou o cartão e o dinheiro não foi cobrado, ou foi cobrado e o app não sabe. Não há comentário explicando por que o erro é irrelevante, então não se enquadra na exceção legítima do `catch` vazio (cleanup em `finally` que não pode falhar).

### blocking-wait `[BLOCKER]` — 3 ocorrências, julgamento por ocorrência

- `RecargaController.cs:23` — `_saldoService.ConsultarAsync(cartaoId).Result` dentro de uma action síncrona (`IActionResult`, não `Task<IActionResult>`) do ASP.NET Core. Isso é exatamente o cenário que a regra existe para pegar: bloquear uma thread do pool do Kestrel por request degrada sob carga, e o sintoma só aparece em produção. A correção é trivial — `async Task<IActionResult>` e `await`.
- `Recarga.Api/Infra/PixGatewayClient.cs:15` — `http.PostAsJsonAsync(...).Wait()` dentro de `RegistrarCobranca`, chamado de dentro do mesmo controller síncrono acima. Mesmo risco, mesmo caminho de correção (`async Task RegistrarCobrancaAsync` e `await`).
- `Recarga.Seed/Program.cs:8` — `SeedRunner.PopularAsync(...).GetAwaiter().GetResult()` dentro de `Main` de uma ferramenta de linha de comando (`Recarga.Seed`, `OutputType Exe`). Essa é a exceção legítima que a própria regra documenta — `Main` síncrono de CLI. Eu não pediria mudança aqui; se quiser eliminar mesmo assim, o caminho é `Main` assíncrono (`static async Task<int> Main`), que o .NET já suporta nativamente, mas não é bloqueador.

### new-httpclient `[HIGH]` — `Recarga.Api/Infra/PixGatewayClient.cs:14`

```
using var http = new HttpClient();
```

Instanciado a cada chamada de `RegistrarCobranca`, ou seja, a cada cobrança Pix. Sob volume isso esgota sockets em `TIME_WAIT`. Trocar por `IHttpClientFactory` injetado (`IHttpClientFactory.CreateClient()` ou um cliente tipado) resolve sem mudar o resto da lógica.

### datetime-now `[MEDIUM]` — `Recarga.Api/Domain/RecargaPix.cs:10`

```
ExpiraEm = DateTime.Now.AddMinutes(30);
```

`ExpiraEm` é um campo de domínio de uma cobrança Pix, não formatação de UI — a exceção legítima da regra (exibição na borda com fuso explícito) não se aplica. Amarrado ao fuso da máquina, o expira-em diverge se a API rodar em servidores com fuso diferente, e o teste da expiração vira dependente de onde roda. Trocar por `DateTime.UtcNow` (ou `TimeProvider` a partir do .NET 8, já que o projeto está em `net8.0`) remove a dependência de ambiente.

### single-impl-interface `[MEDIUM]` — `ISaldoService` / `SaldoService`

Uma interface, uma implementação, um único consumidor (`RecargaController`). Pode ser porta deliberada para troca futura de fonte de saldo, mas nada no diff sugere um segundo consumidor ou um teste que já se beneficie do mock — a implementação atual (`Task.FromResult(0m)`) também parece placeholder. Não bloquearia o PR por isso, mas vale perguntar ao autor se `ISaldoService` já tem um segundo caso de uso em vista; se não tiver, é indireção sem benefício ainda.

## 4. Além do scanner — leitura do diff

O scanner não julga intenção nem invariante de domínio; isso ficou para a leitura direta do diff.

- `CriarCobranca` aceita `decimal valor` do corpo sem nenhuma validação de valor positivo ou de teto de recarga — nada no diff impede `valor` negativo ou zero chegando até `RegistrarCobranca`.
- Não há chave de idempotência na criação da cobrança: duas chamadas ao mesmo endpoint (retry de rede, duplo clique) geram duas cobranças Pix distintas no PSP, e o `catch` vazio da seção anterior torna esse cenário ainda mais difícil de detectar depois.
- `PixGatewayClient` mistura duas responsabilidades — registrar cobrança no PSP externo (`RegistrarCobranca`) e ler histórico do banco local (`Historico`) — numa classe só; não é generic-name nem viola nenhuma regra do scanner, mas separar as duas facilitaria testar cada lado (HTTP vs. EF Core) de forma isolada.

## 5. O que ficou de fora

Esta revisão cobriu apenas os arquivos alterados nesta branch. O restante do monorepo (inclusive os relatórios/legado citados no fixture de setup) não foi tocado nem lido além do necessário para confirmar o baseline de build.
