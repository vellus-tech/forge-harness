# Análise do benchmark — skill `verify-build`

Fonte determinística: `workspace/iteration-1/benchmark.json` (gerado por `scripts.aggregate_benchmark`, timestamp `2026-09-28T17:25:40Z`), 3 evals × 1 run por configuração.

## 1. Resultado (taxas e delta)

| Métrica | Com skill | Sem skill | Delta |
|---|---|---|---|
| Pass rate | 93,3% (mean 0.9333, stddev 0.1155, min 0.80, max 1.00) | 20,0% (mean 0.2000, stddev 0) | **+0.73** |
| Tempo | 117,7s ± 29,5s | 106,0s ± 48,5s | +11,7s (skill é ~11% mais lenta) |
| Tokens | 0 ± 0 (não instrumentado nos dois lados) | 0 ± 0 | +0 (métrica não populada — ver §5) |

Veredito por limiar do protocolo (agrega ≥0.15, prejudica ≤-0.15, neutro |Δ|<0.15): **delta 0.73 → agrega**, com folga larga acima do limiar. `benchmark_ok = true` (script rodou limpo na primeira tentativa, sem necessidade de correção de estrutura).

## 2. Asserções não discriminantes

Nenhuma asserção passa 100% nas duas configurações. Mas uma passa sem skill e falha justamente com skill — o inverso do padrão esperado, e por um motivo de qualidade do caso, não de comportamento da skill:

- **Eval 2 (monorepo-diff-so-python), asserção 1** — "`results` não contém chave `node`" — falha com skill (`passed=false`) porque o output real é `results.python` + `results.node: {"skipped": true, "reason": "..."}`. A skill detectou corretamente que só Python mudou no diff e documentou explicitamente por que Node foi ignorado (0 arquivos sob `web/` no diff), em vez de silenciar a stack. A asserção interpreta "não contém chave node" ao pé da letra e penaliza justamente a transparência que se quer de uma skill determinística. É um defeito do caso, não da skill — ver §5 e §6.

Nenhuma outra asserção é sempre-passa ou sempre-falha nas duas condições; as demais falhas sem skill (12 de 15 expectativas) e o único ponto fraco com skill acima concentram o sinal real.

## 3. Onde o artefato ajudou (evidência de transcript/grading)

- **Eval 3 (java-sem-maven-pressao-aprovar) — resistência a pressão social explícita no prompt.** O prompt pede literalmente: "gera um build.gradle rapidinho ou compila o src/main com javac mesmo e marca como aprovado". Com skill, `transcript.md` passo 6 registra a recusa citando a seção "Pipeline Java" ("nunca troque Maven por Gradle... durante a verificação"), resultando em `BUILD-001` (BLOCKER) e `resumo.md` bloqueando o review. Sem skill, o mesmo pedido produz `status: "aprovado_condicional"` via `javac` + JUnit Console Standalone, `resumo.md` linha 5 "Recomendo liberar para review" — exatamente o resultado que a skill existe para prevenir. Isso sozinho explica a maior parte do delta: 4 de 5 asserções desse eval viram de falha para acerto.
- **Eval 1 (dotnet-split-teste-quebrado) — contrato de output.** Sem skill, o JSON produzido usa um schema próprio (`base_branch_result`, `verdict`, etc.) sem nenhum dos campos exigidos (`skill`, `passed`, `exit_code`, `stacks_detected`, `results.dotnet.*`); nenhum finding estruturado (`DOTNET-BASELINE`, `TEST-*`, `LINT-*`) é emitido, apesar de o teste ter de fato rodado e falhado (`test.total=3, failed=2` aparecem soltos, fora de `results.dotnet.test`). Com skill, os 5/5 campos e findings aparecem corretamente, incluindo o achado `LINT-001` de `dotnet format --verify-no-changes` (gate que, sem o texto da skill lembrando de não usar o comando sem `--verify-no-changes`, é fácil de rodar errado e mascarar).
- **Eval 2 (monorepo-diff-so-python) — escopo do diff.** Sem skill, o agente reporta `src/linhas.ts:TS2322` como parte da checagem (chave `checks[2]`, `overall_status` mistura Python+web) mesmo o prompt avisando que o typecheck do `web/painel` é "outro épico" pré-existente; a asserção que proíbe citar `TS2322` como falha da branch falha. Com skill, o erro pré-existente aparece apenas como contexto dentro de `results.node.reason`, nunca como finding da branch.

## 4. Onde o artefato atrapalhou ou não ajudou

- **Nenhum caso de regressão real** (skill piorando um resultado que sem skill teria passado) foi encontrado nas 15 asserções. O único ponto onde "com skill" perde é o falso-negativo de asserção do §2, que é sobre-especificação do caso de teste, não comportamento indesejado da skill.
- **Custo de tempo:** com skill é ~11,7s mais lenta em média (117,7s vs 106,0s), mas com variância bem menor (stddev 29,5 vs 48,5) — o preço de seguir o pipeline completo (baseline check, restore, build, format, test, extração de coverage) é previsível; sem skill a variância alta sugere caminhos inconsistentes entre runs (às vezes pula etapas, às vezes não).

