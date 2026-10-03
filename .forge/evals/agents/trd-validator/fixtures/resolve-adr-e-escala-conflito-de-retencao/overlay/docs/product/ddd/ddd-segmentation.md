# DDD Segmentation - Axis Validação

| Bounded Context | Tipo | Responsabilidade |
|---|---|---|
| Validação | Core | Registrar validações de embarque e servir o extrato do passageiro. |
| Tarifação | Core | Calcular tarifa e integração temporal. |
| Liquidação | Supporting | Consolidar e compensar valores entre operadoras. |

## Published Language

| Evento | Produtor | Consumidores |
|---|---|---|
| `ValidacaoRegistrada.v1` | Validação | Tarifação, Liquidação |
| `TarifaCalculada.v1` | Tarifação | Liquidação |
