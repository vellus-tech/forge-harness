# Transcript — eval-adr-aceito-vs-proposto-e-contrato-v1-quebrado / without_skill / run-1

## Contexto

Caso de eval `without_skill`: execução sem ler `.forge/skills`, `.forge/agents`, `plugin/` ou `.forge/evals` do template (baseline sem o artefato do skill-creator/arch-reviewer). Conhecimento próprio apenas.

## Passos executados, em ordem

1. Gravei o instante inicial em `.t0` com `date +%s`.
2. Criei o diretório `work/` e executei o fixture setup:
   `bash .../fixtures/adr-aceito-vs-proposto-e-contrato-v1-quebrado/setup.sh <run>/work`
   O script roda `forge init` no alvo, aplica overlay `base/` sobre branch `develop`, depois overlay `feature/` sobre branch `feature/cache-pagamentos`, e remove `.forge/skills`, `.forge/agents`, `.claude/skills`, `.claude/agents` e `plugin/` do alvo (para não contaminar o baseline sem skill).
3. Inspecionei o repositório fixture:
   - `git log --all --oneline` → dois commits (`chore: estado inicial` em develop, `feat(pagamentos): mudança sob revisão` em feature/cache-pagamentos).
   - `git diff develop feature/cache-pagamentos --stat` e depois o diff completo.
   - Listei `docs/product/adr/` → ADR-0005 e ADR-0008.
   - Localizei as rules citadas pelo code-evaluator: `.forge/rules/architecture/{clean-architecture,ddd,api-and-contracts}.md`.
   - Listei a árvore de `services/pagamentos`.
4. Li o conteúdo de ADR-0005 (status **Aceito**, 2026-03-10 — proíbe Newtonsoft.Json em qualquer projeto, inclusive Infrastructure) e ADR-0008 (status **Proposto**, sem votação — troca EF Core por Dapper, ainda não vigente).
5. Li as três rules na íntegra (clean-architecture.md, ddd.md, api-and-contracts.md) e o código de domínio/infraestrutura relevante: `Pagamento.cs`, `IPagamentoRepository.cs`, `PagamentoRepository.cs`, `CamadasTests.cs` (teste de arquitetura existente com NetArchTest).
6. Analisei o diff linha a linha:
   - `PagamentoAprovadoV1.cs`: campo `Valor` (decimal) virou `ValorEmCentavos` (long) **no mesmo tipo**, sem criar V2.
   - `Pagamentos.Infrastructure.csproj`: adiciona `Newtonsoft.Json 13.0.3` e `Microsoft.EntityFrameworkCore 8.0.8`.
   - `CachedPagamentoRepository.cs` (novo): decorator de cache sobre `PagamentoRepository`, usa `JsonConvert.DeserializeObject` (Newtonsoft) para desserializar o cache.
   - `PagamentosDbContext.cs` (novo): `DbContext` simples expondo `DbSet<Pagamento>`, sem `IEntityTypeConfiguration<T>`.
7. Cruzei cada mudança de código com ADRs e rules:
   - Newtonsoft.Json → viola ADR-0005 (Aceito) → **blocker**.
   - Breaking change em `PagamentoAprovadoV1` sem nova versão → viola api-and-contracts.md ("Breaking changes sem nova versão" está nas proibições explícitas) → **blocker**.
   - EF Core / `PagamentosDbContext` → cruzei com ADR-0008 e confirmei que o status é **Proposto**, não Aceito — portanto **não é violação de ADR**, apenas um risco a registrar (se ADR-0008 for aceito depois, este código precisa migrar para Dapper). Tratei explicitamente essa distinção Aceito vs. Proposto para não gerar falso positivo.
   - `Pagamento.Valor` (decimal) no Domain vs. `ValorEmCentavos` (long) no Contract → inconsistência de representação monetária, sem objeto de valor `Money` nem conversão explícita → moderate (ddd.md).
   - `PagamentosDbContext` sem `IEntityTypeConfiguration<T>` → diretriz 12 de clean-architecture.md → moderate.
   - Comentário no código sobre "as duas implementações ficam ativas" sem diff tocando DI no projeto Api → registrado como pendência informativa, não como bug confirmado (não há evidência suficiente no diff).
8. Escrevi os findings em `work/review/arch-reviewer.json` (2 blockers, 2 moderate, 2 info).
9. Copiei os entregáveis para `outputs/`: `review/arch-reviewer.json`, o diff completo (`diff-develop-vs-feature.patch`) e os dois ADRs lidos, como evidência de apoio.
10. Nenhum subagente foi necessário para completar esta tarefa (revisão pontual de um diff pequeno e autocontido) — não houve despacho a registrar.

## Decisões-chave

- Tratei ADR-0005 como vinculante (status Aceito) e ADR-0008 como não vinculante (status Proposto) — distinção central deste caso de eval, feita por leitura literal do campo `Status` de cada ADR, não por suposição.
- Classifiquei a mudança de contrato como blocker por já haver consumidores nomeados (Bilhetagem, Conciliação) e por a regra de contratos proibir explicitamente breaking change sem nova versão.
- Não afirmei bug de DI (duas implementações do repositório) sem evidência no diff — reportei como item informativo a esclarecer com o autor, em vez de elevar a severidade sem prova.
