# Transcript — eval-debito-carteira-bordas-e-concorrencia / without_skill / run-1

## Bootstrap

1. `cd <worktree-do-eval> && pwd && git branch --show-current` — confirmado `evals-100` / `chore/evals-skills-agentes`, como esperado.

## Preparação

2. `date +%s > .../run-1/.t0` — instante inicial gravado.
3. `mkdir -p .../run-1/work`
4. `bash .../fixtures/debito-carteira-bordas-e-concorrencia/setup.sh .../run-1/work` — setup executado sem erros, projeto materializado em `work/`.

## Exploração (sem ler `.forge/skills`, `.forge/agents`, `plugin/` ou `.forge/evals` do worktree pai — apenas o conteúdo entregue dentro de `work/`)

5. `git status` / `git log --oneline -10` dentro de `work/` — branch ativo `feature/debito-carteira`, dois commits: `c268fea` (estado inicial do módulo) e `afa65d8` (mudança sob revisão).
6. `find . -iregex '.*carteira.*'` — localizados `services/carteira/{src,tests}` e `docs/product/modules/carteira/requirements.md`.
7. `git diff c268fea afa65d8 -- services/carteira docs/product/modules/carteira .forge/rules/domain/money-as-cents.md` — diff completo da mudança sob revisão lido integralmente: `SaldoFormatter.cs` (novo), `ICarteiraRepository.cs` (novo), `DebitarTarifaHandler.cs` (novo), `CarteiraPrePaga.cs` (método `Debitar` adicionado), `SaldoInsuficienteException.cs` (novo), `CarteiraPrePagaTests.cs` (novo, 2 testes).
8. Leitura de `docs/product/modules/carteira/requirements.md` — REQ-7 (débito nunca deixa saldo negativo), REQ-8 (débitos simultâneos entre validadores não podem perder débito nem deixar saldo negativo), REQ-9 (carteira inexistente → `CarteiraNaoEncontradaException`, sem efeito colateral).
9. Leitura de `.forge/rules/domain/money-as-cents.md` — dinheiro sempre em centavos (`long`), nunca `decimal`/`float` no domínio, Value Object `Money` obrigatório no domínio, conversão para exibição só na camada de apresentação.
10. Leitura completa de `CarteiraPrePaga.cs`, `DebitarTarifaHandler.cs`, `ICarteiraRepository.cs`, `CarteiraPrePagaTests.cs` com números de linha (`cat -n`).
11. `find services/carteira -iname '*Exception*'` — confirmado que só existe `SaldoInsuficienteException.cs`; `CarteiraNaoEncontradaException` (exigida pelo REQ-9) não existe em lugar nenhum do serviço.

## Análise (raciocínio, sem ferramenta)

- REQ-7: a guarda em `Debitar` só cobre o caso em que `valorEmCentavos` é positivo e maior que o saldo. Não há validação de que `valorEmCentavos > 0`; um valor negativo faz a subtração virar soma e o saldo aumenta sem disparar a exceção — quebra a invariante central do REQ-7 e da rule money-as-cents (que também exige que o domínio use um Value Object `Money`, que poderia ter barrado isso na construção).
- REQ-8: o fluxo do handler é ler (`ObterAsync`) → calcular em memória (`Debitar`) → gravar tudo (`AtualizarAsync`), sem nenhum campo de versão/ETag na entidade nem parâmetro de concorrência na interface do repositório. Isso é um clássico read-modify-write sem proteção: dois débitos concorrentes na mesma carteira podem ler o mesmo saldo, ambos passarem a validação e a segunda escrita sobrescrever a primeira (last-write-wins), perdendo um débito — exatamente o que REQ-8 proíbe.
- REQ-9: o handler usa `carteira!.Debitar(...)` sobre um retorno `Task<CarteiraPrePaga?>` — o operador null-forgiving silencia o aviso do compilador em vez de tratar o caso de carteira inexistente. Como `CarteiraNaoEncontradaException` não existe no código, o caminho real para carteira inexistente é `NullReferenceException`, não a exceção de negócio exigida pelo REQ-9.
- Qualidade de teste: `Debitar_SaldoInsuficiente_LancaExcecao` debita 440 de um saldo de 1000 (débito com saldo de sobra) e só confere o saldo resultante — não há `Assert.Throws` em lugar nenhum do arquivo. O nome promete testar o caminho de exceção por saldo insuficiente, mas o REQ-7 (a regra mais crítica do domínio) está sem cobertura real, apesar do "testes verdes" mencionado na tarefa.
- Dívida secundária, não bloqueante isoladamente: o domínio usa `long` cru em vez do Value Object `Money` exigido pela diretriz 3 da rule — pré-existente ao diff, mas estendida por ele.

## Entregáveis

12. Escrita de `.forge/reviews/logic-debito-carteira.json` dentro de `work/`, com veredito REPROVADO, 5 findings (3 críticos ligados a REQ-7/REQ-8/REQ-9, 1 alto sobre o teste enganoso, 1 médio sobre a rule money-as-cents), seção de borda/concorrência e lista explícita de testes que não testam o que dizem.
13. `python3 -m json.tool` sobre o arquivo — válido.
14. Cópia do JSON para `outputs/logic-debito-carteira.json`.
15. Registro em `outputs/subagent-dispatch-simulado.md` do despacho de subagentes que seria feito (nenhum subagente foi realmente disparado, por regra do harness para este caso de eval).
16. `du -sh work/` — 6,1 MB, abaixo do limite de 20 MB; `work/` mantido.

## Decisões

- Não rodei build/test (`dotnet test`) porque a regra do harness proíbe `npm test`/execução de suíte de verdade nesta run isolada; a análise foi 100% por leitura de código e requisitos, que é justamente o modo de operação esperado de uma revisão de lógica sem execução do teste (a tarefa pede para *revisar*, não rodar a suíte).
- Não li nada em `template/.forge/skills`, `template/.forge/agents`, `plugin/` nem `.forge/evals` do worktree pai, conforme a regra do caso `without_skill` (baseline sem o artefato skill-creator/logic-reviewer).
- Não fiz `git commit`/`push`/`checkout`/`stash` em nenhum momento.
