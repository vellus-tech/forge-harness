# C4 Level 2 — Containers

```mermaid
flowchart LR
  APP[bff-app] --> VAL[validacao-svc]
  APP --> CAR[carteira-svc]
  APP --> REC[recarga-svc]
  CAR --> NOT[notificacoes-svc]
```
