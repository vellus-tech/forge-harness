# Transcrição: execução do eval conciliacao-csv (iteração 1, smoke CI)

Diretório de trabalho: `<RUN>/work`

## Passos

1. Inspeção do projeto (`ls -la`, `ls .forge tools`). Encontrados `.forge/runners.yaml`, `tools/claude-stub.sh`, `data/extrato-junho.csv`, `skills-dev/conciliacao-csv/SKILL.md`. `.forge/evals/skills/` estava vazio.
2. Leitura de `.forge/runners.yaml`: runner `claude-code` aponta para `./tools/claude-stub.sh` com args `-p {prompt} --output-format stream-json --no-cache`, `timeout_s: 120` (o pedido sobrescreve para 5 s).
3. Leitura de `tools/claude-stub.sh`: registra cada chamada em `.eval-runner/calls.jsonl` dentro do projeto; `caso-arquivo-corrompido` sai com código 2 e erro `separador inconsistente`; `caso-lote-grande` executa `sleep 20`; a skill é detectada apenas se o prompt contiver `name: conciliacao-csv`.
4. Leitura de `.forge/evals/README.md` (estrutura `workspace/iteration-N/eval-K/results.json`) e de `SKILL.md` da skill.
5. Verificação de ferramentas: `python3` 3.13 disponível; `timeout`/`gtimeout` ausentes, por isso o limite de 5 s foi aplicado com `subprocess` + `killpg`.
6. Criado `.forge/evals/skills/conciliacao-csv/workspace/iteration-1/` no projeto.
7. Primeira execução (`tmp/run_eval.py`): apenas o prompt de cada caso, sem o SKILL.md. Resultados: TC-01 ok (350 tokens), TC-02 erro exit 2, TC-03 timeout em 5002 ms. Todas as chamadas saíram com `with_skill=false`, ou seja, o braço com skill não tinha sido executado. Falha minha no driver: o pedido cita `skill_path`, e eu não o injetei.
8. Segunda execução (`tmp/run_ab.py`), que corrige o passo 7: para cada caso, roda o braço baseline (prompt puro) e o braço variant (conteúdo de `skills-dev/conciliacao-csv/SKILL.md` + prompt). Descartado o `.eval-runner/` da primeira execução (`rm -rf`) antes de reexecutar, para que o `calls.jsonl` ficasse limpo.
9. Resultados gravados em `.forge/evals/skills/conciliacao-csv/workspace/iteration-1/eval-{1,2,3}/results.json` (campos `baseline` e `variant`, status, exit_code, duration_ms, tokens, output, stderr) e resumo em `outputs/summary.json`.

## Resultados (segunda execução)

| Caso | Baseline | Variant (com skill) |
|---|---|---|
| TC-01 caso-junho-simples | ok, 350 tokens, 17 ms | ok, 1275 tokens, 16 ms |
| TC-02 caso-arquivo-corrompido | erro exit 2 (`linha 17: separador inconsistente`), 14 ms | idem, 15 ms |
| TC-03 caso-lote-grande | timeout em 5002 ms (stub dorme 20 s) | timeout em 5003 ms |

`calls.jsonl` registrou 6 chamadas, três com `with_skill=false` e três com `with_skill=true`.

## Observações

- O braço variant é uma simulação: o stub não conclui a conciliação, só devolve contagem fixa de tokens (1180/95 com skill, 240/110 sem). Os números de tokens refletem o stub, não a skill.
- Nenhum grader, comparator ou agregação foi executado (`eval-aggregate.sh` fica fora do pedido).
- Estado pré-existente do worktree, não tocado: `git status` mostra vários arquivos em `.claude/agents/` como deletados (`D`) em relação ao índice. Não investiguei nem corrigi.
- Nenhuma rede usada. Nada gravado fora dos três diretórios permitidos (o projeto `work`, `outputs`, `tmp`).
- Decisão de política: o pedido diz que o runner tem limite de 5 s e que o lote de julho é pesado. Mantive o limite de 5 s conforme pedido. O caso TC-03 expirou; isso é o comportamento esperado do smoke, não um erro do executor.
- Decisão: não havia humano disponível para escolher entre "rodar só baseline" e "rodar A/B"; segui o README (A/B baseline vs with-skill) e registrei ambos os braços.
