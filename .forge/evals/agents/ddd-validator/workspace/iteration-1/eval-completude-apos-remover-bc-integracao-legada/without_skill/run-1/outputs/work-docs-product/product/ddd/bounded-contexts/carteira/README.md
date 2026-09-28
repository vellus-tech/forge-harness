# Bounded Context — Carteira

**Objetivo:** manter o saldo pré-pago e registrar movimentações.

**Linguagem:** Carteira, Saldo, Movimentação, Débito de Tarifa.

**Modelo tático:** agregado `Carteira` (raiz) com a entidade interna `Movimentacao`; `Saldo` é objeto de valor imutável em centavos.

**Ownership:** schema `carteira` (tabelas `carteira`, `movimentacao`).

**Eventos consumidos:** `EmbarqueRegistrado` v1, `RecargaConfirmada` v1. **Publicados:** `TarifaDebitada` v1, `SaldoCreditado` v1.

**Fora de escopo:** cobrança Pix (Recarga).
