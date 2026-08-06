---
story_id: STORY-02
epic: security-observability-gates
title: Code-graph lê FORGE.md, schemas declarativos, template/validate-spec e rule authz-pdp-pep
depends_on: [STORY-01]
status: todo
---

# STORY-02 — Code-graph lê FORGE.md, schemas declarativos, template/validate-spec e rule authz-pdp-pep

> Story auto-contida derivada de `security-observability-gates`. Toda informação necessária para implementar
> esta story está aqui — sem precisar reler o change completo (§17.1). Ver também `../epic_context.md`.

## Goal

Fazer o code-graph reconhecer os blocos declarativos do `FORGE.md`, criar os três schemas de artefato declarativo, exigir as quatro seções obrigatórias no template de requirements condicionadas a `affects_surfaces`, e publicar a rule `authz-pdp-pep.md`. Wave 2 — depende só da fundação da STORY-01 (schemas estendidos, yaml-lite, manifest, ADR).

## Embedded context

### Requirements

- REQ-11: `graph-build.mjs` deve reconhecer blocos `authz:` (paths do PEP, allowlist, `mode`, `policy_coverage_threshold`) e `observability:` (paths do wrapper, allowlist, `mode`) sem quebrar o parsing de `runtime:`; ausência dos blocos ⇒ gates dependentes em no-op. Habilita REQ-06/07/08/09/10.
- REQ-14: schemas `authz-map`, `data-classification`, `alerts-as-code`, cada um com fixture válido/inválido; `authz-map` exige por endpoint um campo de teste de contrato negativo (`negative_contract_test`, objeto `{unauthenticated_401, forbidden_403}`) — é `required`, reprova endpoint sem ele.
- REQ-13: quatro seções obrigatórias no template de requirements (mapa endpoint→ação→recurso→policy, tabela dado→classificação, checklist de sinais OTel por boundary, mapa de eventos auditáveis mutação→audit event append-only); `validate-spec` reprova change `layer:api` sem o mapa endpoint→policy nem o mapa de eventos auditáveis. Change que não toca `layer:api`/dados passa sem exigir as seções (NFR-03), disparado por `affects_surfaces` (TASK-04, já feito na STORY-01).
- REQ-02: rule `authz-pdp-pep.md` define PDP/PEP, OPA/Rego recomendado (OpenFGA runner-up ReBAC), deny-by-default, fail-closed, claims JWT como insumo do PEP — nunca mecanismo de decisão. `jwt-permissions.md` atualizada nesse sentido.

### Design

> §2.3: `graph-build.mjs` ganha passo novo — lê o frontmatter do `FORGE.md` (entre os dois primeiros `---`) via `parseYamlSubset` de `yaml-lite.mjs` (mesmo parser de `validate-spec.mjs`, zero-dep — NFR-01). Com os blocos em mãos: (1) taggeia cada node cujo `id` casa um glob de `pep_paths`/`wrapper_paths` com `roles: ["pep"]`/`["otel-wrapper"]`; (2) emite bloco `governance: {authz, observability}` no `graph.json`. Não toca o awk de `spec-verify.sh`/`pre-push`, que param no primeiro `^[a-z_]+:` após `runtime:` — blocos posteriores nunca são varridos por engano. Exemplo do bloco:
> ```yaml
> authz:
>   pep_paths: [services/*/internal/authz, packages/pep]
>   policy_dir: policy
>   allowlist: [services/health, services/metrics]
>   mode: warn
>   policy_coverage_threshold: 0.8
> observability:
>   wrapper_paths: [packages/otel, services/*/observability]
>   allowlist: [services/health]
>   mode: warn
> ```
> (blocos reais em block-sequence, não array inline — ver STORY-01 §2.3 sobre o dialeto yaml-lite.)

> §2.4: schemas draft 2020-12, `$id: https://forge.dev/schemas/<nome>.schema.json`, `additionalProperties: false`, estilo `verification.schema.json`. `authz-map.schema.json` — lista `{method, path, action, resource, policy, negative_contract_test}`. `data-classification.schema.json` — mapa `field → {classification: pii|pan|sensitive|public, masking, tokenization_boundary}`. `alerts-as-code.schema.json` — `{service, alerts: [{name, expr, severity, for}]}` (golden signals). Validados por `w30-schemas-gate.sh`.

> §2.5: `templates/spec/requirements.md` ganha as quatro seções, preenchidas só quando o change toca `layer:api`/dados. `validate-spec.mjs` ganha regra condicional nova no molde das `headingRules` existentes (linhas 149-159): quando o change toca `layer:api` (via `affects_surfaces`), reprova ausência do mapa endpoint→policy e do mapa de eventos auditáveis.

