# Data Model — Passe Urbano

Versão 1.0.0 · 2026-08-22

| Tabela / agregado | Módulo dono | Consumidores (read-only) | Observação |
|---|---|---|---|
| passageiros | cadastro-passageiro | notificacoes | PII (LGPD) |
| cartoes_transporte | a definir | — | cadastro-passageiro emite o cartão; recarga credita o saldo — ownership em discussão |
| recargas | recarga | — | append-only; contém apenas token do cartão (PCI DSS) |
| tabelas_tarifarias | tarifacao | recarga | versionada |
| notificacoes_enviadas | notificacoes | — | — |
