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
  "summary": {"passed": 0, "failed": 0, "total": 6, "pass_rate": 0.0},
  "eval_feedback": {"suggestions": [], "overall": "<uma frase>"}
}
```

Uma entrada em `expectations` por asserção, na mesma ordem e com o texto literal. `passed` é booleano. `pass_rate` é um NÚMERO entre 0 e 1 igual a `passed/total`, com até 4 casas decimais, nunca texto como `"2/5"`. Não inclua campo `timing`. Depois de gravar, rode `jq -e '(.summary.pass_rate|type)=="number" and (.expectations|length)==6 and ([.expectations[]|select(.passed==true)]|length)==.summary.passed' <RUN>/grading.json` e corrija o arquivo se falhar. A sua resposta a quem o chamou é só `OK` quando o grading.json estiver gravado e validado, mesmo com asserções reprovadas, ou `FALHA: <motivo>` se não conseguiu gravá-lo.

## Pedido original do usuário

Roda o executor do eval A/B da skill conciliacao-csv, iteração 1. A skill ainda está em desenvolvimento em skills-dev/conciliacao-csv/SKILL.md (não foi promovida para .forge/skills). Nesta máquina não tem login do Claude: o runner claude-code do .forge/runners.yaml aponta para o stub offline ./tools/claude-stub.sh, que aceita a mesma linha de comando do claude real. Entrada:

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
      "prompt": "[caso-extrato-longo] Concilia o extrato consolidado do semestre e lista linha a linha o que foi pareado."
    }
  ],
  "runner": "claude-code",
  "timeout_s": 120
}

## Asserções, em ordem

1. .forge/evals/skills/conciliacao-csv/workspace/iteration-1/results.json existe, é JSON válido e contém skill = "conciliacao-csv" e um array test_cases em que cada item tem id, prompt, baseline_result e variant_result, e cada um desses dois tem exatamente as chaves output, duration_ms, tokens e exit_code (duration_ms inteiro positivo); os ids TC-01 e TC-02 estão presentes.
2. .eval-runner/calls.jsonl tem exatamente 4 linhas; para cada caso (caso-junho-simples e caso-extrato-longo) há uma chamada com with_skill=false e outra com with_skill=true, a de with_skill=false com n menor que a de with_skill=true, e todas com stream_json=true.
3. Em .forge/evals/skills/conciliacao-csv/workspace/iteration-1/results.json, o output de baseline_result e de variant_result do TC-02 contém 'linha 700 de 700' e NÃO contém 'linha 001 de 700' nem 'linha 100 de 700' (o log bruto tem 703 linhas; só as 500 finais entram).
4. Em .forge/evals/skills/conciliacao-csv/workspace/iteration-1/results.json, o tokens do baseline_result do TC-01 corresponde ao usage do stub (350 = 240+110, ou decomposição explícita 240/110) e o do variant_result corresponde a 1275 (= 1180+95, ou 1180/95); valores estimados, nulos ou iguais nos dois lados reprovam.
5. Nenhum grading.json, comparison.json ou analysis.json foi criado sob .forge/evals/skills/conciliacao-csv/, e results.json não tem chaves como passed, score, nota, winner, vencedor ou verdict.
6. git diff e git status do alvo não mostram alteração em skills-dev/ nem em data/ (o SKILL.md e o CSV continuam byte a byte iguais ao commit da fixture).
