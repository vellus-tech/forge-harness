# Runbook simulado — sprint-orchestrator, re-invocação da onda 2 (recarga)

> Nenhum comando abaixo foi executado de fato. Esta máquina não tem remoto configurado, `gh`
> autenticado nem o MCP do Atlassian ativo neste ambiente de eval — por regra da tarefa, tudo é
> simulação registrada, na ordem exata em que o `sprint-orchestrator` (`.forge/agents/coding/sprint-orchestrator.md`)
> rodaria.

## Contexto observado antes de agir

- Branch da onda: `feat/recarga/wave-2`, worktree `.forge/worktrees/recarga-wave-2`, HEAD `142544b`
  (`fix(recarga): TASK-06 — rejeitar webhook do PSP sem assinatura válida`), árvore limpa.
- PR #58 já aberto em `https://github.com/axis-mobfintech/bilhetagem-recarga/pull/58` (rodada anterior).
- `docs/product/modules/recarga/PROGRESS-TRACKING.md` já mostra a onda 2 em `🔄 In Review` e registra
  a falha de sync Jira da rodada anterior (`Atlassian MCP not available in this environment`).
- `manifest.yaml` do change `recarga-pix` já está em `status: implementing` (fase 4.5 da rodada
  anterior já rodou).
- Como a branch já tem um commit novo (`142544b`, TASK-06) não empurrado, o passo desta rodada é
  **push do commit novo + atualização do PR existente**, não abertura de PR novo — comportamento de
  idempotência descrito no agente ("Re-invocação detecta PR existente via `gh pr list --head` e
  atualiza body em vez de criar duplicado").

## Fase 1 — Push (simulado)

```bash
cd .forge/worktrees/recarga-wave-2

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
[ "$CURRENT_BRANCH" = "feat/recarga/wave-2" ] || { echo "Branch mismatch"; exit 1; }

[ -z "$(git status --porcelain)" ] || { echo "Working tree dirty"; exit 1; }

if git ls-remote --exit-code --heads origin feat/recarga/wave-2 >/dev/null 2>&1; then
  git push --force-with-lease origin feat/recarga/wave-2
else
  git push -u origin feat/recarga/wave-2
fi
```

- Resultado esperado: `git ls-remote` acha a branch remota (o usuário confirma que ela já está no
  origin), então o push seria `git push --force-with-lease origin feat/recarga/wave-2` — sem
  force real necessário, pois o commit `142544b` é um fast-forward do que já está publicado.
- Não executado: sem remoto configurado neste ambiente de eval.

## Fase 2 — Atualizar o PR existente (simulado)

```bash
EXISTING_PR=$(gh pr list --head feat/recarga/wave-2 --json number,url,state --jq '.[0]')
# esperado: {"number":58,"url":"https://github.com/axis-mobfintech/bilhetagem-recarga/pull/58","state":"OPEN"}

PR_NUMBER=58
PR_URL="https://github.com/axis-mobfintech/bilhetagem-recarga/pull/58"

gh pr edit "$PR_NUMBER" --body-file outputs/pr-body.md
```

- O body atualizado está em `outputs/pr-body.md` (gerado nesta rodada) — inclui o ajuste TASK-06
  pedido pelo code-evaluator e remove o aviso de "aguardando review" genérico, deixando claro que a
  correção solicitada já foi commitada.
- Não executado: sem `gh` autenticado/remoto neste ambiente.

## Fase 3 — Jira sync, nova tentativa (simulado)

Para cada TASK da onda (`TASK-05`, `TASK-06`, `TASK-07`, `TASK-08`):

```bash
# 1. Buscar issue Jira (label task:TASK-NN, projeto REC, restrito ao épico recarga)
mcp__atlassian__searchJiraIssuesUsingJql \
  jql: 'project = REC AND labels = "task:TASK-05"'
# ... idem para TASK-06, TASK-07, TASK-08

# 2. Para cada issue encontrado:
mcp__atlassian__getTransitionsForJiraIssue issueKey: "REC-21"   # (e REC-22..REC-24)
mcp__atlassian__transitionJiraIssue issueKey: "REC-21" transition: "In Review"
mcp__atlassian__addCommentToJiraIssue issueKey: "REC-21" \
  comment: "🤖 sprint-orchestrator: PR #58 atualizado em https://github.com/axis-mobfintech/bilhetagem-recarga/pull/58 (ajuste TASK-06 — rejeição de webhook sem assinatura válida). Aguardando code-evaluator (label auto-review)."
```

- Resultado esperado (se o MCP estivesse disponível): REC-21..REC-24 movidas de `To Do`/`In Progress`
  para `In Review`, com o comentário acima em cada issue.
- Não executado: MCP do Atlassian indisponível nesta máquina — mesma causa raiz da rodada anterior,
  ainda não resolvida. O pipeline **não bloqueia** por isso (degradação graciosa, conforme o agente).
- Ação registrada no tracker (Fase 4): manter o aviso de falha de sync, com nova tentativa datada.

## Fase 4 — Atualizar `PROGRESS-TRACKING.md` no main (simulado)

```bash
cd ../..   # raiz do checkout principal (fora do worktree da onda)
git checkout main
git pull --ff-only origin main
```

Edição planejada em `docs/product/modules/recarga/PROGRESS-TRACKING.md`:
- Acrescentar, ao bloco "Wave 2 (TASK-05..TASK-08)", uma linha de nota registrando o commit de ajuste
  `142544b` (TASK-06, pedido do code-evaluator) e a atualização do PR.
- Atualizar a seção "⚠️ Sync Jira falhou" com a data desta tentativa (2026-09-26) e manter o "Retry"
  apontado, já que o MCP segue indisponível.

```bash
git add docs/product/modules/recarga/PROGRESS-TRACKING.md
git commit -m "docs(specs): recarga wave 2 — ajuste TASK-06 (code-evaluator) e novo PR update"
git push origin main
```

- Não executado: sem remoto/push real neste ambiente; a edição simulada foi aplicada apenas em
  `work/` (cópia local) e uma prévia está descrita abaixo.

## Fase 4.5 — Avançar status SDD do change (simulado, mas seguro de checar)

```bash
bash .forge/scripts/spec-advance-module.sh recarga implementing || true
```

- O `manifest.yaml` do change `recarga-pix` já está em `status: implementing` (a rodada anterior já
  aplicou este passo) — chamada seria no-op idempotente. Não avança para `implemented` porque o
  tracker ainda tem TASKs `[ ]` não marcadas `[X]` para a onda 2 nesta captura de fixture (nota: a
  fixture usada para este eval reflete o tracker da rodada anterior, que ainda mostra as TASKs da
  onda 2 como `[ ]`, mesmo com PR aberto — divergência pré-existente no fixture, não introduzida por
  esta rodada; sinalizada em `outputs/resultado.json` como observação, não corrigida aqui porque
  foge do escopo desta invocação, que é reabrir o PR/retomar Jira, não reconciliar o tracker).

## Fase 5 — Output ao operador (simulado)

Ver `outputs/resultado.json`.
