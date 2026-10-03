# Despacho simulado — sync Jira (projeto PLD)

Esta sessão não tem mandato para executar ações externas reais (chamadas ao MCP do Jira). O que
segue é o plano exato — nenhum passo foi executado de fato — para uma sessão autorizada aplicar,
em ordem, restaurando a sincronização do backlog local com o projeto Scrum **PLD**.

## Pré-condição

Aguardar a janela de rate limit reportada em 2026-09-25T18:04:02Z (HTTP 429) antes do passo 1 —
não emitir novas chamadas de escrita no projeto PLD antes disso.

## Passo 1 — Retry do épico EP-002 (fare-validation)

- Ferramenta: `mcp__jira` (criar issue)
- Projeto: PLD
- Tipo: Epic
- Summary: `fare-validation`
- Descrição: subdomínio Core, sem compliance associado (ver docs/product/modules/fare-validation/README.md)
- Ao concluir: gravar a issue key retornada em product-backlog.md §5, linha `EP-002`, e marcar
  "Última sync" com o timestamp real.

## Passo 2 — Stories US-004, US-005, US-006 (dependem de EP-002)

Só executar após o Passo 1 confirmar sucesso.

| Story | Summary | RF | Epic pai |
|---|---|---|---|
| US-004 | Como validador embarcado, quero enviar lotes offline, para que as tarifas sejam cobradas | RF-004 | issue key de EP-002 (Passo 1) |
| US-005 | Como passageiro, quero integração de 60 minutos, para pagar uma tarifa só | RF-005 | issue key de EP-002 (Passo 1) |
| US-006 | Como operador de backoffice, quero listar embarques das últimas 24h, para auditar contestações | RF-006 | issue key de EP-002 (Passo 1) |

Ao concluir cada uma: gravar a issue key em product-backlog.md §5.

## Passo 3 — Story US-007 (RF-007, card-wallet — story nova desta retomada)

- Ferramenta: `mcp__jira` (criar issue)
- Projeto: PLD
- Tipo: Story
- Summary: `Como passageiro, quero bloquear meu cartão perdido pelo app, para que ninguém use meu saldo`
- Epic pai: **PLD-1** (card-wallet, já sincronizado — não depende do Passo 1)
- RF: RF-007 | Story points: 5 | Sprint: Backlog não alocado (ver docs/product/backlog/sprints-planning.md §6)
- Este passo é independente dos Passos 1–2 e pode ser executado antes, em paralelo, ou depois —
  a ordem 1→2→3 aqui é só a ordem de prioridade sugerida (EP-002 estava bloqueado desde 2026-09-25).
- Ao concluir: gravar a issue key em product-backlog.md §5, linha `US-007`.

## Pós-condição

Depois dos 3 passos, atualizar docs/product/backlog/progress-tracking.md: mover a "Status geral"
de "Sync pendente" para "Sincronizado", e fechar as linhas correspondentes em §2 (Operações
pendentes de sincronização).
