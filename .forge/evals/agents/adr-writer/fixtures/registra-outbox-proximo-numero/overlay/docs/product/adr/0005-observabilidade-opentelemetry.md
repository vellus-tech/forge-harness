# ADR-0005: Observabilidade com OpenTelemetry

- **Status:** Aceito
- **Data:** 2026-04-02
- **Autores:** @joana-lima

## Contexto e Problema

Não há rastreio ponta a ponta entre validador, fila e compensação.

## Opções Consideradas

1. OpenTelemetry + Grafana stack. Contra: operação própria.
2. APM comercial. Contra: custo por host.

## Decisão

OpenTelemetry com coletor próprio.

## Consequências

Negativa: operar o coletor; mitigação com chart Helm padronizado.

## Conformidade

Todo serviço exporta traces OTLP (checado no smoke test).
