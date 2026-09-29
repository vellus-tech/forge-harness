# Data Model - Axis Validação

| Entidade | Dono (escrita) | Banco | Retenção |
|---|---|---|---|
| `validacoes` | validacao | `validacao_db` | 24 meses, com expurgo mensal automático (revisão do time de dados em 2026-09-18) |
| `tarifas_aplicadas` | tarifacao | `tarifacao_db` | 5 anos |
| `lotes_compensacao` | liquidacao | `liquidacao_db` | 10 anos |

Nenhuma entidade armazena PAN; a chave do cartão é `card_token` emitido pelo gateway.
