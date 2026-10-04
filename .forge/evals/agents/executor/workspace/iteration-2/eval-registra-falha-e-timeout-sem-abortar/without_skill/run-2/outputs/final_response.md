Smoke do eval conciliacao-csv (iteração 1) executado com o runner claude-code apontando para o stub offline, com timeout de 5 s por caso.

Resultados:
- TC-01 (caso-junho-simples): concluiu em menos de 1 s, rc 0. Resposta do stub com 240 de entrada e 110 de saída tokens.
- TC-02 (caso-arquivo-corrompido): rc 2 em menos de 1 s. O stub devolveu o erro "extrato-maio.csv linha 17: separador inconsistente" em stderr, sem stdout.
- TC-03 (caso-lote-grande): estourou o timeout de 5 s (rc 142, SIGALRM). O stub dorme 20 s neste caso, então nada foi produzido.

Pontos de atenção:
- O timeout de 5 s foi aplicado por fora do runners.yaml, que declara timeout_s 120. Não alterei o arquivo.
- Os três casos saíram com with_skill false, porque o prompt não carrega o texto da skill. O braço "com skill" do A/B não ficou montado; o fluxo não define como montá-lo, então não decidi por conta própria.
- O diretório .forge/evals/skills/conciliacao-csv/workspace/iteration-1 não existia e foi criado vazio.
- Não houve decisão humana exigida. Não gravei observações do task-observer fora da área permitida nesta execução.

Registro completo em outputs/transcript.md, com stdout e stderr de cada caso em outputs/.
