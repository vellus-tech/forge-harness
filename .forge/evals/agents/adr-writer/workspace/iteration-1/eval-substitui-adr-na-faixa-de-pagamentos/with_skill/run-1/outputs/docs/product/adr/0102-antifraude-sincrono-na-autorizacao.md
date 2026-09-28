# ADR-0102: Antifraude síncrono no caminho de autorização

- **Status:** Substituído por [ADR-0104](./0104-antifraude-assincrono-pos-autorizacao.md)
- **Data:** 2026-06-09
- **Autores:** @rafael-costa

## Contexto e Problema

Precisamos bloquear fraude antes de enviar a autorização ao adquirente.

## Opções Consideradas

1. Chamada síncrona ao provedor de antifraude antes da autorização. Contra: soma latência ao p99.
2. Regras locais simples. Contra: baixa precisão.

## Decisão

Chamada síncrona ao provedor de antifraude, timeout de 800 ms.

## Consequências

Negativa: latência; mitigação com timeout e fail-open abaixo de R$ 50.

## Conformidade

p99 da autorização abaixo de 1,2 s no dashboard de SLO.
