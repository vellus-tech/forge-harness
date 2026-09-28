# Solution Architecture Diagram

## 1. Objetivo

Mostrar como os módulos da solução Tarifa Viva se relacionam em alto nível.

## 2. Diagrama

```mermaid
flowchart TB
    subgraph External["Atores e Sistemas Externos"]
        Passageiro[Passageiro]
        Validador[Validador do Ônibus]
        Adquirente[Adquirente]
        Operadoras[Operadoras]
    end

    subgraph Application["Módulos da Aplicação"]
        ValidacaoApi[validacao-embarque-api + tarifacao-lib]
        RecargaApi[recarga-api]
        TokenAdapter[tokenizacao-cartao-adapter]
        CadastroApi[cadastro-passageiro-api]
        LiquidacaoWorker[liquidacao-operadoras-worker]
    end

    subgraph Data["Camada de Dados"]
        Postgres[(PostgreSQL por serviço)]
        Redis[(Redis)]
        Broker[RabbitMQ]
        S3[(Bucket S3)]
    end

    Validador --> ValidacaoApi
    Passageiro --> RecargaApi
    RecargaApi --> TokenAdapter
    TokenAdapter --> Adquirente
    ValidacaoApi --> Postgres
    ValidacaoApi --> Redis
    RecargaApi --> Postgres
    CadastroApi --> Postgres
    LiquidacaoWorker --> Postgres
    LiquidacaoWorker --> S3
    S3 --> Operadoras
    ValidacaoApi --> Broker
    RecargaApi --> Broker
    CadastroApi --> Broker
    Broker --> LiquidacaoWorker
    Broker --> ValidacaoApi
```

## 3. Observações

- `tarifacao-lib` é empacotada dentro de `validacao-embarque-api` e não aparece como nó de deploy próprio.
- Os cinco bounded contexts aprovados (Validação, Recarga, Tarifação, Liquidação, Cadastro) mapeiam para seis módulos; nenhuma fusão de contextos foi aplicada (ver `docs/product/modules/README.md`, seção 10, VAL-MOD-01).
- O módulo `relatorios-bi` pedido pela diretoria não está representado por falta de evidência documental (ver VAL-MOD-02).
