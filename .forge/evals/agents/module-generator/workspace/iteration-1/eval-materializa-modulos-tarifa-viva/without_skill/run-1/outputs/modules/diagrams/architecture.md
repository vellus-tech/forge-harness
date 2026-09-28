# Diagrama de Arquitetura — Tarifa Viva

Deployables candidatos (DDD §5) e onde cada um se encaixa na infraestrutura descrita no TRD: serviços em Go, gRPC interno, REST externo, RabbitMQ para eventos, PostgreSQL por serviço, Redis como cache no validador, e o CronJob de liquidação gerando arquivo CNAB em S3.

```mermaid
flowchart TB
    subgraph externo["Externo"]
        app["App do passageiro"]
        validador["Validador físico (ônibus)"]
        adquirente["Adquirente (gateway REST)"]
        operadoras["Operadoras (Aurora, TransVale, Expresso Sol)"]
    end

    subgraph cde["CDE — escopo PCI DSS 4.0.1"]
        tok["tokenizacao-cartao-adapter (Adapter)"]
    end

    subgraph tarifaviva["Tarifa Viva"]
        val["validacao-embarque-api (Microservice)<br/>+ tarifacao-lib embarcada (Shared Kernel)"]
        rec["recarga-api (Microservice)"]
        liq["liquidacao-operadoras-worker (CronJob)"]
        cad["cadastro-passageiro-api (Microservice)<br/>escopo LGPD"]
        pgVal[("PostgreSQL: viagens, cartoes_transporte")]
        redisVal[("Redis: cache lista de bloqueio")]
        pgRec[("PostgreSQL: pedidos_recarga<br/>(token_cartao, ultimos4)")]
        pgLiq[("PostgreSQL: lotes_liquidacao")]
        pgCad[("PostgreSQL: passageiros<br/>(cpf, data_nascimento, comprovante)")]
        mq[["RabbitMQ: tarifa-viva.eventos"]]
        s3[("S3: arquivo CNAB")]
    end

    validador -->|"REST: POST /v1/validacoes"| val
    app -->|"REST: POST /v1/recargas"| rec
    app -->|"REST: GET /v1/passageiros/{id}"| cad
    rec -->|"gRPC interno"| tok
    tok -->|"REST"| adquirente

    val --- pgVal
    val --- redisVal
    rec --- pgRec
    liq --- pgLiq
    cad --- pgCad
    liq --- s3

    val -->|publica EmbarqueValidado| mq
    rec -->|publica RecargaConfirmada / RecargaEstornada| mq
    cad -->|publica PassageiroElegivelAtualizado| mq
    mq -->|consome| liq
    mq -->|consome| val

    liq -->|"arquivo CNAB diário 02:00"| operadoras

    style cde fill:#f8d7da,stroke:#c0392b,stroke-width:2px
    style pgRec fill:#fdebd0
    style pgCad fill:#fdebd0
```

## Leitura

- O retângulo vermelho é o **CDE** (Cardholder Data Environment): só `tokenizacao-cartao-adapter` manipula PAN/CVV, isolado por uma chamada gRPC de `recarga-api`.
- As duas tabelas em destaque (`pedidos_recarga` e `passageiros`) concentram, respectivamente, o recorte PCI (token de cartão) e o recorte LGPD (CPF, data de nascimento, comprovante).
- `tarifacao-lib` não aparece como caixa própria porque roda embarcada no processo de `validacao-embarque-api` (Shared Kernel, sem deploy nem rede própria).
