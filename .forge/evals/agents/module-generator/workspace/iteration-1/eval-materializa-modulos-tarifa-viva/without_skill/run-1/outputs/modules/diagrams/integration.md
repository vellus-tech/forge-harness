# Diagrama de Integração — Tarifa Viva

Sequência dos três fluxos críticos do FRD: embarque (FR-01), recarga com estorno (FR-02/FR-03) e liquidação diária (FR-05), incluindo os pontos externos (adquirente e operadoras).

```mermaid
sequenceDiagram
    participant App as App do passageiro
    participant Validador as Validador (ônibus)
    participant Val as validacao-embarque-api
    participant Tar as tarifacao-lib
    participant Rec as recarga-api
    participant Tok as tokenizacao-cartao-adapter
    participant Adq as Adquirente (externo)
    participant Cad as cadastro-passageiro-api
    participant MQ as RabbitMQ (tarifa-viva.eventos)
    participant Liq as liquidacao-operadoras-worker
    participant Op as Operadoras (externo)

    Note over App,Op: Fluxo 1 — Embarque (FR-01, NFR-01)
    Validador->>Val: POST /v1/validacoes (cartão ou QR)
    Val->>Tar: calcula tarifa (embarcado, sem rede)
    Cad-->>MQ: PassageiroElegivelAtualizado (assíncrono, prévio)
    MQ-->>Tar: elegibilidade (gratuidade/meia-tarifa)
    Val-->>Validador: embarque validado (p99 < 300 ms)
    Val->>MQ: publica EmbarqueValidado

    Note over App,Op: Fluxo 2 — Recarga com cartão (FR-02, FR-03, NFR-02)
    App->>Rec: POST /v1/recargas
    Rec->>Tok: tokeniza + autoriza (gRPC, PAN só aqui)
    Tok->>Adq: autorização (REST)
    Adq-->>Tok: aprovado / negado
    Tok-->>Rec: token + últimos 4 dígitos (nunca PAN)
    alt aprovado
        Rec->>MQ: publica RecargaConfirmada
        MQ-->>Val: atualiza saldo do cartão transporte
    else não confirmado em até 24h
        Rec->>MQ: publica RecargaEstornada
        MQ-->>Val: reverte saldo
    end

    Note over App,Op: Fluxo 3 — Liquidação diária (FR-05, NFR-04)
    MQ-->>Liq: consome EmbarqueValidado (contínuo, durante o dia)
    Liq->>Liq: fecha lote às 02:00 (reprodutível a partir dos eventos)
    Liq->>Op: arquivo CNAB por operadora (S3)
```

## Leitura

- O fluxo de embarque depende de `tarifacao-lib` já ter recebido a elegibilidade do passageiro antes do momento da validação — por isso o consumo de `PassageiroElegivelAtualizado` é assíncrono e prévio, não uma chamada síncrona no caminho crítico dos 300 ms.
- No fluxo de recarga, o PAN nunca sai do trecho `App → recarga-api → tokenizacao-cartao-adapter → Adquirente`; a partir da resposta da adquirente, tudo que circula internamente é token.
- O estorno (FR-03) reusa o mesmo canal de eventos (`RecargaEstornada`) que a confirmação, dando a `validacao-embarque-api` uma única forma de saber o estado do saldo — sem chamada direta a `recarga-api`.
- A liquidação nunca consulta `validacao-embarque-api` diretamente: reconstrói o lote inteiramente a partir dos eventos `EmbarqueValidado` já publicados, o que satisfaz o requisito de auditabilidade (NFR-04).
