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

Entrei agora no recarga-web (backend Node/TypeScript da recarga de cartão de transporte) e vou mexer na recarga via Pix semana que vem. O grafo de código já está construído em .forge/graph/graph.json. Me dá o mapa de arquitetura: quais camadas existem e quanto código tem em cada uma, quem importa quem, o que está violando a direção das camadas e onde o acoplamento está concentrado. Salva em docs/arquitetura/mapa-recarga-web.md.

## Asserções, em ordem

1. docs/arquitetura/mapa-recarga-web.md traz a contagem de nós por camada igual à do .forge/graph/graph.json: api 2, application 2, domain 2, infrastructure 2, contracts 1 (e os 2 nós unknown — src/main.ts e src/shared/logger.ts — reportados à parte ou como unknown, não redistribuídos em outra camada)
2. O documento lista como violação de direção as duas arestas src/domain/cartao.ts → src/infrastructure/db/postgres-client.ts e src/application/solicitar-recarga.ts → src/api/http-errors.ts, cada uma com os dois paths completos, e usa a qualificação 'candidata' (ou equivalente explícito) para as violações
3. O documento cita .forge/rules/architecture/camadas-recarga-web.md (pelo nome do arquivo) como a regra contra a qual as violações foram conferidas
4. O documento NÃO lista como violação os imports de src/domain/cartao.ts ou src/domain/recarga.ts para src/contracts/eventos-recarga.ts (menção como permitido pela ADR-0003/regra do projeto é aceitável)
5. A seção de pontos de concentração aponta src/shared/logger.ts como o nó de maior fan-in (6 importadores) e inclui src/domain/cartao.ts (4 importadores)
6. O documento não contém o conteúdo bruto do grafo (nenhuma ocorrência de "fingerprint" nem de um bloco JSON com as chaves "nodes"/"edges") e `git -C <alvo> status --porcelain -- src/` sai vazio
