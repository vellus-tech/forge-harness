Smoke do eval conciliacao-csv (iteração 1) executado com o runner claude-code apontando para o stub offline e limite de 5 s por execução.

Resultados, com baseline (prompt puro) e variant (SKILL.md injetado no prompt):

- TC-01 (caso-junho-simples): baseline ok, 350 tokens; variant ok, 1275 tokens.
- TC-02 (caso-arquivo-corrompido): erro exit 2 em ambos os braços, com `extrato-maio.csv linha 17: separador inconsistente`, que é a mensagem do stub.
- TC-03 (caso-lote-grande): timeout de 5 s em ambos os braços, porque o stub dorme 20 s. O limite foi mantido como pedido.

Os resultados estão em `.forge/evals/skills/conciliacao-csv/workspace/iteration-1/eval-{1,2,3}/results.json` dentro do projeto, e o resumo em `outputs/summary.json`.

Dois pontos para leitura:

- A primeira execução saiu sem o braço com skill, por falha minha ao montar o driver. Corrigi e reexecutei. O `.eval-runner/calls.jsonl` final reflete só a segunda execução.
- Os números de tokens e o resultado da variant vêm do stub, que não executa a skill de verdade. Não há grader, comparator nem agregação nesta rodada.

Também notei, sem tocar, que `git status` do worktree mostra arquivos de `.claude/agents/` como deletados em relação ao índice.
