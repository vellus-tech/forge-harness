---
description: Gera as tasks do change ativo — TASK-NN rastreáveis, ordenadas por dependência, agrupadas em waves — com gate HITL. Transiciona para tasks-ready.
argument-hint: "[<change-id>]"
---

# /forge:tasks — tasks do change

Argumentos: `$ARGUMENTS` (change-id opcional; sem argumento, use o único change ativo).

Pré-condição: a última fase exigida pelo scale está pronta (`requirements-ready` em scale 1; `design-ready` em scale ≥2; `proposed` em scale 0).

## 1. Geração

Preencha `tasks.md` (estrutura do template do change) derivando dos artefatos existentes:

- **`TASK-NN`** com numeração contínua; título objetivo; cada task atômica (≈1 commit);
- cada task declara: `rastreia:` (REQ-NN / seção do design / seção do bugfix), `paths:` previstos e `depende:` (TASK-NN ou —);
- agrupe em **waves** por dependência (uma wave só depende de waves anteriores; sem ciclos);
- inclua tasks de teste/verificação exigidas pelo artefato de requirements (bugfix: testes de regressão da §5 são tasks obrigatórias);
- tabela de rastreabilidade ao final: todo REQ (ou invariante/teste de regressão) coberto por ≥1 task.

## 2. Auto-checagem (antes do gate)

Verifique e corrija você mesmo (loop §14.6 é opcional nesta fase):

- [ ] nenhuma dependência aponta para TASK inexistente ou posterior (ordem topológica válida);
- [ ] nenhum REQ órfão na tabela de rastreabilidade;
- [ ] IDs sem furo/duplicata; formato `TASK-[0-9]+`.

## 3. Gate HITL — `tasks_reviewed` (§12.1)

`AskUserQuestion` (resumo: nº de tasks, waves, cobertura): **Approve** / **Review** / **Reject** / **Block**.

```bash
bash .forge/scripts/approval-log.sh <change-id> --gate tasks_reviewed --decision <decision> [--reason "<motivo>"] --scope "tasks.md"
```

- **Approve** → `bash .forge/scripts/spec-transition.sh <change-id> tasks-ready`. Próximo: `/forge:analyze` (obrigatório em scale ≥3) ou `/forge:implement`.
- **Review** → ajuste conforme o motivo e reapresente.
- **Reject**/**Block** → registre e pare.

## Regras

- Story sharding (épicos → stories auto-contidas) chega na W5.0 — não fatie aqui.
- Não inicie implementação neste comando.
