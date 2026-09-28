# Análise do benchmark — dotnet-quality-scan

Gerado pela agregação determinística de `.forge/evals/skills/dotnet-quality-scan/workspace/iteration-1/benchmark.json` (script `aggregate_benchmark`, sem cálculo manual). Viewer estático em `workspace/iteration-1/review.html`.

## Resultado

| | pass_rate (média) | stddev | min–max |
|---|---|---|---|
| Com skill | 0.8333 | 0.165 | 0.67–1.0 |
| Sem skill | 0.5533 | 0.3868 | 0.33–1.0 |

Delta = 0.8333 − 0.5533 = **+0.28** → veredito **agrega** (≥ 0.15).

Tempo médio: com skill 140 s, sem skill 116 s (+24 s) — custo de tempo moderado, coerente com o protocolo de 5 passos fixos em vez de leitura livre.

Por eval: eval 1 (revisao-recarga-pix) 0.83 com skill vs 0.33 sem skill; eval 2 (validador-desktop-baseline-furado) 0.67 com skill vs 0.33 sem skill; eval 3 (tokenizacao-go-fora-de-stack) 1.0 em ambas as configurações.

## Asserções não discriminantes

As 5 asserções do eval 3 (tokenizacao-go-fora-de-stack) passam 100% em ambas as configurações — o guard-rail "não aplicar regras .NET a um serviço Go" já é seguido por bom senso, sem precisar da skill. Isso é esperado (é um teste de não-aplicabilidade, não de capacidade), mas não diferencia a skill; ela vale como regressão, não como evidência de valor.

## Onde a skill ajudou (evidência de transcript)

- **Cobertura das 11 regras, inclusive as `OK`.** No eval 1, a asserção "cita as 11 regras, inclusive as que não acharam nada" falha sem skill (0 ocorrências dos IDs) e passa com skill (grep confirma todos os 11 IDs, benchmark.json linhas do eval 1). O transcript `with_skill/run-1` (passo 7) mostra o `scan.sh` sendo rodado e seu output completo preservado; o `without_skill/run-1` nunca roda um scanner e organiza o relatório por severidade subjetiva (Bloqueadores/Riscos/Observações), sem taxonomia de regra — a skill impõe a estrutura auditável que o protocolo pede.
- **Baseline de build antes do achado de código.** Em ambos os evals 1 e 2, a asserção "build reprovado/registrado antes do achado de código" falha sem skill e passa com skill. No eval 2, o transcript `with_skill` (passos 9–10) mostra o modelo rodando `dotnet-baseline.sh --check` duas vezes até acertar o `--root`, encontrando `TreatWarningsAsErrors=false` e a ausência de `dotnet_diagnostic.IDE1006.severity`, e citando isso ANTES da tabela de achados do scanner — exatamente o diagnóstico que o time do fixture não sabia articular (CI verde, IDE vermelha). Sem skill, o parecer (linha 5) chega a afirmar o oposto: "isso é real e está funcionando", sem nunca mencionar `IDE1006` ou `EnforceCodeStyleInBuild`.
- **Veredito diferenciado para a mesma regra em contextos diferentes.** No eval 1, com skill, os três achados de `blocking-wait` recebem veredito distinto — `.Result` no controller é defeito, `GetAwaiter().GetResult()` no `Main` de uma CLI é exceção legítima — porque a skill nomeia essa exceção explicitamente em `references/clean-code-rules.md` e no corpo do `SKILL.md`. Sem skill, o `Program.cs` do `Recarga.Seed` nem é mencionado no relatório.
- **Falso alarme documentado sob demanda.** No eval 2, ambas as configurações (com e sem skill) classificam corretamente `async void` do handler WinForms como falso alarme — aqui a skill não muda o resultado, mas dá um vocabulário padronizado ("FALSO ALARME, não corrigir") que facilita auditoria.

## Onde a skill atrapalhou ou não ajudou

- **Promessa que o script não cumpre.** No eval 2, com skill, `parecer-validador.md` linha 71 afirma que `dotnet-baseline.sh --apply` "fecha a lacuna de enforcement" para `Directory.Build.props` e `.editorconfig` — mas o próprio script (`dotnet-baseline.sh:49`, citado na evidência do grading) documenta que arquivo existente e incompleto **não é sobrescrito** sem `--force`. A skill dá acesso ao script mas não avisa dessa armadilha no texto do `SKILL.md`; o modelo, mesmo carregando a skill, prometeu uma correção automática que o script não entrega. Essa asserção falha nas duas configurações, mas por motivos diferentes: sem skill, por nunca mencionar `--apply`; com skill, por prometer mais do que o `--apply` faz.
- **Regra "arquivo:linha obrigatório" não cobre achados fora do scanner.** No eval 1, com skill, a asserção "cada achado traz arquivo:linha" falha porque o achado de `single-impl-interface` (linha 71 do relatório) e os três itens da seção "Além do scanner" (validação de valor, idempotência, responsabilidade dupla) não trazem `arquivo:linha`. O `SKILL.md` só diz "achado sem arquivo:linha não entra" no passo 5, referindo-se implicitamente à tabela de regras do scanner; a seção "Ele também não substitui a leitura do diff" — que o próprio texto da skill incentiva a incluir — não herda essa exigência, e o modelo tratou os dois tipos de achado com rigor diferente.
- **Achado que expõe uma asserção de eval possivelmente mal calibrada, não uma falha real da skill.** No eval 2, a asserção espera que `single-impl-interface` seja tratado como "porta hexagonal deliberada", não como defeito a remover. Nas duas configurações o modelo investigou (`grep -rl ITabelaTarifariaRepository`, busca por projeto de teste) e não achou segunda implementação nem dublê — ou seja, a exceção alegada no comentário do fixture não se sustenta, e classificar como defeito real é o julgamento correto dado o `references/clean-code-rules.md` (que só perdoa a interface quando a fronteira é genuína). A asserção do eval, portanto, pune o comportamento correto; ver "Qualidade dos casos" abaixo.

