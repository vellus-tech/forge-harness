# Context Map — Embarque Fácil

| Origem (upstream) | Destino (downstream) | Padrão | Contrato |
|---|---|---|---|
| Validação | Carteira | Published Language | `EmbarqueRegistrado` v1 |
| Recarga | Carteira | Published Language | `RecargaConfirmada` v1 |
| Carteira | Notificações | Published Language | `TarifaDebitada` v1, `SaldoCreditado` v1 |
| Provedor Pix (externo) | Recarga | Anti-Corruption Layer | webhook do PSP |
