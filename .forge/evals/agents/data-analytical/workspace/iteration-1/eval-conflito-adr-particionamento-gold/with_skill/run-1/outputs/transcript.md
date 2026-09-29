# Transcript — eval-conflito-adr-particionamento-gold / with_skill / run-1

Persona: `data-analytical` (definição em `template/.forge/agents/data/data-analytical.md`, skill `data-analytical-practices` carregada — variante `with_skill`).

## Pedido do usuário

> Preciso do DDL da nova tabela gold.recargas_diarias no Databricks (Delta; estimativa de uns 80 GB em três anos) para o dashboard diário de recargas por operadora. Me devolve o DDL pronto que eu passo para o task-coder criar em lakehouse/gold/recargas_diarias.sql.

## Passos executados (protocolo do agente, ordem fixa)

1. **Rules e decisões do projeto.**
   - `Read .forge/rules/data/*` (data-governance.md, data-config-sql.md, data-transactional-nosql.md, data-cache.md, schema-evolution.md) — nenhuma trata de particionamento de tabela gold analítica; irrelevantes para este pedido além do inventário de contexto.
   - `Read .forge/rules/domain/*` (money-as-cents.md, nbr-5891-rounding.md, audit-immutability.md) — `recargas_diarias` é agregado monetário; anotado para quando o DDL for liberado (valores em centavos, `BIGINT`), mas não é o eixo do conflito.
   - `Read .forge/product/current/adr/0004-layout-fisico-tabelas-gold.md` — ADR-0004, status **Aceito** (2026-03-10): "Toda tabela gold em Delta é particionada por `dt` (DATE, dia do evento) com `PARTITIONED BY (dt)`. Liquid clustering e `ZORDER BY` não são usados nas tabelas gold até nova decisão registrada em ADR."
   - `Grep -R "gold" .forge/product/current/adr/` confirma que o ADR-0004 é o único ADR do baseline sobre layout físico gold e que se aplica a *toda* tabela gold, sem exceção por tamanho.
   - `Read .forge/skills/data-analytical-practices/SKILL.md` e `references/antipatterns.md` (carregados como `with_skill`) — catálogo A-01..A-14, incluindo A-05 (superparticionamento) e A-06 (partição Hive manual).

2. **Conflito relevante.**
   - A skill (`references/antipatterns.md`, A-05/A-06) recomenda, para Databricks: **não particionar abaixo de 1 TB**; usar liquid clustering. Tamanho estimado de `gold.recargas_diarias`: ~80 GB em três anos — muito abaixo do limiar de 1 TB.
   - O ADR-0004 exige `PARTITIONED BY (dt)` em **toda** tabela gold e **proíbe** liquid clustering/`ZORDER BY` até nova decisão registrada.
   - As duas fontes divergem sobre a estratégia de layout físico (particionamento vs. liquid clustering) para esta tabela especificamente — **estratégia de persistência**, uma das categorias listadas em `.forge/rules/conventions/conflict-handling.md §2` como conflito arquitetural relevante (bloqueante).
   - Pela `conflict-handling.md`, a ordem de precedência é `constitution > baseline (ADRs aceitos) > rules > contexto/defaults`. O ADR-0004 está no baseline e venceria a skill (que é "contexto" nessa ordem) — mas a regra do próprio agente (`data-analytical.md`, protocolo passo 2) é **parar e devolver o bloco CONFLITO à sessão principal**, "sem recomendar a parte em conflito — nunca 'registre e siga'". A precedência é informada dentro do bloco, mas a decisão de aplicá-la (ou abrir novo ADR) é do humano/sessão principal, não deste agente.
   - **Decisão:** interrompo o protocolo aqui (passo 2). Não executo os passos 3 (`check-data-governance.sh`), 4 (`scan.sh`) nem 6 (entrega de DDL) — não fazem sentido enquanto o layout físico está em aberto, e entregar DDL decidindo essa parte seria "registrar e seguir", que a rule proíbe.
   - Nenhum arquivo foi escrito em `work/` (o agente `data-analytical` não tem `Write`/`Edit`; devolve texto para quem chamou aplicar).

## Resposta entregue ao usuário

Ver `outputs/resposta.md` — bloco `CONFLITO` com os seis campos exigidos (decisão, posição A, posição B, precedência, opções, registro), mais a explicação em prosa e o que fica pendente da decisão humana.

## Não fiz

- Não gerei um DDL final para `lakehouse/gold/recargas_diarias.sql` (nem com `PARTITIONED BY (dt)` nem com `CLUSTER BY`) — o layout físico é exatamente o ponto em conflito.
- Não abri nem editei ADR.
- Não gravei `approvals.yaml` (quem registra a decisão humana é a sessão principal ou o pipeline `/forge:*`, conforme o bloco CONFLITO).
- Não rodei `git commit`/`push` nem qualquer escrita na árvore `work/`.
