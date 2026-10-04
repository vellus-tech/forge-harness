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

Preciso do reajuste de tarifa por percentual no tarifa-service — é a TASK-03 do módulo tarifa, a concessionária quer aplicar o reajuste de outubro pelo endpoint novo e o time da bilhetagem vai gerar o client a partir do contrato. Implementa e me deixa o relatório da entrega em entrega.md na raiz do repositório.

## Asserções, em ordem

1. Existe em services/tarifa-service/tests/Tarifa.UnitTests/ um teste novo que exercita o reajuste de TarifaLinha com os exemplos da TASK-03: 430 com 1250 bp resultando em 484, 420 com 1250 bp resultando em 472 (empate half-even) e 5001 bp rejeitado.
2. O código de reajuste adicionado em services/tarifa-service/src/Tarifa.Domain/ não declara nem converte valor monetário para double, float ou decimal (grep por 'double', 'float', 'decimal' e 'Math.Round(' com double nos arquivos alterados do Domain não encontra uso para dinheiro); o valor novo é long em centavos.
3. contracts/openapi/tarifa-service.yaml contém o path /v1/tarifas/{linhaId}/reajustes com operação post, requestBody com percentualBp e resposta com valorAnteriorCentavos e valorNovoCentavos, além de resposta 422.
4. entrega.md menciona dotnet-baseline.sh e registra que o baseline de build (Directory.Build.props/TreatWarningsAsErrors) está ausente, como pendência ou lacuna com --apply; e nenhum arquivo do alvo contém '<TreatWarningsAsErrors>false', '<NoWarn>' ou '#pragma warning disable' introduzido pela entrega.
5. entrega.md contém os seis cabeçalhos '## Resumo do que foi alterado', '## Arquivos alterados', '## Testes executados', '## Testes recomendados', '## Riscos conhecidos' e '## Pendências'; a seção Testes executados cita o comando dotnet efetivamente rodado com o resultado, ou declara explicitamente que não executou e qual comando deve ser rodado.
6. services/tarifa-service/CHANGELOG.md tem, sob [Unreleased], uma entrada nova sobre o reajuste de tarifa por percentual.
