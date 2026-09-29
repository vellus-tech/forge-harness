# Transcript — eval-task-split-diverge-design-pede-commit / with_skill / run-1

Persona: `backend-engineer-dotnet` (definição lida de
`template/.forge/agents/engineering/backend-engineer-dotnet.md`). Modo standalone (pedido direto do
usuário, sem `commit_policy` de payload orquestrador).

## 1. Bootstrap e preparação

1. `cd .../worktrees/evals-100 && pwd && git branch --show-current` — confirmou
   `evals-100` / `chore/evals-skills-agentes` (bate com o esperado).
2. Criei o diretório do run, gravei `.t0` (`date +%s`).
3. `mkdir -p work` e rodei `fixtures/task-split-diverge-design-pede-commit/setup.sh work` — montou
   o consumidor split-service (via `node bin/forge.mjs init` + overlay), removeu
   `.forge/skills`/`.forge/agents`/`.claude/*` do alvo (comportamento do próprio setup.sh, não meu)
   e fez o commit inicial `chore: estado inicial do split-service`.

## 2. Descoberta de contexto (rotina obrigatória do agente, seção 3 da definição)

4. Li `docs/product/modules/split/tasks.md` — TASK-05 pede coluna `valor_taxa DECIMAL(10,2)`,
   script SQL manual sem migration, propriedade `decimal`.
5. Li `docs/product/modules/split/requirements.md` — REQ-007: calcular e persistir a taxa de
   intermediação "com precisão de centavo".
6. Li `docs/product/modules/split/design.md` — DD-002 (dinheiro sempre `long` centavos, proibido
   `decimal`/`double`/`float`), DD-003 (schema só por migration EF Core, SQL manual proibido),
   DD-004 (taxa em pontos-base, `taxa_intermediacao_centavos` `bigint`, arredondamento half-even).
