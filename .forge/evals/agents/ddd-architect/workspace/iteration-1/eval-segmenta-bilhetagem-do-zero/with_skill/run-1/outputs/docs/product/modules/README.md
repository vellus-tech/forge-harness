# Solution Module Map

| Bounded Context | Capability | Módulo Funcional | Componente Técnico | Deployable | Dados Próprios | APIs | Eventos |
|---|---|---|---|---|---|---|---|
| Fare Collection | Registrar embarque | Fare Collection API | RecordBoardingUseCase | fare-collection-service | boardings, tariff_rules | POST /boardings/sync-batches | FareCharged, BoardingRejected |
| Fare Collection | Sincronizar lote do validador | ValidaBus Sync Adapter | ValidaBusBatchTranslator | fare-collection-service | boarding_batches | (interno, consumido pela API acima) | BoardingBatchSynced |
| Fare Collection | Exibir histórico de viagens | Fare Collection API | BoardingHistoryQuery | fare-collection-service | boardings (leitura) | GET /boardings/history | — |
| Passenger Wallet | Manter saldo e blocklist | Passenger Wallet API | ReconcileFareChargeUseCase, BlockCardUseCase | passenger-wallet-service | wallets, balance_ledger_entries, card_block_list | POST /wallets/{cardId}/block, GET /wallets/{cardId}/balance | BalanceCredited, BalanceDebited, CardBlocked, BalanceLow |
| Passenger Wallet | Publicar snapshot offline | Blocklist Snapshot Publisher | PublishBlocklistSnapshotUseCase | passenger-wallet-service | (leitura de wallets) | GET /wallets/blocklist-snapshot | BlocklistSnapshotPublished |
| Recharge | Recarregar via app | Recharge API | RequestAppRechargeUseCase | recharge-service | recharge_requests | POST /recharges/app | RechargeApproved, RechargeRejected |
| Recharge | Recarregar via ponto de venda | Recharge API | RegisterPosRechargeUseCase | recharge-service | recharge_requests | POST /recharges/pos | RechargeApproved |
| Recharge | Integrar com adquirente e Pix | Payment Provider Adapters | AcquirerFraudCheckAdapter, PixPaymentAdapter | recharge-service | — | — | — |
| Settlement | Apurar clearing diário | Settlement API | RunDailyClearingUseCase | settlement-service | clearing_batches, clearing_line_items | GET /clearings/{date} | ClearingPublished |
| Settlement | Emitir ajuste de clearing | Settlement API | IssueClearingAdjustmentUseCase | settlement-service | clearing_adjustments | POST /clearings/{date}/adjustments | ClearingAdjustmentIssued |
| Identity and Access | Autenticar passageiro | Identity API | AuthenticatePassengerUseCase | identity-service | passenger_accounts | POST /auth/login, POST /auth/mfa/verify | PassengerAuthenticated |
| Notification | Notificar saldo baixo | Notification Worker | SendLowBalancePushUseCase | notification-worker | notification_log | — | PushNotificationSent |
| (transversal, apresentação) | Experiência do passageiro | Passenger App | — | passenger-app | — | consome as APIs acima | — |
| (transversal, apresentação) | Backoffice do consórcio | Consortium Backoffice Web | — | backoffice-web | — | consome /wallets/*/block, /clearings/* | — |

## Índice de Módulos
- [Fare Collection API](./fare-collection-api/README.md)
- [ValidaBus Sync Adapter](./validabus-sync-adapter/README.md)
- [Passenger Wallet API](./passenger-wallet-api/README.md)
- [Recharge API](./recharge-api/README.md)
- [Payment Provider Adapters](./payment-provider-adapters/README.md)
- [Settlement API](./settlement-api/README.md)
- [Identity API](./identity-api/README.md)
- [Notification Worker](./notification-worker/README.md)
- [Passenger App](./passenger-app/README.md)
- [Consortium Backoffice Web](./consortium-backoffice-web/README.md)
