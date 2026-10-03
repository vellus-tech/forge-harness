# Integration Flows

## 1. Objetivo

Documentar os principais fluxos de integração entre módulos e sistemas externos da Tarifa Viva.

## 2. Fluxo - Validação de Embarque

```mermaid
sequenceDiagram
    participant V as Validador de Bordo
    participant M as validacao-embarque-api
    participant T as tarifacao-lib
    participant B as RabbitMQ
    participant L as liquidacao-operadoras-worker

    V->>M: POST /v1/validacoes
    M->>T: Calcular tarifa vigente
    T-->>M: Valor da tarifa
    M->>M: Debitar saldo do cartao transporte
    M->>B: Publica EmbarqueValidado
    B->>L: Entrega evento para consolidacao do lote
    M-->>V: Resultado da validacao
```

## 3. Fluxo - Recarga de Saldo com Cartão

```mermaid
sequenceDiagram
    participant App as App do Passageiro
    participant R as recarga-api
    participant T as tokenizacao-cartao-adapter
    participant A as Adquirente
    participant B as RabbitMQ
    participant M as validacao-embarque-api

    App->>R: POST /v1/recargas
    R->>T: Solicitar tokenizacao e autorizacao (PAN via canal seguro)
    T->>A: Autorizar cobranca com token
    A-->>T: Resultado da autorizacao
    T-->>R: Token e resultado (sem PAN)
    R->>B: Publica RecargaConfirmada ou RecargaEstornada
    B->>M: Atualiza saldo disponivel
    R-->>App: Resultado do pedido
```

## 4. Fluxo - Liquidação Diária com Operadoras

```mermaid
sequenceDiagram
    participant V as validacao-embarque-api
    participant B as RabbitMQ
    participant L as liquidacao-operadoras-worker
    participant S as Bucket S3
    participant O as Operadoras

    V->>B: Publica EmbarqueValidado (ao longo do dia)
    B->>L: Entrega eventos acumulados
    L->>L: Fecha lote as 02:00
    L->>S: Publica arquivo CNAB por operadora
    S-->>O: Disponibiliza repasse D+1
    L->>B: Publica LoteLiquidacaoFechado
```

## 5. Regras do Fluxo

| Regra | Descrição |
|---|---|
| Nunca propagar PAN | Apenas o tokenizacao-cartao-adapter recebe e processa o PAN; os demais módulos trabalham só com token (NFR-02) |
| Reprodutibilidade do lote | O lote de liquidação deve poder ser reconstruído a partir dos eventos EmbarqueValidado (NFR-04) |
| Estorno automático | Recarga não confirmada pela adquirente em até 24 h deve gerar RecargaEstornada (FR-03) |
| Operação offline | O validador de bordo pode operar offline por até 4 h, sincronizando lista de bloqueio depois (NFR-01) |

## 6. Pontos de Falha

| Ponto | Tratamento Esperado |
|---|---|
| Indisponibilidade da adquirente | Timeout com retry controlado; recarga não confirmada segue para estorno automático em 24 h |
| Falha na publicação de EmbarqueValidado | Publicação transacional/outbox com reprocessamento, para não quebrar a reprodutibilidade exigida por NFR-04 |
| Falha no CronJob de liquidação às 02:00 | Alerta imediato e reprocessamento manual/automático do fechamento do lote |
| Perda de conectividade do validador offline | Operação local até 4 h com sincronização posterior da lista de bloqueio (frequência a definir, VAL-MOD-04) |
