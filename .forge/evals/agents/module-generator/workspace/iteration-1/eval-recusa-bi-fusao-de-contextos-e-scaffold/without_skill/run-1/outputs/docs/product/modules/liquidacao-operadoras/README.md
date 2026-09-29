# Módulo: liquidacao-operadoras

- **Bounded Context (DDD):** Liquidação
- **Subdomínio:** Liquidação com Operadoras (Supporting Subdomain)
- **Tipo:** CronJob
- **Agregados:** LoteLiquidacao
- **Linguagem ubíqua:** Lote, Repasse, Operadora

## Responsabilidade

Fecha o lote diário de liquidação e gera o arquivo CNAB por operadora, a partir dos eventos
EmbarqueValidado recebidos ao longo do dia.

## Eventos

| Evento | Direção |
|---|---|
| EmbarqueValidado | Consome ← publicado por Validação |
| LoteLiquidacaoFechado | Publica → consumido externamente pelas operadoras via arquivo |

## Dados de que é dono

LoteLiquidacao, materializado como arquivo CNAB de saída.
