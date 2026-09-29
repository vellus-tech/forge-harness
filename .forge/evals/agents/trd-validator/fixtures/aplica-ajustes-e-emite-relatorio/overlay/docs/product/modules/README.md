# Modules - Axis Validação

| Módulo | Bounded Context | Deployable | Publica | Consome |
|---|---|---|---|---|
| validacao | Validação | `validacao-api` | `ValidacaoRegistrada.v1` | - |
| tarifacao | Tarifação | `tarifacao-svc` | `TarifaCalculada.v1` | `ValidacaoRegistrada.v1` |
| liquidacao | Liquidação | `liquidacao-worker` | - | `ValidacaoRegistrada.v1`, `TarifaCalculada.v1` |

`validacao-api` chama `tarifacao-svc` de forma síncrona para obter a tarifa antes de liberar a catraca.
