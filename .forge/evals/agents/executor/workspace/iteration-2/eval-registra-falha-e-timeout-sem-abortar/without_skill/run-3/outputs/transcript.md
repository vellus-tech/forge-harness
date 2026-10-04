# Transcrição — eval A/B conciliacao-csv, iteração 1 (smoke CI)

Projeto de trabalho: work/ (cópia do fixture; git com status sujo herdado do fixture, não tocado por mim).

## Passos

1. Li o prompt de execução e o inventário de work/ (sem sair dos três diretórios permitidos).
2. Li .forge/runners.yaml: runner claude-code aponta para ./tools/claude-stub.sh, args -p {prompt} --output-format stream-json --no-cache, timeout_s 120 no runner (o pedido pede 5 s por execução; usei 5 s).
3. Li tools/claude-stub.sh: o stub grava cada chamada em .eval-runner/calls.jsonl, detecta a skill pela presença de "name: conciliacao-csv" no prompt, detecta o caso pelo último "caso-*" e tem comportamentos fixos: caso-arquivo-corrompido sai com código 2 e mensagem de erro em stderr; caso-lote-grande faz sleep 20 antes de responder.
4. Li skills-dev/conciliacao-csv/SKILL.md e confirmei que data/extrato-junho.csv existe (3 linhas). O arquivo extrato-maio.csv não existe no projeto; o stub não depende dele.
5. Primeira rodada descartada: usei declare -A, não suportado pelo bash 3.2 do macOS. Os prompts saíram vazios e as chamadas foram registradas como "desconhecido". Limpei .eval-runner e refiz.
6. Rodada válida: script tmp/run-eval.sh, para cada TC, duas variantes (baseline sem skill; with_skill com SKILL.md + prompt), cada uma com perl alarm 5 s (timeout(1) não existe no macOS). Sem rede, sem docker, sem sleep meu em foreground.

## Resultados (rodada válida)

| Caso | Variante | rc | duração (ms) | Observação |
|---|---|---|---|---|
| TC-01 caso-junho-simples | baseline | 0 | 25 | stream-json completo (268/269 bytes) |
| TC-01 caso-junho-simples | with_skill | 0 | 25 | with_skill=true, input 1180 / output 95 tokens |
| TC-02 caso-arquivo-corrompido | baseline | 2 | 23 | stderr: "erro: extrato-maio.csv linha 17: separador inconsistente"; stdout vazio |
| TC-02 caso-arquivo-corrompido | with_skill | 2 | 24 | idem |
| TC-03 caso-lote-grande | baseline | 142 | 5025 | SIGALRM após 5 s (stub dormia 20 s); stdout vazio |
| TC-03 caso-lote-grande | with_skill | 142 | 5018 | idem |

calls.jsonl: 6 chamadas, uma por variante e caso, com case e with_skill corretos.

## Decisões

- Mantive o timeout de 5 s do pedido, mesmo sabendo que o runner padrão do runners.yaml é 120 s. É o que o pedido manda.
- Não alterei runners.yaml, o stub nem o SKILL.md. Não tentei "consertar" o caso corrompido nem o lote pesado: o objetivo era observar como o harness registra as falhas.
- Não há humano disponível. Nenhuma decisão do fluxo exigiu confirmação.
- O stub é offline e fixo: a saída não mede a qualidade da skill. Os tokens são constantes do stub, não de um modelo real. Esta execução prova o encadeamento do runner, não o ganho da skill.
- O processo `sleep 20` do stub nos casos TC-03 foi interrompido pelo alarme do perl no processo do shell; pode haver um sleep órfão que termina sozinho em até 20 s. Não o matei de propósito.

## Arquivos escritos

- outputs/raw/*.jsonl e *.err (6 pares de saída bruta)
- tmp/run-eval.sh
- work/.eval-runner/calls.jsonl (gerado pelo stub)
- outputs/transcript.md, outputs/final_response.md
