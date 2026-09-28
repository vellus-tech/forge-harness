# Revisão .NET — feature/meia-tarifa-estudante vs. main

Escopo: `src/Tarifa.Api/Program.cs` e `src/Tarifa.Api/Services/DescontoService.cs` (arquivos novos/alterados no diff da branch contra `main`).

## Não abra o PR ainda — há um bug de ciclo de vida que derruba a API

`DescontoService` é registrado como `Singleton` em `Program.cs`, mas seu construtor recebe `TarifaDbContext`, que é `Scoped` por padrão via `AddDbContext`. Singleton capturando dependência scoped é o defeito clássico de "captive dependency": em ambiente de desenvolvimento a validação de escopo do próprio ASP.NET Core derruba a aplicação já na primeira chamada ao novo endpoint; em produção (sem essa validação) o mesmo `DbContext` fica preso entre requisições, o que produz corrida de dados e exceções de contexto descartado sob concorrência. É o achado mais grave do diff — trocar o registro para `Scoped` (ou usar `IDbContextFactory<TarifaDbContext>` se singleton for mesmo necessário).

## Baseline de build ausente (`DOTNET-BASELINE`, HIGH)

`bash .forge/scripts/dotnet-baseline.sh --root . --check` reprova: faltam `Directory.Build.props`, `.editorconfig` e `Directory.Packages.props` na raiz. Sem isso nenhuma das violações abaixo vira erro de build em commits futuros — vale rodar `--apply` (ou adotar o capability pack `backend-dotnet-relational`) antes deste PR.

## Achados do scan determinístico confirmados no diff

O scan (`dotnet-quality-scan`) rodou sobre o repositório inteiro e encontrou 6 ocorrências; só duas caem dentro do diff sob revisão — as outras quatro (`region`, `generic-name`, `bool-param`, `datetime-now`) estão em `src/Legado.Relatorios/RelatorioHelper.cs`, código legado não tocado por esta branch, e por isso não entraram como finding deste PR (ficam registradas no JSON para rastreabilidade, mas não bloqueiam).

- **`.Result` sobre `GetStringAsync` (BLOCKER)** — `DescontoService.cs:19`. Bloqueia a thread; sob carga esgota o pool. O método nem é `async` — precisa virar `Task<decimal>` com `await` e `CancellationToken` propagado, igual ao endpoint irmão.
- **`new HttpClient()` a cada chamada (HIGH)** — `DescontoService.cs:18`. Esgota sockets (`TIME_WAIT`). Trocar por `IHttpClientFactory`.

## Achados só de leitura de julgamento (não cobertos pelo scan)

- **`_db.Tarifas.ToList().Where(...)` (HIGH)** — `DescontoService.cs:22`. Puxa a tabela inteira antes de filtrar, exatamente o anti-padrão citado no guia do revisor, e sem `AsNoTracking()` (o endpoint irmão em `Program.cs` já filtra no banco corretamente).
- **Chamada ao SGE sem timeout, try/catch nem parsing JSON real (HIGH)** — `DescontoService.cs:18-20`. `resposta.Contains("\"ativa\":true")` é checagem de substring, não deserialização; qualquer variação de formatação, erro HTTP ou timeout do SGE propaga exceção não tratada (risco de stack trace no cliente) em vez de um erro de domínio distinguível de "estudante inativo".
- **`tarifas.First()` sem tratamento de linha inexistente (MEDIUM)** — `DescontoService.cs:23`. Lança `InvalidOperationException` não tratada se `linhaId` não existir; trocar por `FirstOrDefaultAsync` + `NotFound`.
- **`matricula` interpolada sem validação/escape na URL externa (MEDIUM)** — `DescontoService.cs:19`. Parâmetro de rota vai direto para a URL do SGE sem `Uri.EscapeDataString` nem validação de formato — risco de manipulação da chamada a um sistema de terceiro.
- **Cálculo `cheia * 0.5m` sem arredondamento e na contramão da convenção "money as integer cents" do `AGENTS.md` (MEDIUM)** — `DescontoService.cs:26`. Pode gerar mais de duas casas decimais; o tipo `decimal` é herdado de `main`, mas o novo cálculo é o lugar natural para não agravar o desvio.
- **Endpoint novo sem `CancellationToken`, inconsistente com o irmão (LOW)** — `Program.cs:17-18`.

## Cobertura declarada (regra: toda regra do scan entra, achado ou não)

`async-void` OK · `blocking-wait` FOUND (no diff) · `new-httpclient` FOUND (no diff) · `region` FOUND (fora do diff) · `generic-name` FOUND (fora do diff) · `bool-param` FOUND (fora do diff) · `empty-catch` OK · `datetime-now` FOUND (fora do diff) · `sql-interpolation` OK · `mutable-static` OK · `single-impl-interface` OK.

## Recomendação

Não abrir o PR para `develop` no estado atual — o registro `Singleton` de `DescontoService` é um bug funcional (derruba ou corrompe o serviço), e o `.Result` bloqueante combinado com `new HttpClient()` degrada a API sob carga real desde o primeiro deploy. Os demais achados (MEDIUM/LOW) valem a correção no mesmo PR, já que tocam o mesmo método pequeno, mas não são, isoladamente, bloqueadores de merge.
