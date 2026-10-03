# ADR-0006: Transactional Outbox no serviço `validacao` para publicação de eventos no RabbitMQ

- **Status:** Proposto
- **Data:** 2026-09-26
- **Autores:** @joana-lima

## Contexto e Problema

O serviço `validacao` grava o resultado da validação de embarque no PostgreSQL e, em seguida, publica o evento correspondente na fila `validacao.eventos` no RabbitMQ (decisão registrada em ADR-0003). Esses dois passos não são atômicos: na semana anterior a esta proposta, pods do serviço caíram entre o commit no PostgreSQL e o publish na fila, perdendo cerca de 1.200 eventos de validação. Como a compensação das operadoras depende desses eventos, o resultado foi divergência nos valores compensados. A proposta é da @joana-lima e será discutida na revisão de arquitetura de quinta-feira; ainda não foi aprovada.

## Opções Consideradas

1. **Transactional Outbox** — grava o evento em uma tabela `outbox` na mesma transação PostgreSQL da validação, e um publicador separado lê a tabela e publica no RabbitMQ com confirmação. Contra: exige tabela extra, processo publicador e limpeza/retention da tabela outbox.
2. **CDC com Debezium lendo o WAL do PostgreSQL** — captura mudanças diretamente do log de replicação e publica no RabbitMQ (ou em um tópico intermediário) sem alterar o código da aplicação. Contra: adiciona um componente de infraestrutura (Kafka Connect/Debezium) novo ao stack, aumentando a superfície operacional e a curva de aprendizado da equipe.
3. **Publish antes do commit, com retentativa** — publica no RabbitMQ primeiro e só então comita no PostgreSQL, reprocessando em caso de falha. Contra: inverte o problema para duplicidade (mensagem publicada sem commit correspondente) e exige idempotência mais rigorosa nos consumidores; não elimina a janela de inconsistência, apenas troca o lado que pode falhar.

## Decisão

Adotar o padrão Transactional Outbox no serviço `validacao`: o evento de validação é gravado em uma tabela `outbox` na mesma transação PostgreSQL que grava o resultado da validação, garantindo atomicidade entre os dois. Um processo publicador (polling ou baseado em trigger) lê a tabela `outbox` e publica os eventos pendentes na fila `validacao.eventos`, marcando-os como publicados após confirmação (ack) do RabbitMQ.

Esta decisão ainda não foi aprovada — segue para a revisão de arquitetura de quinta-feira.

## Consequências

Positiva: elimina a perda de eventos por queda de pod entre commit e publish, já que o evento só é considerado perdido se a transação PostgreSQL falhar (caso em que a validação também não existe).

Negativa: introduz um processo publicador adicional e uma tabela de outbox que precisa de limpeza/retention; a entrega passa a ser at-least-once, exigindo idempotência nos consumidores (já coberta por ADR-0004).

Negativa: aumento de latência entre a gravação da validação e a publicação do evento, proporcional ao intervalo de polling do publicador (ou ao lag do mecanismo escolhido).

## Conformidade

A validar na implementação: teste de integração que derruba o processo publicador entre a gravação na tabela `outbox` e a publicação, e confirma que o evento é publicado após o restart, sem duplicidade observável pelo consumidor (dado ADR-0004).
