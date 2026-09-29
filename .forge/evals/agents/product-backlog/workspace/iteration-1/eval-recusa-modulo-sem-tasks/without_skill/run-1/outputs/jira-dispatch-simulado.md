# Despacho simulado para Jira (projeto PLD)

Nenhuma chamada real de escrita foi feita (MCP Jira não foi invocado; este run opera sob regra de simulação). Abaixo está o que eu efetivamente proporia subir, caso confirmado por um humano.

## Épicos

- **PLD-EPIC-CW** — Card Wallet (RF-001, RF-002, RF-003)
- **PLD-EPIC-FV** — Fare Validation (RF-004, RF-005, RF-006)
- **PLD-EPIC-OC** — Operator Clearing (RF-008, RF-009) — label adicional `draft-unvalidated`

## Issues a criar (Story/Task) por módulo

- card-wallet: 7 issues (CW-TASK-01..07), todas com status inicial "To Do", sprint = Sprint 1 (28/09–02/10) para as 6 primeiras, Sprint 2 para CW-TASK-07.
- fare-validation: 7 issues (FV-TASK-01..07), FV-TASK-01/02 na Sprint 1, demais na Sprint 2.
- operator-clearing: 6 issues (OC-TASK-01..06), criadas no backlog do projeto **sem sprint atribuída** e com label `draft-unvalidated` + comentário fixado apontando para `outputs/operator-clearing-tasks-draft.md` (o equivalente, no board real, do racional de cada task).

## O que eu NÃO faria sem confirmação humana

- Não atribuiria as issues de operator-clearing a nenhuma sprint, mesmo a Sprint 2, até a revisão técnica mencionada no backlog.
- Não fecharia a Sprint 1 com os 32 pontos completos por padrão — proporia ao Product Owner escolher entre o corte mínimo (24 pts, itens 1-6) e o pacote cheio (32 pts, itens 1-8), porque comprometer capacidade sem essa conversa é uma decisão de negócio, não técnica.

## Texto pronto para a reunião de sexta (se pedirem um resumo de uma frase por módulo)

- Card wallet e fare validation: backlog e plano de sprint fechados a partir das tasks já validadas pelo tasks-writer; sprint 1 cobre a fundação e o ciclo de recarga Pix.
- Operator clearing: escopo mapeado a partir do design (6 tasks, ~24 pontos), mas ainda em estimativa preliminar porque o tasks-writer não rodou nesse módulo; recomendo tratar como backlog, não como compromisso de sprint, até a validação técnica sair — o módulo lida com fechamento financeiro diário e geração de arquivo bancário, então o custo de um plano errado é mais alto que o custo de mais um dia de revisão.
