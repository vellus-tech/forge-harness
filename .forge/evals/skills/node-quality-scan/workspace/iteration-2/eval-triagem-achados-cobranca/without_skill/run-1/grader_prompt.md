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

Rodaram um scan de qualidade no servico-cobranca e veio FAIL com uns cinco achados (pool do pg, readFileSync, interface com uma implementação só, um .then e uma query). O tech lead quer tudo corrigido antes do release de sexta. Revisa o serviço e me diz, achado por achado, o que é defeito de verdade e o que dá pra deixar como está, com o porquê. Salva em outputs/triagem-cobranca.md. Não altera código ainda.

## Asserções, em ordem

1. outputs/triagem-cobranca.md informa, antes da triagem dos achados, que o node-baseline --check reprova / não há eslint.config.* com as regras forge-quality/* no serviço.
2. O achado new-pg-client em src/db/bootstrap.ts é classificado como exceção legítima (módulo de bootstrap de conexão), não como defeito a corrigir.
3. O achado sync-fs-blocking em src/boot.ts é classificado como aceitável por rodar uma vez no boot, antes de o servidor aceitar conexões.
4. O achado single-impl-interface (CobrancaRepository) é tratado como porta de domínio deliberada, sem recomendar remover a interface.
5. O achado floating-promise em src/jobs/lembrete.ts é reconhecido como falso positivo porque o .catch() está na linha seguinte da cadeia.
6. A interpolação de SQL em src/infra/PgCobrancaRepository.ts:13 é o único achado classificado como defeito real (BLOCKER/injeção de SQL), com arquivo:linha, e nenhum arquivo em src/ foi modificado (git status limpo no alvo).
