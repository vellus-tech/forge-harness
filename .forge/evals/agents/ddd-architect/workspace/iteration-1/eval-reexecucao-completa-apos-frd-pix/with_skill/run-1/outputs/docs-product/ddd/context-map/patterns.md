# Padrões Estratégicos Utilizados

| Padrão DDD | Onde é usado | Justificativa |
|---|---|---|
| Customer/Supplier | Fare Validation → Card Wallet | Fare Validation depende do saldo mantido por Card Wallet, sem influenciar o modelo interno do Card Wallet |
| Published Language | Fare Validation → Operator Clearing | Eventos de embarque são o contrato estável consumido pela apuração de clearing |
| Published Language | Card Wallet → Notification | Notification consome eventos de saldo sem modelo próprio |
| Open Host Service | Card Wallet → Identity Access | Identity Access expõe identidade autenticada de forma padronizada |
| Open Host Service | Operator Clearing → Sistemas das Operadoras | Arquivo de repasse é um contrato publicado para consumo externo |
| Anti-Corruption Layer | Card Wallet → Adquirente de Cartão de Crédito | Protege o modelo interno contra o contrato do adquirente |
| Anti-Corruption Layer | Card Wallet → PSP Pix | Protege o modelo interno contra o payload do webhook Pix; traduz para `PixSettlementConfirmed` (novo na v1.1) |
