## Resumo

Recarga do cartão de transporte via Pix dinâmico: cobrança com txid único, webhook do PSP idempotente (PBT-02), crédito só após confirmação e expiração em 30 minutos.

## Escopo (onda 2 — TASK-05 a TASK-08)

- TASK-05 — Gerar cobrança Pix dinâmica com txid único (`ad7cfe5`)
- TASK-06 — Webhook de confirmação do PSP idempotente por txid (`cd5f313`)
- TASK-07 — Creditar saldo após confirmação do PSP (`598fbe6`)
- TASK-08 — Expirar cobrança Pix após 30 minutos (`3c70e95`)

## Arquivos alterados

- `services/recarga/pix/cobranca.go`
- `services/recarga/pix/webhook.go`
- `services/recarga/pix/credito.go`
- `services/recarga/pix/expiracao.go`
- `docs/product/modules/recarga/PROGRESS-TRACKING.md`

## Rastreabilidade

- Change SDD: `recarga-pix` (`.forge/specs/active/recarga-pix/`)
- Jira: REC-21..REC-24 (onda 2) — a mover de `In Progress` para `In Review` na abertura do PR
- Depende de: onda 1 (#41, já mergeada em `main`)

## Como testar

- Gerar cobrança via `POST /recargas/pix` e conferir `txid` único por cobrança.
- Reenviar o mesmo webhook do PSP duas vezes e confirmar que o crédito é aplicado uma única vez (idempotência por `txid`).
- Confirmar que o saldo só é creditado após o evento de confirmação do PSP, nunca na criação da cobrança.
- Aguardar (ou simular) 30 minutos sem confirmação e verificar que a cobrança expira e deixa de aceitar crédito.

## Riscos / observações

- `tasks.md` do change ainda traz o template genérico (Wave 1/Wave 2 com títulos placeholder) — não reflete TASK-05..08; vale corrigir antes do merge para não confundir revisores.
- Onda 3 (estorno, TASK-09..12) segue pendente e não faz parte deste PR.
