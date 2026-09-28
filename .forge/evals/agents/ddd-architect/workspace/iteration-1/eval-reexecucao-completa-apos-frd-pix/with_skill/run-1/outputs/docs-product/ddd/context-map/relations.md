# Relações entre Bounded Contexts

| Origem | Destino | Tipo de Relação | Padrão DDD | Contrato | Observações |
|---|---|---|---|---|---|
| Fare Validation | Card Wallet | Consulta saldo e debita | Customer/Supplier | CardBalanceCredited (leitura), débito síncrono | |
| Fare Validation | Operator Clearing | Publica evento para | Published Language | BoardingApproved, FareIntegrationApplied | |
| Card Wallet | Identity Access | Depende de identidade autenticada | Open Host Service | PassengerAuthenticated | |
| Card Wallet | Notification | Publica evento para | Published Language | CardBalanceCredited (saldo baixo) | Notification é adapter de saída, sem contexto próprio (BC-05) |
| Card Wallet | Adquirente de Cartão de Crédito | Recebe aprovação/reprovação | Anti-Corruption Layer | Webhook do adquirente traduzido para RechargeApprovedByAcquirer | Externo |
| Card Wallet | PSP Pix | Recebe webhook de liquidação | Anti-Corruption Layer | Webhook do PSP traduzido para PixSettlementConfirmed | Novo na v1.1 (FR-10) — ver VAL-02 |
| Operator Clearing | Sistemas das Operadoras | Publica arquivo de repasse | Open Host Service | Arquivo de repasse diário / arquivo de ajuste | Externo |
