# C4 Level 2 — Container Diagram — Tarifa Viva

```mermaid
flowchart TB
    Passenger[Passageiro] --> PassengerApp[Passenger App]
    Manager[Gestor do Consorcio] --> BackofficeWeb[Consortium Backoffice Web]

    PassengerApp -->|REST| IdentityService[identity-service]
    PassengerApp -->|REST| RechargeService[recharge-service]
    PassengerApp -->|REST| WalletService[passenger-wallet-service]
    PassengerApp -->|REST| FareService[fare-collection-service]

    BackofficeWeb -->|REST| WalletService
    BackofficeWeb -->|REST| SettlementService[settlement-service]

    ValidaBus[Firmware ValidaBus] -->|Protocolo proprietario| FareService
    FareService -->|gRPC interno| WalletService
    FareService -->|gRPC interno| SettlementService
    RechargeService -->|gRPC interno| WalletService
    WalletService -->|Fila RabbitMQ| NotificationWorker[notification-worker]

    RechargeService -->|REST| Acquirer[Adquirente de Cartao]
    RechargeService -->|REST| PixPsp[PSP de Pix]
    PosNetwork[Ponto de Venda Credenciado] -->|REST| RechargeService

    SettlementService -->|Arquivo/REST| Operators[Operadoras do Consorcio]
    NotificationWorker -->|REST| Fcm[Firebase Cloud Messaging]

    FareService --> FareDb[(PostgreSQL fare-collection)]
    WalletService --> WalletDb[(PostgreSQL passenger-wallet)]
    RechargeService --> RechargeDb[(PostgreSQL recharge)]
    SettlementService --> SettlementDb[(PostgreSQL settlement)]
    IdentityService --> IdentityDb[(PostgreSQL identity)]
```

## Descrição

Comunicação interna entre os serviços da Tarifa Viva é **gRPC** (TEC-01); a superfície externa (app, backoffice, adquirente, Pix, ponto de venda, operadoras, FCM) é **REST** ou arquivo. Eventos assíncronos internos (ex.: `BalanceLow` para o `notification-worker`) trafegam por **fila RabbitMQ** (TEC-02). Cada serviço possui seu próprio schema **PostgreSQL** — não há banco compartilhado entre bounded contexts.
