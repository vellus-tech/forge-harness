# Análise do benchmark — agente `eval-executor` (template/.forge/agents/quality/executor.md)

Gerado por retomada (`retome`) da issue #176. Agregação determinística via `scripts.aggregate_benchmark` (rc=0, sem erro — `benchmark_ok=true`) sobre `.forge/evals/agents/executor/workspace/iteration-1/benchmark.json` (timestamp `2026-09-28T17:29:48Z`) e viewer estático em `workspace/iteration-1/review.html`. Os dados de `grading.json`/`transcript.md` mudaram em disco desde a agregação anterior (havia uma rodada de `retome` corrigindo falhas mecânicas de uma passada mais antiga); a análise abaixo usa o estado atual, não o histórico.

## 1. Resultado (benchmark.json → run_summary)

| Config | pass_rate (média) | stddev | min | max | time_seconds (média) |
|---|---|---|---|---|---|
| with_skill (com executor.md) | 0.60 | 0.529 | 0.0 | 1.0 | 139.3 |
| without_skill (sem executor.md) | 0.4433 | 0.510 | 0.0 | 1.0 | 125.3 |

Delta = 0,60 − 0,4433 = **+0,1567 (~+0,16)**. Pelo corte do enunciado (agrega se delta ≥ 0,15), o veredito determinístico é **agrega**. Mas o delta inteiro vem de um único eval (dos três) e uma única run por configuração — ver §5 sobre robustez.

Por eval (3 evals × 1 run/config):

| Eval | with_skill | without_skill |
|---|---|---|
| 1 — executa-ab-conciliacao-dois-casos | 1.0 (6/6) | 0.33 (2/6) |
| 2 — registra-falha-e-timeout-sem-abortar | 0.0 (0/5) | 0.0 (0/5) |
| 3 — recusa-dar-nota-e-editar-skill | 0.8 (4/5) | 1.0 (5/5) |

## 2. Asserções não discriminantes

- Eval 1, "nenhum grading.json/comparison.json/analysis.json e nenhuma chave de veredito em results.json" e "git diff limpo em skills-dev/data" — passam em ambas as configs em todas as runs. Testam disciplina geral de não escrever fora do escopo, não conhecimento específico do executor.md.
- Eval 3, três das cinco expectations (contrato do results.json no caminho certo, ausência de chaves de veredito, git diff limpo) passam com e sem o artefato — comportamento que o agente já produz por bom senso/pelas regras do harness, sem precisar ler `executor.md`.
- Eval 3, a expectation "resposta final recusa nota/edição e encaminha ao grader" também passa **sem** o artefato nesta rodada (evidência abaixo) — o texto de `executor.md` não é decisivo aqui; a recusa parece vir da própria moldura da tarefa ("dar nota é trabalho de outro estágio") e das regras gerais de "não altere skills" do harness superior, não de algo que só está em `executor.md`.

## 3. Onde o artefato ajudou

Eval 1 é o único caso com diferenciação limpa e evidência causal clara. A run `with_skill` (que leu `executor.md`) corrigiu, de forma explícita, os erros de uma passada anterior que havia tratado o nome da pasta de benchmark `with_skill/run-1` como instrução para rodar só a perna variant:

> "A run anterior tratou 'with_skill' (nome da pasta with_skill/run-1) como se fosse o único braço a executar; é apenas o nome do diretório do caso de eval, não uma instrução para pular o baseline." (`eval-executa-ab-conciliacao-dois-casos/with_skill/run-1/outputs/transcript.md`)

Depois de reler a seção "Execução" do artefato, o agente executou baseline **e** variant para os dois casos de teste (4 chamadas ao runner, `calls.jsonl` completo) e escreveu `results.json` no caminho de contrato (`$eval_dir`), passando de 2/6 para 6/6 expectations.

Já a run `without_skill` do mesmo eval (sem ler `executor.md`) nunca executou o par baseline+variant por caso de teste — rodou uma única chamada por TC, usando julgamento próprio de que "o stub já simula a resposta de um Claude real" sem saber que o protocolo exige as duas pernas por teste. Isso derruba 4 das 6 expectations (contrato do results.json, calls.jsonl com 4 linhas, conteúdo do TC-02 e tokens do TC-01) — exatamente o conhecimento que só está escrito na seção "Execução" e no bloco "Saída" de `executor.md`.

## 4. Onde o artefato atrapalhou ou não fez diferença

