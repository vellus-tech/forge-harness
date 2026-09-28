# ADR-0104: Pontuação de fraude assíncrona pós-autorização, com anulação antes da captura

- **Status:** Aceito
- **Data:** 2026-09-24
- **Autores:** @rafael-costa
- **Substitui:** [ADR-0102](./0102-antifraude-sincrono-na-autorizacao.md) (Antifraude síncrono no caminho de autorização)

## Contexto e Problema

A chamada síncrona de antifraude no caminho de autorização (ADR-0102) soma latência ao fluxo crítico. Nos picos de agosto, o p99 de autorização chegou a 1,9 s e o SLO foi estourado três vezes. Precisamos tirar a pontuação de fraude do caminho de autorização sem abrir mão de bloquear a captura de transações fraudulentas.

## Opções Consideradas

1. Manter a chamada síncrona com timeout de 800 ms (status quo do ADR-0102). Contra: p99 de autorização em 1,9 s nos picos; SLO de autorização estourado três vezes em agosto.
2. Pontuação de fraude assíncrona logo após a autorização, com anulação (void) da autorização antes da captura, já que a captura só ocorre em D+0 às 23:00. Contra: parte das autorizações fraudulentas chega a tocar o emissor e a taxa de autorização é paga antes da anulação.
3. Motor de regras locais apenas, sem chamada a provedor externo. Contra: precisão baixa — 38% de falsos positivos no piloto.

## Decisão

Adotar a opção 2. A pontuação de fraude passa a ser assíncrona, calculada imediatamente após a autorização. Quando o score for maior que 0,85, a autorização é anulada antes da janela de captura (D+0 23:00). Esta decisão substitui o ADR-0102.

## Consequências

Negativa: parte das autorizações fraudulentas chega a tocar o emissor antes da anulação, e a taxa de autorização correspondente é paga mesmo quando a transação acaba anulada.

Positiva: remove a latência do provedor de antifraude do caminho crítico de autorização, eliminando a causa dos estouros de SLO observados em agosto.

## Conformidade

Acompanhar no dashboard de SLO: (a) p99 de autorização, que deve voltar a ficar dentro do SLO antes violado três vezes em agosto sob o modelo síncrono; (b) taxa e valor de autorizações anuladas por score de fraude entre autorização e captura; (c) taxa de fraude que efetivamente chega ao emissor antes da anulação, para acompanhar o custo da taxa de autorização paga indevidamente.

## Metadados

Aprovado em revisão de arquitetura em 2026-09-24. Owner: @rafael-costa.
