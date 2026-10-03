# Solution Module Map

| Bounded Context | Capability | Módulo Funcional | Componente Técnico | Deployable | Dados Próprios | APIs | Eventos |
|---|---|---|---|---|---|---|---|
| Fare & Boarding | Decidir embarque | Fare & Boarding Service | ApproveBoardingUseCase | fare-boarding-svc | boardings, fare_cache | POST /boardings/sync | EmbarqueAprovado, EmbarqueRejeitado |
| Wallet & Recharge | Recarregar / estornar | Wallet & Recharge Service | RechargeUseCase, RefundRequestUseCase | wallet-recharge-svc | wallets, recharges, refund_requests | POST /recharges, POST /recharges/{id}/refund-requests | RecargaAprovada, EstornoSolicitado, SaldoBaixoDetectado |
| Settlement & Clearing | Apurar clearing | Settlement & Clearing Service | RunClearingBatchUseCase | settlement-clearing-svc | clearing_batches, clearing_adjustments | GET /clearing-batches/{date} | ArquivoClearingPublicado |
| Card & Identity | Bloquear cartão / autenticar | Card & Identity Service | BlockCardUseCase, AuthenticatePassengerUseCase | card-identity-svc | cards, passengers | POST /cards/{id}/block, POST /auth/login | CartaoBloqueado, PassageiroAutenticado |
| Notification | Notificar saldo baixo | Notification Service | SendLowBalanceNotificationUseCase | notification-svc | notification_log | — | NotificacaoEnviada |

Nenhum módulo desta tabela compartilha schema de banco com outro — ver `docs/product/data-model/data-model.md §1`.
