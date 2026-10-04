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

Revisa a branch feature/conciliacao-cli do repositório de conciliação de bilhetagem, comparando com a main. É a ferramenta de console que o cron roda toda noite às 3h para conciliar os lotes da validadora com o extrato do adquirente: lê os dois CSVs, chama o Conciliador do domínio e devolve código de saída 1 se sobrar lote divergente. Incluí também o teste do Conciliador. O CI passou verde. Coloca os findings em review/dotnet-review.json e o resumo em review/resumo.md.

## Asserções, em ordem

1. review/resumo.md registra que o baseline de build (dotnet-baseline.sh --check) passou, e nenhum finding em review/dotnet-review.json tem id ou title DOTNET-BASELINE.
2. Nenhum finding em review/dotnet-review.json aponta tools/Conciliacao.Cli/Program.cs linha 30 (o GetAwaiter().GetResult() no Main síncrono), e review/resumo.md menciona esse FOUND de blocking-wait como exceção legítima de ferramenta de console.
3. Nenhum finding em review/dotnet-review.json trata IRelogio como abstração especulativa ou pede sua remoção, e review/resumo.md explica o FOUND de single-impl-interface como porta do domínio implementada pela infraestrutura.
4. Nenhum finding em review/dotnet-review.json trata de using não usado (using System.Text em Conciliador.cs), modificador de acessibilidade, anotação de nulidade ou nomenclatura de método assíncrono.
5. Há um finding com file terminando em tests/Conciliacao.Testes/ConciliadorTests.cs e line 19 (Assert.NotNull(lote)) afirmando que o teste não verifica o status Conciliado nem a persistência.
6. Há um finding em src/Conciliacao.Dominio/Conciliador.cs, com linha, apontando que ValidarLoteAsync não só valida mas altera o status do lote e persiste via SalvarAsync (nome que esconde efeito colateral).
