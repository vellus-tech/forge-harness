# Tasks — operator-clearing (DRAFT, estimado manualmente a partir do design.md)

> Este arquivo NÃO substitui a saída normal do tasks-writer. Foi produzido porque o usuário pediu explicitamente uma estimativa para não atrasar a sprint review de sexta, dado que o tasks-writer ainda não rodou neste módulo. Cada task abaixo cita a frase do design ou do requirement de onde veio, para que a revisão técnica possa checar rápido se a leitura foi correta.

| TASK | Descrição | Tipo | RF | Depende de | Origem no design/requirements |
|---|---|---|---|---|---|
| OC-TASK-01 | Scaffold do job batch .NET 8 como CronJob Kubernetes, schema `clearing`, migrations (`settlement_period`, `operator_share`) | infra | — | — | "Job batch .NET 8 agendado (CronJob Kubernetes)"; README lista schema `clearing` com essas duas tabelas |
| OC-TASK-02 | Read model replicado de `FareCharged` consolidado a partir do schema `validation` | feature | RF-008 | OC-TASK-01, fare-validation TASK-04 (publica `FareCharged`) | "lê `FareCharged` consolidados do schema `validation` via read model replicado" |
| OC-TASK-03 | Cálculo da cota por operadora e persistência em `clearing.operator_share` | feature | RF-008 | OC-TASK-02 | "calcula a cota por operadora e persiste em `clearing.operator_share`"; RF-008 pede repartição proporcional aos trechos integrados |
| OC-TASK-04 | Adaptador `ISettlementFileWriter` e gerador de arquivo CNAB 240 | feature | RF-009 | OC-TASK-03 | "Gerador CNAB 240 isolado em adaptador `ISettlementFileWriter`"; RF-009 pede CNAB 240 com uma linha por operadora |
| OC-TASK-05 | Job/trigger do fechamento diário às 02:00, com opção de disparo manual para reprocessamento | feature | RF-008 | OC-TASK-03 | RF-008: "quero fechar o período às 02:00" — o design não detalha o agendador além do CronJob, então o horário exato e o trigger manual são inferência minha, não estão explícitos no design |
| OC-TASK-06 | Testes de integração do fechamento (soma da cota = receita do período) e da geração do CNAB | test | RF-008, RF-009 | OC-TASK-04, OC-TASK-05 | critérios de aceite de RF-008 ("soma proporcional") e RF-009 ("soma igual à receita do período") |

## O que ficou sem cobertura clara e precisa de decisão humana

- **Reprocessamento/correção de período já fechado**: nem requirements nem design falam de retificação se um embarque chegar atrasado depois do fechamento. Não criei task para isso porque seria pura invenção meu; sinalizo como gap a esclarecer com o time de negócio.
- **Formato exato do CNAB 240 e dados cadastrais do banco liquidante** (agência, convênio, layout de segmento): o design só diz "CNAB 240"; a task OC-TASK-04 vai precisar de especificação adicional de integração bancária antes de virar código, provavelmente uma sub-task ou um requirement adicional.
- **Timeout/observabilidade do CronJob**: card-wallet e fare-validation têm task explícita de OpenTelemetry (FV-TASK-07); operator-clearing não tem equivalente no design, então não estimei — pode ser um item esquecido ou proposital (job noturno, sem SLA de latência).

## Recomendação

Tratar este arquivo como insumo para uma sessão curta de tasks-writer (ou revisão técnica equivalente) antes de comprometer prazos de operator-clearing no Jira. Ele é suficiente para dar visibilidade de escopo na reunião de sexta, mas não para virar compromisso de sprint sem revisão.
