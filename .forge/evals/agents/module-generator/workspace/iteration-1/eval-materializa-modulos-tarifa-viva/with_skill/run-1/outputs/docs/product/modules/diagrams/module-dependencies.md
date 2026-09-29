# Module Dependencies Diagram

## 1. Objetivo

Mostrar as dependências diretas e indiretas entre os módulos da solução Tarifa Viva.

## 2. Diagrama

```mermaid
flowchart LR
    Validacao[validacao-embarque-api] -->|Package| TarifaLib[tarifacao-lib]
    Recarga[recarga-api] -->|gRPC| Token[tokenizacao-cartao-adapter]
    Recarga -->|Publica RecargaConfirmada/Estornada| Broker[RabbitMQ]
    Broker -->|Consome| Validacao
    Cadastro[cadastro-passageiro-api] -->|Publica PassageiroElegivelAtualizado| Broker
    Validacao -->|Publica EmbarqueValidado| Broker
    Broker -->|Consome| Liquidacao[liquidacao-operadoras-worker]
    Token -->|Chama| Adquirente[Adquirente Externa]
    Liquidacao -->|Gera arquivo| S3[(Bucket S3)]
```

## 3. Matriz de Dependências

| Origem | Destino | Tipo | Obrigatória? | Observação |
|---|---|---|---|---|
| validacao-embarque-api | tarifacao-lib | Package | Sim | Cálculo de tarifa embarcado no mesmo deployable |
| recarga-api | tokenizacao-cartao-adapter | Síncrona (gRPC) | Sim | Nunca envia PAN, apenas dados necessários à tokenização |
| recarga-api | RabbitMQ (validacao-embarque-api) | Assíncrona | Sim | RecargaConfirmada/RecargaEstornada |
| cadastro-passageiro-api | RabbitMQ (validacao-embarque-api / tarifacao-lib) | Assíncrona | Sim | PassageiroElegivelAtualizado |
| validacao-embarque-api | RabbitMQ (liquidacao-operadoras-worker) | Assíncrona | Sim | EmbarqueValidado |
| tokenizacao-cartao-adapter | Adquirente (externa) | Externa | Sim | Autorização de pagamento |
| liquidacao-operadoras-worker | Bucket S3 | Dados | Sim | Publicação do arquivo CNAB |
