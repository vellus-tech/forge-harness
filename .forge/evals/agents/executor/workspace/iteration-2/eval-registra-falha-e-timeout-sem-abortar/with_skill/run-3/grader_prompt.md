# Grading de uma execução

Você é o grader cético de uma execução. Decida, asserção por asserção, se a evidência mostra que ela foi cumprida. Não avalie se a execução foi boa em geral.

## Entradas

- Projeto no estado em que a execução o deixou: `<RUN>/work`. É somente leitura: não altere nada nele (git só com comandos de leitura).
- Registro do executor em `<RUN>/outputs/`: `transcript.md`, `final_response.md` (a resposta final dada ao usuário é o conteúdo desse arquivo) e os demais arquivos ali.
- O `/tmp` desta execução é `<RUN>/tmp`: uma asserção sobre `/tmp/<x>` se verifica em `<RUN>/tmp/<x>`.
- Não leia nada fora de `<RUN>`.

## Regras

- PASS só com evidência concreta, de preferência um comando que você mesmo rodou (`grep -n`, `jq`, `git log`, `shasum`, `cmp`, `ls`), citado com o resultado. Na dúvida, FAIL, com o motivo na evidência.
- Não confie no que o transcript diz ter feito: confira no projeto e nos arquivos.
- Avalie só esta execução. Não existe outra configuração para comparar.

## Saída

Grave `<RUN>/grading.json`, JSON válido, exatamente neste formato:

```json
{
  "expectations": [
    {"text": "<texto literal da asserção>", "passed": true, "evidence": "<comando e resultado, ou citação>"}
  ],
  "summary": {"passed": 0, "failed": 0, "total": 5, "pass_rate": 0.0},
  "eval_feedback": {"suggestions": [], "overall": "<uma frase>"}
}
```

Uma entrada em `expectations` por asserção, na mesma ordem e com o texto literal. `passed` é booleano. `pass_rate` é um NÚMERO entre 0 e 1 igual a `passed/total`, com até 4 casas decimais, nunca texto como `"2/5"`. Não inclua campo `timing`. Depois de gravar, rode `jq -e '(.summary.pass_rate|type)=="number" and (.expectations|length)==5 and ([.expectations[]|select(.passed==true)]|length)==.summary.passed' <RUN>/grading.json` e corrija o arquivo se falhar. A sua resposta a quem o chamou é só `OK` quando o grading.json estiver gravado e validado, mesmo com asserções reprovadas, ou `FALHA: <motivo>` se não conseguiu gravá-lo.

## Pedido original do usuário

Executor do eval A/B da conciliacao-csv, iteração 1 do smoke do CI. Aqui o runner fica limitado a 5 s por execução. O extrato de maio veio corrompido do banco e o lote de julho é pesado, mas roda assim mesmo porque quero ver como o harness registra isso. Nesta máquina não tem login do Claude: o runner claude-code do .forge/runners.yaml aponta para o stub offline ./tools/claude-stub.sh, que aceita a mesma linha de comando do claude real. Entrada:

{
  "skill": "conciliacao-csv",
  "skill_path": "skills-dev/conciliacao-csv/SKILL.md",
  "eval_dir": ".forge/evals/skills/conciliacao-csv/workspace/iteration-1",
  "test_cases": [
    {
      "id": "TC-01",
      "prompt": "[caso-junho-simples] Concilia o data/extrato-junho.csv com o razão de junho e me diz o que ficou sem par."
    },
    {
      "id": "TC-02",
      "prompt": "[caso-arquivo-corrompido] Concilia o extrato-maio.csv que o banco reenviou ontem."
    },
    {
      "id": "TC-03",
      "prompt": "[caso-lote-grande] Concilia o lote de julho das 14 contas correntes da tesouraria."
    }
  ],
  "runner": "claude-code",
  "timeout_s": 5
}

## Asserções, em ordem

1. .forge/evals/skills/conciliacao-csv/workspace/iteration-1/results.json existe, é JSON válido e contém TC-01, TC-02 e TC-03, cada um com baseline_result e variant_result preenchidos com output, duration_ms, tokens e exit_code.
2. No TC-02, baseline_result.exit_code e variant_result.exit_code são 2 e o output de ambos contém 'separador inconsistente' (stderr capturado junto com stdout).
3. No TC-03, os dois lados têm exit_code diferente de 0 (ex.: 142 do SIGALRM ou 124 do timeout) e duration_ms menor que 15000; um duration_ms ≥ 20000 ou exit_code 0 com 'lote processado' no output reprova.
4. .eval-runner/calls.jsonl tem exatamente 6 linhas: uma com with_skill=false e uma com with_skill=true para cada um de caso-junho-simples, caso-arquivo-corrompido e caso-lote-grande.
5. results.json não traz campos de avaliação (passed, score, status de aprovado/reprovado, error_fatal ou similar) e nenhum grading.json foi criado; o caso bom (TC-01) tem exit_code 0 nos dois lados.
