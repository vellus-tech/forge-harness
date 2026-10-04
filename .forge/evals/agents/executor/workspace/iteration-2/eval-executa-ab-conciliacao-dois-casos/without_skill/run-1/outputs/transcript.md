# Transcrição — executor do eval A/B conciliacao-csv, iteração 1

## Passos

1. Inspeção do projeto `work`: `.forge/runners.yaml` (runner `claude-code` aponta para `./tools/claude-stub.sh`, args `-p {prompt} --output-format stream-json --no-cache`, timeout 120 s); `skills-dev/conciliacao-csv/SKILL.md` lido; `tools/claude-stub.sh` lido (grava chamadas em `.eval-runner/calls.jsonl` e detecta a skill pela presença de `name: conciliacao-csv` no prompt); `data/extrato-junho.csv` lido.
2. `.forge/evals/skills/conciliacao-csv/` não existia (sem `evals.json`, sem `workspace/`). Os casos vieram do pedido inline. Criada a estrutura `workspace/iteration-1/eval-1` (TC-01) e `eval-2` (TC-02).
3. Verificado `quality.evals_enabled: true` em `.forge/FORGE.md`, então o eval está habilitado.
4. Agente `agents/quality/executor.md` não existe nesta árvore. Executor feito diretamente: para cada caso, duas execuções via runner, baseline (prompt puro) e variant (SKILL.md concatenado antes do prompt, que é como o stub detecta a skill).
5. Primeira tentativa falhou por ambiente macOS: `date +%s%3N` não suportado e `timeout` ausente. Corrigido com `python3` para timestamps e `perl -e "alarm shift; exec @ARGV"` como timeout de 120 s. Nenhuma execução válida foi perdida (o stub não chegou a rodar nessa tentativa).
6. Execução: TC-01 baseline rc=0 (64 ms), TC-01 variant rc=0 (37 ms), TC-02 baseline rc=0 (39 ms), TC-02 variant rc=0 (37 ms). `calls.jsonl` com 4 entradas, com_skill false/true em cada caso, conforme esperado.
7. Gravados `eval-1/results.json`, `eval-2/results.json` e `timing.json` de cada um, via `tmp/build-results.py`. `results.json` validado como JSON. Saídas gravadas só como tail (3 últimas linhas de texto), conforme a regra de artefatos.
8. `bash .forge/scripts/eval-aggregate.sh .forge/evals/skills/conciliacao-csv/workspace/iteration-1` executado. Resultado: `FAIL: nenhum grading.json`. Esperado: o grading é etapa do grader (`agents/quality/grader.md`), que não faz parte deste pedido e não foi executado. O `rc=0` exibido é do `tail`, não do script.

## Decisões

- Não criei `evals.json` nem `grading.json`: `evals.json` é insumo de criação (não foi pedido) e `grading.json` é responsabilidade do grader. Sem expectations no pedido, não há base para julgar passed/failed.
- Não alterei `skills-dev/conciliacao-csv/SKILL.md`, `data/` nem o stub.
- Nenhum acesso de rede, nenhum push, nenhum docker.

## Arquivos escritos (dentro de `work/`)

- `.forge/evals/skills/conciliacao-csv/workspace/iteration-1/eval-1/results.json`
- `.forge/evals/skills/conciliacao-csv/workspace/iteration-1/eval-1/timing.json`
- `.forge/evals/skills/conciliacao-csv/workspace/iteration-1/eval-2/results.json`
- `.forge/evals/skills/conciliacao-csv/workspace/iteration-1/eval-2/timing.json`
- `.eval-runner/calls.jsonl` (gerado pelo stub)

Fora de `work/`, em `tmp/`: `run-eval.sh`, `build-results.py`, saídas brutas do runner (`*.out`, `*.err`, `*-meta.tsv`).

## Lacuna

Sem grader, `aggregate.json` e `analysis.json` não existem. A iteração não está completa até o grader rodar.
