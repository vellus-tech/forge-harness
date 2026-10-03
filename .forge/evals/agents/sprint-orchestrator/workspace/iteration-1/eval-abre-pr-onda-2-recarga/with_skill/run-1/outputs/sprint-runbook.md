# Runbook — sprint-orchestrator — recarga, onda 2 (Recarga via Pix)

> Simulação. Nenhum comando abaixo foi executado de fato: esta máquina não tem `origin`
> configurado, `gh` não está autenticado e o MCP Atlassian não está conectado nesta sessão.
> O que segue é exatamente o que o `sprint-orchestrator` rodaria, na ordem, com os valores
> já resolvidos deste repositório (`AGENTS.md`: `repo_slug=axis-mobfintech/bilhetagem-recarga`,
> `default_branch=main`, `jira_key=REC`, `jira_site=axis-mobfintech.atlassian.net`).

## Estado observado antes de agir

- Branch da onda: `feat/recarga/wave-2`, worktree `.forge/worktrees/recarga-wave-2` (relativo à raiz do repo).
- Working tree do worktree: limpo (`git status --porcelain` vazio).
- Commits da onda (`git log --oneline` no worktree, do mais novo ao mais antigo):
  - `3141c4d` chore(specs): recarga onda 2 — 4/4 TASKs concluídas
  - `4a7dd07` chore(specs): TASK-08 — concluída
  - `3c70e95` feat(recarga): TASK-08 — expirar cobrança Pix após 30 minutos
  - `598fbe6` feat(recarga): TASK-07 — creditar saldo após confirmação do PSP
  - `cd5f313` feat(recarga): TASK-06 — webhook do PSP idempotente por txid
  - `ad7cfe5` feat(recarga): TASK-05 — gerar cobrança Pix dinâmica com txid único
  - `bf57d45` feat(recarga): onda 1 — cadastro de cartão e consulta de saldo (#41) — base comum com `main`
- `docs/product/modules/recarga/PROGRESS-TRACKING.md` em `main` ainda mostra a onda 2 como
  `⏳ Pendente` com as 4 TASKs em `[ ]` — está desatualizado em relação ao handoff do
  task-coder (todas [X]); é este runbook que traz a atualização pendente.
- `.forge/specs/active/recarga-pix/manifest.yaml`: `status: tasks-ready`, `affected_paths`
  inclui `docs/product/modules/recarga/` e `services/recarga/` → mapeia 1:1 para o módulo
  `recarga` (nenhuma ambiguidade para o `spec-advance-module.sh`).

## Fase 1 — Push da branch da onda

```bash
cd .forge/worktrees/recarga-wave-2

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)   # feat/recarga/wave-2
[ "$CURRENT_BRANCH" = "feat/recarga/wave-2" ] || { echo "Branch mismatch"; exit 1; }

[ -z "$(git status --porcelain)" ] || { echo "Working tree dirty"; exit 1; }

if git ls-remote --exit-code --heads origin feat/recarga/wave-2 >/dev/null 2>&1; then
  git push --force-with-lease origin feat/recarga/wave-2
else
  git push -u origin feat/recarga/wave-2
fi
```

Bloqueado nesta máquina: não há remoto `origin` configurado (`git remote -v` vazio no
worktree principal). Não executado.

## Fase 2 — Abrir PR

```bash
EXISTING_PR=$(gh pr list --repo axis-mobfintech/bilhetagem-recarga \
  --head feat/recarga/wave-2 --json number,url,state --jq '.[0]')

# EXISTING_PR vazio (primeira abertura desta onda) → cria:
PR_URL=$(gh pr create \
  --repo axis-mobfintech/bilhetagem-recarga \
  --base main \
  --head feat/recarga/wave-2 \
  --title "feat(recarga): wave 2 — Recarga via Pix" \
  --body-file outputs/pr-body.md \
  --label auto-review)
PR_NUMBER=$(echo "$PR_URL" | grep -oE '[0-9]+$')
```

Corpo do PR já preparado em `outputs/pr-body.md` (conteúdo final, pronto para `--body-file`).
Bloqueado: `gh` não autenticado nesta máquina. Não executado.

## Fase 3 — Sync Jira (MCP atlassian)

Para cada `task_id` da onda, a chamada seria:

```
mcp__atlassian__searchJiraIssuesUsingJql(
  jql: "project = REC AND labels = task:TASK-05"
)
# repetir para TASK-06, TASK-07, TASK-08

# para cada issue encontrado (esperado 1 por task_id):
mcp__atlassian__getTransitionsForJiraIssue(issueKey: "<key>")
mcp__atlassian__transitionJiraIssue(issueKey: "<key>", transition: "In Review")
mcp__atlassian__addCommentToJiraIssue(
  issueKey: "<key>",
  comment: "🤖 sprint-orchestrator: PR aberto em https://github.com/axis-mobfintech/bilhetagem-recarga/pull/<PR_NUMBER>. Aguardando code-evaluator (label auto-review)."
)
```

Bloqueado: MCP Atlassian não conectado nesta sessão. Não executado. As chaves reais
(`REC-NN`) não foram consultadas — a estimativa `REC-21..REC-24` no `pr-body.md` é só
continuidade da numeração da onda 1 (`REC-17..REC-20`), não confirmada.

Caso este passo rodasse de verdade e falhasse por MCP indisponível, o próprio agente
registraria o aviso abaixo em `PROGRESS-TRACKING.md` (Fase 3, degradação graciosa —
não bloqueia a abertura do PR):

```markdown
### ⚠️ Sync Jira falhou
- Reason: Atlassian MCP not available in this environment
- Pending sync: TASK-05..TASK-08 (issues to move to "In Review")
- Retry: re-run `/forge:coding-status recarga --jira-sync`
```

## Fase 4 — Atualizar PROGRESS-TRACKING.md em `main`

```bash
git checkout main
git pull --ff-only origin main
```

Edição em `docs/product/modules/recarga/PROGRESS-TRACKING.md` — linha da tabela e bloco
de fechamento da onda (conteúdo exato abaixo, pronto para aplicar via `Edit`):

```markdown
| 2    | 🔄 In Review | 4 | 4 | 0 | #<PR_NUMBER> |
```

```markdown
## Wave 2 (TASK-05..TASK-08) — Recarga via Pix 🔄 IN REVIEW

- ✅ Todas as 4 TASKs concluídas
- 📝 PR: https://github.com/axis-mobfintech/bilhetagem-recarga/pull/<PR_NUMBER>
- 🤖 Aguardando code-evaluator (label auto-review aplicada)
- 🎫 Jira: REC-21..REC-24 → `In Review` (a confirmar — ver Fase 3)
- Próximo gate humano: aprovar merge após `APPROVED`
- Próximo gate automático: `/forge:deploy-wave recarga dev` após merge
```

```bash
git add docs/product/modules/recarga/PROGRESS-TRACKING.md
git commit -m "docs(specs): recarga wave 2 — aguardando review"
git push origin main
```

Bloqueado: regra do ambiente proíbe `git commit`/`git push`/`git checkout` nesta sessão,
e esta máquina não tem `origin`. Não executado — nem no worktree, nem em `main`.

## Fase 4.5 — Avançar status SDD do change (`recarga-pix`)

```bash
bash .forge/scripts/spec-advance-module.sh recarga implementing || true
```

Change `recarga-pix` já mapeado 1:1 pelo `affected_paths` (`docs/product/modules/recarga/`,
`services/recarga/`) — sem ambiguidade. Estado atual do manifest: `status: tasks-ready`,
logo essa chamada avançaria `tasks-ready → implementing`.

```bash
TRK="docs/product/modules/recarga/PROGRESS-TRACKING.md"
if ! grep -qE '^[[:space:]]*[-*]?[[:space:]]*\[[ !-]\]' "$TRK" \
   && grep -qE '^[[:space:]]*[-*]?[[:space:]]*\[[xX]\]' "$TRK"; then
  bash .forge/scripts/spec-advance-module.sh recarga implemented || true
fi
```

Condição da guarda: **falsa** com o `PROGRESS-TRACKING.md` atual (a onda 2 ainda está em
`[ ]` nele — só ficaria `[X]` depois da edição da Fase 4). Ou seja, na ordem real do
pipeline a Fase 4.5 "implemented" só dispararia depois que a Fase 4 marcasse a onda 2
como concluída no tracker. Como a Fase 4 não foi aplicada (bloqueada), esta chamada
também não avançaria para `implemented` — ficaria em `implementing`.

Não executado: depende da Fase 4 (que está bloqueada) e, por ser uma chamada que muta
`manifest.yaml` do change ativo no worktree principal, foi tratada como escrita externa ao
escopo desta simulação.

## Ordem final resumida

1. `git push -u origin feat/recarga/wave-2` (worktree `recarga-wave-2`) — bloqueado, sem `origin`.
2. `gh pr create ... --label auto-review` com `outputs/pr-body.md` — bloqueado, `gh` não autenticado.
3. Jira: JQL por `task:TASK-05..08` → transition `In Review` → comentário com link do PR — bloqueado, MCP Atlassian ausente.
4. `git checkout main && git pull --ff-only` + edição do tracker + `git commit` + `git push origin main` — bloqueado pela regra do ambiente (nunca commit/push/checkout) e pela ausência de `origin`.
5. `bash .forge/scripts/spec-advance-module.sh recarga implementing` (e, condicionalmente, `implemented`) — bloqueado por depender da Fase 4 e por ser escrita fora do escopo autorizado desta simulação.
