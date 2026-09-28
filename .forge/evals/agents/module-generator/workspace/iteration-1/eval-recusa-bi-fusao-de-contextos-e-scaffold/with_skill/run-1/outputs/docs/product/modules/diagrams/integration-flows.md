# Integration Flows

## 1. Objetivo

Documentar os principais fluxos de integração entre módulos e sistemas externos da solução Tarifa Viva.

## 2. Fluxo - Validação de Embarque

```mermaid
sequenceDiagram
    participant V as Validador do Ônibus
    participant M as validacao-embarque-api
    participant T as tarifacao-lib
    participant B as RabbitMQ

    V->>M: POST /v1/validacoes
    M->>T: Calcular tarifa vigente
    T-->>M: Valor da tarifa
    M->>M: Debitar saldo
    M->>B: Publica EmbarqueValidado
    M-->>V: Resultado
```

## 3. Fluxo - Recarga com Tokenização

```mermaid
sequenceDiagram
    participant App as App do Passageiro
    participant R as recarga-api
    participant T as tokenizacao-cartao-adapter
    participant Adq as Adquirente

    App->>R: POST /v1/recargas
    R->>T: Solicitar tokenização/autorização
    T->>Adq: Autorizar cartão
    Adq-->>T: Resultado
    T-->>R: Token + resultado
    R->>R: Confirmar ou agendar estorno em até 24 h
    R-->>App: Resultado da recarga
```

## 4. Fluxo - Liquidação Diária

```mermaid
sequenceDiagram
    participant V as validacao-embarque-api
    participant L as liquidacao-operadoras-worker
    participant Op as Operadoras

    V->>L: Publica EmbarqueValidado (contínuo)
    L->>L: Acumula lote do dia
    L->>L: Fecha lote às 02:00
    L->>Op: Gera arquivo CNAB em S3
```

## 5. Regras do Fluxo

| Regra | Descrição |
|---|---|
| Nenhum PAN fora do CDE | Apenas tokenizacao-cartao-adapter recebe PAN; demais módulos só recebem token (NFR-02) |
| Reprodutibilidade do lote | O lote diário deve ser reproduzível a partir dos eventos EmbarqueValidado (NFR-04) |
| Janela de integração | Embarques dentro de 60 min não geram nova cobrança integral (FR-04) |

## 6. Pontos de Falha

| Ponto | Tratamento Esperado |
|---|---|
| Falha de confirmação da adquirente em até 24 h | Estorno automático (FR-03) |
| Validador offline por mais de 4 h | Ponto a Validar — política de expiração da lista de bloqueio (VAL-DDD-03) |
| Falha no fechamento do lote às 02:00 | Ponto a Validar — runbook de reprocessamento não definido |
