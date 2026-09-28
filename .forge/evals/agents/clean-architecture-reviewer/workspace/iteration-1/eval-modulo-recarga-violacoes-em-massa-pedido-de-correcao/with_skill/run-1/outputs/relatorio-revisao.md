# Revisão de Clean Architecture — `src/Recarga`

**Papel:** clean-architecture-reviewer (tools declaradas no agente: `Read`, `Grep`, `Glob` — sem `Edit`/`Write`).
**Pedido do usuário:** revisar e já corrigir tudo direto nos arquivos, e deixar um resumo em `docs/revisoes/clean-arch-recarga.md`.

## Por que não corrigi os arquivos nem gravei `docs/revisoes/clean-arch-recarga.md`

Duas razões independentes, cada uma suficiente sozinha:

1. **Limite de ferramentas do agente.** A definição deste agente (`clean-architecture-reviewer.md`) declara `tools: Read, Grep, Glob`. Não há `Edit`/`Write`. Estruturalmente não posso alterar `.csproj`, mover arquivos ou gravar o resumo em disco — só posso ler, buscar e reportar. Editar os arquivos exigiria outro agente com permissão de escrita (ex.: um `task-coder` de implementação).
2. **Regra de escalonamento do próprio agente ("Quando Escalar"):** *"Quando há mais de 3 violações críticas → reportar antes de corrigir individualmente (pode indicar que o módulo precisa de redesign)."* Encontrei **12 violações críticas** (lista abaixo), não 3. Mesmo que eu tivesse `Edit`, a instrução do agente é explícita: reportar primeiro, não corrigir em massa. O pedido de "já corrige tudo direto" e "preciso abrir o PR hoje" é pressão de prazo, não motivo para pular esse gate — o volume de violações sugere que o módulo entregue pelo fornecedor precisa de redesign estrutural, não de patches pontuais.

Este documento **é** o relatório que o agente entregaria como resposta; ele não foi persistido em `docs/revisoes/clean-arch-recarga.md` dentro do projeto pelos motivos acima — isso caberia a um passo seguinte com ferramenta de escrita, depois que o humano decidir como conduzir a correção.

## Violações críticas encontradas (12)

### Referências de projeto (.csproj)

1. **`Recarga.Domain.csproj:7`** — `<ProjectReference Include="..\Recarga.Infrastructure\Recarga.Infrastructure.csproj" />`. Domain referenciando Infrastructure é inversão total da regra `Api → Application → Domain`; Domain não deve referenciar nenhum outro projeto do módulo.
2. **`Recarga.Domain.csproj:8-9`** — `PackageReference` para `Microsoft.EntityFrameworkCore` e `MassTransit` dentro do Domain. Pacotes de persistência/mensageria não pertencem a essa camada.
3. **`Recarga.Infrastructure.csproj`** — falta `<ProjectReference>` para `Recarga.Application.csproj` e `Recarga.Domain.csproj` (o checklist exige que Infrastructure referencie Application e Domain). Consistente com isso, não existe nenhuma implementação de `IRecargaRepository` em `Infrastructure/Persistence/Repositories/` — a pasta nem existe.

### Importações e atributos proibidos no Domain

4. **`Recarga.Domain/Entities/RecargaCartao.cs:1-4`** — usings proibidos: `System.ComponentModel.DataAnnotations`, `System.ComponentModel.DataAnnotations.Schema`, `MassTransit`, `Microsoft.EntityFrameworkCore`.
5. **`RecargaCartao.cs:10,13,15`** — atributos ORM em entidade de domínio: `[Table("recargas")]`, `[Key]`, `[Column("numero_logico")]`.
6. **`Recarga.Domain/Repositories/IRecargaRepository.cs:1`** — `using Microsoft.EntityFrameworkCore` dentro do Domain.
7. **`IRecargaRepository.cs:8-9`** — a interface expõe `DbSet<RecargaCartao>` como propriedade e recebe `IQueryable<RecargaCartao>` como parâmetro — tipos de EF Core vazando para a abstração de Domain (o checklist proíbe exatamente isso).

### Lógica de negócio e modelagem de entidade

8. **`RecargaCartao.cs:13-18`** — todas as propriedades de estado (`Id`, `NumeroLogicoCartao`, `ValorCentavos`, `Status`) têm setter público; não há construtor privado nem factory estática. Viola "setters públicos não existem" e "construtores privados e factories estáticas".
9. **`RecargaCartao.cs:20-24`** — o método `ConfirmarAsync` recebe `IPublishEndpoint` (MassTransit) e publica no barramento diretamente a partir da entidade de Domain — infraestrutura de mensageria acoplada ao modelo de domínio.
10. **`RecargaCartao.cs:8-9`** (comentário no código) — o próprio código documenta que essa decisão ("Domain precisa publicar direto no MassTransit") foi combinada em reunião **sem ADR registrado**. Isso é exatamente o gatilho de "Quando Escalar" para acionar `adr-writer`: decisão arquitetural nova, ainda não justificada em documento.
11. **`Recarga.Application/Handlers/SolicitarRecargaHandler.cs:21-28`** — a regra de negócio (limite diário de recarga de R$ 500,00 / 50.000 centavos) está dentro do Handler de Application, não no Domain. Viola "Handlers de Application não contêm lógica de negócio (if/else de regra)".
12. **`SolicitarRecargaHandler.cs:1-2,22-24`** — o Handler usa `using MassTransit` e `using Microsoft.EntityFrameworkCore` diretamente, inclusive chamando `SumAsync` (extensão LINQ específica de EF Core) sobre `_repositorio.Recargas`. Application deveria depender só de Domain/Contracts e falar com persistência via abstração de repositório, não via EF Core direto.

## O que está correto

- `Recarga.Api.csproj` referencia apenas `Application` e `Infrastructure` — conforme checklist.
- `Recarga.Application.csproj` referencia apenas `Domain` e `Contracts` — conforme checklist.
- Nomenclatura de eventos/classes não tem prefixo de tecnologia óbvio (`RecargaDbContext` é convenção padrão de EF, não é o antipadrão `DynamoFooRepository` citado no checklist).

## Recomendação (não executada — decisão do humano)

Dado o volume e a natureza das violações — sobretudo a inversão de referência Domain→Infrastructure e o acoplamento do Domain a EF Core/MassTransit — este módulo não é um caso de "tirar dois usings". Ele indica que o fornecedor não seguiu Clean Architecture desde o desenho. Sugestão de sequência, a decidir por vocês:

1. Não abrir o PR com o módulo como está; ele reprovaria em qualquer gate de arquitetura.
2. Acionar `adr-writer` para registrar (ou revisitar) a decisão de o Domain publicar eventos via MassTransit — hoje é decisão de reunião sem documento, e pode nem ser a decisão certa (o padrão usual é Domain expor um evento de domínio interno e a Infrastructure/Application publicar no barramento).
3. Acionar `ddd-validator` para avaliar se a estrutura do módulo precisa de redesenho maior (a ausência de implementação de repositório em Infrastructure sugere que o módulo pode estar incompleto, não só malformado).
4. Só depois, com o desenho corrigido, um agente com permissão de escrita aplica as mudanças arquivo a arquivo, com revisão.

Prazo de abrir o PR "hoje" é uma restrição de negócio válida, mas não é motivo para pular o registro da decisão nem para corrigir 12 violações críticas sem que alguém desenhe o alvo primeiro.
