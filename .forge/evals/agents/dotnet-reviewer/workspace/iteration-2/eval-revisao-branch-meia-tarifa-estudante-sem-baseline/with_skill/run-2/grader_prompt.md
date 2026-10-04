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

Terminei a branch feature/meia-tarifa-estudante no TarifaApi: o DescontoService novo consulta o SGE da secretaria de educação para saber se a matrícula está ativa e aplica 50% sobre a tarifa da linha, e o Program.cs registra o serviço e expõe GET /tarifas/{linhaId}/estudante/{matricula}. Faz a revisão .NET do que mudou em relação à main antes de eu abrir o PR para develop. Grava os findings em review/dotnet-review.json e um resumo legível em review/resumo.md.

## Asserções, em ordem

1. Em review/dotnet-review.json, o primeiro elemento de findings tem id ou title contendo DOTNET-BASELINE, severity HIGH, e fix_suggested menciona 'dotnet-baseline.sh' com '--apply'.
2. review/resumo.md contém uma linha (ou linha de tabela) para cada uma das 11 regras do scan — async-void, blocking-wait, new-httpclient, region, generic-name, bool-param, empty-catch, datetime-now, sql-interpolation, mutable-static e single-impl-interface — cada uma com status explícito (OK/limpo ou FOUND/achado); as regras sem ocorrência aparecem como OK, não são omitidas.
3. Há um finding com file terminando em src/Tarifa.Api/Program.cs e line 9 (o AddSingleton<DescontoService>) cuja descrição identifica que o singleton captura o TarifaDbContext de ciclo de vida Scoped (captive dependency).
4. review/dotnet-review.json é JSON válido com a chave reviewer e o array findings; todo finding tem id único, severity em {BLOCKER, HIGH, MEDIUM, LOW}, file não vazio, line inteiro positivo, title, description e fix_suggested — nenhum finding sem arquivo:linha.
5. Nenhum finding em review/dotnet-review.json aponta arquivo sob src/Legado.Relatorios/ (o RelatorioHelper com #region, DateTime.Now e parâmetro bool existe só na main e não foi tocado pela branch).
