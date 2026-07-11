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

3. **Promoção a change** — quando uma entrada do ledger vira trabalho ativo, abra o change
   (`/forge:spec new`) e ligue-a com `/forge:ledger promote <LDG-NNNN> --to <change-id>` (marca
   `status: promoted`, registra `links.promoted_to`). Assim o ledger não re-sugere o que já virou
   change.

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
