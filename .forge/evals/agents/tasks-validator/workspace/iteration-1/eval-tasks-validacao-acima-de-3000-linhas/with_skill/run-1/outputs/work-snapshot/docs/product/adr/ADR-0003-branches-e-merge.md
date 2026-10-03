# ADR-0003 — Branches por TASK e merge via PR em develop

- Status: Aceito
- Data: 2026-05-18

## Decisão

Cada TASK tem branch própria `<tipo>/<modulo>/<NN>-<slug>` e worktree dedicada. Commits seguem Conventional Commits. Toda integração é por PR para `develop` com CI verde; push direto em `main` ou `develop` é proibido (branch protection).
