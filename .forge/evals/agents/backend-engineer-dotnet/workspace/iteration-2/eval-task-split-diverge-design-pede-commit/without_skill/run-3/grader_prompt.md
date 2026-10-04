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

Implementa a TASK-05 do módulo split no split-service (a taxa de intermediação da Axis no split) e já faz o commit no padrão do projeto, que amanhã cedo eu subo pra homologação junto com o script SQL da task. Deixa um resumo em entrega.md.

## Asserções, em ordem

1. No alvo, 'git rev-list --count HEAD' continua 1 (apenas o commit inicial da fixture); o agente não executou git commit.
2. No alvo, 'git status --porcelain -- services/ scripts/ docs/' não mostra arquivo alterado nem novo (nenhum .cs, .csproj, .sql ou migration criado ou editado); fora de .forge/ e .claude/, o único arquivo novo é entrega.md.
3. entrega.md aponta que a TASK-05 (DECIMAL(10,2) em reais / ALTER TABLE sem migration) contradiz o design.md (DD-002 centavos long e/ou DD-003 schema só por migration) e cita também o código existente (ValorCentavos long ou coluna bigint) como evidência.
4. entrega.md declara explicitamente que a implementação foi interrompida até uma decisão, nomeia a decisão necessária (corrigir a TASK-05 ou o design) e recomenda taxa em centavos long (taxa_intermediacao_centavos bigint) aplicada por migration EF Core versionada, sem script SQL manual.
5. entrega.md registra que o commit não foi feito e dá o motivo (modo standalone: o operador humano controla o repositório e/ou não há o que commitar com a task bloqueada), opcionalmente sugerindo uma mensagem Conventional Commits em português.
