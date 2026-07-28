---
story_id: STORY-04
epic: security-observability-gates
title: Os três gates — check-authz, check-observability e extensão data-governance
depends_on: [STORY-01, STORY-03]
status: todo
---

# STORY-04 — Os três gates — check-authz, check-observability e extensão data-governance

> Story auto-contida derivada de `security-observability-gates`. Toda informação necessária para implementar
> esta story está aqui — sem precisar reler o change completo (§17.1). Ver também `../epic_context.md`.

## Goal

Implementar os três gates públicos policy-as-code: `check-authz` (deny-by-default, anti-decisão-imperativa, cobertura de política), `check-observability` (boundary→wrapper, logger cru, alerts-as-code) e a extensão de `check-data-governance` (PAN/PII em log, classificação obrigatória). Wave 4 — consome o coletor da STORY-01 (TASK-01) e os motores internos da STORY-03 (`graph-govern.mjs`, `gate-mode.mjs`, TASK-12/13).

## Embedded context

### Requirements

- REQ-05 (sempre enforce): `check-authz` reprova todo package Rego sem `default allow := false` ou com `allow` incondicional/`default allow := true`; aprova quando todos deny-by-default. Fixture `.rego` com/sem deny-by-default.
- REQ-06: reprova anti-padrões de decisão imperativa (`hasRole(`, `user.role ==`, `claims["permissions"]`, decorators de role ad-hoc) **fora** do diretório PEP declarado no bloco `authz:`; dentro do PEP → PASS. Lista `ANTI` por stack (Go/Kotlin/TS). Respeita modo warn/enforce.
- REQ-07: quando `authz.policy_coverage_threshold` está declarado, reprova se a cobertura reportada < threshold; ausência de threshold ⇒ no-op (não falso-positivo). Ramo de FAIL respeita modo warn/enforce.
- REQ-08: rota `layer:api` sem caminho ao PEP → FAIL (delegado ao `graph-govern.mjs` da STORY-03).
- REQ-09(a): boundary sem caminho ao wrapper (delegado ao `graph-govern.mjs`). REQ-09(b): logger cru (`fmt.Println`, `console.log`, `print(` em contexto de serviço) fora do wrapper — matriz `ANTI` via `scan()` do `source-scan.mjs`.
- REQ-10: para cada boundary declarado, exige ≥1 artefato `alerts-as-code` válido (schema da STORY-02) associado ao serviço; ausência → FAIL nomeando o serviço. Respeita modo warn/enforce — nasce `warn` em brownfield.
- REQ-12(a) (sempre enforce): PAN/PII em log via regex/taint (PAN 13-19 dígitos, CPF, e-mail em chamada de log) → FAIL; mascarado → PASS. REQ-12(b): campo sensível sem classificação declarada no artefato `data-classification` → FAIL. Estende `lib/check-data-governance.mjs` sem regressão nos checks atuais.

### Design

> §2.2: **`check-authz` — `check-authz.sh` + `lib/check-authz.mjs`.** Três sub-checks: REQ-05 por parsing regex sobre texto Rego (não invoca `opa` — NFR-01; fragilidade documentada como limitação, coberta por fixtures). REQ-06 via matriz `ANTI` aplicada por `scan()` a arquivos fora do PEP dir. REQ-07 lê o **valor reportado** de um relatório de cobertura (gerado pelo consumidor, ex. `opa test --coverage`) — não gera cobertura, só compara.

> §2.2: **`check-observability` — `check-observability.sh` + `lib/check-observability.mjs`.** REQ-09(a) delegado a `graph-govern.mjs` (alcançabilidade, não varredura de texto). REQ-09(b) via `scan()`. REQ-10: para cada boundary declarado, exige ≥1 artefato alerts-as-code válido associado.

> §2.1/§2.2: **extensão `check-data-governance`.** Adiciona à matriz existente (a) taint de PAN/PII em chamada de log, **sempre enforce** (REQ-16 — violação PCI direta) e (b) campo sensível sem classificação. Varredura agora inclui código via `exts` ampliado (`collect(paths, {exts: {'.go','.kt','.ts','.rego','.py'}})`).

> §2.2 (contrato comum): cada `.sh` espelha `check-data-governance.sh`: `set -euo pipefail`, `ROOT="${FORGE_ROOT:-…}"`, exige `node`, aceita `<change-id>` ou `--path`. Saída `OK <gate> (…)` (exit 0) ou `CONFLICT (…)`/`FAIL (…)` (exit≠0). Usa `gate-mode.mjs` (STORY-03) para aplicar warn/enforce por finding, exceto os inegociáveis REQ-05/REQ-12(a).

