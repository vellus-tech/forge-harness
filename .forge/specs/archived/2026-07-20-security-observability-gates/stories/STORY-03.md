---
story_id: STORY-03
epic: security-observability-gates
title: Rule pii-pci, motor de grafo de governança e modo warn/enforce
depends_on: [STORY-01, STORY-02]
status: todo
---

# STORY-03 — Rule pii-pci, motor de grafo de governança e modo warn/enforce

> Story auto-contida derivada de `security-observability-gates`. Toda informação necessária para implementar
> esta story está aqui — sem precisar reler o change completo (§17.1). Ver também `../epic_context.md`.

## Goal

Publicar a rule `pii-pci-classification.md` e estender `observability.md`, e construir os dois motores internos que os gates da Wave 4 vão consumir: `graph-govern.mjs` (reachability rota→PEP/wrapper) e `gate-mode.mjs` (leitura de `mode`/`allowlist` e rebaixamento a warn). Wave 3 — depende do `governance` emitido pelo `graph-build.mjs` (STORY-02, TASK-07) e da rule/ADR da STORY-02/01 (TASK-10/05).

## Embedded context

### Requirements

- REQ-03: rule `pii-pci-classification.md` exige classificação de dados como código, mascaramento em log, fronteira de tokenização, e mapeia controles a PCI DSS 4.0.1 (Req 3 storage, Req 4 transit, Req 7 acesso, Req 8 identidade — fronteira explícita ficando no auth-service, Req 10 audit trail). Deve referenciar `domain/audit-immutability.md` — sustenta a tríade de audit trail declarada em REQ-01.
- REQ-04: `observability.md` estendida exige, por boundary, span + log estruturado + métrica (golden signals) + alerts-as-code, na stack OSS OTel Collector → Tempo/Loki/Prometheus/Grafana.
- REQ-08: gate de grafo reprova todo node `layer:api` que não alcance (edge direto/transitivo) o módulo PEP declarado, exceto por allowlist versionada. Usa `lib/graph-deps.mjs` sobre `graph.json`.
- REQ-09(a): mesma lógica para boundary→wrapper de instrumentação.
- REQ-16: modo lido do bloco `authz:`/`observability:` (`mode: warn|enforce`), aplicado aos cinco gates de adoção (REQ-06/07/08/09/10). `warn` → exit 0 com aviso; `enforce` → exit≠0 no achado. REQ-05 e REQ-12(a) nunca são rebaixáveis — sempre enforce.

### Design

> §2.3: `graph-govern.mjs` é **motor interno** (biblioteca), não gate público — reusa a alcançabilidade de `graph-deps.mjs`: para cada node `layer:api` fora da `allowlist`, computa se alcança (edge direto/transitivo, só `resolved:true`) algum node `roles:["pep"]` (REQ-08) e algum `roles:["otel-wrapper"]` (REQ-09a). Node sem caminho → finding nomeando o arquivo. Respeita `mode` do bloco correspondente. O resultado de REQ-08 é reportado sob `check-authz` e o de REQ-09(a) sob `check-observability` (ambos gates ficam na STORY-04) — `graph-govern.mjs` prova só **importação, não aplicação**; a prova comportamental fica no `authz-map` (REQ-14, já schematizado na STORY-02) e no CI do consumidor.

> §2.2 (contrato comum dos gates): o **modo warn|enforce** é aplicado apenas aos cinco gates de adoção (REQ-06/07/08/09/10): em `warn` o achado imprime `WARN (…)` e sai 0; em `enforce`, `CONFLICT (…)`/`FAIL (…)` e sai 1. Os ramos **inegociáveis** — REQ-05 e REQ-12(a) — ignoram o `mode` e sempre saem 1. Implementado como flag interno `enforceable=false` por finding: o modo só rebaixa findings marcados rebaixáveis. Isso é a responsabilidade de `lib/gate-mode.mjs`.

> §2.7: rule `pii-pci-classification.md` (REQ-03, `architecture/`) — mapa controle→PCI, ref a `domain/audit-immutability.md`; extensão de `observability.md` (REQ-04 — alerts-as-code + stack OSS). Ambas indexadas em `rules/README.md`, `validate-rules.sh` verde.

> Nota de sequenciamento (tasks.md, TASK-11): dependência em TASK-10 (STORY-02) serializa a edição de `rules/README.md` (evita conflito de merge no índice — AN-02 do analyze). Ao acrescentar a stack Tempo em `observability.md`, reconciliar com as menções a Jaeger já existentes — Tempo como padrão OSS greenfield, Jaeger permanece alternativa compatível via OTLP — sem regressão de seção (AN-04).

