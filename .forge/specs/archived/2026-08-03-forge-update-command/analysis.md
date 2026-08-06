# Analysis — forge-update-command (scale 3)

> Cross-artifact (proposal × requirements × design × tasks × convenções). Substitui
> `/forge:analyze`/`/forge:impact` (grafo não materializado na raiz do harness-source).

## Consistência REQ ↔ design ↔ tasks

| REQ | Design | Tasks | Status |
|---|---|---|---|
| REQ-01 | §2.1/2.2 | 01,02 | OK |
| REQ-02 | §2.2 | 02 | OK |
| REQ-03 | §2.2 | 02 | OK |
| REQ-04 | §2.3 | 03 | OK |
| REQ-05 | §2.2 | 03 | OK |
| REQ-06 | §2.2/2.4 | 01,04 | OK |
| REQ-07 | §2.5 | 05 | OK |
| REQ-08 | §2.6 | 06 | OK |
| REQ-09 | §4 | 07,08,09 | OK |

Sem REQ órfão, sem task sem rastreio, sem `NEEDS CLARIFICATION`.

## Cobertura de superfície

`update`/`--target`/`--source`/`--dry-run`/`--no-backup`/`--no-plugin` → CLI (TASK-01). `/forge:upgrade`
→ slash (TASK-05). Demais REQs sem parâmetro exposto. Sem parâmetro implementado sem superfície.

## Impacto (manual)

- **`bin/forge.mjs`** — arquivo central do CLI publicado. Blast radius: `npx-pack-gate`, `w13-init-gate`
  (testam init/install.sh, não update — não regridem se o update for aditivo). Mitigação: `update` não
  toca o caminho de `init`; gates existentes continuam válidos.
- **`doctor.sh`** — afrouxar a varredura pode teoricamente esconder vazamento real. Mitigação: exclui só
  dirs de **dado** (`specs/worktrees/product/evals/custom`); a maquinaria (`agents/commands/scripts/...`)
  segue varrida. Cobertura: o próprio doctor roda em `w13`/`npx-pack`.
- **`plugin/forge/**`** — +1 comando; `plugin-sync-gate` trava sincronia.

## Ordem / dependências

W1 (01→02→03, 04 depende de 02) → W2 (05 depende de 03; 06 independente) → W3 (07,08 dependem de 04) →
W4 (09 depende de 05+08). Sem ciclo.

## Riscos residuais

Ver design §6. Nenhum bloqueia o início. O maior é a regex de `template_version` — coberta por assert
explícito no w63 (adapters intactos).
