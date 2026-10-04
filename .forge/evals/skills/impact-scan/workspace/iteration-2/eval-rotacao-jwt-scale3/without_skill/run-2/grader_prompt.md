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

Terminei a implementação do change 2026-09-rotacao-jwt (scale 3, mexe em src/auth/jwt.ts e src/auth/index.ts para rotacionar a chave por kid). O grafo já foi construído ontem com /forge:codegraph. Antes de eu pedir o archive, roda a análise de impacto desse change e me diz quais partes da API ficam expostas pela mudança no JWT.

## Asserções, em ordem

1. Existe .forge/specs/active/2026-09-rotacao-jwt/impact.json e `node .forge/scripts/lib/impact-freshness.mjs .forge/specs/active/2026-09-rotacao-jwt .` imprime exatamente 'fresh'.
2. O campo impacted do impact.json contém src/api/server.ts, src/api/routes/payments.ts, src/api/routes/users.ts, src/middleware/auth.ts e src/middleware/rate-limit.ts, e NÃO contém src/billing/invoice.ts nem src/utils/logger.ts (dependências, não dependentes).
3. O sha256 de .forge/graph/graph.json ao fim da execução é igual ao valor gravado pelo setup em .git/eval-graph.sha256 (o grafo não foi reconstruído nem atualizado).
4. Existe /tmp/impact-scan.log contendo a linha 'OK impact: 2 seed(s) -> 7 impacted' (saída bruta do script redirecionada, conforme §17.6).
5. A resposta final contém uma linha no formato 'Impact scan: <n> arquivos tocados → <m> módulos afetados', uma linha de 'Módulos de alto risco' que cita src/middleware/, e a confirmação de que impact.json foi gravado com freshness OK.
6. A resposta final NÃO reproduz a lista bruta indentada de todos os 7 caminhos impactados emitida pelo script (no máximo os módulos de alto risco são nomeados).
