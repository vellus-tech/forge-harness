---
story_id: STORY-01
epic: security-observability-gates
title: Fundação — engine compartilhado, yaml-lite, schemas aditivos, ADR e constitution
depends_on: []
status: todo
---

# STORY-01 — Fundação — engine compartilhado, yaml-lite, schemas aditivos, ADR e constitution

> Story auto-contida derivada de `security-observability-gates`. Toda informação necessária para implementar
> esta story está aqui — sem precisar reler o change completo (§17.1). Ver também `../epic_context.md`.

## Goal

Estabelecer os seis blocos de fundação sem dependência de nada mais no change: extrair o coletor de código compartilhado, estender `yaml-lite` para tolerar comentário final de linha, estender os schemas `graph.schema.json`/`forge.schema.json` de forma aditiva, adicionar `affects_surfaces` ao manifest, criar o ADR de substrato e emendar a constitution. Wave 1 — nenhuma task depende de outra fora desta story.

## Embedded context

### Requirements

- REQ-12 (parte engine): o coletor atual do `check-data-governance` varre só `.md`; generaliza para leitor de código-fonte parametrizável por extensão/glob, reusado depois por `check-authz`/`check-observability`/data-governance estendido.
- REQ-11 (parte schema): `graph-build.mjs` deve ler blocos novos sem quebrar o parsing de `runtime:`; schema do `FORGE.md`/graph atualizado e validando — sem isso, todo `FORGE.md` com os blocos novos reprova `w20-spec-gate.sh` (NFR-04).
- REQ-13/NFR-03: gatilho de proporcionalidade via campo declarativo `affects_surfaces: [api, data]` no `manifest.yaml`, preferido a heurística de texto.
- REQ-17: ADR de substrato registrando OPA/Rego (OpenFGA runner-up), stack OSS OTel, fronteira PCI Req 7/8.
- REQ-01: constitution declara cinco invariantes inegociáveis: (a) toda decisão de acesso via PDP; (b) deny-by-default/fail-closed; (c) toda mutação/decisão auditável (trilha append-only); (d) zero PII/PAN em log; (e) todo boundary instrumentado. Cláusula (a)/(b) referencia a tríade (gate estático + teste de contrato negativo + evidência de decision-log).

### Design

> §2.1: `lib/source-scan.mjs` — `collect(paths, {exts=new Set(['.md']), skipDirs=DEFAULT_SKIP})` retorna `string[]` de arquivos; `scan(files, matrix, {rel})` retorna `findings[]` "rel:line: why" aplicando `{re, why, allow}` por linha (mesma semântica das linhas 46-50 do `check-data-governance.mjs` atual). `check-data-governance.mjs` passa a importar `collect`/`scan` preservando `exts={'.md'}` como default — nenhum comportamento observável muda; `gw3-data-governance-gate.sh` [1]-[8] prova isso.

> §2.3 (terceira restrição, §1): `yaml-lite.mjs` aceita `- scalar` e `key: []` mas não faz strip de comentário final de linha; o `FORGE.md` real tem comentários finais em campos existentes (ex.: linhas 12-14 e 31). Extensão: strip de ` #…` fora de aspas no `parseScalar` — retrocompatível (nenhum emissor atual produz comentário final), testada por fixture própria; beneficia `validate-spec`/`validate-archive`/`delta-apply`.

> §2.3 (Schema do FORGE.md): `forge.schema.json` (`$defs/forgeFrontmatter`, hoje `additionalProperties: false`) ganha `authz`/`observability` como objetos opcionais e `gates` como chave opcional (lista) dentro de `runtime`. `graph.schema.json` ganha `roles` (array opcional) nas properties de `nodes` e um objeto `governance` opcional no topo — aditivo, sem bump de `graph/v0`.

> §2.5: `affects_surfaces` no `manifest.yaml`, aditivo em `spec-manifest.schema.json` e nos campos permitidos de `validate-spec.mjs` — explícito, testável, existe antes do código (vs. derivação pós-código via `/forge:impact`).

> §2.7: constitution — emenda ao item 7 "Security by default" existente (não item novo redundante), com as cinco cláusulas e a nota da tríade.

> §5 (rollout): "Expand silencioso" — entra `source-scan.mjs` com `check-data-governance` refatorado (retrocompat provada por `gw3`), schemas, e constitution — nada bloqueia código de consumidor ainda nesta wave.

### Contratos / interfaces

- `template/.forge/scripts/lib/source-scan.mjs` — módulo novo, exporta `collect`/`scan`.
- `template/.forge/schemas/graph.schema.json` — `roles` (node), `governance` (topo), ambos opcionais.
- `template/.forge/schemas/forge.schema.json` — `authz`/`observability` opcionais no frontmatter, `gates` opcional em `runtime`.
- `template/.forge/schemas/spec-manifest.schema.json` — `affects_surfaces` opcional.

