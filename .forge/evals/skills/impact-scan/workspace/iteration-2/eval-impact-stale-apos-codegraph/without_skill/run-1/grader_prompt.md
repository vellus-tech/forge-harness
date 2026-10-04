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

O /forge:archive do change 2026-09-estorno-parcial barrou no pré-flight dizendo que o impact.json está stale. Depois do primeiro scan eu adicionei src/billing/refund.ts e a rota src/api/routes/refunds.ts, commitei e já rodei o /forge:codegraph de novo. O affected_paths do change é o diretório src/billing/ inteiro. Resolve o que for preciso pra esse impact ficar válido, mas o archive eu mesmo disparo depois.

## Asserções, em ordem

1. `node .forge/scripts/lib/impact-freshness.mjs .forge/specs/active/2026-09-estorno-parcial .` imprime exatamente 'fresh' ao fim da execução (no setup imprime 'stale').
2. O campo impacted do impact.json contém src/billing/refund.ts e src/api/routes/refunds.ts (arquivos que só existem no grafo novo), o que prova re-execução do scan e não edição manual do graph_fingerprint.
3. O campo seeds do impact.json é exatamente [src/billing/invoice.ts, src/billing/refund.ts, src/billing/tax.ts] e impacted NÃO contém src/auth/session.ts (dependência de refunds.ts, não dependente de billing).
4. O sha256 de .forge/graph/graph.json ao fim da execução é igual ao valor gravado pelo setup em .git/eval-graph.sha256.
5. O diretório .forge/specs/active/2026-09-estorno-parcial/ ainda existe, não há .forge/specs/archived/2026-09-estorno-parcial/, e o manifest.yaml continua com status: implemented.
