# Parecer de qualidade — Validador.Desktop

## Resumo executivo

O CI passar verde e a IDE mostrar sublinhado vermelho em nomenclatura não significam o que o time está assumindo. O `Directory.Build.props` e o `.editorconfig` do repositório existem, mas estão configurados de um jeito que faz exatamente o que o time relatou: a IDE sinaliza, o build ignora. Isso não é uma opinião de estilo — é uma lacuna estrutural de enforcement, e ela vem antes de qualquer achado pontual de código.

Além da lacuna de baseline, o scanner determinístico encontrou três ocorrências. Uma é falso alarme legítimo. Uma é falha real. A terceira é real hoje, mas por um motivo diferente do que o comentário no código alega — vale a pena o time ver o raciocínio, não só o veredito.

## 1. Por que o CI passa verde e a IDE ainda assim não protege

`Directory.Build.props` declara `TreatWarningsAsErrors = false` explicitamente — não é ausência, é uma escolha registrada que desliga a conversão de warning em erro de build. Faltam também `AnalysisLevel`/`AnalysisMode` (nenhum conjunto de analisadores Roslyn está ligado) e `EnforceCodeStyleInBuild` (sem essa flag, toda regra `IDExxxx` — inclusive a de nomenclatura de interface — vale só dentro da IDE).

O `.editorconfig` tem `dotnet_naming_rule` com severidade para nomenclatura, mas não tem o par que liga essa regra ao build: `dotnet_diagnostic.IDE1006.severity = warning|error`. É exatamente essa a armadilha que o time está vivendo sem saber: a severidade dentro de `dotnet_naming_rule` é lida **apenas por IDEs**. O squiggle vermelho que aparece quando alguém nomeia uma interface sem `I` é 100% real e 100% inofensivo para o pipeline — ele não passa para o build, então o CI segue verde mesmo com a convenção violada. O time não está errado sobre o sintoma (a IDE reclama); está errado sobre a conclusão (isso significa que está protegido).

Faltam ainda `Directory.Packages.props` (gestão central de versão de pacote — hoje cada `.csproj` fixa sua própria versão, e divergência entre projetos é silenciosa) e qualquer analisador de terceiros declarado.

**Recomendação:** rodar `bash .forge/scripts/dotnet-baseline.sh --apply` antes de qualquer rodada de revisão manual de estilo. Revisar à mão o que um `TreatWarningsAsErrors=true` + `dotnet_diagnostic.IDE1006.severity=error` pegariam de graça é gastar julgamento de revisor onde faltava um interruptor — e qualquer achado de nomenclatura, hoje, pode reaparecer amanhã porque nada impede.

## 2. Achados do scanner (`dotnet-quality-scan`), julgados um a um

Convenção: `FOUND` é candidato, não veredito. Regra que não achou nada também é relatada — para o time não confundir "não olhei" com "olhei e está limpo".

| Regra | Severidade | Resultado | Local |
|---|---|---|---|
| blocking-wait | BLOCKER | OK — nenhuma ocorrência | — |
| new-httpclient | HIGH | OK — nenhuma ocorrência | — |
| region | MEDIUM | OK — nenhuma ocorrência | — |
| generic-name | MEDIUM | OK — nenhuma ocorrência | — |
| bool-param | MEDIUM | OK — nenhuma ocorrência | — |
| empty-catch | HIGH | OK — nenhuma ocorrência | — |
| sql-interpolation | BLOCKER | OK — nenhuma ocorrência | — |
| mutable-static | HIGH | OK — nenhuma ocorrência | — |
| async-void | HIGH | FOUND, julgado **falso alarme** | `UI/MainForm.cs:15` |
| datetime-now | MEDIUM | FOUND, julgado **defeito real** | `Domain/TabelaTarifaria.cs:16` |
| single-impl-interface | MEDIUM | FOUND, julgado **defeito real** (motivo abaixo) | `Domain/Ports/ITabelaTarifariaRepository.cs` |

### async-void — `UI/MainForm.cs:15` — FALSO ALARME, não corrigir

```
private async void btnSincronizar_Click(object sender, EventArgs e)
```

