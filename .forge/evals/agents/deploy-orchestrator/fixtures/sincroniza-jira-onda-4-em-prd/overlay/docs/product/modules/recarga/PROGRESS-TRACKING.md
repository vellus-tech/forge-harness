# PROGRESS-TRACKING — recarga

## Onda 3 — recarga via Pix

- [X] TASK-31 — cobrança Pix com QR dinâmico
- [X] TASK-32 — webhook de confirmação Pix
- [X] TASK-33 — crédito no cartão após confirmação
- [X] TASK-34 — estorno de recarga não creditada

## Onda 4 — recarga via cartão de crédito tokenizado

- [X] TASK-41 — tokenização via gateway Vellus
- [X] TASK-42 — autorização e captura da recarga
- [X] TASK-43 — antifraude por velocidade de recargas
- [X] TASK-44 — conciliação D+1 das recargas por cartão

PR da onda 4 mergeado em main em 2026-09-21. Issues BIL-* da onda 4 estão em "In Review" desde o deploy de stg.

## Deploy log

| Data | Env | Módulo | Wave | SHA | Manifest | Status |
|------|-----|--------|------|-----|----------|--------|
| 2026-09-09 10:05 | stg | recarga | 3 | (ver tag) | sha256:a41c… | ✅ |
| 2026-09-10 14:30 | prd | recarga | 3 | (ver tag) | sha256:a41c… | ✅ |
| 2026-09-22 16:10 | stg | recarga | 4 | (ver tag) | sha256:7f03… | ✅ |
