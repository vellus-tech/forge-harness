---
description: Ledger durável de projeto (roadmap & dívida técnica). Registra e consulta trabalho conhecido que sobrevive entre changes — roadmap, dívida técnica, bugs conhecidos, follow-ups, ideias de feature. Alimentado por captura automática (harvest no close/archive) + curadoria manual. NÃO-BLOQUEANTE. Operado por script determinista.
argument-hint: "[list|add|update|resolve|promote|render|status] [flags]"
---

# /forge:ledger — ledger durável de projeto

Argumentos: `$ARGUMENTS`. Sem subcomando, mostra o ledger (equivale a `list`) e o caminho do
arquivo mestre `.forge/ledger/LEDGER.md`.

> **Por que existe:** o `deferrals.json` é escopado a um change, bloqueante e efêmero (morre no
> archive). O ledger é o oposto: **durável** (sobrevive entre changes, vive em `.forge/ledger/`,
> preservado pelo `forge update`), **não-bloqueante** (registrar aqui nunca trava um change) e
> **de projeto** (nada se perde entre uma spec e outra). Fonte consultada por `/forge:resume` e ao
> sugerir o próximo trabalho — ver `rules/conventions/ledger-consultation.md`.

## Protocolo

Tudo é operado pelo script determinista (IDs `LDG-NNNN`, escrita atômica, re-render do `LEDGER.md`
a cada mutação, `created_at` = data do commit HEAD, sem wall clock):

```bash
# consultar
bash .forge/scripts/ledger-ops.sh list [--status open] [--type <t>] [--top N] [--by-priority]
bash .forge/scripts/ledger-ops.sh status                      # one-line (usado por /forge:status)

# registrar / semear (type: roadmap | tech-debt | known-bug | follow-up | feature-idea)
bash .forge/scripts/ledger-ops.sh add --type <t> --title "<txt>" \
  [--detail "<txt>"] [--severity BLOCKER|HIGH|MEDIUM|LOW] [--priority P0|P1|P2|P3] \
  [--change <change-id>] [--ref <ref>] [--adr <ADR>] [--capability <cap>]

# ciclo de vida de uma entrada
bash .forge/scripts/ledger-ops.sh update  <LDG-NNNN> [--status <s>] [--priority P1] [--severity HIGH] [--title "<txt>"] [--detail "<txt>"]
bash .forge/scripts/ledger-ops.sh resolve <LDG-NNNN> --note "<como foi resolvido>"
bash .forge/scripts/ledger-ops.sh promote <LDG-NNNN> --to <change-id>   # virou um change (status: promoted)

# regenerar a view mestre
bash .forge/scripts/ledger-ops.sh render                      # .forge/ledger/LEDGER.md
```

## Captura automática (o ledger se alimenta sozinho)

Você **não** precisa lembrar de registrar findings — o harness colhe por construção:

- `/forge:close` e `/forge:archive` rodam `ledger-ops.sh harvest <id>` **antes de mover a pasta do
  change** (onde o dado morreria): deferrals `open` → `follow-up`, `wont-fix` → `tech-debt`,
  findings `MEDIUM`/`LOW` do `analysis.md` → `tech-debt`, desvios/RESSALVAS do `verification.md`
  → `follow-up`. Idempotente (dedup por `${change_id}:${ref}`).
- Como decidir manualmente vs. deixar automático: use `add` para **semear** roadmap/features/
  arquitetura planejados (ex.: os módulos de um redesign) e para capturar uma descoberta na hora;
  deixe o harvest cuidar do que sai de `analyze`/`verify`/`defer`.

## Quando usar

- **Semear** o roadmap no início de um projeto/redesign (entradas `roadmap`/`feature-idea`).
- **Registrar** na hora uma dívida técnica, bug conhecido ou ideia que surgiu fora do escopo do
  change atual — em vez de abrir um deferral (que bloquearia) ou perder.
- **Consultar** antes de decidir o próximo trabalho ou promover uma entrada a um change
  (`promote` + `/forge:spec new`).

## Regras

- **Não-bloqueante:** o ledger nunca trava um change. Falha bloqueante = deferral/analyze, não ledger.
- **Não edite `LEDGER.md` à mão** (exceto a seção "Notas"): é gerado do `ledger.json`. Edições vão
  via `/forge:ledger`.
- Emita one-line de confirmação com o ID afetado (`LDG-NNNN ...`).
