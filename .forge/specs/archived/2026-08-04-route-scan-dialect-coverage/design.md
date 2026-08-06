# Design — route-scan-dialect-coverage

## A escolha que se repete: falso positivo × falso negativo

Três das quatro lacunas são a mesma pergunta — errar para que lado quando não se sabe? O módulo já tinha a resposta para path (**ausente é melhor que inventado**, porque o `SUR-01` bloqueia). Aqui a resposta muda conforme o lado do cruzamento:

- **Superfície declarada** (tabela de policy): ler demais faz o gate bloquear indevidamente; ler de menos faz o gate aprovar por vacuidade. O segundo é pior, então a âncora **degrada** para varredura ampla quando o heading não existe, e anuncia. Só com o heading presente a leitura é estrita.
- **Superfície do código** (caixa do `[controller]`): o endpoint existe e o roteamento é case-insensitive, então acusar por caixa é falso positivo puro. Rebaixar é correto — no indexador do dialeto, nunca no normalizador compartilhado.
- **Dialeto sem indexador**: não ler é ausência silenciosa. Ler mal é path inventado. A saída foi implementar os frameworks dominantes e recusar explicitamente o que não dá para saber (`HandleFunc` sem verbo declarado).

## Por que o case-fold não pode ir para o normalizePath

`normalizePath` serve os seis dialetos. Spring e Express são case-sensitive: `/Orders` e `/orders` são endpoints diferentes, e colapsá-los faria duas rotas distintas comparar iguais — inventando cobertura. O ASP.NET é que é case-insensitive, e só o token derivado do nome da classe (uma decisão do C#, não do autor da rota) é rebaixado.

## Premissa que envelheceu

O item afirmava que Nest resolvia "um controller por arquivo". Medido, multi-controller já funciona: a correção de prefixo-por-classe do PR #40 o cobriu de passagem. O caso `[56]` passa a travar isso.

## Impacto

`lib/route-scan.mjs` (indexadores .NET, Python, Go) e `lib/api-surface.mjs` (âncora + diagnóstico). Dois casos existentes do `w132` atualizados, por mudança deliberada de comportamento.
