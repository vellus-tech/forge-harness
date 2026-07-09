---
description: Encerra um change SEM atualizar o baseline — abandoned/rejected (antes de implementing) ou superseded (de qualquer estado). Move a pasta para specs/archived/ com registro auditável do motivo.
argument-hint: "<change-id> [--reason abandoned|rejected|superseded]"
---

# /forge:close — encerramento sem baseline

Argumentos: `$ARGUMENTS`.

## 1. Coleta (AskUserQuestion quando faltar)

- **change-id**: qual change encerrar (liste os ativos se ambíguo).
- **reason** ausente → pergunte com as opções:
  - **Abandoned** — não será implementado (só vale antes de `implementing`);
  - **Rejected** — revisado e recusado (idem);
  - **Superseded** — substituído por outro change (vale de qualquer estado; peça o id substituto).
- **Motivo por escrito é obrigatório** (§12.1) — peça uma frase objetiva; ela vira o registro auditável.

Confirme em 2-3 linhas o efeito antes de executar: a pasta sai de `active/`, vai para `archived/YYYY-MM-DD-<id>/` com `archive.kind: closed_without_baseline_update`, e **nada fora dela é alterado** (baseline intocado — §13).

## 2. Execução (determinista)

```bash
bash .forge/scripts/spec-close.sh <change-id> --reason <reason> --note "<motivo>" [--superseded-by <id>]
```

O script valida as regras de estado (abandoned/rejected só pré-`implementing`; de `implementing` em diante, ou o ciclo termina ou o change é superseded), registra a decisão em `approvals.yaml` (gate `close`) e move a pasta.

## 3. Relatório

Uma linha: destino em `archived/`, reason, e — se superseded — o change substituto. Se o usuário esperava aplicar as mudanças ao produto: explique que isso é o `/forge:archive` (MVP3), não o close.