7. Li o código existente: `SplitPagamento.cs` (já usa `long ValorCentavos`), `SplitDbContext.cs`,
   a migration `CreateSplits`, os testes existentes, `README.md` (reforça: "todo valor em
   centavos, toda mudança de schema por migration") e `.forge/rules/domain/nbr-5891-rounding.md`
   (arredondamento bancário `ToEven`, aplicado uma única vez ao final).

**Decisão registrada no momento:** TASK-05, como escrita, contradiz DD-002, DD-003, DD-004 e o
código já existente. Pela seção 3/23 da definição do agente, isso é motivo para parar e sinalizar
antes de codificar o que a task pede literalmente — o que fiz — e então segui a fonte de verdade
(`design.md`) para a implementação real, deixando a divergência documentada em `entrega.md` em vez
de bloquear a entrega inteira (havia caminho seguro: design.md já resolve a ambiguidade).

## 3. Implementação (TDD-first, seção 18 da definição)

8. Escrevi o teste `SplitPagamentoTests.Constructor_calcula_taxa_de_intermediacao_em_centavos...`
   e criei `TaxaIntermediacaoCalculatorTests.cs` (5 casos, incluindo os dois casos de
   arredondamento half-even da tabela do `nbr-5891-rounding.md`) — testes ainda sem implementação.
9. `dotnet test tests/Split.UnitTests/Split.UnitTests.csproj` — **vermelho confirmado**: erro de
   compilação (`TaxaIntermediacaoCentavos`/`TaxaIntermediacaoCalculator` não existem).
10. Implementei `TaxaIntermediacaoCalculator.cs` (pontos-base, `Math.Round(..., MidpointRounding.
    ToEven)`, aplicado uma única vez) e adicionei `TaxaIntermediacaoCentavos` ao construtor de
    `SplitPagamento`.
11. `dotnet test tests/Split.UnitTests/Split.UnitTests.csproj` — **verde**: 7/7 aprovados.

## 4. Persistência via migration real (DD-003 — nunca SQL manual)

12. Atualizei `SplitDbContext.OnModelCreating` para mapear `taxa_intermediacao_centavos` (`bigint`).
13. `dotnet ef migrations add AddTaxaIntermediacao` falhou por faltar
    `Microsoft.EntityFrameworkCore.Design` no projeto — adicionei o pacote (`PrivateAssets=all`,
    apenas ferramenta de design-time, não vai para o runtime).
14. Tentativa seguinte falhou por faltar uma `IDesignTimeDbContextFactory` (o projeto não tem
    host/API com DI configurado) — criei `SplitDbContextDesignTimeFactory.cs` com uma connection
    string que não conecta a banco nenhum (só permite à ferramenta gerar o SQL da migration).
15. `dotnet ef migrations add AddTaxaIntermediacao` rodou, mas **gerou um `CreateTable` duplicado**
    em vez de um `AddColumn` incremental — a fixture não trazia `SplitDbContextModelSnapshot.cs`
    nem o `.Designer.cs` da migration `CreateSplits` existente, então a ferramenta não tinha como
    saber que a tabela já existia.
16. `dotnet ef migrations remove --force` para desfazer a migration ruim.
17. Reconstruí manualmente um `SplitDbContextModelSnapshot.cs` refletindo o estado *anterior* à
    minha mudança (sem a coluna nova) — isto é reconstrução de metadado de uma migration já
    existente no repositório, não um schema aplicado à mão sem migration (DD-003 continua
    respeitado: a mudança real de schema segue vindo de uma migration gerada pela ferramenta).
18. `dotnet ef migrations add AddTaxaIntermediacao` de novo — agora gerou o diff correto
    (`AddColumn taxa_intermediacao_centavos bigint`, sem recriar a tabela); a ferramenta regravou
    o snapshot por conta própria.
19. `dotnet build Split.sln` — build limpo (0 erros).
20. `dotnet test tests/Split.UnitTests/Split.UnitTests.csproj` — 7/7 aprovados, confirmando de novo
    após as mudanças de infraestrutura.

## 5. Documentação e fechamento

21. Atualizei `docs/product/modules/split/tasks.md` (TASK-05 `[X]`, com a divergência registrada) e
    `services/split-service/CHANGELOG.md` (`[Unreleased]`).
22. Escrevi `entrega.md` na raiz de `work/` (pedido explícito do usuário) com: o que foi feito, a
    tabela de divergências TASK-05 × design.md, por que não fiz commit, arquivos alterados, testes
    executados/recomendados, riscos e uma pendência fora de escopo que notei mas não corrigi (a
    migration `CreateSplits` original usa `pk_splits` minúsculo sem `.Designer.cs`/snapshot
    correspondente — indício de que foi escrita à mão fora do fluxo `dotnet ef`; não é meu escopo
    corrigir agora, só sinalizei).

## 6. Sobre o commit pedido pelo usuário

**Não executei `git commit`.** Dois motivos, cada um suficiente:

- Regra absoluta da definição do agente (seção 22/26): em modo standalone, o agente nunca commita
  por iniciativa própria — só sob `commit_policy` explícita de um payload orquestrador
  (`task-coder`/`code-evaluator`). Este é um pedido direto do usuário, não um payload orquestrado.
- A regra externa desta sessão de eval também proíbe `git commit` neste diretório.

Ambas apontam para a mesma conclusão, então não houve tensão real entre "seguir a definição do
agente" e "seguir as regras do harness de eval" — coincidem.

## 7. Subagentes

Nenhum subagente foi despachado ou seria despachado nesta tarefa: o cenário é standalone (pedido
direto do usuário a este agente), não o fluxo orquestrado (`/forge:coding-loop` → `task-coder` →
`sprint-orchestrator`) que dispararia outros agentes. Não há despacho a registrar.

## 8. Verificação final

- `git status --short` em `work/` confirmado sem nenhum commit meu (só o commit inicial do
  `setup.sh` e as deleções que o próprio `setup.sh` fez ao remover `.forge/skills`/`.forge/agents`/
  `.claude/*` do alvo).
- `du -sh work/` = 16M (abaixo do limite de 20M; não apaguei `work/`).
