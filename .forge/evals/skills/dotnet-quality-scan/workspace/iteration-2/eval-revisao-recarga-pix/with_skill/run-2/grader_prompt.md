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

Estou na branch feature/recarga-pix deste monorepo e vou abrir PR para develop. Faz um code review de qualidade do C# que eu mexi nessa branch (a cobrança Pix de recarga de cartão) e grava o relatório em revisao-qualidade.md na raiz do repositório. Não quero que você corrija nada, só o relatório para eu decidir o que ajustar antes do PR.

## Asserções, em ordem

1. revisao-qualidade.md cita pelo ID todas as 11 regras do scanner (async-void, blocking-wait, new-httpclient, region, generic-name, bool-param, empty-catch, datetime-now, sql-interpolation, mutable-static, single-impl-interface), e as que não acharam nada no escopo (ao menos async-void, region, generic-name, bool-param e mutable-static) aparecem marcadas como OK/limpas, não omitidas.
2. revisao-qualidade.md não reporta nenhum achado de src/Legacy.Relatorios (nem RelatorioManager, PedidoHelper, #region, UltimoLote ou o parâmetro bool detalhado), que está fora do diff main...feature/recarga-pix; region, generic-name, bool-param e mutable-static não aparecem como FOUND.
3. Cada achado listado em revisao-qualidade.md traz caminho e número de linha, incluindo pelo menos RecargaController.cs:23 (.Result), RecargaController.cs:29 (catch vazio), PixGatewayClient.cs:14 (new HttpClient), PixGatewayClient.cs:15 (.Wait()), PixGatewayClient.cs:20 (FromSqlRaw interpolado) e RecargaPix.cs:10 (DateTime.Now).
4. revisao-qualidade.md registra que a auditoria da camada de build (dotnet-baseline.sh --check, ou TreatWarningsAsErrors/AnalysisMode/EnforceCodeStyleInBuild verificados) foi executada e passou, antes ou separado da lista de achados do scanner.
5. revisao-qualidade.md trata o GetAwaiter().GetResult() em Recarga.Seed/Program.cs:8 (Main síncrono de ferramenta de linha de comando) como exceção aceitável ou não-defeito, enquanto classifica o .Result em RecargaController.cs:23 como defeito — ou seja, os três achados de blocking-wait não recebem o mesmo veredito.
6. git -C <alvo> status --porcelain não mostra nenhum arquivo .cs modificado; o único arquivo novo ou alterado é revisao-qualidade.md (a revisão não reescreveu o código).
