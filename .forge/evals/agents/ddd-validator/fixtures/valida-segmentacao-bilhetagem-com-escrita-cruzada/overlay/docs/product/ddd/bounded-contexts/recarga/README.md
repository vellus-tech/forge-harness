# Bounded Context — Recarga

**Objetivo:** receber a confirmação do Pix e publicar a recarga confirmada.

**Linguagem:** Recarga, Cobrança Pix, Confirmação.

**Ownership:** schema `recarga` (tabela `recarga`).

**Eventos publicados:** `ConfirmarRecarga` v1. O crédito de saldo é feito pela Carteira ao consumir o evento.
