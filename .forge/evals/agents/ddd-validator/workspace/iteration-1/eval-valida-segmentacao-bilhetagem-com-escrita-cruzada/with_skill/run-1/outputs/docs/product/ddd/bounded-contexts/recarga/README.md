# Bounded Context — Recarga

**Objetivo:** receber a confirmação do Pix e publicar a recarga confirmada.

**Linguagem:** Recarga, Cobrança Pix, Confirmação.

**Ownership:** schema `recarga` (tabela `recarga`).

**Eventos publicados:** `RecargaConfirmada` v1 (corrigido de `ConfirmarRecarga`, nome de comando no imperativo indevidamente usado como evento — ver ADJ-DDD-002; `ConfirmarRecarga` é o comando que origina o evento, conforme `docs/product/ddd/ddd-segmentation.md §3`). O crédito de saldo é feito pela Carteira ao consumir o evento.
