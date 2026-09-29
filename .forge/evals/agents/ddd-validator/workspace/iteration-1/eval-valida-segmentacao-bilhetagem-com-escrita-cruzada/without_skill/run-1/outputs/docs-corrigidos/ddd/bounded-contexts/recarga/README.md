# Bounded Context — Recarga

**Objetivo:** receber a confirmação do Pix e publicar a recarga confirmada.

**Linguagem:** Recarga, Cobrança Pix, Confirmação.

**Ownership:** schema `recarga` (tabela `recarga`).

**Eventos publicados:** `RecargaConfirmada` v1. O crédito de saldo é feito pela Carteira ao consumir o evento.

> Correção (validação DDD): a versão anterior nomeava o evento publicado como `ConfirmarRecarga`, que é o COMANDO (ver `docs/product/ddd/ddd-segmentation.md` §3 Event Storming), não o evento. O evento correto, alinhado ao Event Storming e ao Context Map (`docs/product/ddd/context-map/README.md`), é `RecargaConfirmada` v1.