### Rules aplicáveis

- Nenhuma rule é criada/editada nesta story (rules ficam nas Wave 2/3 — STORY-02/03).

### ADRs

- ADR de substrato (criado por TASK-05 desta story) — OPA/Rego principal, OpenFGA runner-up ReBAC; stack OSS OTel Collector→Tempo/Loki/Prometheus/Grafana; fronteira PCI Req 7 (esta capability) vs Req 8 (auth-service, fora de escopo). Referenciado por `based_on:` nas rules de STORY-02/03.

## Tasks

- [ ] TASK-01 — Extrair `lib/source-scan.mjs` (collect+scan) de `check-data-governance.mjs` e refatorar o gate para importá-lo com `exts` default `.md` (paths: `template/.forge/scripts/lib/source-scan.mjs`, `template/.forge/scripts/lib/check-data-governance.mjs`; depende: —; DoD: `tests/gw3-data-governance-gate.sh` verde sem alteração de comportamento).
- [ ] TASK-02 — Estender `yaml-lite.mjs` com strip de comentário final de linha (` #…` fora de aspas) no `parseScalar` (paths: `template/.forge/scripts/lib/yaml-lite.mjs`, `tests/`; depende: —; DoD: fixture nova verde + `validate-spec`/`delta-apply` sem regressão em `run-all`).
- [ ] TASK-03 — Estender `graph.schema.json` (`roles` no node + `governance` no topo) e `forge.schema.json` (`authz`/`observability` opcionais no `$defs/forgeFrontmatter` + `gates` opcional em `runtime`) (paths: `template/.forge/schemas/graph.schema.json`, `template/.forge/schemas/forge.schema.json`; depende: —; DoD: `w20-spec-gate.sh` verde com fixture de `FORGE.md` contendo os blocos).
- [ ] TASK-04 — Campo declarativo `affects_surfaces` no `manifest.yaml` (aditivo em `spec-manifest.schema.json` + campos permitidos do `validate-spec.mjs`) (paths: `template/.forge/schemas/spec-manifest.schema.json`, `template/.forge/scripts/lib/validate-spec.mjs`; depende: —; DoD: manifest com/sem o campo validam; change sem o campo não exige seções novas).
- [ ] TASK-05 — ADR de substrato no baseline via `/forge:adr` (OPA/Rego; OpenFGA runner-up para ReBAC; stack OSS OTel Collector→Tempo/Loki/Prometheus/Grafana; fronteira PCI Req 7/8) (paths: `.forge/product/current/adr/`; depende: —; DoD: ADR numerado + índice atualizado).
- [ ] TASK-06 — Emenda ao item 7 "Security by default" da constitution: cinco invariantes (PDP; deny-by-default/fail-closed; auditabilidade append-only; zero PII/PAN em log; boundary instrumentado) + nota da tríade (paths: `template/.forge/constitution.md`; depende: —; DoD: `validate-rules.sh` sem drift).

## Acceptance criteria

- [ ] `tests/gw3-data-governance-gate.sh` passa idêntico antes/depois de TASK-01 (retrocompat provada, NFR-04).
- [ ] Fixture nova de `yaml-lite` com comentário final de linha parseia corretamente; `run-all` sem regressão em `validate-spec`/`delta-apply`.
- [ ] `tests/w20-spec-gate.sh` passa com fixture de `FORGE.md` contendo os blocos `authz:`/`observability:`/`gates:` (schema aditivo aceita, não exige).
- [ ] Manifest com `affects_surfaces` e sem `affects_surfaces` ambos validam contra `spec-manifest.schema.json`.
- [ ] ADR numerado existe em `.forge/product/current/adr/`, indexado.
- [ ] `template/.forge/constitution.md` contém as cinco cláusulas ancoradas no item "Security by default" existente; `validate-rules.sh` sem drift.
- [ ] Nenhum achado de gate aberto (gate-runner verde antes de `/forge:verify`).
- [ ] Commit atômico por task; nenhum `TODO`/`FIXME` residual.

## Out of scope

- Leitura efetiva do `FORGE.md` pelo `graph-build.mjs` (parsing dos blocos, tagging de roles) — isso é TASK-07, STORY-02.
- Rules `authz-pdp-pep.md`/`pii-pci-classification.md`/extensão de `observability.md` — STORY-02/STORY-03.
- Qualquer gate novo (`check-authz`/`check-observability`) — STORY-04.
- Integração em `spec-verify.sh`/`pre-push` — STORY-05.