## Trechos do artefato ignorados, ambíguos ou desperdiçando tempo

- **Passo 2 do protocolo ("Baseline de build") não diz como localizar a raiz correta do repositório para `--root`.** No eval 2 (transcript `with_skill`, passo 9), o modelo errou a primeira tentativa (`--root src/Validador.Desktop`, resultado `MISS` em tudo) porque os arquivos de baseline vivem na raiz do monorepo, não no projeto. Isso não é falha do scanner, é ambiguidade do `SKILL.md`: o passo 1 ("Escopo") define paths .NET afetados, mas não distingue explicitamente "escopo da varredura de código" (pode ser um projeto) de "raiz para o baseline de build" (é o repositório/solução). Uma frase adicional evitaria a tentativa-e-erro.
- **`scripts/scan.sh` referenciado com dois caminhos diferentes ao longo da sessão.** O protocolo cita `.forge/skills/dotnet-quality-scan/scripts/scan.sh` (SKILL.md, passo 3), mas dentro do worktree de avaliação o caminho real é `template/.forge/skills/dotnet-quality-scan/scripts/scan.sh` — o modelo teve que inferir isso sozinho (transcript eval 2, passo 11: "o `scan.sh` do fixture project não existia... usei o `scan.sh` da própria skill carregada"). Em produção normal (repositório com o harness instalado na raiz) esse desvio não existiria, mas é o tipo de ambiguidade de caminho relativo que custa uma rodada extra de busca sempre que a skill roda fora do próprio repositório do harness.
- Não foi identificado texto do `SKILL.md` explicitamente contraditório entre si; a única contradição observada foi entre o texto da skill (silencioso sobre o comportamento de `--apply` com arquivo incompleto) e o comportamento real do script chamado por ela — tratado acima como a melhoria mais concreta.

## Melhorias concretas priorizadas

1. **[Alto] Documentar a limitação do `--apply` diretamente no `SKILL.md` ou no passo 2 do protocolo**: uma frase do tipo "`--apply` só cria o que falta; arquivo existente e incompleto exige edição manual ou `--force`" evitaria a promessa incorreta observada no eval 2. Hoje essa informação só está no próprio script (`dotnet-baseline.sh`), que a skill não obriga a ler.
2. **[Alto] Estender a exigência de `arquivo:linha` do passo 5 para qualquer achado do relatório, não só a tabela de regras do scanner.** Reformular: "Todo achado do relatório — inclusive os da leitura do diff que o scanner não cobre — traz arquivo:linha; achado sem isso não entra." Isso fecha a lacuna que reprovou o eval 1 mesmo com a skill carregada.
3. **[Médio] Esclarecer no passo 2 que `--root` do `dotnet-baseline.sh` é a raiz do repositório/solução (onde vivem `Directory.Build.props`/`.editorconfig`), distinta do `--root` do `scan.sh` (o escopo de código a varrer).** Isso teria evitado a tentativa `MISS` no eval 2.
4. **[Baixo] Script a embutir**: nenhum novo script é necessário — `scan.sh` e `dotnet-baseline.sh` já cobrem o determinístico. A melhoria é textual, não de tooling.
5. **[Baixo/fusão] Não fundir nem remover seções**: as duas camadas (build vs scanner) e a distinção "scanner não julga" já estão bem separadas e cada uma se provou necessária nos transcripts; não há redundância a cortar.

## Qualidade dos casos (eval_quality)

Os dois casos discriminantes (eval 1 e eval 2) são bem desenhados: cada um embute uma pegadinha de julgamento (exceção legítima vs defeito real) e uma reprovação de infraestrutura de build que só aparece se o protocolo completo for seguido — isso é exatamente o que a skill promete cobrir, e a diferença de pass rate (0.83 vs 0.33, e 0.67 vs 0.33) confirma que os casos capturam esse valor.

Dois problemas, porém:

- **A asserção `single-impl-interface` do eval 2** ("não exige remover... trata como porta hexagonal deliberada") está desalinhada com o próprio fixture: o `references/clean-code-rules.md` da skill só perdoa essa regra quando a fronteira é genuína, e o fixture não contém segunda implementação nem dublê de teste que sustente a alegação do comentário. Um modelo que investiga (como os dois fizeram) chega à conclusão oposta à esperada pela asserção, por bons motivos. Ou o fixture ganha uma implementação de teste real (tornando a exceção genuína) ou a asserção é reescrita para aceitar "defeito real, com justificativa investigada" como resultado válido.
- **Eval 3 não diferencia** (100%/100%) — é um bom guard-rail de "não aplicar fora de stack", mas não mede capacidade da skill. Se o objetivo do conjunto é medir valor incremental, vale substituí-lo ou complementá-lo por um caso de fronteira que realmente estresse a skill (ex.: monorepo misto .NET + Go, onde só a parte .NET deve ser escaneada) — mantendo o atual como regressão de baixo custo, não como sinal de qualidade.

Nenhuma asserção foi encontrada sempre-falha nas duas configurações por razão de bug do harness de avaliação (grading.json não indica erro de execução); a única falha sistemática (`single-impl-interface`) tem causa de calibração do fixture, não de framework.
