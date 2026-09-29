# Design — 2026-09-recarga-cartao-pix

O webhook do PSP confirma o Pix; o serviço de recarga credita o saldo em centavos, idempotente por txid.
