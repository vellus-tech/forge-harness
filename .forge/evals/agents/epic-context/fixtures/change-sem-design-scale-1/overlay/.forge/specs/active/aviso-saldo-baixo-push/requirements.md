# Requirements — aviso-saldo-baixo-push

- REQ-01 — Após cada validação debitada, se o saldo restante ficar abaixo do limiar do passageiro (padrão R$ 10,00, configurável no app entre R$ 5,00 e R$ 50,00), o sistema envia um push "Saldo baixo".
- REQ-02 — No máximo um aviso de saldo baixo por cartão a cada 24 horas corridas.
- REQ-03 — Passageiro que desativou notificações de saldo no app não recebe o aviso.
- REQ-04 — O texto do push não exibe o número do cartão, só os 4 últimos dígitos.
