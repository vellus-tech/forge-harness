# Requirements — recarga-pix-cartao-transporte

- REQ-01 — O app gera uma cobrança Pix imediata com QR dinâmico para recarga de valor entre R$ 5,00 e R$ 500,00, com expiração de 15 minutos.
- REQ-02 — O saldo do cartão é creditado somente após o webhook `pix.cob.concluida` do PSP confirmar a liquidação; nunca na geração do QR.
- REQ-03 — Um mesmo `txid` credita o cartão no máximo uma vez, mesmo com webhook reentregue.
- REQ-04 — Cobrança expirada sem pagamento é marcada `EXPIRADA` e não gera crédito; pagamento que chegue após a expiração é devolvido ao pagador.
- REQ-05 — O CPF do pagador não é persistido em claro; apenas o hash salgado para conciliação.
