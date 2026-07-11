---
title: Consulta ao ledger durável (roadmap & dívida técnica)
applies_to:
  - all
priority: high
last_reviewed: 2026-07-11
based_on: []
---

# Consulta ao ledger — o que fazer a seguir nasce do `LEDGER.md`

## Princípio

O projeto mantém um **ledger durável** (`.forge/ledger/ledger.json`, com a view humana
`.forge/ledger/LEDGER.md`) — o registro que sobrevive entre changes de roadmap, dívida técnica,
bugs conhecidos, follow-ups e ideias de feature. É a fonte canônica de "trabalho conhecido ainda
não feito". Operado por `/forge:ledger` (script `ledger-ops.sh`); ver o comando para a mecânica.

## Regras operacionais

1. **Ao sugerir o próximo trabalho** — sempre que o usuário pedir "o que implementar agora / o que
   falta / sugira o próximo passo", **consulte primeiro** `.forge/ledger/LEDGER.md` (ou
   `ledger-ops.sh list --status open --by-priority`). As entradas `open`/`planned` de maior
   prioridade são os candidatos naturais. Não invente um backlog do zero se o ledger já o tem.

2. **No `/forge:resume`** — o mandato de retomada lê o estado do change ativo **e** os itens de
   maior prioridade do ledger, para que o "Próximo passo lógico" reflita tanto o change em curso
   quanto o roadmap durável.

3. **Promoção a change (elo bidirecional, ciclo fechado)** — quando uma entrada do ledger vira
   trabalho ativo, abra o change **declarando o elo**: `/forge:spec new <id> --type … --from-ledger
   <LDG-NNNN>`. Isso marca a entrada `promoted` (some da lista ativa, não é re-sugerida) **e** grava
   `ledger_origin` no manifest, o que fecha o ciclo **automaticamente e sem depender de memória**:
   - `/forge:archive` → entrada vira `resolved` (entregue ao baseline);
   - `/forge:close --reason abandoned|rejected` → entrada **reaberta** (`open`, volta ao roadmap —
     não foi entregue);
   - `/forge:close --reason delivered-externally` → `resolved`;
   - `superseded` → permanece `promoted` (o sucessor carrega o item).

   Se o change já foi criado sem o flag, ligue manualmente com `/forge:ledger promote <LDG-NNNN>
   --to <change-id>` (mas aí a baixa/reabertura no fim vira manual — prefira `--from-ledger`). Para
   marcar "comecei a mexer" sem abrir change ainda: `/forge:ledger update <LDG-NNNN> --status
   in-progress`. O `/forge:doctor` sinaliza itens `promoted` cujo change de destino sumiu sem baixa.

4. **Semeadura** — o ledger pode **nascer** com o plano do projeto: módulos, features e decisões de
   arquitetura previstos entram como entradas `roadmap`/`feature-idea` (`/forge:ledger add`). Num
   redesign amplo, as entradas de módulos planejados são o esqueleto do roadmap. (Integração
   automática do pipeline de spec → ledger é evolução futura; hoje a semeadura é explícita.)

## Fronteira com outros mecanismos (não confundir)

- **Deferral** (`/forge:defer`) — pendência **escopada ao change atual**, **bloqueante** (trava o
  close), **efêmera**. Use quando a pendência é daquele change. Se for descoberta transversal que
  não deve travar, é ledger, não deferral. No close/archive, deferrals `open`/`wont-fix` são
  **colhidos automaticamente** para o ledger (nada se perde).
- **Backlog** (`/forge:backlog`) — derivado de specs **já aprovadas**, gate humano, execução. O
  ledger é upstream disso: captura o que ainda **não** virou spec.
- **ADR** — decisão arquitetural aceita. Uma entrada de ledger pode **originar** um ADR, mas o
  ledger em si não é registro de decisão.

## Não-bloqueante por design

Registrar no ledger **nunca** trava um change, um gate ou um archive. O objetivo é garantia de
memória ("nada se perde"), não enforcement. Bloqueio é papel de deferral/`analyze` (findings
BLOCKER), não do ledger.
