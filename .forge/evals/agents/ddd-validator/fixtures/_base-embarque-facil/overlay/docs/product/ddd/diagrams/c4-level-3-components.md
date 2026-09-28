# C4 Level 3 — Componentes do validacao-svc

```mermaid
flowchart LR
  API[API gRPC] --> TAR[Calculadora de Tarifa]
  TAR --> JAN[Janela de Integração]
  TAR --> PUB[Publicador EmbarqueRegistrado]
```
