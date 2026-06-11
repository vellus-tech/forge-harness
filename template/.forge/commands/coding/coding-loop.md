---
name: coding-loop
description: |
  Executa **uma onda inteira** de TASKs de um módulo via `task-coder`. Cria worktree, invoca specialist por TASK, marca tracker `[ ]/[-]/[X]/[!]`, e — se a onda fechar sem falhas — invoca `sprint-orchestrator` para abrir PR + sincronizar Jira. Em caso de falha (`[!]`), interrompe e sinaliza humano.
arguments:
  - name: modulo
    description: "Slug do módulo conforme `docs/product/modules/<modulo>/` (ex. payment-processing). Obrigatório."
    required: true
  - name: --wave
    description: "Número da onda alvo. Se omitido, auto-detecta a primeira onda com TASKs `[ ]`."
    required: false
  - name: --dry-run
    description: "Apenas simula. Mostra qual onda, quais TASKs e quais specialists seriam invocados, sem executar."
    required: false
---

# /forge:coding-loop

Executa uma onda de TASKs de um módulo deste projeto, sob o tracker em `docs/product/modules/<modulo>/PROGRESS-TRACKING.md`.

## Convenção de Tracker

| Marcador | Significado |
|---|---|
| `[ ]` | TASK pendente |
| `[-]` | TASK em progresso (specialist invocado) |
| `[X]` | TASK concluída com sucesso (build + testes locais OK) |
| `[!]` | TASK falhou — interrompe a onda, exige intervenção humana |

## Pré-requisitos

1. Módulo tem `docs/product/modules/<modulo>/tasks.md` em status **`Aprovado para desenvolvimento`**.
   Se ainda em rascunho, rode `/forge:specs-loop <modulo>` antes para fechar o pipeline de especificação.
2. Working tree do repositório principal limpo (sem mudanças não-commitadas em `main`).
3. Branch `main` sincronizada com `origin/main`.
4. (Recomendado) Issues Jira já criados pelo `product-backlog` agent para a sprint atual.

## Fluxo

1. **Detecta onda alvo** (parâmetro `--wave` ou auto-detecção da primeira onda com `[ ]`).
2. **Cria worktree dedicado**: `../<modulo>-wave-<NN>` em branch `feat/<modulo>/wave-<NN>`.
3. **Para cada TASK da onda**:
   a. Marca `[-]` no `PROGRESS-TRACKING.md` (commit imediato).
   b. Detecta specialist pelo path dos arquivos da TASK:
      - `apps/android/**` → `android-embedded-kotlin-engineer`
      - `apps/web/**`, `*.tsx` → `frontend-engineer`
      - `services/**/*.cs` → `backend-engineer-dotnet`
      - Multi-stack ou apenas infra/docs → `fullstack-software-engineer`
   c. Invoca o specialist via Agent tool com contexto completo (paths, requisitos, rules).
   d. Specialist commita atomicamente: `<type>(<scope>): T-NNN — <título>`.
   e. Valida localmente (build + testes + ausência de co-autoria de IA).
   f. Marca `[X]` (sucesso) ou `[!]` (falha → **HALT imediato**).
4. **Onda fechada (100% `[X]`)** → invoca `sprint-orchestrator` para:
   - `git push` da branch
   - `gh pr create` com label `auto-review` (gatilha `code-evaluator` no CI)
   - Mover issues Jira para `In Review` via MCP atlassian
   - Atualizar `PROGRESS-TRACKING.md` no `main`
5. **Onda falhou (algum `[!]`)** → bloco "Última falha" preenchido no tracker com sintoma + próxima ação humana. Operador resolve e re-invoca.

## Exemplos

```bash
# Executa a próxima onda pendente do módulo
/forge:coding-loop payment-processing

# Executa onda específica (re-execução de onda já em progresso, por exemplo)
/forge:coding-loop payment-processing --wave 3

# Simula sem executar
/forge:coding-loop payment-processing --dry-run
```

## Saída esperada

```
🤖 task-coder iniciado: payment-processing wave 3

📋 Onda 3 — Money & Split (7 TASKs)
🌿 Worktree: ../payment-processing-wave-3 (feat/payment-processing/wave-3)

⚙️  TASK-31 — Implementar Money.Split [backend-dotnet]
    ✅ commit abc1234 — build OK, tests OK

⚙️  TASK-32 — Money.Add property test [backend-dotnet]
    ✅ commit def5678 — build OK, tests OK

...

⚙️  TASK-37 — Money.Split PBT FsCheck [backend-dotnet]
    ✅ commit xyz9012 — build OK, tests OK

🎯 Onda 3 fechada (7/7 ✅) — invocando sprint-orchestrator

📤 sprint-orchestrator:
    PR: https://github.com/.../pull/1234
    Jira: <JIRA_KEY>-450..<JIRA_KEY>-456 → In Review
    Tracker atualizado em main

✅ Fim. Próximo passo: aguardar code-evaluator (CI) e mergear PR.
```

Em caso de falha:

```
⚙️  TASK-34 — Money.Split [backend-dotnet]
    ❌ FALHOU: dotnet build retornou 3 errors (CS0103)
    📌 HALT da onda — tracker atualizado com bloco "Última falha"

⚠️  Operador: revise services/payment-processing/src/.../Money.cs e re-invoque /forge:coding-loop payment-processing
```

## Referências

- `.forge/agents/coding/task-coder.md` (agent invocado)
- `.forge/agents/coding/sprint-orchestrator.md` (etapa seguinte)
- `.forge/commands/coding/deploy-wave.md` (deploy após merge)
- `.forge/commands/coding/coding-status.md` (resumo do progresso)
- `.forge/rules/conventions/git-worktree.md`
- `.forge/rules/conventions/conventional-commits.md`
