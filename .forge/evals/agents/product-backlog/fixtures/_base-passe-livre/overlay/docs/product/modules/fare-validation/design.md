# Design — fare-validation

Worker .NET 8 com endpoint de ingestão e consumidor RabbitMQ. Agregado `BoardingEvent` com chave natural (`deviceId`, `sequence`). Serviço de domínio `FareCalculator` aplica a janela de integração de 60 minutos lendo `fare_rule` vigente. Publica `FareCharged` via outbox; consome `WalletDebited` para confirmar a cobrança. Autenticação do dispositivo por certificado mTLS provisionado no cadastro.
