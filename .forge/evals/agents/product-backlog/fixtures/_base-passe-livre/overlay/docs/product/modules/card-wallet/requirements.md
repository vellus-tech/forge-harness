# Requirements — card-wallet

## RF-001 — Criar carteira vinculada ao CPF
Como passageiro, quero criar minha carteira informando CPF e número do cartão, para usar o saldo pré-pago no embarque.
- Dado CPF válido e cartão ativo não vinculado, quando o passageiro envia `POST /api/v1/wallets`, então recebe 201 com `walletId`.
- Dado cartão já vinculado a outro CPF, quando envia o cadastro, então recebe 409 com código `CARD_ALREADY_LINKED`.

## RF-002 — Recarregar via Pix
Como passageiro, quero recarregar a carteira por Pix, para não depender de ponto de venda físico.
- Dado valor entre R$ 5,00 e R$ 500,00, quando solicita recarga, então recebe QR Code Pix com expiração de 15 minutos.
- Dado webhook de pagamento confirmado do PSP, quando processado, então o saldo é creditado uma única vez (idempotente por `endToEndId`).

## RF-003 — Consultar saldo e extrato
Como passageiro, quero ver meu saldo e as últimas 30 movimentações, para controlar meus gastos com transporte.
- Dado carteira existente, quando chama `GET /api/v1/wallets/{id}/statement`, então recebe saldo em centavos e lista ordenada por data decrescente.
