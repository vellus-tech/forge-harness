# Design — card-wallet

Clean Architecture em .NET 8 (Domain / Application / Infrastructure / Api). Agregado `Wallet` com invariante de saldo não negativo; `LedgerEntry` imutável (crédito/débito). Integração com PSP Pix via adaptador `IPixGateway`; webhook validado por assinatura HMAC. Persistência no schema `wallet` do postgres-main via EF Core com migrations versionadas. Evento `WalletDebited` publicado via outbox transacional no RabbitMQ.
