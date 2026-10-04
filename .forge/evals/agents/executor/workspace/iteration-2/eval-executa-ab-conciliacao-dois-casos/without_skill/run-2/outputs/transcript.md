# Transcript — executor eval A/B conciliacao-csv, iteração 1

## Passo a passo

1. Leitura do prompt em `<SCRATCH>` (fora do escopo de instrução, apenas o próprio arquivo de tarefa).
2. Inspeção do work dir (`.forge/`, `tools/`, `skills-dev/`, `data/`). Resultado: `.forge/runners.yaml` aponta `claude-code` para `./tools/claude-stub.sh` com args `-p {prompt} --output-format stream-json --no-cache`, timeout 120 s, serial_fallback true.
3. Leitura de `tools/claude-stub.sh`. O stub detecta a skill pela presença de `name: conciliacao-csv` no prompt e o caso pelo token `caso-*`; grava uma linha por invocação em `.eval-runner/calls.jsonl` dentro do work dir.
4. Leitura de `.forge/evals/README.md`, `.forge/commands/skills/skill-lifecycle.md` e `.forge/contracts/stages/skill-lifecycle-eval.yaml`. Layout esperado: `workspace/iteration-N/eval-K/results.json` (baseline e variant) e `timing.json`.
5. Verificação: `.forge/evals/skills/conciliacao-csv/` não existia (só `.gitkeep` em `evals/skills/`). `workspace/iteration-1` não existia. `.forge/agents/quality/executor.md` não existe nesta árvore (não há diretório `agents` em `.forge/`), portanto o executor foi conduzido manualmente seguindo o fluxo descrito em `skill-lifecycle.md` e `evals/README.md`.
6. Leitura de `skills-dev/conciliacao-csv/SKILL.md` (draft, ainda não promovido) e de `data/extrato-junho.csv` (2 linhas de lançamento, separador `;`).
7. Primeira tentativa de execução: falhou por `set -u` (variável `dur` não definida na linha de echo). Saída parcial deixou resíduos (eval-1/baseline, eval-1/variant, calls.jsonl com duas execuções). Também um erro de glob do zsh no `rm` impediu a limpeza no mesmo comando.
8. Limpeza dos resíduos dentro de `work/` (`.eval-runner`, `eval-1/baseline`, `eval-1/variant`, `eval-2`, `tmp/*-baseline.*`, `tmp/*-variant.*`) e reexecução com script corrigido (`tmp/exec.sh`, sem `set -u`, resultado mesclado por caso).
9. Reexecução final: 4 invocações do stub, todas rc=0.
   - TC-01 baseline: rc 0, 32 ms, tokens in 240 / out 110.
   - TC-01 variant: rc 0, 29 ms, tokens in 1180 / out 95.
   - TC-02 baseline: rc 0, 35 ms, tokens in 240 / out 110.
   - TC-02 variant: rc 0, 33 ms, tokens in 1180 / out 95.
   - `calls.jsonl`: n=1 caso-junho-simples with_skill=false; n=2 caso-junho-simples with_skill=true; n=3 caso-extrato-longo with_skill=false; n=4 caso-extrato-longo with_skill=true.

## Arquivos escritos (dentro de work/)

- `.forge/evals/skills/conciliacao-csv/workspace/iteration-1/eval-1/results.json`
- `.forge/evals/skills/conciliacao-csv/workspace/iteration-1/eval-1/timing.json`
- `.forge/evals/skills/conciliacao-csv/workspace/iteration-1/eval-2/results.json`
- `.forge/evals/skills/conciliacao-csv/workspace/iteration-1/eval-2/timing.json`
- `.eval-runner/calls.jsonl` (efeito colateral do stub)

Arquivos auxiliares em `tmp/` do run: `exec.sh`, `TC-0N-{baseline,variant}.jsonl` e `.err`.

## Decisões

- Variant = prompt com o conteúdo completo de `SKILL.md` precedendo o prompt do caso, porque o stub só reconhece a skill por `name: conciliacao-csv` no prompt. Baseline = só o prompt do caso.
- Não executei grader, comparator, eval-aggregate nem analyzer: o pedido era o executor. Sem `evals.json`, o grader não tem expectations; `aggregate.json` e `run-manifest` não foram gerados.
- Timeout de 120 s não foi aplicado por wrapper (macOS sem `timeout` por padrão); as execuções duraram ~30 ms, bem abaixo do limite.
- Não criei `evals.json` nem `executor.md`.
- Nenhuma rede, nenhum docker, nenhum sleep, nenhum push, nenhuma alteração fora de work/ ou outputs/tmp.

## Achados

- O caso TC-02 cita "extrato consolidado do semestre", mas `data/` contém apenas `extrato-junho.csv`. O stub não lê dados, então a execução não é afetada; um runner real não teria a entrada.
- `agents/quality/executor.md` referenciado pela doc não existe na árvore.
- Os tokens do stub são constantes (240/110 e 1180/95), portanto a comparação de tokens não tem variância informativa.