### Contratos / interfaces

- `template/.forge/scripts/lib/graph-govern.mjs` — biblioteca, não script standalone; consumida por `check-authz.mjs`/`check-observability.mjs` (STORY-04).
- `template/.forge/scripts/lib/gate-mode.mjs` — biblioteca; lê `mode`/`allowlist` do bloco `governance` do `graph.json` (emitido pela STORY-02, TASK-07).
- `tests/*-graph-govern-gate.sh` — teste de unidade próprio, exercita o motor isoladamente; não é declarado na chave `gates:` do `FORGE.md` (não é gate público).

### Rules aplicáveis

- `template/.forge/rules/architecture/pii-pci-classification.md` (nova, TASK-11) — mapa controle→PCI, ref a `audit-immutability.md`.
- `template/.forge/rules/architecture/observability.md` (estendida, TASK-11) — alerts-as-code + stack OSS OTel.
- `template/.forge/rules/architecture/authz-pdp-pep.md` (da STORY-02) — referenciada por coerência de modo warn/enforce.
- `template/.forge/rules/README.md` — índice atualizado.

### ADRs

- ADR de substrato (STORY-01, TASK-05) — stack OSS OTel Collector→Tempo/Loki/Prometheus/Grafana referenciada na extensão de `observability.md`.

## Tasks

- [ ] TASK-11 — Rule `pii-pci-classification.md` (mapa controle→PCI 3/4/7/8/10, ref a `domain/audit-immutability.md`) + estender `observability.md` (alerts-as-code + stack OSS OTel) + indexar (paths: `template/.forge/rules/architecture/pii-pci-classification.md`, `.../observability.md`, `.../README.md`; depende: TASK-05, TASK-10 — feitas na STORY-01/STORY-02; DoD: `validate-rules.sh` sem drift; ref a `audit-immutability.md` presente; reconciliar Tempo/Jaeger em `observability.md` sem regressão de seção).
- [ ] TASK-12 — `lib/graph-govern.mjs` (reachability via `graph-deps.mjs`: node `layer:api` fora da allowlist alcança `roles:pep` / `roles:otel-wrapper`) + teste de unidade `tests/*-graph-govern-gate.sh` (paths: `template/.forge/scripts/lib/graph-govern.mjs`, `tests/`; depende: TASK-07 — feita na STORY-02; DoD: fixture rota com/sem caminho ao PEP → PASS/FAIL; allowlist isenta).
- [ ] TASK-13 — `lib/gate-mode.mjs`: lê `mode`/`allowlist` do bloco de `governance`, rebaixa findings marcados `enforceable=false` em `warn`, mantém inegociáveis sempre enforce (paths: `template/.forge/scripts/lib/gate-mode.mjs`, `tests/`; depende: TASK-07 — feita na STORY-02; DoD: `mode:warn` → exit 0 com aviso em findings rebaixáveis; finding inegociável → exit≠0 mesmo em warn).

## Acceptance criteria

- [ ] `pii-pci-classification.md` existe, indexado, referencia `domain/audit-immutability.md`, mapa controle→PCI presente, `validate-rules.sh` sem drift.
- [ ] `observability.md` cobre os três sinais por boundary + alerts-as-code + stack OSS nomeada, sem regressão nas seções pré-existentes (Tempo/Jaeger reconciliados).
- [ ] Fixture de rota com caminho ao PEP → PASS; sem caminho → FAIL nomeando o arquivo; rota na allowlist → isenta (PASS/no-op).
- [ ] Mesma lógica validada para `roles:otel-wrapper` (boundary→wrapper).
- [ ] `mode: warn` no bloco de governance rebaixa finding rebaixável a `WARN` com exit 0; finding inegociável (`enforceable=false`) sai ≠0 mesmo em `warn`.
- [ ] Nenhum achado de gate aberto (gate-runner verde antes de `/forge:verify`).
- [ ] Commit atômico por task; nenhum `TODO`/`FIXME` residual.

## Out of scope

- Os três gates públicos que consomem `graph-govern.mjs`/`gate-mode.mjs` (`check-authz.sh`, `check-observability.sh`, extensão de `check-data-governance`) — STORY-04.
- Integração em `spec-verify.sh`/`pre-push`/CI e `run-manifest` — STORY-05.
