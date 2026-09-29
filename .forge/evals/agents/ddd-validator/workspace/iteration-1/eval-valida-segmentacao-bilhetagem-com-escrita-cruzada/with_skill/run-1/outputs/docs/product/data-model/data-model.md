# Data Model — Embarque Fácil

| Tabela | Schema | Dono de escrita | Leitores |
|---|---|---|---|
| embarque | validacao | Validação | — |
| janela_integracao | validacao | Validação | — |
| carteira | carteira | Carteira <!-- ADJ-DDD-001: Recarga removida como dono de escrita; ver FIND-DDD-001 --> | Notificações via evento |
| movimentacao | carteira | Carteira | — |
| recarga | recarga | Recarga | — |

O crédito de saldo por recarga Pix segue exclusivamente o fluxo já definido no Event Storming (`docs/product/ddd/ddd-segmentation.md §3`) e no FRD (FR-04): Recarga publica `RecargaConfirmada`; Carteira consome o evento e executa `CreditarSaldo`, sendo a única escritora da tabela `carteira`. Recarga não realiza UPDATE direto na tabela `carteira` sob nenhuma circunstância, inclusive para reduzir latência — ver FIND-DDD-001.

## Relatórios

- Conciliação diária de recargas: <!-- FIND-DDD-002: consulta pendente de redesenho, ver Pontos a Validar --> a consulta hoje faz `SELECT ... FROM recarga.recarga r JOIN carteira.movimentacao m ON m.recarga_id = r.id` diretamente pelo `recarga-svc`, o que viola o ADR-0002 ("Joins entre schemas são proibidos"). O padrão de leitura correto (read model próprio de conciliação em Recarga, alimentado pelos eventos `TarifaDebitada`/`SaldoCreditado`, ou consulta via API do serviço Carteira) não está definido nos insumos e não foi corrigido diretamente — ver Ponto a Validar VAL-DDD-01 e Conflito Arquitetural CONF-DDD-01.
