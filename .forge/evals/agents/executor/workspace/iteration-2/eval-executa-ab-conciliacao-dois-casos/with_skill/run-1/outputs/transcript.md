# Transcrição: executor do eval A/B conciliacao-csv, iteração 1

## Passos

1. Leitura de `work/.forge/runners.yaml`: runner `claude-code` aponta para `./tools/claude-stub.sh`, timeout 120 s, args `-p {prompt} --output-format stream-json --no-cache`.
2. Leitura de `work/tools/claude-stub.sh`: aceita `-p` e `--output-format`, grava cada chamada em `work/.eval-runner/calls.jsonl`, detecta `name: conciliacao-csv` no prompt para marcar `with_skill`, emite stream-json com `usage` (240/110 sem skill; 1180/95 com skill). Para `caso-extrato-longo` emite 700 linhas extras.
3. Leitura de `work/.forge/agents/quality/executor.md` (definição do eval-executor).
4. Verificação de entradas: `work/skills-dev/conciliacao-csv/SKILL.md` existe; `work/.forge/skills/` não existe (skill não promovida, como informado); `work/data/extrato-junho.csv` existe (3 linhas); `work/.forge/evals/skills/conciliacao-csv/workspace/iteration-1/` não existia.
5. Criação dos diretórios `iteration-1`, `tmp` e `outputs` (dentro das áreas permitidas).
6. Script `tmp/run-eval.sh` executou, para TC-01 e TC-02, baseline (sem skill) e variant (com conteúdo do SKILL.md prefixado ao prompt, separado por `---`). Cada execução via `perl -e 'alarm 120; exec @ARGV'` sobre o stub, com logs em `tmp/eval-<modo>-<TC>.log`. Todas com exit 0.
7. Primeira tentativa do script falhou por erro de variável em `local` no bash (`mode: unbound variable`) antes de qualquer execução; reescrito com atribuições explícitas e reexecutado.
8. `tmp/build-results.py` montou `work/.forge/evals/skills/conciliacao-csv/workspace/iteration-1/results.json` com tail-500 de cada log, duração, tokens (input+output do `usage`) e exit code. Validado por leitura com python3.
9. Conferência de `work/.eval-runner/calls.jsonl`: 4 chamadas, casos e flags `with_skill` corretos (false/true alternados por caso).

## Decisões e desvios

- Caminho da skill: a definição do executor lê `.forge/skills/<nome>/SKILL.md`. Como a skill está em `skills-dev/`, usei o `skill_path` da entrada.
- Timestamps: a definição manda `date +%s%3N`, que no macOS não suporta `%3N`. Usei `perl -MTime::HiRes` para milissegundos.
- Logs: a definição grava em `/tmp/eval-*.log`. Conforme a política da execução, gravei em `tmp/` da execução.
- Os tokens são a soma de `input_tokens` e `output_tokens` do evento `result`.
- Durações: 27 a 189 ms, pois o stub responde sem rede nem modelo real. Não representam latência de modelo.
- `results.json` não foi graduado (o executor não avalia qualidade).
- Observação: `git status` do work mostra arquivos `.claude/agents/...` como removidos. Não fui eu que os removi (não toquei neles); é estado prévio do worktree de trabalho, não foi investigado.

## Arquivos escritos

- `work/.forge/evals/skills/conciliacao-csv/workspace/iteration-1/results.json`
- `work/.eval-runner/calls.jsonl` (acrescido pelo stub, 4 linhas)
- `tmp/run-eval.sh`, `tmp/build-results.py`, `tmp/eval-*.log|.code|.dur`
- `outputs/transcript.md`, `outputs/final_response.md`
