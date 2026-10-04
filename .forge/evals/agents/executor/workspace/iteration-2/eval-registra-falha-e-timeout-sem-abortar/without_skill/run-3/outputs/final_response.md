Execução do eval conciliacao-csv (iteração 1, smoke do CI) concluída com o stub offline, timeout de 5 s por execução.

Resultado por caso (baseline e with_skill dão o mesmo rc em cada caso):

- TC-01 caso-junho-simples: rc 0, 25 ms.
- TC-02 caso-arquivo-corrompido: rc 2 com "erro: extrato-maio.csv linha 17: separador inconsistente". Falha registrada como erro, não como timeout.
- TC-03 caso-lote-grande: rc 142 (timeout), 5 s. O stub dorme 20 s, então o runner de 5 s o encerra.

Pontos de atenção:

- O runner de produção em runners.yaml tem timeout_s 120. Com 5 s, o lote de julho vai sempre para timeout. Se o objetivo é validar o registro de timeout, o resultado está como esperado.
- O stub é fixo e não mede qualidade. Os tokens (1180/95 com skill, 240/110 sem) são constantes do stub; não servem para comparar ganho da skill.
- A primeira tentativa usou declare -A, não suportado pelo bash 3.2 do macOS, e foi descartada.

Arquivos: outputs/transcript.md, outputs/raw/, work/.eval-runner/calls.jsonl.