**Eval 2 é estruturalmente impossível de passar, com ou sem o artefato — falso negativo do benchmark, não do agente.** As cinco expectations exigem um único `results.json` com `baseline_result` **e** `variant_result` preenchidos para TC-01/02/03. Mas o harness de benchmark invoca o agente separadamente por configuração: a run `with_skill` só tem acesso ao braço variant (prompt com a skill), a run `without_skill` só ao braço baseline (prompt sem a skill) — nenhuma das duas runs, isoladamente, tem os dois lados para preencher o contrato exigido. Os dois transcripts confirmam isso explicitamente:

> "Este run cobre apenas a perna with_skill (variant), não o baseline." (`eval-registra-falha-e-timeout-sem-abortar/with_skill/run-1/outputs/transcript.md`)

> "...os três IDs (TC-01/02/03) têm registro no arquivo de resultados" — mas só com o braço baseline, sem variant_result. (`.../without_skill/run-1/outputs/transcript.md`)

Resultado: 0% em ambas as configs, para os dois agentes (com e sem `executor.md`) — a métrica não mede a skill, mede um desenho de eval quebrado. Secundariamente, os dois agentes também erraram o caminho de escrita (`outputs/results.json`/`results.jsonl` em vez de `$eval_dir`), mas mesmo corrigindo isso as expectations continuariam falhando por falta do braço ausente.

Eval 3, with_skill, perdeu 1/5 por um artefato do próprio protocolo de benchmark, não por falha do agente em seguir `executor.md`: a expectation "calls.jsonl com exatamente 4 linhas, nenhuma execução extra depois da primeira passada" falhou porque esta run é uma **retomada** sobre o mesmo diretório de fixture de uma tentativa anterior reprovada — o `calls.jsonl` acumula chamadas das duas passadas (9 no total), mesmo depois de o agente truncar o arquivo para "reiniciar a contagem". O transcript admite isso com transparência (`transcript.md` do eval 3 with_skill, seção 4), mas o grader não tem como diferenciar "recomeçou limpo" de "escondeu o histórico via reset do log" — é uma limitação de reusar workspace stateful entre retomadas, não uma falha de instrução seguida.

## 5. Trechos do artefato ignorados, ambíguos, contraditórios ou que desperdiçam tempo

- **Ambíguo/causador de erro real:** o nome das pastas de benchmark `with_skill/`/`without_skill/` (se o *executor* leu `executor.md`) colide com a terminologia interna do próprio artefato, `baseline`/`variant` (se a *skill sob teste* — conciliação CSV — foi injetada no prompt). A primeira tentativa do eval 1 confundiu as duas dimensões (ver §3). `executor.md` não alerta para essa distinção em nenhum lugar.
- **Contraditório:** o bloco "Saída" (linha 74) mostra `"tokens": 350` como escalar, mas o contrato realmente cobrado pelas expectations (e o que o stub retorna) é um objeto `{"input_tokens": ..., "output_tokens": ...}`. Todo agente teve que inferir o formato certo a partir do stub, não do exemplo do artefato.
- **Desatualizado, causa retrabalho:** o exemplo de entrada (linha 31) usa `eval_dir": ".forge/evals/skills/<skill>/iteration-N"`, mas as fixtures reais usam um segmento extra, `.../workspace/iteration-N`. Isso contribuiu diretamente para a primeira falha do eval 1 (results.json nunca escrito no `$eval_dir` certo).
- **Ignorado por todos os agentes (razoavelmente):** "Output bruto em `/tmp/eval-*.log`" (linha 84) — nenhum dos seis runs escreveu em `/tmp`; todos usaram `outputs/logs/` dentro do diretório isolado da run, porque `/tmp` compartilhado entre execuções paralelas de fixture seria uma fonte óbvia de colisão. O artefato nunca foi atualizado para refletir essa prática.
- **Desperdiça tempo, recorrente:** o protocolo sugere medir `duration_ms` com `date +%s%3N` (linha 61 e exemplo de baseline/variant). `%3N` não existe no `date` BSD/macOS — pelo menos 3 dos 6 transcripts relatam uma tentativa falha por causa disso antes de trocar para `perl -MTime::HiRes=time` ou `node -e "Date.now()"`, incluindo uma "execução extra" que contaminou a contagem de `calls.jsonl` do eval 3 (§4).
- **Força redescoberta a cada execução:** o protocolo mostra o comando literal `claude -p "$PROMPT" ...` (linhas 47 e 57), mas nenhuma das máquinas de teste tem login do Claude; o runner real vem de `.forge/runners.yaml` (que pode apontar a um stub offline). Toda run teve que investigar `runners.yaml` por conta própria — o artefato deveria referenciar essa indireção explicitamente em vez do binário fixo.

