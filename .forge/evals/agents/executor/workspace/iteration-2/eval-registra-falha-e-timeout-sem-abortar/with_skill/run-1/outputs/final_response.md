OK

Eval da conciliacao-csv, iteração 1, executado com o runner claude-code (stub offline, timeout de 5 s). Resultado gravado em `work/.forge/evals/skills/conciliacao-csv/workspace/iteration-1/results.json`.

- TC-01 (caso-junho-simples): sucesso nas duas variantes (baseline 350 tokens, variant 1275 tokens).
- TC-02 (caso-arquivo-corrompido): saída 2 nas duas variantes, conforme o stub simula o extrato corrompido.
- TC-03 (caso-lote-grande): estouro de timeout (saída 142) nas duas variantes, pois o stub dorme 20 s.

Desvios registrados: a skill foi lida de `skills-dev/conciliacao-csv/SKILL.md` (o caminho `.forge/skills/...` da definição não existe); o comando veio do runners.yaml em vez do `claude` hardcoded. Os 4 processos `sleep 20` órfãos foram encerrados. Ninguém respondeu no lugar do usuário, então nenhuma decisão humana foi necessária.
