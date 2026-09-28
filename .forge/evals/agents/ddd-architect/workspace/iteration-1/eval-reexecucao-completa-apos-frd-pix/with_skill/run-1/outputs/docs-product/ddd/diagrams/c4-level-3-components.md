# C4 Level 3 - Component Diagram (card-wallet-ms)

Prioridade neste nível: `card-wallet-ms`, por concentrar a mudança da v1.1 (FR-10, recarga via Pix) e por ser o contexto com maior número de integrações externas assíncronas.

```mermaid
flowchart TB
    subgraph CardWalletMS[card-wallet-ms]
        CreditUC[CreditBalanceUseCase]
        AppRechargeUC[RequestAppRechargeUseCase]
        POSRechargeUC[RegisterPOSRechargeUseCase]
        PixGenerateUC[GeneratePixChargeUseCase]
        PixConfirmUC[ConfirmPixSettlementUseCase]
        BlockUC[BlockCardUseCase]
        BalanceRepo[CardBalanceRepository]
        AcquirerAdapter[AcquirerAdapter ACL]
        PixAdapter[PixPSPAdapter ACL]
    end
    AppRechargeUC --> AcquirerAdapter
    AcquirerAdapter --> CreditUC
    POSRechargeUC --> CreditUC
    PixGenerateUC --> BalanceRepo
    PixAdapter --> PixConfirmUC
    PixConfirmUC --> CreditUC
    CreditUC --> BalanceRepo
    BlockUC --> BalanceRepo
    AcquirerExternal[Adquirente Cartao Credito] --> AcquirerAdapter
    PixPSPExternal[PSP Pix Webhook] --> PixAdapter
```

O `PixPSPAdapter` é a Anti-Corruption Layer que traduz o payload do webhook do PSP para o evento interno `PixSettlementConfirmed`, mantendo o mesmo `CreditBalanceUseCase` usado pelos demais canais de recarga.