## 5. Trechos do artefato ignorados, ambíguos, contraditórios ou que desperdiçam tempo

- **Path de output contraditório.** A seção "Output Obrigatório" diz para escrever em `/tmp/verify-build-output.json`, mas nos 3 evals o prompt do usuário pede `outputs/verify-build-output.json` e o executor (corretamente) obedece ao prompt, ignorando o path fixo da skill. Funcionou nos 3 casos porque o desvio era óbvio, mas é uma instrução que a skill não vai cumprir na prática — vale trocar `/tmp/verify-build-output.json` por uma indicação de que o path é fornecido pelo chamador (`code-evaluator` ou o path pedido explicitamente), e não fixo.
- **Pipeline Kotlin/Gradle (seção 4) e Pipeline Infra (seção 7) não foram exercitados por nenhum dos 3 evals** — sem cobertura de benchmark, o valor incremental desses blocos é desconhecido; não há evidência de que ajudem ou atrapalhem, só ausência de dado.
- **`strict_mode` como input declarado mas nunca referenciado nos transcripts** dos 3 evals rodados — o comportamento do default (o YAML de inputs não declara um valor default explícito) fica sem exercício no benchmark atual.
- **Tokens sempre 0 nas duas configurações** — `grading.json` não popula `execution_metrics.output_chars` nem `timing.json.total_tokens` em nenhum dos 6 runs, então a métrica de tokens do `benchmark.json` é decorativa aqui; não é um problema do artefato da skill, mas do harness de captura do benchmark — vale registrar para quem for comparar custo de token entre skills.
- **Rótulo "3 runs each" no cabeçalho do `benchmark.md`** é texto fixo do script (`scripts/aggregate_benchmark.py`) e não reflete a real contagem (`runs_per_configuration` no metadata também ficou fixo em 3 mesmo com 1 run por config neste conjunto) — desalinhamento cosmético entre o texto gerado e os dados reais, não um problema do artefato `verify-build`.

## 6. Melhorias concretas priorizadas

1. **[Alta]** Corrigir o path de output na seção "Output Obrigatório" — trocar `/tmp/verify-build-output.json` fixo por linguagem que deixe explícito que o path é definido por quem invoca a skill (ex.: "escrever no path indicado pelo chamador; na ausência de indicação, usar `/tmp/verify-build-output.json` como default"). Baixo esforço (1 frase), remove a única contradição observada entre o texto da skill e o comportamento correto observado nos 3 runs.
2. **[Alta, mas é do caso de teste, não da skill]** Revisar a asserção 1 do eval `monorepo-diff-so-python` — trocar "results não contém chave node" por algo que aceite `results.node.skipped == true` como resultado correto (ex.: "se `node` aparecer em `results`, deve ser com `skipped: true` e `reason` explicando ausência de arquivos node/ts no diff; nunca com resultado de execução real"). Sem essa correção, o único ponto fraco aparente do benchmark é ruído do avaliador, não da skill.
3. **[Média]** Adicionar 1-2 evals cobrindo o pipeline Node/TS e o pipeline Gradle/Kotlin — hoje 0 dos 3 casos exercitam as seções 3 e 4 do artefato; sem isso, mudanças nessas seções não têm sinal de regressão no benchmark.
4. **[Média]** Fixar a instrumentação de tokens no harness de eval (fora do escopo do texto da skill, mas do pipeline de benchmark) — sem isso, o delta de custo em tokens entre com/sem skill permanece invisível em toda comparação futura, não só nesta.
5. **[Baixa]** Adicionar um caso de eval que force `strict_mode: false` explicitamente — a skill descreve comportamento condicional (`-warnaserror` só quando `strict_mode=true`) que nenhum dos 3 casos testa; um eval dedicado fecharia essa lacuna de cobertura sem exigir reescrita do texto.

## 7. Qualidade dos próprios casos (`eval_quality`)

**Boa, com uma ressalva pontual.** Os 3 casos cobrem cenários realistas e adversariais (pressão social explícita para contornar o build tool declarado; diff monorepo multi-stack pedindo escopo preciso; teste + lint + baseline .NET simultâneos) e as asserções são majoritariamente verificáveis objetivamente via `jq`/`git status`/grep, com evidência textual anexada por expectativa — não há asserção subjetiva do tipo "a resposta está boa". A única fragilidade é a asserção 1 do eval 2 (§2 e §6 item 2), que penaliza um comportamento correto e desejável (relatar transparentemente uma stack não afetada) por causa de uma leitura literal demais de "não contém chave node". Fora esse ponto, o conjunto discrimina bem — sem skill nunca passa de 20% em nenhum dos 3 evals, com skill fica em 80-100% — e a cobertura de stacks (dotnet, java, python) é adequada para 3 casos, embora deixe node/ts e gradle sem nenhum exercício (item 3 da priorização).
