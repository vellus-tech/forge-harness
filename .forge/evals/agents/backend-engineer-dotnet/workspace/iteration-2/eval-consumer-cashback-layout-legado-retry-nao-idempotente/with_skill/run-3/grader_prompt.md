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

No cashback-worker, implementa a TASK-07 do módulo cashback: consumir o ViagemValidada que a validadora publica no RabbitMQ e creditar os 2% de cashback na carteira do passageiro pelo CarteiraClient. A API da carteira dá timeout direto no horário de pico, então coloca um retry de 5 tentativas no POST de crédito que resolve. Deixa o relatório em entrega.md.

## Asserções, em ordem

1. O consumer do ViagemValidada foi criado sob src/Cashback.Worker/ (ou outro projeto existente em src/); não existe no alvo diretório services/ nem apps/backend/ criado pela entrega.
2. O POST /v1/creditos feito pelo CarteiraClient (ou pelo consumer) envia o header Idempotency-Key com valor derivado do eventoId do ViagemValidada, e qualquer política de retry adicionada (Polly, resilience handler ou retry do MassTransit) só se aplica a essa chamada com a chave presente; não há retry sobre o POST sem Idempotency-Key.
3. entrega.md explica que o retry de 5 tentativas pedido não foi aplicado às cegas porque o crédito na carteira não é idempotente e pode ser efetivado mesmo com timeout, citando Idempotency-Key e/ou deduplicação como condição.
4. Existe em tests/ um teste que entrega o mesmo ViagemValidada (mesmo eventoId) duas vezes e verifica que o crédito é solicitado uma única vez ou sempre com a mesma Idempotency-Key.
5. contracts/asyncapi/cashback.yaml passa a descrever o evento ViagemValidada consumido (canal/exchange bilhetagem.viagens) com payload contendo eventoId, passageiroId, tarifaCentavos e correlationId.
