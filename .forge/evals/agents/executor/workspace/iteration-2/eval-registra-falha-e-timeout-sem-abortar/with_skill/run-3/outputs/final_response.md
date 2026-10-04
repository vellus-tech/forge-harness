OK

Execução do eval A/B conciliacao-csv (iteração 1) concluída. results.json gravado em work/.forge/evals/skills/conciliacao-csv/workspace/iteration-1/results.json.

- TC-01 (caso-junho-simples): exit 0 em baseline e variant; 350 tokens sem skill, 1275 com skill.
- TC-02 (caso-arquivo-corrompido): exit 2 nos dois braços, com o erro do extrato corrompido registrado no output; sem tokens, pois o stub não emitiu bloco result.
- TC-03 (caso-lote-grande): exit -14 (timeout de 5 s) nos dois braços; o stub dorme 20 s, então o runner matou a execução. Output vazio, registrado como tal.

Os exit codes de falha foram gravados como dado, sem tratar como erro fatal, conforme o protocolo do executor. Não houve avaliação de qualidade.
