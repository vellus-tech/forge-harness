# Análise — benchmark do agente `task-coder`

## 1. Resultado (benchmark.json, run_summary)

| Configuração | pass_rate (média) | stddev | min | max |
|---|---|---|---|---|
| with_skill | 0.39 | 0.535 | 0.00 | 1.00 |
| without_skill | 0.36 | 0.376 | 0.00 | 0.75 |

Delta = 0.39 − 0.36 = **+0.03** → pelo limiar (agrega ≥0.15 / neutro <0.15 / prejudica ≤-0.15), cairia em **neutro**. Mas a amostra é de apenas 3 evals × 1 run, com stddev maior que a própria média em `with_skill` — a agregação determinística rodou corretamente, porém o sinal não é confiável (ver §5). Tempo médio: with_skill 268.7s vs without_skill 215.0s (+53.7s, +25%); tokens/tool_calls ficaram zerados nas duas configurações — instrumentação não capturou esses campos.

## 2. Asserções não discriminantes

- **Eval 2 (primeira-onda-extrato-sem-tracker):** as 6 asserções falham em ambas as configurações (0.0/0.0) — não diferenciam a skill, e a causa é comum às duas (ver §5), não uma limitação do artefato em si.
- **§3.2.4 (TASK de Encerramento não invoca specialist) e o template canônico do tracker:** ambas as configurações, em todos os runs, produziram o formato inicial do `PROGRESS-TRACKING.md` corretamente e marcaram a TASK de encerramento sem commit de feature — instrução bem seguida por ambas, não diferencia.
- **Fallback de specialist por stack-dominante (§3.2.3, TASK-02 sem path → frontend, não fullstack):** conteúdo correto nas duas configurações (eval 2, asserção 2) — o baseline chegou ao mesmo resultado por raciocínio geral, sem precisar da regra explícita do artefato.

## 3. Onde o artefato ajudou (evidência)

**Eval 3 (recusa-tasks-em-rascunho) é o único caso limpo, sem contaminação de sandbox:** with_skill = 1.00 (4/4), without_skill = 0.75 (3/4). A diferença está na asserção "resposta cita status e regra de rascunho": o run with_skill cita textualmente o contrato do agente — a mensagem de abort exata do artefato ("tasks.md em status `Rascunho para revisão`. Não execute coder sobre rascunho.") e o anti-pattern "executar sem tasks.md aprovado" (`outputs/resposta-ao-usuario.md` L5-8, L18-20). O run without_skill cita o status e pede formalização, mas **oferece um meio-termo** ("já deixar o código de TASK-03/TASK-04 pronto num branch separado, sem tocar no tasks.md", L13) — uma execução parcial que o artefato proíbe explicitamente na lista de anti-patterns ("Executar sem `tasks.md` em status `Aprovado para desenvolvimento`"). Sinal real de valor: a lista explícita de anti-patterns do artefato produziu uma recusa mais estrita e correta do que o raciocínio genérico do baseline.

## 4. Trechos do artefato ignorados, ambíguos ou contraditórios

1. **Convenção de worktree incompatível com o próprio projeto (`../<modulo>-wave-<NN>`, Fase 2).** O `task-coder.md` manda criar o worktree como diretório-irmão fora da árvore (`WORKTREE_PATH="../<modulo>-wave-<NN>"`). Isso contradiz a convenção que o próprio forge-harness usa na prática (worktrees sob `.forge/worktrees/<nome>` — a própria árvore em que esta análise roda é um exemplo). Em ambiente com escopo de escrita restrito ao diretório designado (comum em CI, sandboxes de eval, ou na disciplina de subagente deste harness), `../` é justamente o padrão que a política de escrita bloqueia. Isso é uma causa plausível de todos os runs terem evitado criar um worktree real e tratado `work/`/a árvore principal como se fosse a onda — nenhuma run, em nenhuma configuração, produziu o worktree dedicado exigido pela asserção 1 dos evals 1 e 2. **Correção sugerida:** trocar Fase 2 para `WORKTREE_PATH=".forge/worktrees/<modulo>-wave-<NN>"` (dentro da árvore), alinhado à convenção real do projeto, com nota explícita de que o path nunca deve sair da raiz do repositório.

2. **Vocabulário inconsistente para "onda fechada" (tabela vs. cabeçalho de seção).** A §Formato canônico usa "✅ Done" na coluna `Status` da tabela `## Status geral`, mas a Fase 4 (e o exemplo da Wave 1) usa "✅ COMPLETA" no cabeçalho da seção `## Wave N`. A asserção do eval 1 (`tracker-com-sha-specialist-e-onda-completa`) grava especificamente a string `'COMPLETA'` no cabeçalho. No run without_skill do eval 1 (o run com melhor execução real, 0.33 de pass_rate), o agente fechou a wave corretamente (commits reais, tracker com sha, build verde) mas escreveu o cabeçalho `## Wave 2 (TASK-03..TASK-04) — Troco no guichê` sem `COMPLETA` — só a tabela dizia `✅ Done` — e perdeu essa asserção por essa única discrepância léxica. **Correção sugerida:** unificar o marcador (sempre acrescentar `✅ COMPLETA` ao cabeçalho de toda wave 100% `[X]`) e declarar explicitamente que essa string é contratual/verificável, não só estética.