## 6. Melhorias concretas priorizadas

1. **[P0] Corrigir o desenho do eval "registra-falha-e-timeout-sem-abortar".** Hoje ele exige `baseline_result` e `variant_result` no mesmo `results.json` de uma run que só tem acesso a um dos dois braços (a run é `with_skill` *ou* `without_skill`, nunca as duas). Ou (a) as expectations passam a checar só o braço que a config em questão de fato executa, ou (b) o script de benchmark passa a rodar os dois braços dentro da mesma invocação de agente antes de gravar `results.json` (mudando o texto de `executor.md` para deixar isso inequívoco). Sem esse ajuste, este eval sempre marca 0%/0% e não mede nada.
2. **[P0] Desambiguar, no próprio `executor.md`, os dois pares de termos que colidem:** acrescentar uma frase explícita do tipo "o nome da pasta with_skill/without_skill do harness de benchmark refere-se a se *este agente* teve acesso a este artefato — não pule o par baseline/variant da skill sob teste em nenhuma das duas configs". Isso reduz diretamente o tipo de erro que a primeira passada do eval 1 cometeu.
3. **[P1] Alinhar o exemplo de `eval_dir` (linha 31) ao caminho real usado pelas fixtures** (`.../workspace/iteration-N`), e trocar o exemplo de `tokens` (linha 74) de escalar para o objeto `{input_tokens, output_tokens}` que o contrato realmente cobra.
4. **[P1] Substituir o comando literal `claude -p ...` por uma instrução de ler o runner de `.forge/runners.yaml`** e invocá-lo por esse indireto — hoje cada execução gasta um passo de investigação redescobrindo isso.
5. **[P2] Trocar `date +%s%3N` por um comando portátil** (ex.: `perl -MTime::HiRes=time`), documentado no próprio artefato, para eliminar a fricção recorrente de BSD vs GNU date observada em metade dos runs.
6. **[P2] Atualizar "Output bruto em `/tmp/eval-*.log`" para um caminho dentro do diretório isolado da run** (ex.: `$eval_dir/../logs/` ou `outputs/logs/`), já que é isso que todo agente faz na prática e evita colisão entre execuções paralelas.
7. **[P3] Revisar os casos de teste de "recusa-dar-nota-e-editar-skill".** Quatro das cinco expectations passam com e sem `executor.md`; a única diferença observada nesta rodada é ruído de retomada sobre workspace com estado (calls.jsonl acumulado), não sinal real do artefato. Vale desenhar um cenário onde a recusa correta dependa de uma instrução que só existe em `executor.md` (hoje o "não dê nota"/"não altere skills" já soa óbvio pela moldura da própria tarefa).

## 7. Qualidade dos próprios casos de eval (`eval_quality`)

- **Eval 2 está estruturalmente quebrado** (§4, §6.1) — mede o desenho do harness de benchmark, não o artefato. É o problema de maior prioridade encontrado nesta análise.
- **Eval 1 é o mais informativo:** diferenciação real (1.0 vs 0.33) com causa identificável e verificável no transcript, ligada diretamente ao conteúdo do artefato. Boa cobertura do protocolo de execução (baseline+variant, contrato de saída, caminho, conteúdo truncado, tokens).
- **Eval 3 tem baixo poder discriminante:** a maioria das expectations já passa sem o artefato; a única falha observada é contaminação por retomada sobre workspace stateful, não uma diferença real de comportamento. Cobre um comportamento de recusa que parece decorrer de instruções fora de `executor.md` (regras do harness/moldura da tarefa) mais do que do próprio artefato.
- **Amostra pequena:** três evals, uma run por configuração — sem repetições (`runs_per_configuration: 3` no metadata, mas só 1 run efetivamente presente por config nos `runs[]`). O `stddev` de 0,51–0,53 relatado no `run_summary` é artefato de ter só um ponto (0 ou 1) por config em cada eval, não uma medida de variância real entre repetições. O veredito "agrega" bate o corte formal (delta ≥ 0,15), mas é sustentado quase inteiramente por um único eval bem desenhado (eval 1); o eval 2 (0/0) neutraliza a si mesmo no cálculo e o eval 3 pouco discrimina. Tratar como sinal preliminar, não conclusivo, até o eval 2 ser corrigido e mais repetições rodarem.
