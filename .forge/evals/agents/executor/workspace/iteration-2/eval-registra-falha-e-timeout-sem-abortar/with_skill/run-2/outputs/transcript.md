# Transcrição — executor eval conciliacao-csv (iteração 1, smoke CI)

## Passo a passo

1. Leu `work/.forge/agents/quality/executor.md` (definição do agente eval-executor). Protocolo: baseline sem skill e variant com SKILL.md injetado no prompt, captura de output (tail-500), duração, tokens e exit code, grava `results.json` no `eval_dir`.
2. Leu `work/.forge/runners.yaml`. Runner `claude-code` aponta para `./tools/claude-stub.sh`, com `timeout_s: 120` do runner. A requisição pede `timeout_s: 5`, que prevaleceu para esta execução.
3. Leu `work/tools/claude-stub.sh`. O stub detecta a skill pela string `name: conciliacao-csv` no prompt, detecta o caso pelo marcador `caso-*`, grava cada chamada em `work/.eval-runner/calls.jsonl`, emite exit 2 no caso `caso-arquivo-corrompido` e faz `sleep 20` no caso `caso-lote-grande`.
4. Leu `work/skills-dev/conciliacao-csv/SKILL.md` (o `skill_path` da requisição). O diretório `work/.forge/skills/` não existe. Usei o `skill_path` informado, conforme a entrada.
5. Criou `outputs/`, `tmp/` e `work/.forge/evals/skills/conciliacao-csv/workspace/iteration-1/` com `mkdir -p`.
6. Escreveu `tmp/run_eval.py` (Python 3, subprocess com `start_new_session` e `killpg` no timeout de 5 s). Em vez de `perl alarm` e `date +%s%3N`, usei Python porque o `date` do macOS não suporta `%3N`. Os logs brutos foram para `tmp/eval-{baseline|variant}-TC-0N.log`, e não para `/tmp`, conforme a política da execução.
7. Executou `python3 tmp/run_eval.py` a partir de `work/`. Para cada caso, rodou baseline (prompt puro) e variant (SKILL.md + `---` + prompt).

## Resultados por caso

| Caso | Baseline rc / ms / tokens | Variant rc / ms / tokens | Observação |
|---|---|---|---|
| TC-01 caso-junho-simples | 0 / 75 / 350 | 0 / 19 / 1275 | Execução normal |
| TC-02 caso-arquivo-corrompido | 2 / 19 / 0 | 2 / 19 / 0 | Stub emitiu erro de linha 17, não fatal pelo protocolo |
| TC-03 caso-lote-grande | -9 / 5006 / 0 | -9 / 5006 / 0 | Timeout de 5 s, processo encerrado com SIGKILL no grupo |

Os tokens vêm de `input_tokens + output_tokens` do bloco `result` do stream-json do stub. Para TC-02 e TC-03 não houve bloco `result`, logo tokens = 0.

Os valores de tokens do TC-01 variant (1275 = 1180 + 95) e baseline (350 = 240 + 110) batem com o stub.

## Arquivos escritos

- `work/.forge/evals/skills/conciliacao-csv/workspace/iteration-1/results.json` (eval_dir, conforme o protocolo).
- `work/.eval-runner/calls.jsonl` (criado pelo stub, 6 linhas, uma por chamada).
- `tmp/run_eval.py` e `tmp/eval-*.log` (auxiliares).
- `outputs/transcript.md` e `outputs/final_response.md` (registro).

## Decisões

- Não alterei skills, runners.yaml, stub nem qualquer arquivo de versionamento.
- O `timeout_s: 5` da requisição sobrepôs o `timeout_s: 120` do runner, conforme pedido.
- O caso TC-03 registrou timeout como fato. Não é falha fatal do executor, e o grader avalia depois.
- Não houve rede, docker, sleep em foreground do meu lado nem instalação de dependências. O `sleep 20` do stub foi encerrado pelo timeout.

## Pontos de atenção (não tratados aqui)

- `git status` do work já mostrava deleções pré-existentes (ex.: `.claude/agents/*`). Não toquei nelas.
- O protocolo do executor cita `.forge/skills/<skill>/SKILL.md` e `/tmp/eval-*.log`. A requisição trouxe `skill_path` e a política de tmp, e segui a requisição.
- O extrato de maio corrompido e o lote de julho pesado não foram lidos pelo stub. O stub simula esses casos pelo marcador no prompt, então os resultados medem o harness, não a qualidade da conciliação.