3. **Nenhuma orientação para quando o Agent tool (specialist) não pode ser invocado.** Em todas as 6 execuções (3 evals × 2 configs) o agente sob teste tratou a ausência de subagentes reais fazendo o trabalho de código diretamente — decisão razoável, mas não coberta pelo artefato, que assume implicitamente que o specialist sempre está disponível via Agent tool. Como o próprio `/forge:coding-loop` é pensado para rodar de forma autônoma (inclusive em pipelines restritos), o artefato deveria descrever o modo degradado: "se o Agent tool não estiver disponível ou a invocação falhar, o task-coder pode executar a TASK diretamente seguindo `commit_policy`/`test_policy` do payload, registrando no tracker que não houve specialist real" — isso reduziria a variância de comportamento observada entre runs.

## 5. Qualidade dos próprios casos (eval_quality) — problema central desta rodada

O achado mais importante não é sobre o texto do artefato, é sobre a **contaminação do harness de execução**: em 3 dos 4 runs afetados (with_skill eval 1, with_skill eval 2, without_skill eval 2), o agente executor auto-aplicou uma "regra do eval" que proíbe `git commit`/`push`/`checkout`/worktree real e spawn de subagentes — quase idêntica, palavra por palavra, às regras que governam esta própria análise ("nunca rode git commit/push/checkout/stash ... Se o artefato mandar spawnar subagentes, NÃO spawne"). Isso indica que a restrição de sandbox usada para orquestrar esta tarefa de meta-avaliação vazou para dentro da simulação do agente sob teste em parte dos runs, mas não em todos: o run without_skill do eval 1 executou git real (branch, 4 commits) e chegou ao pass_rate mais alto do lote (0.33 real vs. 0.17 simulado no with_skill equivalente). Como a mesma restrição não foi aplicada de forma consistente entre configurações nem entre evals, o que o benchmark está medindo em 2 dos 3 evals não é a qualidade do `task-coder.md`, é **se a sandbox daquele run em particular permitiu ou não git real** — uma variável de execução, não do artefato. Isso invalida a comparação A/B nesses dois evals e reduz a amostra útil a um único eval (o de recusa), que por si só não sustenta um veredito de benchmark.

Problema adicional de design dos casos: as asserções dos evals 1 e 2 são condicionadas em cascata a "a branch da onda existe" — quando ela não existe, várias asserções (ex. "nenhum commit menciona TASK-04") passam **vacuamente** (nada para violar) enquanto outras falham "no vácuo" (nada para confirmar). Isso faz o pass_rate desses casos oscilar por artefato de redação da asserção, não por comportamento do agente — vale revisar essas asserções para não depender de uma pré-condição binária que zera ou infla o resto do caso.

## 6. Melhorias concretas priorizadas

1. **Alta prioridade / eval, não artefato:** eliminar a contaminação de "regra de sandbox do harness de meta-avaliação" vazando para o prompt do executor nos runs de benchmark — garantir que o executor sob teste rode com as mesmas permissões (incluindo git real e Agent tool) em todas as configurações e evals, ou documentar explicitamente, por eval, se git real é esperado. Sem isso, repetir o benchmark não muda o resultado.
2. **Alta prioridade / artefato:** trocar a convenção de worktree de `../<modulo>-wave-<NN>` para `.forge/worktrees/<modulo>-wave-<NN>` (Fase 2), alinhando com a convenção real do projeto e evitando escrita fora da raiz do repositório.
3. **Média prioridade / artefato:** unificar o vocabulário de "onda concluída" entre a tabela (`✅ Done`) e o cabeçalho de seção (`✅ COMPLETA`), e marcar explicitamente que a string do cabeçalho é verificável/contratual.
4. **Média prioridade / artefato:** adicionar uma seção curta de "modo degradado" cobrindo o que fazer quando o Agent tool não pode invocar o specialist (fazer o trabalho diretamente seguindo `commit_policy`/`test_policy`, registrar no tracker a ausência de specialist real).
5. **Baixa prioridade / evals:** revisar as asserções de eval 1 e eval 2 para não depender de uma cascata "branch existe → resto é avaliável"; separar em asserções independentes ou marcar claramente quais são condicionais, para que a falha de uma pré-condição não gere aprovações/reprovações vazias.

## 7. Veredito

- `run_summary`: with_skill 0.39, without_skill 0.36, delta +0.03.
- `benchmark_ok`: true (script determinístico rodou sem erro, gerou `benchmark.json`/`benchmark.md`; viewer estático gerado com sucesso).
- **Veredito: inconclusivo.** O delta numérico cairia em "neutro" pelo limiar, mas 2 dos 3 casos (eval 1 e eval 2) estão contaminados por uma restrição de sandbox aplicada de forma inconsistente entre runs (não uma propriedade do artefato), o que classifica os casos como ruins para efeito de comparação A/B. O único caso limpo (recusa-tasks-em-rascunho) mostra sinal real e positivo (1.00 vs. 0.75), mas um único eval não sustenta um veredito de benchmark.
