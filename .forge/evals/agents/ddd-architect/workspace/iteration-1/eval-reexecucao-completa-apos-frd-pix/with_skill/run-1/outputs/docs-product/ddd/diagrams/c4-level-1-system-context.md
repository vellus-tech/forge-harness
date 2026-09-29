# C4 Level 1 - System Context

```mermaid
flowchart LR
    Passenger[Passageiro] --> TarifaViva[Tarifa Viva]
    POS[Ponto de Venda Credenciado] --> TarifaViva
    Manager[Gestor do Consorcio] --> TarifaViva
    TarifaViva --> Acquirer[Adquirente Cartao Credito]
    TarifaViva --> PixPSP[PSP Pix]
    TarifaViva --> Operators[Sistemas das Operadoras]
    TarifaViva --> AuditBody[Orgao Gestor Auditoria]
```

O sistema Tarifa Viva atende passageiros (embarque, recarga inclusive via Pix, consulta de saldo), pontos de venda credenciados (recarga em dinheiro) e gestores do consórcio (bloqueio de cartão, ajustes de clearing). Depende externamente do adquirente de cartão de crédito, do PSP Pix (novo na v1.1 — FR-10) e publica arquivos de repasse para as operadoras.