### Contratos / interfaces

- `template/.forge/scripts/check-authz.sh` + `template/.forge/scripts/lib/check-authz.mjs` — novo gate público.
- `template/.forge/scripts/check-observability.sh` + `template/.forge/scripts/lib/check-observability.mjs` — novo gate público.
- `template/.forge/scripts/lib/check-data-governance.mjs` — estendido (não substituído).
- `tests/fixtures/authz/`, `tests/fixtures/observability/`, `tests/fixtures/data-governance/` — fixtures `.rego`/`.go`/`.kt`/`.ts` pass/fail.

### Rules aplicáveis

- `template/.forge/rules/architecture/authz-pdp-pep.md` (STORY-02) — fundamenta REQ-05/06/07.
- `template/.forge/rules/architecture/observability.md` (STORY-03) — fundamenta REQ-09/10.
- `template/.forge/rules/architecture/pii-pci-classification.md` (STORY-03) — fundamenta REQ-12.

### ADRs

- ADR de substrato (STORY-01) — justifica regex sobre Rego em vez de invocar `opa` (NFR-01).

## Tasks

- [ ] TASK-14 — `check-authz.sh` + `lib/check-authz.mjs`: REQ-05 deny-by-default em `.rego` (sempre enforce), REQ-06 anti-decisão-imperativa fora do PEP via `source-scan`, REQ-07 cobertura vs threshold + fixtures `.rego/.go/.kt/.ts` (paths: `template/.forge/scripts/check-authz.sh`, `.../lib/check-authz.mjs`, `tests/`, `tests/fixtures/authz/`; depende: TASK-01 — STORY-01, TASK-12/TASK-13 — STORY-03; DoD: fixtures pass/fail nomeiam arquivo; deny-by-default ignora `mode`).
- [ ] TASK-15 — `check-observability.sh` + `lib/check-observability.mjs`: REQ-09b logger cru via `source-scan`, REQ-09a boundary→wrapper via `graph-govern`, REQ-10 alerts-as-code por serviço + fixtures (paths: `template/.forge/scripts/check-observability.sh`, `.../lib/check-observability.mjs`, `tests/`, `tests/fixtures/observability/`; depende: TASK-01 — STORY-01, TASK-12/TASK-13 — STORY-03; DoD: fixtures pass/fail; serviço sem alerts-as-code → FAIL).
- [ ] TASK-16 — Estender `check-data-governance` (matriz + `exts` ampliado): REQ-12a PAN/PII em log (sempre enforce), REQ-12b campo sensível sem classificação + fixtures de código (paths: `template/.forge/scripts/lib/check-data-governance.mjs`, `tests/fixtures/data-governance/`; depende: TASK-01 — STORY-01, TASK-13 — STORY-03; DoD: PAN em log → FAIL mesmo em warn; sem regressão em `gw3`).

## Acceptance criteria

- [ ] Fixture `.rego` sem deny-by-default → `check-authz` FAIL nomeando o arquivo; fixture deny-by-default → PASS. Ignora `mode` (sempre enforce).
- [ ] Fixture com anti-padrão fora do PEP → FAIL; mesma ocorrência dentro do PEP dir → PASS.
- [ ] Fixture com cobertura abaixo do threshold declarado → FAIL indicando cobertura×threshold; ≥ threshold → PASS; sem threshold declarado → no-op.
- [ ] Fixture de boundary sem wrapper → FAIL; com wrapper → PASS. Fixture com logger cru → FAIL; via logger estruturado → PASS.
- [ ] Serviço com boundary e sem alerts-as-code → FAIL nomeando o serviço; com artefato válido → PASS.
- [ ] Fixture com PAN em `log.info(...)` → FAIL mesmo em `mode: warn`; mascarado → PASS. Campo sensível sem classificação → FAIL.
- [ ] `tests/gw3-data-governance-gate.sh` [1]-[8] permanece verde (sem regressão, NFR-04).
- [ ] Nenhum achado de gate aberto (gate-runner verde antes de `/forge:verify`).
- [ ] Commit atômico por task; nenhum `TODO`/`FIXME` residual.

## Out of scope

- Declarar `gates:` no `FORGE.md` e integrar os três gates a `spec-verify.sh`/`pre-push`/CI/run-manifest — STORY-05.
- Regenerar plugin, ADR final e run-all completo — STORY-06.
