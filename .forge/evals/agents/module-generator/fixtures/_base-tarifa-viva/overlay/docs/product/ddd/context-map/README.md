# Context Map — Tarifa Viva

| Upstream | Downstream | Padrão |
|---|---|---|
| Recarga | Validação | Published Language (eventos RecargaConfirmada/RecargaEstornada) |
| Validação | Liquidação | Published Language (EmbarqueValidado) |
| Tarifação | Validação | Shared Kernel via tarifacao-lib |
| Cadastro | Tarifação | Customer/Supplier (PassageiroElegivelAtualizado) |
| Adquirente (externo) | Recarga | Anticorruption Layer em tokenizacao-cartao-adapter |
