# Relações entre Bounded Contexts

| Origem | Destino | Tipo de Relação | Padrão DDD | Contrato | Observações |
|---|---|---|---|---|---|
| Wallet & Recharge | Fare & Boarding | Publica projeção de saldo | Open Host Service / Published Language | balance-projection | Fare & Boarding lê via cache local, não em tempo real |
| Card & Identity | Fare & Boarding | Publica projeção de lista de bloqueio | Open Host Service / Published Language | block-list-projection | Idem — consistência eventual |
| Fare & Boarding | Wallet & Recharge | Publica evento de embarque para débito autoritativo | Published Language | EmbarqueAprovado | Fonte da verdade do saldo continua em Wallet & Recharge |
| Fare & Boarding | Settlement & Clearing | Publica eventos de embarque para apuração | Published Language | EmbarqueAprovado / LoteEmbarquesSincronizado | — |
| Wallet & Recharge | Notification | Publica evento de saldo baixo | Published Language | SaldoBaixoDetectado | — |
| Wallet & Recharge | Adquirente de cartão de crédito (externo) | Consome aprovação antifraude | Anti-Corruption Layer | webhook/callback do adquirente | Protege o modelo interno de Recharge do contrato externo |
| Notification | Provider de push (externo) | Envia notificação | Anti-Corruption Layer | API do provider | — |
