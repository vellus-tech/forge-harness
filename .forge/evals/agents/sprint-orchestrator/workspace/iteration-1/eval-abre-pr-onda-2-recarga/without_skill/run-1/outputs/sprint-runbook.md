# Runbook — abertura do PR da onda 2 (recarga)

> Esta sessão não tem `origin` configurado nem `gh` autenticado nesta máquina, e o MCP do Atlassian
> não está conectado. Nada abaixo foi executado — é a sequência exata que eu rodaria, com os valores
> já resolvidos deste repositório, para o operador rodar manualmente ou reautorizar a automação.

## 0. Pré-condições verificadas localmente

```
git -C . remote -v
# (vazio — sem origin configurado)

git -C .forge/worktrees/recarga-wave-2 status
# On branch feat/recarga/wave-2, nothing to commit, working tree clean

git -C .forge/worktrees/recarga-wave-2 log --oneline -5
# 3141c4d chore(specs): recarga onda 2 — 4/4 TASKs concluídas
# 4a7dd07 chore(specs): TASK-08 — concluída
# 3c70e95 feat(recarga): TASK-08 — expirar cobrança Pix após 30 minutos
# 241d41e chore(specs): TASK-07 — concluída
# 598fbe6 feat(recarga): TASK-07 — creditar saldo após confirmação do PSP
```

Onda 2 fechada 100% (4/4 TASKs `[X]` no PROGRESS-TRACKING.md), árvore limpa, nada para commitar.

## 1. Configurar o remoto (uma vez, fora desta automação)

```
git remote add origin git@github.com:axis-mobfintech/bilhetagem-recarga.git
```

`repo_slug` já está em `AGENTS.md`: `axis-mobfintech/bilhetagem-recarga`.

## 2. Autenticar o gh (uma vez, fora desta automação)

```
gh auth login --hostname github.com --git-protocol ssh --web
```

## 3. Publicar a branch da onda

```
git -C .forge/worktrees/recarga-wave-2 push -u origin feat/recarga/wave-2
```

## 4. Abrir o PR

```
gh pr create \
  --repo axis-mobfintech/bilhetagem-recarga \
  --base main \
  --head feat/recarga/wave-2 \
  --title "feat(recarga): wave 2 — Recarga via Pix" \
  --body-file outputs/pr-body.md
```

Corpo do PR em `outputs/pr-body.md` (resumo + escopo TASK-05..08 + rastreabilidade + como testar).

## 5. Sincronizar Jira (via MCP Atlassian, não conectado nesta sessão)

```
# Mover as issues da onda 2 de "In Progress" para "In Review"
jira transition REC-21 --status "In Review"
jira transition REC-22 --status "In Review"
jira transition REC-23 --status "In Review"
jira transition REC-24 --status "In Review"

# Comentar o link do PR em cada issue
jira comment REC-21 "PR aberto: <url-do-pr>"
jira comment REC-22 "PR aberto: <url-do-pr>"
jira comment REC-23 "PR aberto: <url-do-pr>"
jira comment REC-24 "PR aberto: <url-do-pr>"
```

Os IDs REC-21..24 são inferidos por continuidade da onda 1 (REC-17..20, conforme
`docs/product/modules/recarga/PROGRESS-TRACKING.md`) — **não confirmados no Jira real**, já que o
MCP Atlassian não está conectado nesta sessão. Confirmar os IDs corretos antes de rodar a transição.

## 6. Atualizar PROGRESS-TRACKING.md com o link do PR

Depois do PR aberto, substituir a linha da onda 2 na tabela
(`docs/product/modules/recarga/PROGRESS-TRACKING.md`), coluna `PR`, de `-` para a URL retornada por
`gh pr create`, e no bloco de detalhe da onda 2 acrescentar a mesma referência que a onda 1 já tem
("PR: https://...", "Jira: REC-xx..REC-yy → In Review").

## 7. O que eu NÃO fiz nesta simulação

- Não configurei remoto, não autentiquei `gh`, não fiz `git push`, não abri PR real, não chamei o
  MCP do Atlassian e não escrevi em `.forge/ledger` nem `.forge/liaison`.
- Se esta tarefa tivesse instruído a spawnar um subagente para qualquer um dos passos acima, o
  despacho registrado seria: agente `sprint-orchestrator` (ou um `general-purpose` sob o protocolo
  do skill-creator), modelo `sonnet`, prompt resumido "publicar `feat/recarga/wave-2`, abrir PR com
  o corpo de `outputs/pr-body.md` e sincronizar REC-21..24 para In Review via MCP Atlassian" — não
  spawnado, por instrução explícita desta rodada de eval.
