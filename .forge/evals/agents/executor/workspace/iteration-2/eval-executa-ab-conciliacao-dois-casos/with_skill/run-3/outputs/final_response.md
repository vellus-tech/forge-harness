Eval A/B da skill conciliacao-csv, iteracao 1, executado com o runner claude-code (stub offline).

Resultados gravados em .forge/evals/skills/conciliacao-csv/workspace/iteration-1/results.json (no work do run).

- TC-01 (caso-junho-simples): baseline exit 0, 350 tokens, 72 ms; variant exit 0, 1275 tokens, 39 ms.
- TC-02 (caso-extrato-longo): baseline exit 0, 350 tokens, 38 ms; variant exit 0, 1275 tokens, 38 ms.

Desvios: o skill_path do pedido (skills-dev) foi usado no lugar de .forge/skills, que nao existe. Logs brutos em tmp/. Os tokens sao os do stub, nao de um modelo real. TC-02 cita um extrato semestral que nao existe em data/.
