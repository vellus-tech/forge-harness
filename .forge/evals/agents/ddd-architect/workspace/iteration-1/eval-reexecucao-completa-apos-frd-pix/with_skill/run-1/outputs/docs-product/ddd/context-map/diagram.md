# Diagrama do Context Map

```mermaid
flowchart LR
    FareValidation[Fare Validation] -->|Customer Supplier| CardWallet[Card Wallet]
    FareValidation -->|Published Language| OperatorClearing[Operator Clearing]
    CardWallet -->|Open Host Service| IdentityAccess[Identity Access]
    CardWallet -->|Published Language| Notification[Notification adapter]
    CardWallet -->|Anti Corruption Layer| Acquirer[Adquirente Cartao Credito]
    CardWallet -->|Anti Corruption Layer| PixPSP[PSP Pix]
    OperatorClearing -->|Open Host Service| Operators[Sistemas das Operadoras]
```
