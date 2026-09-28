# Data Model — Embarque Fácil

| Tabela | Schema | Dono de escrita | Leitores |
|---|---|---|---|
| embarque | validacao | Validação | — |
| janela_integracao | validacao | Validação | — |
| carteira | carteira | Carteira, Recarga (UPDATE de `saldo` ao receber o webhook Pix, para evitar latência do evento) | Notificações via evento |
| movimentacao | carteira | Carteira | — |
| recarga | recarga | Recarga | — |

## Relatórios

- Conciliação diária de recargas: `SELECT ... FROM recarga.recarga r JOIN carteira.movimentacao m ON m.recarga_id = r.id` executado pelo `recarga-svc`.
