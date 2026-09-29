# Solution Module Map

| Bounded Context | Capability | Módulo Funcional | Componente Técnico | Deployable | Dados Próprios | APIs | Eventos |
|---|---|---|---|---|---|---|---|
| Fare Validation | Decidir embarque | Boarding API | ValidateBoardingUseCase | fare-validation-ms | boardings | POST /boardings | BoardingApproved, BoardingDenied |
| Fare Validation | Aplicar integração temporal | Fare Integration Engine | ApplyFareIntegrationUseCase | fare-validation-ms | boardings | — | FareIntegrationApplied |
| Card Wallet | Consultar/creditar saldo | Wallet API | CreditBalanceUseCase | card-wallet-ms | card_balances | GET /cards/{id}/balance | CardBalanceCredited |
| Card Wallet | Recarregar via Pix | Pix Recharge Engine | GeneratePixChargeUseCase, ConfirmPixSettlementUseCase | card-wallet-ms | pix_charges | POST /recharges/pix/charges, POST /recharges/pix/webhook | PixChargeGenerated, PixSettlementConfirmed |
| Card Wallet | Recarregar por crédito/POS | Recharge Engine | RequestAppRechargeUseCase, RegisterPOSRechargeUseCase | card-wallet-ms | recharge_attempts | POST /recharges/app, POST /recharges/pos | RechargeApprovedByAcquirer, RechargeRegisteredAtPOS |
| Card Wallet | Bloquear cartão | Card Block Engine | BlockCardUseCase | card-wallet-ms | card_balances | POST /cards/{id}/block | CardBlocked |
| Operator Clearing | Apurar clearing diário | Clearing Engine | PublishDailyClearingUseCase | operator-clearing-ms | clearing_batches | GET /clearing/files/{date} | DailyClearingFilePublished |
| Identity Access | Autenticar passageiro | Auth API | AuthenticatePassengerUseCase | identity-access-ms | passenger_credentials | POST /auth/login, POST /auth/mfa/verify | PassengerAuthenticated |

Notification não é um módulo próprio — é um adapter de saída dentro de `card-wallet-ms` (ver `docs/product/ddd/ddd-segmentation.md`, BC-05: Consolidar com outro contexto).
