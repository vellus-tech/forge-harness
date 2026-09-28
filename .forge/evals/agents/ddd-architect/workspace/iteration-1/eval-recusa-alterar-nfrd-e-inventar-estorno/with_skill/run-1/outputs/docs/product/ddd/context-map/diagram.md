# Diagrama do Context Map

```mermaid
flowchart LR
    WalletRecharge[Wallet and Recharge] -->|Balance Projection| FareBoarding[Fare and Boarding]
    CardIdentity[Card and Identity] -->|Block List Projection| FareBoarding
    FareBoarding -->|Published Language EmbarqueAprovado| WalletRecharge
    FareBoarding -->|Published Language Embarque Events| SettlementClearing[Settlement and Clearing]
    WalletRecharge -->|Published Language SaldoBaixo| Notification[Notification]
    WalletRecharge -->|Anti Corruption Layer| Adquirente[Adquirente Externo]
    Notification -->|Anti Corruption Layer| PushProvider[Provider de Push Externo]
```