> §2.7: rule nova `authz-pdp-pep.md` com `based_on: [ADR-00NN]` (ADR da STORY-01, TASK-05); `jwt-permissions.md` atualizada; ambas indexadas em `rules/README.md`; coerência com `security-and-compliance.md`/`jwt-authentication.md` existentes.

### Contratos / interfaces

- `graph.json` ganha bloco `governance: {authz, observability}` + `roles` por node (schema já estendido pela STORY-01, TASK-03).
- `template/.forge/schemas/authz-map.schema.json`, `data-classification.schema.json`, `alerts-as-code.schema.json` — novos, consumidos por REQ-10 (STORY-04) e pelos projetos consumidores.
- `template/.forge/templates/spec/requirements.md` — quatro seções novas condicionais.

### Rules aplicáveis

- `template/.forge/rules/architecture/authz-pdp-pep.md` (nova, TASK-10) — PDP/PEP, deny-by-default, `based_on:` ao ADR.
- `template/.forge/rules/architecture/jwt-permissions.md` (atualizada) — claims são insumo do PEP.
- `template/.forge/rules/README.md` — índice atualizado.

### ADRs

- ADR de substrato (criado na STORY-01, TASK-05) — `authz-pdp-pep.md` referencia via `based_on:`.

## Tasks

- [ ] TASK-07 — `graph-build.mjs` lê o frontmatter do `FORGE.md` via `yaml-lite`, taggeia nodes com `roles` (pep/otel-wrapper) por glob e emite `governance` no `graph.json` (paths: `template/.forge/scripts/lib/graph-build.mjs`; depende: TASK-02, TASK-03 — feitas na STORY-01; DoD: fixture `FORGE.md` com blocos → `governance` correto; awk de `spec-verify`/`pre-push` intocado).
- [ ] TASK-08 — Schemas `authz-map` (com `negative_contract_test` obrigatório por endpoint), `data-classification`, `alerts-as-code` + fixtures válido/inválido (paths: `template/.forge/schemas/`, `tests/`; depende: TASK-03 — feita na STORY-01; DoD: cada schema aprova o fixture válido e reprova o inválido).
- [ ] TASK-09 — Quatro seções obrigatórias no template de requirements (endpoint→policy, dado→classificação, sinais OTel, mapa de eventos auditáveis) + regra condicional em `validate-spec.mjs` que reprova `layer:api`/dados sem mapa endpoint→policy nem mapa auditável (paths: `template/.forge/templates/spec/requirements.md`, `template/.forge/scripts/lib/validate-spec.mjs`, `tests/`; depende: TASK-04 — feita na STORY-01; DoD: change `layer:api` sem mapa reprova; change trivial passa — NFR-03).
- [ ] TASK-10 — Rule `authz-pdp-pep.md` (`based_on:` ao ADR) + atualizar `jwt-permissions.md` (claims são insumo do PEP) + indexar em `rules/README.md` (paths: `template/.forge/rules/architecture/authz-pdp-pep.md`, `.../jwt-permissions.md`, `.../README.md`; depende: TASK-05 — feita na STORY-01; DoD: `validate-rules.sh` sem drift; `based_on:` resolve ao ADR).

## Acceptance criteria

- [ ] Fixture de `FORGE.md` com blocos `authz:`/`observability:` produz `governance` correto em `graph.json`; nodes casando glob de `pep_paths`/`wrapper_paths` ganham `roles` correto.
- [ ] Awk de `spec-verify.sh`/`pre-push` continua lendo só `runtime:` sem interferência dos blocos novos.
- [ ] `authz-map.schema.json` reprova entrada de endpoint sem `negative_contract_test`; os três schemas aprovam fixture válido e reprovam fixture inválido.
- [ ] Change `layer:api` (via `affects_surfaces`) sem mapa endpoint→policy nem mapa de eventos auditáveis reprova em `validate-spec.mjs`; change trivial passa sem exigir as seções.
- [ ] `authz-pdp-pep.md` existe, indexado, `based_on:` resolve ao ADR da STORY-01, `validate-rules.sh` sem drift.
- [ ] Nenhum achado de gate aberto (gate-runner verde antes de `/forge:verify`).
- [ ] Commit atômico por task; nenhum `TODO`/`FIXME` residual.

## Out of scope

- Rule `pii-pci-classification.md` e extensão de `observability.md` — STORY-03.
- `lib/graph-govern.mjs` (reachability real) e `lib/gate-mode.mjs` — STORY-03 (usam o `governance` emitido aqui, mas a lógica de gate fica lá).
- Os três gates (`check-authz`/`check-observability`/extensão data-governance) — STORY-04.
