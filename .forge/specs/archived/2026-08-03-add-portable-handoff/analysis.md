# Analysis — add-portable-handoff (scale 3)

> Análise cross-artifact (proposal × requirements × design × tasks × convenções) antes de implementar.
> Não altera artefatos. Substitui `/forge:analyze`/`/forge:impact` (grafo não materializado na raiz).

## Consistência REQ ↔ design ↔ tasks

| REQ | Design | Tasks | Status |
|---|---|---|---|
| REQ-01 | §2.1/2.2/2.7 | 01,02,04 | OK |
| REQ-02 | §2.1 | 02,03 | OK |
| REQ-03 | §2.3 | 06 | OK |
| REQ-04 | §2.4 | 07 | OK |
| REQ-05 | §2.5 | 11,12,13,14 | OK |
| REQ-06 | §2.6 | 08,09,10 | OK |
| REQ-07 | §4 | 05,10,14,15 | OK |

Sem REQ órfão, sem task sem rastreio, sem `NEEDS CLARIFICATION` pendente.

## Cobertura de superfície (do requirements)

- `<change-id>` → CLI (TASK-04). `handoff.auto` → `forge.yaml` (TASK-12). Gate → hook, sem parâmetro
  (TASK-08). Sem parâmetro implementado sem superfície.

## Impacto (manual, sem grafo)

Blast radius em componentes compartilhados:
- **`sync-adapters.mjs`** — tocado por TASK-07 (agents) e TASK-13 (claude). Consumidores: `doctor`
  (lockfile), `sync-adapters` command, todo projeto que regenera adapters. Mitigação: manter o formato
  baseline quando `handoff.auto=false` (byte-idêntico) → doctor/lock não driftam para quem não opta.
- **`hooks/git/pre-push`** — tocado por TASK-09. Consumidor: todo repo com `core.hooksPath` setado.
  Mudança de comportamento (bloqueio) é o objetivo; documentada.
- **`claude-contract.bats` C5** — quebra esperada (TASK-14) ao adicionar caminho de Session hooks.
- **`plugin/forge/**`** — regenerado (TASK-05); `plugin-sync-gate` trava sincronia.

## Ordem de execução / dependências

Waves W1→W6 respeitam deps. W1-W4 são independentes entre si exceto pelas deps internas; W5 depende de
W1 (script) e introduz a mudança de contrato; W6 depende de W2+W5 (contagem/docs finais) e é o que
exercita o gate novo no próprio push. Sem ciclo de dependência.

## Riscos residuais

Ver design §6. Nenhum bloqueia o início da implementação.
