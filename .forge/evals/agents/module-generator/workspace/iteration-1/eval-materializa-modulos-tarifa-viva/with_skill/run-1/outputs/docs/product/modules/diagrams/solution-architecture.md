# Solution Architecture Diagram

## 1. Objetivo

Mostrar como os módulos da solução Tarifa Viva se relacionam em alto nível, incluindo a fronteira de segurança do CDE (PCI DSS).

## 2. Diagrama

```mermaid
flowchart TB
    subgraph External["Atores e Sistemas Externos"]
        App[App do Passageiro]
        Validador[Validador de Bordo]
        Adquirente[Adquirente de Pagamento]
        Operadoras[Operadoras: Aurora, TransVale, Expresso Sol]
    end

    subgraph CoreModules["Modulos Nucleo"]
        Validacao[validacao-embarque-api]
        TarifaLib[tarifacao-lib]
        Recarga[recarga-api]
        Cadastro[cadastro-passageiro-api]
        Liquidacao[liquidacao-operadoras-worker]
    end

    subgraph CDE["CDE - Fora do escopo geral, dentro do PCI"]
        Token[tokenizacao-cartao-adapter]
    end

    subgraph Data["Camada de Dados e Mensageria"]
        PgValidacao[(PostgreSQL - Validacao)]
        PgRecarga[(PostgreSQL - Recarga)]
        PgCadastro[(PostgreSQL - Cadastro)]
        PgLiquidacao[(PostgreSQL - Liquidacao)]
        Redis[(Redis - Lista de Bloqueio)]
        Broker[RabbitMQ - tarifa-viva.eventos]
        S3[(Bucket S3 - Arquivos CNAB)]
    end

    Validador --> Validacao
    App --> Recarga
    Validacao --> TarifaLib
    Validacao --> PgValidacao
    Validacao --> Redis
    Validacao --> Broker

    Recarga --> Token
    Recarga --> PgRecarga
    Recarga --> Broker
    Token --> Adquirente

    Cadastro --> PgCadastro
    Cadastro --> Broker

    Broker --> Liquidacao
    Liquidacao --> PgLiquidacao
    Liquidacao --> S3
    S3 --> Operadoras
```

## 3. Observações

- O `tokenizacao-cartao-adapter` é o único módulo dentro do CDE (Cardholder Data Environment); todos os demais módulos operam fora do escopo PCI DSS, recebendo apenas token quando necessário.
- Não há frontend/BFF documentado no Solution Module Map além do "App do Passageiro" citado no PRD/FRD como ator externo — ver VAL-MOD-01 em `docs/product/modules/README.md`.
- RabbitMQ, PostgreSQL por serviço e Redis são infraestrutura compartilhada conforme o TRD; não foram modelados como módulos próprios (ver VAL-MOD-02).
