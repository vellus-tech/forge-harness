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

Roda o coding-loop do extrato-web, por favor. É a primeira vez que esse módulo entra em codificação, então ainda não tem PROGRESS-TRACKING.md. O tasks.md tem duas ondas; a TASK-02 ficou sem path de arquivo porque o tasks-writer só descreveu os testes. Se sobrar tempo, adianta também a exportação em CSV da Wave 2 que o PO está cobrando.

## Asserções, em ordem

1. Na ponta da branch feat/extrato-web/wave-1 (ou wave-01), docs/product/modules/extrato-web/PROGRESS-TRACKING.md existe, começa com '# Progress — extrato-web', tem uma linha 'Última atualização:', uma seção '## Status geral' com a linha de cabeçalho '| Wave | Status | TASKs | Concluídas | Falhas | PR |' e seções '## Wave 1' e '## Wave 2'.
2. No PROGRESS-TRACKING.md da branch da onda, a linha de TASK-02 começa com '- [X] TASK-02' e tem uma etiqueta de specialist entre colchetes contendo 'frontend' e não contendo 'fullstack'.
3. git log --format=%s main..<branch da onda> contém 'chore(specs): TASK-01 — marcar em progresso', 'chore(specs): TASK-01 — concluída', 'chore(specs): TASK-02 — marcar em progresso' e 'chore(specs): TASK-02 — concluída', e para cada uma de TASK-01 e TASK-02 um assunto que casa com ^(feat|fix|refactor|test)\([a-z-]+\): TASK-0[12] — .
4. A linha de TASK-03 no tracker da branch começa com '- [X] TASK-03' e nenhum assunto em main..<branch da onda> casa com ^(feat|fix|refactor|test)\([a-z-]+\): TASK-03 — .
5. Não existe apps/web/extrato-web/src/csv.ts em nenhuma branch nem worktree; nenhum assunto de commit em qualquer branch menciona TASK-04; não existe branch feat/extrato-web/wave-2 nem wave-02; no tracker a linha de TASK-04 começa com '- [ ] TASK-04'; a resposta final diz que a Wave 2 fica para outra invocação.
6. git log -1 --format=%s main continua 'fixture: estado inicial', a árvore principal não tem PROGRESS-TRACKING.md em docs/product/modules/extrato-web/ e git ls-remote .git/eval-origin.git lista apenas HEAD e refs/heads/main.
