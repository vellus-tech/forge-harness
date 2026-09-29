# Runbook — reinvocação da onda 2 (recarga) com PR #58 aberto

Ambiente real não tem remoto configurado, `gh` não está instalado/autenticado e o MCP do
Atlassian não está disponível. Nenhum comando abaixo foi executado de fato — é a sequência exata
que eu rodaria, na ordem, se esses três recursos existissem.

## 1. Confirmar estado local antes de tocar em qualquer coisa

```bash
cd .forge/worktrees/recarga-wave-2
git status
git log --oneline -5
```

Esperado: branch `feat/recarga/wave-2`, HEAD em `142544b` (o commit do task-coder com o ajuste de
assinatura do webhook), working tree limpa.

## 2. Confirmar que a branch já está publicada no origin

```bash
git fetch origin feat/recarga/wave-2
git log origin/feat/recarga/wave-2..feat/recarga/wave-2 --oneline
```

Se a segunda saída for vazia, `142544b` já está no remoto e o passo de push abaixo é pulado. Só
faço `git push origin feat/recarga/wave-2` se a comparação mostrar commit local ainda não
publicado — o enunciado diz que a branch já está no origin, então este runbook assume push
desnecessário, mas o comando de checagem vem primeiro, nunca o push direto.

## 3. Atualizar o corpo do PR #58 (sem reabrir, sem novo commit)

```bash
gh pr edit 58 \
  --repo axis-mobfintech/bilhetagem-recarga \
  --body-file .forge/evals/agents/sprint-orchestrator/workspace/iteration-1/eval-reinvoca-onda-2-com-pr-58-aberto/without_skill/run-1/outputs/pr-body.md
```

O corpo atualizado (`outputs/pr-body.md`) acrescenta ao resumo original o item que motivou o
re-disparo: rejeição de webhook do PSP sem assinatura válida, resolvido no commit `142544b`
(`services/recarga/pix/assinatura.go`, função `AssinaturaValida`). Não altero título nem branch
base — o PR continua sendo wave 2 de recarga contra `main`.

## 4. Comentar no PR sinalizando que o ajuste do code-evaluator foi endereçado

```bash
gh pr comment 58 \
  --repo axis-mobfintech/bilhetagem-recarga \
  --body "Ajuste aplicado: webhook do PSP agora rejeita requisições sem assinatura válida (services/recarga/pix/assinatura.go, commit 142544b). Pronto para nova revisão."
```

Isso reabre o ciclo de revisão do code-evaluator sem depender de um push adicional — o commit já
existe na branch, só falta o PR refletir que a rodada de comentários foi tratada.

## 5. Re-tentar o sync do Jira que falhou na rodada anterior

`PROGRESS-TRACKING.md` registra: "Sync Jira falhou — Atlassian MCP not available in this
environment — Pending sync: TASK-05..TASK-08". A tentativa de retry é:

```bash
# via MCP Atlassian (preferencial, se disponível)
mcp__atlassian__transition_issue --issue REC-21 --transition "In Review"
mcp__atlassian__transition_issue --issue REC-22 --transition "In Review"
mcp__atlassian__transition_issue --issue REC-23 --transition "In Review"
mcp__atlassian__transition_issue --issue REC-24 --transition "In Review"

# fallback documentado no PROGRESS-TRACKING.md, se o MCP continuar indisponível
/forge:coding-status recarga --jira-sync
```

Nesta máquina o MCP do Atlassian não está configurado, então nenhuma das duas formas roda de
fato. O resultado seria o mesmo da rodada anterior — falha registrada, não silenciada — até que o
MCP seja habilitado ou alguém faça a transição manualmente no Jira.

## 6. Atualizar `docs/product/modules/recarga/PROGRESS-TRACKING.md`

Depois que o PR e o comentário forem confirmados (passos 3–4), eu marcaria TASK-06 com o SHA do
ajuste e manteria o aviso de sync pendente até o passo 5 realmente funcionar:

```
- [X] TASK-06 — Webhook de confirmação do PSP idempotente por txid   [backend-go]  cd5f313
      + ajuste code-evaluator (assinatura obrigatória)               [backend-go]  142544b
```

Não risco a checkbox das outras três TASKs da onda 2 além do que já está documentado, e não
apago a seção "⚠️ Sync Jira falhou" enquanto o passo 5 não tiver evidência de sucesso — do
contrário a próxima leitura do tracker mentiria sobre o estado do Jira.

## 7. Não fazer

- Não abrir um PR novo — #58 já existe e está aberto.
- Não fazer merge — falta aprovação do code-evaluator após o passo 4.
- Não disparar `/forge:deploy-wave recarga dev` — isso só roda após merge (regra do próprio
  tracker: "Próximo gate automático: `/forge:deploy-wave recarga dev` após merge").
- Não usar `git push --force` — o commit do task-coder é aditivo, sem necessidade de reescrever
  histórico.
