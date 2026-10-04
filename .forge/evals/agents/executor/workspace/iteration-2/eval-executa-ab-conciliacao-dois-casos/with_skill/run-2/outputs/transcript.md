# Transcript: executor do eval A/B, conciliacao-csv, iteração 1

## Passo a passo

1. Li o prompt de execução (`tmp` fora do projeto) e a definição `.forge/agents/quality/executor.md` (agente eval-executor, modelo sonnet, Read/Bash/Write).
2. Conferi `.forge/runners.yaml`: runner `claude-code` com `command: ./tools/claude-stub.sh`, args `-p {prompt} --output-format stream-json --no-cache`, timeout 120 s.
3. Conferi `tools/claude-stub.sh`: aceita `-p` e `--output-format`, ignora `--no-cache`, registra cada chamada em `.eval-runner/calls.jsonl`, detecta a skill pela presença de `name: conciliacao-csv` no prompt, e emite um bloco `result` com `usage` (input/output tokens). Para `caso-extrato-longo` emite 700 linhas de assistant.
4. Conferi `skills-dev/conciliacao-csv/SKILL.md` (existe, frontmatter com `name: conciliacao-csv`) e `data/extrato-junho.csv` (existe, 2 linhas de dados).
5. `.forge/evals/skills/conciliacao-csv/` não existia. Criei `workspace/iteration-1` com `mkdir -p` (escrita dentro do projeto, conforme a definição do executor).
6. Escrevi `tmp/run-eval.sh` (script de execução, fora do projeto, na pasta tmp do run).
7. Executei `bash tmp/run-eval.sh` a partir de `work/`. Resultado: exit 0.
   - TC-01 baseline rc=0, 60 ms
   - TC-02 baseline rc=0, 28 ms
   - TC-01 variant rc=0, 23 ms
   - TC-02 variant rc=0, 30 ms
8. Validei `results.json`: TC-01 baseline 350 tokens, variant 1275 tokens; TC-02 baseline 350 tokens com 500 linhas de output (tail), variant 1275 tokens com 500 linhas. Todos com exit_code 0.
9. `.eval-runner/calls.jsonl` recebeu 4 linhas: casos caso-junho-simples e caso-extrato-longo, sem skill (baseline) e com skill (variant).

## Decisões

- Variant: o conteúdo de `skills-dev/conciliacao-csv/SKILL.md` foi injetado antes do prompt, com separador `---`, como manda o executor. O caminho veio do pedido (`skill_path`), não de `.forge/skills/`, porque a skill ainda não foi promovida.
- Runner: usei o `command` do runners.yaml (`./tools/claude-stub.sh`) no lugar de `claude`, conforme o pedido.
- Duração: `date +%s%3N` não funciona no macOS (imprime literal `3N`). Usei `perl -MTime::HiRes` para obter milissegundos.
- Timeout: `perl -e 'alarm 120; exec @ARGV'`, como no executor.
- Logs brutos em `tmp/eval-<variant>-<id>.log` (no lugar de `/tmp/`, conforme a política). `results.json` tem tail de 500 linhas.
- Tokens: soma de `usage.input_tokens + usage.output_tokens` do bloco `result` do stream-json.

## Observações

- O `git status` do work já estava sujo antes da execução (deleções em `.claude/agents/...`). Não toquei nesses arquivos.
- O stub criou `.eval-runner/` na raiz do work (artefato do próprio stub, untracked).
- Não houve rede, docker ou sleep em foreground. O caso `caso-lote-grande` (sleep 20) não estava no pedido e não foi executado.

## Arquivos

- Lidos: `.forge/agents/quality/executor.md`, `.forge/runners.yaml`, `tools/claude-stub.sh`, `skills-dev/conciliacao-csv/SKILL.md`, `data/extrato-junho.csv`.
- Escritos: `.forge/evals/skills/conciliacao-csv/workspace/iteration-1/results.json`, `.eval-runner/calls.jsonl` (via stub), `tmp/run-eval.sh`, `tmp/*.log`, `tmp/meta-*.env`, `outputs/transcript.md`, `outputs/final_response.md`.
