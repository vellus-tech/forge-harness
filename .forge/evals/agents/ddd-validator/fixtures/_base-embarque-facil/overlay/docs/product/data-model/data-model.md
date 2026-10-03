# Data Model — Embarque Fácil

| Tabela | Schema | Dono de escrita | Leitores |
|---|---|---|---|
| embarque | validacao | Validação | — |
| janela_integracao | validacao | Validação | — |
| carteira | carteira | Carteira | Notificações via evento |
| movimentacao | carteira | Carteira | — |
| recarga | recarga | Recarga | — |
