# C4 Level 2 - Container Diagram

```mermaid
flowchart LR
    App[App do Passageiro] --> FareValidationMS[fare-validation-ms]
    Validator[Validador Offline] --> FareValidationMS
    App --> CardWalletMS[card-wallet-ms]
    POSTerminal[Terminal do Ponto de Venda] --> CardWalletMS
    App --> IdentityAccessMS[identity-access-ms]
    FareValidationMS --> CardWalletMS
    FareValidationMS --> ClearingBus[(Event Bus)]
    ClearingBus --> OperatorClearingMS[operator-clearing-ms]
    CardWalletMS --> Acquirer[Adquirente Cartao Credito]
    CardWalletMS --> PixPSP[PSP Pix]
    CardWalletMS --> WalletDb[(card-wallet DB)]
    FareValidationMS --> BoardingDb[(fare-validation DB)]
    OperatorClearingMS --> ClearingDb[(operator-clearing DB)]
    IdentityAccessMS --> IdentityDb[(identity-access DB)]
    OperatorClearingMS --> Operators[Sistemas das Operadoras]
```

O `card-wallet-ms` ganha, na v1.1, uma nova integração de saída com o PSP Pix (via webhook), sem alterar os demais containers. A comunicação entre `fare-validation-ms` e `operator-clearing-ms` permanece assíncrona via barramento de eventos.
