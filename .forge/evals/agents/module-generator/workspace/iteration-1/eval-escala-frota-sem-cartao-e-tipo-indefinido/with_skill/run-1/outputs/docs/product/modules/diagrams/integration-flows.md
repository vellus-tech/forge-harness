# Integration Flows

## 1. Objetivo

Documentar os principais fluxos de integração entre os módulos do Frota Certa e os sistemas externos.

## 2. Fluxo - Montagem e Bloqueio de Escala

```mermaid
sequenceDiagram
    participant Desp as Despachante
    participant Painel as painel-despachante-web
    participant Esc as escalas-api
    participant Jor as jornada-api

    Desp->>Painel: Monta escala do dia seguinte
    Painel->>Esc: Envia montagem de escala
    Esc-->>Esc: Verifica turnos contra JornadaExcedida ja conhecida
    Esc-->>Painel: Escala montada ou bloqueio por jornada excedida
    Painel-->>Desp: Exibe resultado
```

## 3. Fluxo - Publicação da Escala Fechada

```mermaid
sequenceDiagram
    participant Cron as Scheduler as 18:00
    participant Pub as publicador-escala-worker
    participant Esc as escalas-api
    participant Catraca as Sistema de Catraca as External
    participant Notif as notificacao-motoristas

    Cron->>Pub: Dispara as 18:00
    Pub->>Esc: Le escala fechada do dia
    Esc-->>Pub: Escala fechada
    Pub->>Catraca: Publica escala
    Catraca-->>Pub: Confirmacao
    Pub-->>Notif: EscalaPublicada as evento
```

## 4. Fluxo - Notificação de Mudança de Escala

```mermaid
sequenceDiagram
    participant Esc as escalas-api
    participant Notif as notificacao-motoristas
    participant Jor as jornada-api
    participant Prov as Provedor de SMS ou Push
    participant Mot as Motorista

    Esc-->>Notif: EscalaAlterada as evento
    Notif->>Jor: Obtem telefone do motorista
    Jor-->>Notif: Telefone
    Notif->>Prov: Envia SMS ou push
    Prov-->>Mot: Notificacao entregue
```

## 5. Regras do Fluxo

| Regra | Descrição |
|---|---|
| Bloqueio antes da publicação | Nenhum turno que exceda 10h diárias pode chegar ao fechamento da escala (FR-04) |
| Janela de publicação | A publicação da escala fechada não pode atrasar mais de 10 min além de 18:00 (NFR-02) |
| Minimização de PII em trânsito | O telefone do motorista só deve trafegar entre jornada-api e notificacao-motoristas no momento do envio, sem replicação persistente (Ponto a Validar, VAL-JOR-01) |

## 6. Pontos de Falha

| Ponto | Tratamento Esperado |
|---|---|
| Escala não fecha a tempo em escalas-api | publicador-escala-worker não tem o que publicar às 18:00; alertar operação (RISK-MOD-02 de publicador-escala-worker) |
| Sistema de catraca indisponível às 18:00 | Retry com backoff e alerta imediato (RISK-MOD-01 de publicador-escala-worker) |
| Provedor de SMS/push indisponível | Retry e fila de reenvio (Ponto a Validar quanto à estratégia exata) |
