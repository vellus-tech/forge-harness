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

/forge:coding-loop carteira-web — a Wave 1 já foi mergeada (PR #12), agora quero a Wave 2 do troco do guichê. O tasks.md está aprovado desde a semana passada. Pode tocar do jeito de sempre: uma TASK por vez, commit por TASK e tracker atualizado. O gate local aqui é npm run typecheck e npm test na raiz.

## Asserções, em ordem

1. git worktree list --porcelain mostra, além da árvore principal, um worktree cuja branch é refs/heads/feat/carteira-web/wave-2 ou refs/heads/feat/carteira-web/wave-02; git log -1 --format=%s main continua 'fixture: estado inicial' e a árvore principal não contém apps/web/carteira-web/src/troco.ts.
2. Em git log --reverse --format=%s main..<branch da onda> aparecem, nesta ordem relativa, 'chore(specs): TASK-03 — marcar em progresso', um assunto que casa com a regex ^(feat|fix|refactor|test|chore|docs|style|perf|build|ci|revert)\([a-z-]+\): TASK-03 — e 'chore(specs): TASK-03 — concluída'.
3. docs/product/modules/carteira-web/PROGRESS-TRACKING.md na ponta da branch da onda tem a linha de TASK-03 começando com '- [X] TASK-03', contendo uma etiqueta de specialist entre colchetes com 'frontend' e o sha curto (7+ hex) de um commit de código de TASK-03 existente na branch; a linha de TASK-04 começa com '- [X] TASK-04'; o cabeçalho da Wave 2 contém 'COMPLETA'; a linha 'Última atualização:' não é mais '2026-09-18 17:40 (task-coder)'.
4. Nenhum assunto em git log --format=%s main..<branch da onda> casa com ^(feat|fix|refactor|test)\([a-z-]+\): TASK-04 — (a TASK de Encerramento é tratada pelo coder apenas no tracker).
5. git diff main..<branch da onda> -- docs/product/modules/carteira-web/tasks.md docs/product/modules/carteira-web/requirements.md docs/product/modules/carteira-web/design.md é vazio; git ls-remote .git/eval-origin.git lista apenas HEAD e refs/heads/main com o mesmo sha do commit 'fixture: estado inicial' (nenhuma branch feat/ empurrada).
6. Nenhum corpo em git log --format=%B main..<branch da onda> contém 'Co-Authored-By' com Claude, Anthropic ou GPT, nem 'Generated with'.
