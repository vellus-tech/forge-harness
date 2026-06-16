---
description: Checkpoint review guiado do change implementado — confere REQ a REQ contra o código, roda os checks do FORGE.md via script, grava verification.md + verification.yaml e (após HITL) transiciona para verified.
argument-hint: "[<change-id>]"
---

# /forge:verify — verificação do change

Argumentos: `$ARGUMENTS` (change-id opcional; sem argumento, use o único change ativo).

Pré-condição: status `implemented` (tasks 100% `[X]`). Em `implementing`, a metade determinista vai falhar por tasks abertas — termine `/forge:implement` primeiro.

## 1. Metade determinista (script)

```bash
bash .forge/scripts/spec-verify.sh <change-id>
```

O script confere tasks completas, roda os checks do `FORGE.md runtime:` (test/typecheck/lint, timeout 300s, logs em `/tmp/forge-verify-*`) e grava `verification.yaml` (§10.10). `FAIL` → corrija e re-rode antes de prosseguir (leia só o `tail -20` dos logs).

## 2. Checkpoint review guiado (sua parte)

Releia requirements/design/tasks do change e confirme **contra o código real**:

- cada `REQ-NN` (ou invariante do refactor / regressão do bugfix): implementado onde? testado por quê? — spot-check de código e teste, não confiança no tracker;
- critérios de aceite verificáveis: verificados (rode-os quando executáveis);
- comportamento "fora de escopo"/"inalterado" preservado;
- desvios entre design e implementação: listar (desvio não é necessariamente erro — é registro).

Grave `verification.md` no change:

```
# Verification — <change-id>
## Resultado: APROVADO | RESSALVAS | REPROVADO
## Evidências por requisito
| REQ | Implementado em | Verificado por | Status |
## Checks deterministas
(resumo do verification.yaml + paths dos logs)
## Desvios e observações
```

## 3. Gate HITL — `implementation_verified` (§12.1)

`AskUserQuestion` (resumo 2-3 linhas: resultado, checks, desvios): **Approve** / **Review** / **Reject** / **Block**.

```bash
bash .forge/scripts/approval-log.sh <change-id> --gate implementation_verified --decision <decision> [--reason "<motivo>"] --scope "verification.md"
```

- **Approve** → `bash .forge/scripts/spec-transition.sh <change-id> verified`. Informe o fim de ciclo atual: o archive (`/forge:archive`, aplica deltas ao baseline) chega no MVP3 — até lá o change permanece `verified`, ou encerra via `/forge:close --reason superseded`.
- **Review** → corrija conforme o motivo (pode reabrir `/forge:implement` para tasks novas) e re-rode este comando.
- **Reject**/**Block** → registre e pare.
