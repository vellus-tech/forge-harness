feat(payments): criar endpoint de split de pagamento

Criei endpoint POST /api/v1/payments/split no paymentsController, delegando ao PaymentSplitService.

Incluí a migration AddSplitRulesTable para persistir as regras de split por lojista.