Este é exatamente a exceção legítima da regra: event handler de framework WinForms, cuja assinatura `void` é imposta pelo delegate `EventHandler` — não dá para trocar por `Task` sem trocar o framework. A condição que valida a exceção também está satisfeita: o corpo inteiro está dentro de `try/catch`, então nenhuma exceção escapa para o `SynchronizationContext` e derruba o processo. Se o time me pedisse para "corrigir" isso, eu discordaria — é exatamente o tipo de item que, sinalizado como defeito sem essa leitura, ensina o time a ignorar o próximo relatório.

### datetime-now — `Domain/TabelaTarifaria.cs:16` — DEFEITO REAL, corrigir

```
public bool EstaVigente() => DateTime.Now <= VigenteAte;
```

A exceção legítima da regra é "formatação para exibição na borda de UI, com fuso explícito" — e este não é esse caso. `EstaVigente()` é lógica de **domínio** (a classe `TabelaTarifaria` decide se ela própria está vigente), não uma tela formatando data para o usuário. `DateTime.Now` amarra essa decisão ao fuso da máquina onde o validador desktop está rodando; um validador instalado em outro fuso, ou um teste rodando num CI com fuso diferente do esperado, pode concluir vigência de forma inconsistente com o que o servidor de tarifas pretendia. Correção: `DateTime.UtcNow` (comparando contra `VigenteAte` também em UTC) ou, melhor, injetar `TimeProvider` (disponível a partir do .NET 8) para que o "agora" vire testável.

### single-impl-interface — `Domain/Ports/ITabelaTarifariaRepository.cs` — DEFEITO REAL, mas não pelo motivo óbvio

```csharp
// Porta do domínio (arquitetura hexagonal): o domínio declara, a infraestrutura implementa.
// A segunda implementação é o dublê em memória usado pelos testes do domínio.
public interface ITabelaTarifariaRepository
```

O comentário no próprio código já invoca a exceção legítima da regra — "porta de arquitetura hexagonal deliberada" com uma segunda implementação nos testes. Se essa segunda implementação existisse, este seria outro falso alarme, igual ao `async-void` acima. Ela não existe: não há projeto de teste no repositório (busquei por `*test*` e por qualquer outro `.cs` que implemente `ITabelaTarifariaRepository` além de `SqliteTabelaTarifariaRepository` — nenhum resultado). O comentário descreve uma intenção arquitetural que ainda não foi materializada.

Isso não invalida a intenção — hexagonal é uma escolha razoável aqui — mas hoje a interface tem uma implementação, nenhum teste de domínio a exercita através dela, e o comentário afirma algo que um novo integrante vai acreditar sem checar. Duas saídas igualmente aceitáveis: (a) criar o dublê em memória e os testes de domínio que o comentário promete, o que resolve o achado e cumpre a intenção original; ou (b) se não houver plano concreto de testar isso tão cedo, remover a alegação do comentário e tratar a interface como especulativa até que um segundo consumidor real apareça. O que não deveria acontecer é o comentário continuar como está — ele é hoje uma dívida disfarçada de decisão arquitetural.

## O que o scanner não cobre (fora deste parecer)

`blocking-wait`, `new-httpclient`, `region`, `generic-name`, `bool-param`, `empty-catch`, `sql-interpolation` e `mutable-static` não tiveram ocorrência — não há indício de nenhum desses problemas no projeto hoje, mas isso cobre só o que grep enxerga. Acoplamento, nome de método que promete algo diferente do que faz, invariante de domínio ausente e teste sem asserção continuam sendo trabalho de leitura de diff, não deste relatório — e, dado que não há projeto de teste no repositório, "teste sem asserção" nem se aplica ainda: o próximo item de dívida antes de falar em cobertura é simplesmente ter testes.

## Ação recomendada, em ordem

1. `bash .forge/scripts/dotnet-baseline.sh --apply` — fecha a lacuna de enforcement (`TreatWarningsAsErrors`, `AnalysisMode`, `EnforceCodeStyleInBuild`, `dotnet_diagnostic.IDE1006.severity`) para que a IDE e o CI concordem.
2. Corrigir `DateTime.Now` em `TabelaTarifaria.EstaVigente()`.
3. Decidir sobre `ITabelaTarifariaRepository`: materializar o dublê/teste prometido no comentário, ou reescrever o comentário para não prometer o que não existe.
4. Não mexer no `async-void` de `MainForm.btnSincronizar_Click` — está correto como está.
