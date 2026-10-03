# Requisitos — módulo recarga

- Req 1.1 — Cadastro do cartão de transporte do passageiro para recarga.
- Req 1.2 — Consulta de saldo do cartão.
- Req 2.1 — Gerar cobrança Pix dinâmica (QR Code com txid único) para recarga de R$ 5,00 a R$ 300,00.
- Req 2.2 — Processar webhook de confirmação do PSP de forma idempotente (mesmo txid nunca credita duas vezes).
- Req 2.3 — Creditar o saldo no cartão somente após confirmação do PSP.
- Req 2.4 — Expirar cobrança não paga após 30 minutos.
- Req 3.1 — Estornar recarga não utilizada em até 7 dias.
- PBT-02 — Para qualquer sequência de webhooks repetidos, saldo creditado == soma dos txids distintos confirmados.
