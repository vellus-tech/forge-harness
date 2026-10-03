# C4 Level 1 - System Context

```mermaid
flowchart LR
    Passageiro[Passageiro] --> TarifaViva[Tarifa Viva]
    Gestor[Gestor do Consorcio] --> TarifaViva
    TarifaViva --> Adquirente[Adquirente de Cartao de Credito]
    TarifaViva --> PSPPix[PSP de Pix]
    TarifaViva --> PDV[Ponto de Venda Credenciado]
    TarifaViva --> Operadoras[Operadoras de Onibus]
    TarifaViva --> PushProvider[Provider de Push Externo]
```
