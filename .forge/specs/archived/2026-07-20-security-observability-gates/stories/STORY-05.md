---
story_id: STORY-05
epic: security-observability-gates
title: Integração dos gates a verify, pre-push e CI via chave gates:
depends_on: [STORY-04]
status: todo
---

# STORY-05 — Integração dos gates a verify, pre-push e CI via chave gates:

> Story auto-contida derivada de `security-observability-gates`. Toda informação necessária para implementar
> esta story está aqui — sem precisar reler o change completo (§17.1). Ver também `../epic_context.md`.

## Goal

Introduzir a chave `gates:` (CSV escalar) no bloco `runtime:` do `FORGE.md`, lida por `get_runtime`/`fm_field` via awk, e acionar os três gates da STORY-04 a partir de `spec-verify.sh` e `hooks/git/pre-push`, com resultado registrado em `verification.yaml`/`run-manifest`. Wave 5 — depende dos três gates já implementados (STORY-04).

## Embedded context

### Requirements

- REQ-15: quando um change é verificado (`spec-verify.sh`), empurrado (`pre-push`) ou roda no CI, o sistema deve executar os novos gates (`check-authz`, `check-observability`, data-governance estendido) via declaração no `FORGE.md`, registrando resultado no run-manifest. Gates aparecem como checks no `spec-verify.sh` e no `pre-push`; resultado (pass/fail por gate) consta do `run-manifest.json`; `tests/run-all.sh` cobre os novos gates e permanece verde.

### Design

> §2.6: chave `gates:` cujo valor é uma **lista CSV escalar numa única linha** (ex.: `gates: check-authz,check-observability,check-data-governance`) — deliberadamente escalar, e não block-sequence, porque os leitores de `runtime:` são os parsers **awk** `get_runtime` (`spec-verify.sh`) e `fm_field` (`pre-push`), que extraem valor escalar de uma linha `key: value` e não leem sequências YAML multilinha.

> `spec-verify.sh` ganha, **após** o `for check in test typecheck lint` (linha 65), um loop que lê `gates:` via `get_runtime`, faz split por vírgula (`IFS=','`) e roda `check-<gate>.sh <id>` via o mesmo `run_check` (linhas 54-63) — resultado em `verification.yaml` (`CHECKS_YAML`) e, por consequência, no `run-manifest.sh write` (linhas 106-120).

> `pre-push` **hoje não tem loop** — faz duas chamadas explícitas `run_check "typecheck"`/`"test"` (§1 do design). O change acrescenta ali o mesmo split de `gates:` via `fm_field` e roda cada gate, que respeita seu `mode: warn|enforce` (os `warn` reportam sem bloquear o push; os inegociáveis sempre bloqueiam). No CI é a mesma chamada.

> `gates:` fica **dentro** de `runtime:` (chave escalar a mais que ambos os parsers já alcançam) e é admitida no `runtime` do `forge.schema.json` como string (já feito na STORY-01, TASK-03). **Assimetria intencional (AN-01 do analyze):** os blocos `authz:`/`observability:` continuam block-sequence (lidos por `graph-build.mjs` via `yaml-lite`); só `gates:`, lida por awk, precisa ser escalar CSV.

> `verification.schema.json` já aceita `checks[*]` arbitrários (nome/comando/status) — sem mudança de schema necessária para os checks novos.

### Contratos / interfaces

- `template/.forge/FORGE.md` — chave `gates:` nova em `runtime:` (ex.: `gates: check-authz,check-observability,check-data-governance`).
- `template/.forge/scripts/spec-verify.sh` — loop novo após `for check in test typecheck lint` (linha ~65).
- `template/.forge/hooks/git/pre-push` — split de `gates:` via `fm_field` + execução de cada gate.
- `verification.yaml`/`run-manifest.json` — checks novos aparecem em `CHECKS_YAML` sem mudança de schema.

### Rules aplicáveis

- Nenhuma rule nova nesta story — consome as rules já publicadas (STORY-02/03) indiretamente via comportamento dos gates.

### ADRs

- Nenhum ADR novo — referencia o ADR de substrato (STORY-01) apenas como contexto de por que os gates existem.

## Tasks

- [ ] TASK-17 — Chave `gates:` (CSV escalar numa linha) no bloco `runtime:` do `FORGE.md`, lida por `get_runtime`/`fm_field` + split por vírgula (`IFS=','`); loop novo em `spec-verify.sh` após a linha 65 (via `run_check`); trecho equivalente no `hooks/git/pre-push`; resultado no `verification.yaml`/`run-manifest` (paths: `template/.forge/FORGE.md`, `template/.forge/scripts/spec-verify.sh`, `template/.forge/hooks/git/pre-push`; depende: TASK-14, TASK-15, TASK-16 — feitas na STORY-04; DoD: gates aparecem como checks no verify e no run-manifest; `gates:` legível pelo awk existente — AN-01).

## Acceptance criteria

- [ ] `gates: check-authz,check-observability,check-data-governance` no `FORGE.md` é lida corretamente por `get_runtime` (spec-verify) e `fm_field` (pre-push) sem quebrar o parsing das demais chaves de `runtime:`.
- [ ] `spec-verify.sh` executa cada gate declarado via `run_check`, resultado aparece em `verification.yaml` (`CHECKS_YAML`) e em `run-manifest.json`.
- [ ] `pre-push` executa os mesmos gates; gates em `mode: warn` reportam sem bloquear o push; gates inegociáveis (REQ-05/REQ-12a) sempre bloqueiam.
- [ ] `tests/run-all.sh` cobre os checks novos de integração e permanece verde.
- [ ] Nenhum achado de gate aberto (gate-runner verde antes de `/forge:verify`).
- [ ] Commit atômico por task; nenhum `TODO`/`FIXME` residual.

## Out of scope

- Regenerar `plugin/forge/**`, atualizar `CHANGELOG.md` e rodar `run-all.sh` completo como gate final de aceitação do change — STORY-06.
