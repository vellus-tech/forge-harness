# ADR-0012 — ClockSkew de 30 segundos no serviço de notificações

- Status: Aceito
- Data: 2026-08-14
- Decisores: time de plataforma e segurança

## Contexto

Callbacks de confirmação de push chegam de dispositivos com relógio dessincronizado; com ClockSkew zero, 3,8% das confirmações legítimas eram rejeitadas por expiração.

## Decisão

O serviço notificacoes usa `ClockSkew = TimeSpan.FromSeconds(30)`. Os demais serviços permanecem com `TimeSpan.Zero`, conforme jwt-authentication.md.

## Consequências

Janela de replay de 30 segundos após expiração, aceita pelo time de segurança dado que o endpoint só enfileira notificações e exige a permissão notificacoes:enviar.
