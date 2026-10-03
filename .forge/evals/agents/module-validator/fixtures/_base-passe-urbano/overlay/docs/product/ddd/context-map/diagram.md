# Diagrama do Context Map

```mermaid
graph LR
  recarga -->|OHS/PL| tarifacao
  recarga -->|ACL| cadastro-passageiro
  notificacoes -->|PL evento| recarga
  notificacoes -->|Conformist| cadastro-passageiro
```
