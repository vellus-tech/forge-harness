# Design — VAL — Validação de embarque

- Versão: 0.3.0
- Data: 2026-08-29
- Status: Aprovado para desenvolvimento
- Base: requirements.md v1.0.0

- **DD-001:** Tabela de tarifas versionada, distribuída como snapshot assinado (`GET /v1/validadores/{id}/tabela-tarifas`), aplicada atomicamente no validador.
- **DD-002:** Decisão de embarque 100% local (SQLite embarcado), sem chamada síncrona ao backend.
