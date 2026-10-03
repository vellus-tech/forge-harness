# ADR-0003: RabbitMQ para eventos de validação de embarque

- **Status:** Aceito
- **Data:** 2026-03-05
- **Autores:** @rafael-costa

## Contexto e Problema

Os validadores embarcados geram eventos de validação que o serviço de compensação consome de forma assíncrona.

## Opções Consideradas

1. RabbitMQ — roteamento flexível, operação conhecida. Contra: retenção curta.
2. Kafka — retenção e replay. Contra: custo operacional alto para o volume atual.

## Decisão

RabbitMQ com filas quorum; o serviço `validacao` publica após gravar a validação no PostgreSQL.

## Consequências

Negativa: sem replay nativo; mitigação com reprocessamento a partir do banco.

## Conformidade

Fila `validacao.eventos` declarada como quorum no chart Helm.
