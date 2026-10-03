# ADR-0006: Transactional Outbox para publicação de eventos de validação no serviço `validacao`

- **Status:** Proposto (aguarda revisão de arquitetura de quinta-feira)
- **Data:** 2026-09-26
- **Autores:** @joana-lima

## Contexto e Problema

O serviço `validacao` grava a validação de embarque no PostgreSQL (ADR-0002) e, em seguida, publica o evento correspondente na fila `validacao.eventos` do RabbitMQ (ADR-0003), consumida pela compensação das operadoras. As duas operações não são atômicas: na semana de 2026-09-14 perdemos cerca de 1.200 eventos porque pods do serviço caíram entre o commit no PostgreSQL e o publish no RabbitMQ, deixando o evento gravado no banco mas nunca publicado. A compensação das operadoras ficou divergente do estado real de validações, exigindo reconciliação manual. Precisamos de uma forma de garantir que todo commit de validação resulte, eventualmente, na publicação do evento correspondente — sem depender da janela entre duas chamadas de sistemas distintos.

## Opções Consideradas

1. **Transactional Outbox** — grava o evento em uma tabela `outbox` dentro da mesma transação PostgreSQL do commit de validação; um processo relay (poller ou baseado em `LISTEN/NOTIFY`) lê a tabela e publica no RabbitMQ, marcando o registro como enviado. Prós: atomicidade garantida pela própria transação do banco já usado (ADR-0002); não exige infraestrutura nova, só uma tabela e um relay simples. Contras: introduz uma tabela e um processo adicional para operar; publicação passa a ser assíncrona em relação ao commit (latência do poller); exige consumidores idempotentes, o que já é mandatório pela ADR-0004.

2. **CDC com Debezium lendo o WAL do PostgreSQL** — captura mudanças direto do write-ahead log e publica os eventos sem alteração no código da aplicação. Prós: nenhuma mudança no serviço `validacao`; replicação nativa do banco. Contras: exige operar Kafka Connect/Debezium, stack que o time não opera hoje; o evento de domínio publicado corresponderia à linha da tabela, não à semântica de negócio, exigindo uma camada de tradução; maior custo operacional para o volume atual do que o problema justifica.

3. **Publish-antes-do-commit com retentativa** — publica o evento no RabbitMQ antes de commitar a transação no PostgreSQL, com retry em caso de falha. Prós: simples de implementar, sem tabela nova. Contras: não resolve a falta de atomicidade, apenas a desloca — uma transação que falha ou sofre rollback após o publish gera evento para uma validação que nunca existiu, o que é pior para a divergência das operadoras do que o problema atual; retry de publish sem outbox ainda pode perder eventos se o pod cair entre o publish e o commit.

## Decisão

Adotar o padrão Transactional Outbox no serviço `validacao`: o evento de validação é gravado em uma tabela `outbox` na mesma transação do commit de domínio, e um relay dedicado publica os registros pendentes na fila `validacao.eventos` (RabbitMQ, ADR-0003), marcando-os como entregues após confirmação do broker.

Esta é uma proposta de @joana-lima, ainda não aprovada — segue para a revisão de arquitetura de quinta-feira antes de avançar para desenho detalhado e implementação.

## Consequências

Positiva: elimina a janela de perda de eventos entre commit e publish, já que ambos passam a depender de uma única transação do PostgreSQL.

Negativa: adiciona uma tabela `outbox` e um processo relay ao serviço `validacao`, com latência entre o commit e a publicação efetiva (dependente do intervalo do poller). Mitigação: dimensionar o intervalo do poller para a tolerância de latência da compensação e monitorar o atraso via OpenTelemetry (ADR-0005).

Negativa: a tabela `outbox` cresce indefinidamente sem rotina de purge. Mitigação: job de limpeza dos registros já entregues, com retenção definida em desenho detalhado.

Negativa: o padrão é at-least-once — reentregas são possíveis em caso de falha do relay após publish e antes de marcar como entregue. Mitigação: já coberta pela ADR-0004 (idempotência obrigatória nos consumidores de eventos).

## Conformidade

Métrica de atraso do relay (idade do registro pendente mais antigo na tabela `outbox`) exportada via OpenTelemetry (ADR-0005), com alerta acima do limiar definido no desenho detalhado.
