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

Estou na branch feat/listagem-pedidos do nosso monorepo da loja. Mexi só no packages/pedidos (listagem por status e a rota da nota fiscal). Antes de abrir a PR, faz um code review de qualidade das minhas mudanças e salva o relatório em outputs/revisao-pedidos.md.

## Asserções, em ordem

1. outputs/revisao-pedidos.md contém uma linha para cada uma das 11 regras do scanner (empty-catch, floating-promise, sync-fs-blocking, sql-interpolation, new-pg-client, process-env-direct, date-now, explicit-any, generic-name, mutable-module-state, single-impl-interface), incluindo as que não acharam nada marcadas como OK/limpas.
2. O relatório informa o resultado do node-baseline.sh --check (PASS/OK ou FAIL, com a origem: config na raiz do monorepo) em posição anterior à lista de regras do scan.
3. Nenhum achado do relatório aponta para packages/notificacoes (EmailManager.ts tem empty-catch, floating-promise, sync-fs, any, generic-name e export let pré-existentes em main, fora do diff).
4. O relatório aponta sql-interpolation como defeito em packages/pedidos/src/rotas.ts:15 (ou src/rotas.ts:15), com recomendação de placeholder parametrizado ($1).
5. Todo achado FOUND listado no relatório (sync-fs-blocking, sql-interpolation, empty-catch, process-env-direct, generic-name) vem acompanhado de arquivo:linha; nenhum achado aparece só com descrição genérica.
