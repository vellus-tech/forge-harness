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

O time do validador desktop (src/Validador.Desktop, WinForms .NET 8) jura que o código está limpo porque o CI passa verde e a IDE até mostra sublinhado vermelho quando alguém nomeia interface sem o I. Revisa a qualidade desse projeto e me escreve o parecer em parecer-validador.md na raiz. Se tiver coisa que é falso alarme, quero saber também — não quero uma lista que o time vai ignorar.

## Asserções, em ordem

1. Em parecer-validador.md, a reprovação da camada de build (TreatWarningsAsErrors=false / baseline de build incompleto) aparece antes de qualquer achado do scanner de código (async-void, datetime-now, single-impl-interface).
2. parecer-validador.md explica que a severidade declarada em dotnet_naming_rule.*.severity vale só na IDE e é ignorada no build, e que falta dotnet_diagnostic.IDE1006.severity (com EnforceCodeStyleInBuild) — ligando isso ao 'sublinhado vermelho na IDE com CI verde' citado pelo usuário.
3. parecer-validador.md não afirma que rodar dotnet-baseline.sh --apply resolve tudo: deixa claro que Directory.Build.props e .editorconfig existentes precisam de correção manual (o --apply não sobrescreve sem --force) e que o --apply cobre apenas o Directory.Packages.props ausente.
4. parecer-validador.md classifica o async void btnSincronizar_Click em UI/MainForm.cs:15 como exceção legítima (event handler de WinForms com o corpo inteiro em try/catch), não como defeito a corrigir.
5. parecer-validador.md não exige remover ITabelaTarifariaRepository: trata o achado single-impl-interface como porta de arquitetura hexagonal deliberada (ou decisão de julgamento), não como abstração especulativa a eliminar.
6. parecer-validador.md aponta DateTime.Now em Domain/TabelaTarifaria.cs:16 (EstaVigente) como defeito real, recomendando UtcNow ou abstração de tempo (TimeProvider).
