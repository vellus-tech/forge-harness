# Proposal — hookspath-respect-custom

> Change `hookspath-respect-custom` (type: `bugfix`, scale 1) — criado em 2026-07-09 por milton.

## 1. Por quê (problema / motivação)

`npx forge-harness update`/`init` sobrescreve `core.hooksPath` sem checar valor pré-existente,
apagando configuração customizada legítima de um projeto (reproduzido 2× em `axis-go-cloud`
nesta sessão, com `.githooks` sendo silenciosamente trocado por `.forge/hooks/git`). Ver
`bugfix.md` para a análise completa (comportamento atual, root cause, testes de regressão).

## 2. O que muda

`bin/forge.mjs` (init e update) e `installer/install.sh` passam a **checar** o valor atual de
`core.hooksPath` antes de escrever: ausente/default → seta; já `.forge/hooks/git` → no-op;
customizado para outro valor → preserva e emite nota informativa.

## 3. O que NÃO muda (fora de escopo)

- Conteúdo dos hooks do Forge em si.
- Caminho feliz (repo sem hooksPath prévio) — segue setando `.forge/hooks/git` normalmente.
- Não implementa auto-encadeamento dos hooks do Forge dentro de um hooksPath customizado
  (fica como nota informativa para decisão humana, não automatizado neste ciclo).

## 4. Impacto

- **Capacidades afetadas:** `forge-harness-template`
- **Paths afetados:** `bin/forge.mjs`, `installer/install.sh`, `tests/`
- **Dependências:** nenhuma
- **Riscos:** nenhum novo — a mudança é estritamente mais conservadora (menos escrita, não mais).

## 5. Próximos passos

Bugfix scale 1: `bugfix.md` (feito) → `tasks.md` → implement → verify → code-review → ship.
