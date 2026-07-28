---
story_id: STORY-06
epic: security-observability-gates
title: Plugin, changelog e verificação final do change
depends_on: [STORY-01, STORY-02, STORY-03, STORY-04, STORY-05]
status: todo
---

# STORY-06 — Plugin, changelog e verificação final do change

> Story auto-contida derivada de `security-observability-gates`. Toda informação necessária para implementar
> esta story está aqui — sem precisar reler o change completo (§17.1). Ver também `../epic_context.md`.

## Goal

Fechar o change: regenerar `plugin/forge/**` refletindo todas as rules/comandos novos das stories anteriores, atualizar `CHANGELOG.md`, e rodar `tests/run-all.sh` completo garantindo 100% verde (gates novos + `gw3` + `w20` + demais suítes preexistentes). Wave 6 — última story, depende de todo o restante do change (TASK-01 a TASK-17).

## Embedded context

### Requirements

- REQ-17: quando o change é publicado, o sistema deve regenerar `plugin/forge/**` refletindo rules/comandos novos, e registrar um ADR no baseline documentando a decisão de substrato (já criado na STORY-01, TASK-05). `npm run build:plugin` passa e o diff do plugin reflete as rules novas; ADR criado, rules `based_on:` apontam a ele, `validate-rules.sh` sem drift; `CHANGELOG.md` atualizado.
- NFR-04: sem regressão — `tests/run-all.sh` permanece 100% verde após o change completo.

### Design

> §2.7: `plugin/forge/**` regenerado por `npm run build:plugin` (REQ-17), `CHANGELOG.md` atualizado. Esta é a etapa final de consolidação — não introduz lógica nova, apenas materializa o que as stories 1-5 já implementaram.

> §2.8 (fixtures e testes, NFR-04): os gates novos (`tests/wXX-authz-gate.sh`, `tests/wXX-observability-gate.sh`, `tests/wXX-graph-govern-gate.sh`, extensão de `gw3`) são auto-descobertos por `ls tests/*-gate.sh` em `run-all.sh` — nenhuma alteração manual no runner é necessária, só garantir que os arquivos de teste sigam a convenção de nome `*-gate.sh`. A suíte deve permanecer 100% verde.

> §5 (rollout): esta story fecha o "Expand silencioso" — nenhum consumidor real é tocado neste change (piloto axis-go-cloud é follow-up cross-repo, fora de escopo); o harness em si (este repo) valida tudo pelas fixtures.

### Contratos / interfaces

- `plugin/forge/**` — artefato gerado, não editado manualmente; regenerar via `npm run build:plugin`.
- `CHANGELOG.md` — entrada nova descrevendo o change `security-observability-gates`.

### Rules aplicáveis

- Todas as rules novas/estendidas das stories anteriores (`authz-pdp-pep.md`, `pii-pci-classification.md`, `observability.md`, `jwt-permissions.md`) devem estar refletidas no plugin regenerado.

### ADRs

- ADR de substrato (STORY-01, TASK-05) — confirmar que `based_on:` nas rules resolve corretamente após a regeneração do plugin.

## Tasks

- [ ] TASK-18 — Regenerar `plugin/forge/**` (`npm run build:plugin`) + atualizar `CHANGELOG.md` + rodar `tests/run-all.sh` completo garantindo 100% verde (gates novos + `gw3` + `w20`) (paths: `plugin/forge/`, `CHANGELOG.md`; depende: TASK-01..TASK-17 — todas as stories anteriores; DoD: run-all 100% verde; plugin reflete rules novas).

## Acceptance criteria

- [ ] `npm run build:plugin` executa sem erro; diff do plugin reflete as rules `authz-pdp-pep.md`, `pii-pci-classification.md`, `observability.md` (estendida) e `jwt-permissions.md` (atualizada).
- [ ] `CHANGELOG.md` tem entrada nova para `security-observability-gates` no formato Keep a Changelog do repositório.
- [ ] `tests/run-all.sh` roda 100% verde: gates novos (`check-authz`, `check-observability`, `check-data-governance` estendido, `graph-govern`) + suítes preexistentes (`gw3-data-governance-gate.sh`, `w20-spec-gate.sh`, `w30-schemas-gate.sh`, demais `w*`/`gw*`) sem regressão.
- [ ] Nenhum achado de gate aberto (gate-runner verde antes de `/forge:verify`).
- [ ] Commit atômico por task; nenhum `TODO`/`FIXME` residual.

## Out of scope

- Qualquer lógica de gate, schema, rule ou integração nova — tudo isso já foi entregue nas STORY-01 a STORY-05; esta story é puramente consolidação/publicação.
- Promoção `warn`→`enforce` em qualquer repo consumidor — decisão operacional via ledger, fora de escopo temporal deste change.
- Piloto axis-go-cloud — outro repo, follow-up cross-repo.
