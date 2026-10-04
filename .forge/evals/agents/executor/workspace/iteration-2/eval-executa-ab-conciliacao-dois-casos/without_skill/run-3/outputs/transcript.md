# Transcrição — executor do eval A/B conciliacao-csv, iteração 1

## Passos

1. Leitura de `prompt.md` (fora do projeto, dentro do diretório de execução permitido).
2. Inspeção do projeto `work/`: `.forge/runners.yaml` (runner `claude-code` aponta para `./tools/claude-stub.sh`, args `-p {prompt} --output-format stream-json --no-cache`, timeout 120s); `tools/claude-stub.sh` (stub offline que detecta `name: conciliacao-csv` no prompt para marcar `with_skill=true` e usa o trecho `caso-*` do prompt para variar a saída); `skills-dev/conciliacao-csv/SKILL.md` (existe); `data/extrato-junho.csv` (3 linhas).
3. Constatado: `.forge/evals/skills/conciliacao-csv/` não existe. Não há `evals.json` nem `workspace/iteration-1`. O diretório `.forge/agents/quality/` (executor.md, grader.md, analyzer.md) também não existe nesta árvore. Por isso o executor foi executado diretamente, seguindo o fluxo descrito em `.forge/commands/skills/skill-lifecycle.md` (passo 1), e não via agent definition.
4. Primeira tentativa de execução: os runs do stub rodaram (4 entradas em `.eval-runner/calls.jsonl`), mas o parsing dos resultados falhou por erro meu de índice em `node -e` (`process.argv` sem o slot dummy). Nenhum `results.json` foi gravado nessa tentativa.
5. Limpeza: removidos `work/.eval-runner` e `work/.forge/evals/skills/conciliacao-csv` (criados por mim na tentativa anterior). Nada do repositório git foi tocado.
6. Segunda execução com o parsing corrigido. Para cada caso (TC-01, TC-02): braço baseline (prompt = tarefa) e braço variant (prompt = conteúdo de `SKILL.md` + linha vazia + tarefa; é o que faz o stub marcar `with_skill=true`). Cada invocação: `./tools/claude-stub.sh -p "<prompt>" --output-format stream-json --no-cache`, serial, sem rede.
7. Gravados:
   - `work/.forge/evals/skills/conciliacao-csv/workspace/iteration-1/eval-1/results.json` (TC-01)
   - `work/.forge/evals/skills/conciliacao-csv/workspace/iteration-1/eval-2/results.json` (TC-02)
   Campos por caso: `test_case_id`, `prompt`, `baseline_result` e `variant_result` (`exit_code`, `duration_ms`, `tokens`, `output_lines`, `output_text`).

## Resultados brutos (stub)

- TC-01: baseline exit 0, tokens 350, 3 linhas, "with_skill=false"; variant exit 0, tokens 1275, 3 linhas, "with_skill=true".
- TC-02: baseline exit 0, tokens 350, 703 linhas; variant exit 0, tokens 1275, 703 linhas.
- `calls.jsonl` registrou 4 chamadas (2 por caso) com os marcadores esperados.

## Não executado (fora do pedido ou impossível nesta árvore)

- Grader (`eval-K/grading.json`), `eval-aggregate.sh`, comparator e analyzer: não fazem parte do executor, e as definições de agent não existem aqui. `evals.json` também não existe, então `eval-aggregate.sh` não tem como gerar `aggregate.json` sem esse passo.
- `timing.json` não foi gravado separadamente; a duração está em `results.json`.

## Ressalvas

- O stub produz respostas e contagens de tokens fixas por braço. Os números comparam o mecanismo do harness, não a qualidade da skill. Não servem como evidência de melhora.
- A `duration_ms` mede o tempo de um processo bash com stub (~20 ms), sem significado real.
- O stub de `caso-lote-grande` tem `sleep 20`, mas nenhum caso deste pedido usa esse ramo.
- Decisão tomada sem humano: o braço variant foi montado injetando o `SKILL.md` no prompt, porque é assim que o stub identifica a skill. Um runner real precisaria de outro mecanismo para carregar a skill.
- Nenhuma rede, nenhum docker, nenhum sleep em foreground, nenhum push.
