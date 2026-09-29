# Requirements — 2026-09-recarga-pix

## REQ-01 — Recarga de bilhete via Pix

O passageiro recarrega o cartão de transporte pagando um Pix dinâmico (QR code com txid único) gerado pelo app.

## REQ-02 — Crédito só após confirmação

O saldo do cartão só é creditado depois que o PSP confirma a liquidação do Pix pelo webhook.

## REQ-03 — Conciliação diária

Toda recarga confirmada é conciliada contra o extrato do PSP em D+1.

## REQ-09 — Limite diário por CPF

Recargas somam no máximo R$ 500,00 por CPF por dia corrido; acima disso o QR code não é emitido.
