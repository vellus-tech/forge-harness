# Transcript — eval-registra-falha-e-timeout-sem-abortar / with_skill / run-1

## Papel assumido

Executei este caso como o agente `eval-executor` (definição em `template/.forge/agents/quality/executor.md`, lido em modo somente leitura), papel: executar os casos de teste de um eval A/B invocando o runner configurado, capturando output/duração/tokens/exit_code, sem julgar qualidade. Este run cobre apenas a perna **with_skill** (variant), não o baseline.

## Passos executados, em ordem

1. `date +%s > .../with_skill/run-1/.t0` — gravei o instante inicial (epoch `1790444562`).
2. `mkdir -p .../with_skill/run-1/work` — criei o diretório de trabalho.
3. `bash .../fixtures/registra-falha-e-timeout-sem-abortar/setup.sh .../with_skill/run-1/work` — montei a fixture: rodou `node bin/forge.mjs init` dentro do diretório de trabalho isolado, copiou o overlay (`tools/claude-stub.sh`, `.forge/runners.yaml`, `data/extrato-junho.csv`, `skills-dev/conciliacao-csv/SKILL.md`), ligou `evals_enabled: true` em `.forge/FORGE.md`, e fez `git init` + commit inicial **dentro desse diretório isolado** (não toca o worktree principal nem seu branch). Confirmei `evals_enabled: true` e o commit `501f493 fixture: estado inicial`.
4. Li `template/.forge/agents/quality/executor.md` para seguir o protocolo de entrada/saída do eval-executor (formato de `results.json`, uso de `timeout_s`, tratamento de exit≠0 como não-fatal).
5. Li os artefatos da fixture (`setup.sh`, `tools/claude-stub.sh`, `.forge/runners.yaml`, `data/extrato-junho.csv`, `skills-dev/conciliacao-csv/SKILL.md`) para entender o comportamento do stub: `caso-arquivo-corrompido` sai com `exit 2` e mensagem em stderr; `caso-lote-grande` dorme 20s antes de produzir saída; ambos exercitam o `timeout_s=5` do input da tarefa (menor que os 120s default do `runners.yaml`).
6. Executei os três casos de teste do runner `claude-code` (stub offline `./tools/claude-stub.sh`, já que esta máquina não tem login do Claude), cada um sob `perl -e 'alarm 5; exec @ARGV' -- ./tools/claude-stub.sh -p "$SKILL_CONTENT\n\n---\n\n$PROMPT" --output-format stream-json`, com `$SKILL_CONTENT` = conteúdo de `skills-dev/conciliacao-csv/SKILL.md` (variant/with_skill, conforme protocolo do executor):
   - **TC-01** (`caso-junho-simples`): exit `0`, duração `42ms`, stream-json com `usage.input_tokens=1180, output_tokens=95` — consistente com `WITH_SKILL=true` no stub.
   - **TC-02** (`caso-arquivo-corrompido`): exit `2`, duração `54ms`, saída apenas em stderr (`erro: extrato-maio.csv linha 17: separador inconsistente`). Registrei como falha não fatal, sem interromper a sequência — o protocolo do executor diz explicitamente para não tratar exit≠0 como erro fatal.
   - **TC-03** (`caso-lote-grande`): o stub dorme 20s; o `alarm(5)` do perl disparou antes, processo terminou com exit `142` (128+SIGALRM) e duração `5015ms`, sem nenhuma saída capturada. Registrado como timeout não fatal; era o último caso da lista, então não houve mais execuções a prosseguir, mas a lógica não teria abortado o loop se houvesse.
7. Nota de auditoria: uma primeira tentativa de rodar os três casos falhou por erro de sintaxe de shell (`date +%s%3N` não é suportado pelo `date` BSD/macOS, só GNU), mas essa tentativa já havia invocado o stub uma vez para TC-01 antes de falhar na aritmética de duração — por isso `outputs/eval-runner-calls.jsonl` tem 4 entradas em vez de 3 (a primeira, `n=1`, é resíduo dessa tentativa; `n=2..4` são a execução válida cujos resultados estão em `results.json`). Corrigi trocando a medição de tempo para `perl -MTime::HiRes=time`.
8. Copiei para `outputs/`: `results.json` (formato do protocolo do eval-executor, com `variant_result` por caso), os três logs brutos (`eval-variant-TC-0{1,2,3}.log`) e `eval-runner-calls.jsonl` (log de chamadas do stub, produzido em `work/.eval-runner/calls.jsonl`).
9. Verifiquei o tamanho de `work/` (`du -sh`): 6,0M, abaixo do limite de 20MB — não apaguei.

## Despacho de subagentes

Nem o `executor.md` nem o input desta tarefa instruem a spawnar subagentes — o protocolo do eval-executor é executar diretamente os casos de teste via runner configurado. Não houve, portanto, despacho a simular/registrar para este run.

## Decisões

- Tratei `timeout_s: 5` do input da tarefa como o timeout efetivo por execução (sobrepõe o `timeout_s: 120` default de `.forge/runners.yaml`), pois o protocolo do executor diz "respeite `timeout_s` do runner" e o input explicitamente fornece esse valor para este caso de eval.
- Não alterei `.forge/runners.yaml` nem qualquer outro arquivo do harness dentro de `work/` além do que `setup.sh` já produziu.
- Não rodei `git commit`/`push`/`checkout`/`stash` fora do que `setup.sh` fez isoladamente dentro de `work/` (fixture própria, exigida pelo próprio script de setup, sem tocar o worktree principal `evals-100` nem seu branch `chore/evals-skills-agentes`).
- Não rodei testes/`run-all.sh`/`npm test`/docker/ledger-ops/liaison-ops/`gh` de escrita/`npm publish`/deploy.
