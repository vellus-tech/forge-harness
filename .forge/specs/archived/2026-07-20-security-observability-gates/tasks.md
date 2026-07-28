# Tasks — security-observability-gates

> Tasks do change `security-observability-gates`, ordenadas por dependência. Formato de ID: `TASK-NN` (numeração contínua).
> Status: `[ ]` todo · `[-]` em progresso · `[X]` concluída · `[!]` bloqueada (exige intervenção humana).
> Waves são **níveis topológicos**: nenhuma task depende de outra da mesma wave — a `coding-loop` pode paralelizar cada wave com segurança. Cada wave só depende de waves anteriores. Gate de fechamento de wave: `npm test` (tests/run-all.sh) verde.

## Wave 1 — Fundação (sem dependências)

- [X] TASK-01 — Extrair `lib/source-scan.mjs` (collect+scan) de `check-data-governance.mjs` e refatorar o gate para importá-lo com `exts` default `.md` (rastreia: REQ-12/§2.1, NFR-04; paths: `template/.forge/scripts/lib/source-scan.mjs`, `template/.forge/scripts/lib/check-data-governance.mjs`; depende: —; DoD: `tests/gw3-data-governance-gate.sh` verde sem alteração de comportamento).
- [X] TASK-02 — Estender `yaml-lite.mjs` com strip de comentário final de linha (` #…` fora de aspas) no `parseScalar` (rastreia: §1/§2.3; paths: `template/.forge/scripts/lib/yaml-lite.mjs`, `tests/`; depende: —; DoD: fixture nova verde + `validate-spec`/`delta-apply` sem regressão em `run-all`).
- [X] TASK-03 — Estender `graph.schema.json` (`roles` no node + `governance` no topo) e `forge.schema.json` (`authz`/`observability` opcionais no `$defs/forgeFrontmatter` + `gates` opcional em `runtime`) (rastreia: REQ-11/§2.3/§4; paths: `template/.forge/schemas/graph.schema.json`, `template/.forge/schemas/forge.schema.json`; depende: —; DoD: `w20-spec-gate.sh` verde com fixture de `FORGE.md` contendo os blocos).
- [X] TASK-04 — Campo declarativo `affects_surfaces` no `manifest.yaml` (aditivo em `spec-manifest.schema.json` + campos permitidos do `validate-spec.mjs`) (rastreia: REQ-13/NFR-03/§2.5; paths: `template/.forge/schemas/spec-manifest.schema.json`, `template/.forge/scripts/lib/validate-spec.mjs`; depende: —; DoD: manifest com/sem o campo validam; change sem o campo não exige seções novas).
- [X] TASK-05 — ADR de substrato no baseline via `/forge:adr` (OPA/Rego; OpenFGA runner-up para ReBAC; stack OSS OTel Collector→Tempo/Loki/Prometheus/Grafana; fronteira PCI Req 7/8/10) (rastreia: REQ-17/§2.7; paths: `.forge/product/current/adr/`; depende: —; DoD: ADR numerado + índice atualizado).
- [X] TASK-06 — Emenda ao item 7 "Security by default" da constitution: cinco invariantes (PDP; deny-by-default/fail-closed; auditabilidade append-only; zero PII/PAN em log; boundary instrumentado) + nota da tríade (rastreia: REQ-01; paths: `template/.forge/constitution.md`; depende: —; DoD: `validate-rules.sh` sem drift).

## Wave 2 — Camadas que dependem só da fundação

- [X] TASK-07 — `graph-build.mjs` lê o frontmatter do `FORGE.md` via `yaml-lite`, taggeia nodes com `roles` (pep/otel-wrapper) por glob e emite `governance` no `graph.json` (rastreia: REQ-11/§2.3; paths: `template/.forge/scripts/lib/graph-build.mjs`; depende: TASK-02, TASK-03; DoD: fixture `FORGE.md` com blocos → `governance` correto; awk de `spec-verify`/`pre-push` intocado).
- [X] TASK-08 — Schemas `authz-map` (com `negative_contract_test` obrigatório por endpoint), `data-classification`, `alerts-as-code` + fixtures válido/inválido (rastreia: REQ-14/§2.4, sustenta REQ-10; paths: `template/.forge/schemas/`, `tests/`; depende: TASK-03; DoD: cada schema aprova o fixture válido e reprova o inválido).
- [X] TASK-09 — Quatro seções obrigatórias no template de requirements (endpoint→policy, dado→classificação, sinais OTel, mapa de eventos auditáveis) + regra condicional em `validate-spec.mjs` que reprova `layer:api`/dados sem mapa endpoint→policy nem mapa auditável (rastreia: REQ-13; paths: `template/.forge/templates/spec/requirements.md`, `template/.forge/scripts/lib/validate-spec.mjs`, `tests/`; depende: TASK-04; DoD: change `layer:api` sem mapa reprova; change trivial passa — NFR-03).
- [X] TASK-10 — Rule `authz-pdp-pep.md` (`based_on: []` — convenção G3; ADR-0002 referenciado em prosa) + atualizar `jwt-permissions.md` (claims são insumo do PEP) + indexar em `rules/README.md` (rastreia: REQ-02; paths: `template/.forge/rules/architecture/authz-pdp-pep.md`, `.../jwt-permissions.md`, `.../README.md`; depende: TASK-05; DoD: `gw2-rules-anchor-gate.sh` e `validate-rules.sh` verdes, sem drift).
## Wave 3 — Rule pii-pci, motor de grafo e modo dos gates

- [X] TASK-11 — Rule `pii-pci-classification.md` (`based_on: []` — G3, como TASK-10; mapa controle→PCI 3/4/7/8/10, ref a `domain/audit-immutability.md`) + estender `observability.md` (alerts-as-code + stack OSS OTel) + indexar (rastreia: REQ-03/04; paths: `template/.forge/rules/architecture/pii-pci-classification.md`, `.../observability.md`, `.../README.md`; depende: TASK-05, TASK-10; DoD: `validate-rules.sh` sem drift; ref a `audit-immutability.md` presente; ao acrescentar a stack Tempo em `observability.md`, reconciliar com as menções a Jaeger já existentes — Tempo como padrão OSS greenfield, Jaeger permanece alternativa compatível via OTLP — sem regressão de seção, AN-04). Dep em TASK-10 serializa a edição de `rules/README.md` (AN-02).

- [X] TASK-12 — `lib/graph-govern.mjs` (reachability via `graph-deps.mjs`: node `layer:api` fora da allowlist alcança `roles:pep` / `roles:otel-wrapper`) + teste de unidade `tests/*-graph-govern-gate.sh` (rastreia: REQ-08/09a/§2.3; paths: `template/.forge/scripts/lib/graph-govern.mjs`, `tests/`; depende: TASK-07; DoD: fixture rota com/sem caminho ao PEP → PASS/FAIL; allowlist isenta).
- [X] TASK-13 — `lib/gate-mode.mjs`: lê `mode`/`allowlist` do bloco de `governance`, rebaixa findings marcados `enforceable=false` em `warn`, mantém inegociáveis sempre enforce (rastreia: REQ-16/§2.2; paths: `template/.forge/scripts/lib/gate-mode.mjs`, `tests/`; depende: TASK-07; DoD: `mode:warn` → exit 0 com aviso em findings rebaixáveis; finding inegociável → exit≠0 mesmo em warn).

## Wave 4 — Os três gates

- [X] TASK-14 — `check-authz.sh` + `lib/check-authz.mjs`: REQ-05 deny-by-default em `.rego` (sempre enforce), REQ-06 anti-decisão-imperativa fora do PEP via `source-scan`, REQ-07 cobertura vs threshold + fixtures `.rego/.go/.kt/.ts` (rastreia: REQ-05/06/07/08; paths: `template/.forge/scripts/check-authz.sh`, `.../lib/check-authz.mjs`, `tests/`, `tests/fixtures/authz/`; depende: TASK-01, TASK-12, TASK-13; DoD: fixtures pass/fail nomeiam arquivo; deny-by-default ignora `mode`).
- [X] TASK-15 — `check-observability.sh` + `lib/check-observability.mjs`: REQ-09b logger cru via `source-scan`, REQ-09a boundary→wrapper via `graph-govern`, REQ-10 alerts-as-code por serviço + fixtures (rastreia: REQ-09/10; paths: `template/.forge/scripts/check-observability.sh`, `.../lib/check-observability.mjs`, `tests/`, `tests/fixtures/observability/`; depende: TASK-01, TASK-12, TASK-13; DoD: fixtures pass/fail; serviço sem alerts-as-code → FAIL).
- [X] TASK-16 — Estender `check-data-governance` (matriz + `exts` ampliado): REQ-12a PAN/PII em log (sempre enforce), REQ-12b campo sensível sem classificação + fixtures de código (rastreia: REQ-12; paths: `template/.forge/scripts/lib/check-data-governance.mjs`, `tests/fixtures/data-governance/`; depende: TASK-01, TASK-13; DoD: PAN em log → FAIL mesmo em warn; sem regressão em `gw3`).

## Wave 5 — Integração verify / pre-push / CI

- [X] TASK-17 — Chave `gates:` (CSV escalar numa linha) no bloco `runtime:` do `FORGE.md`, lida por `get_runtime`/`fm_field` + split por vírgula (`IFS=','`); loop novo em `spec-verify.sh` após a linha 65 (via `run_check`); trecho equivalente no `hooks/git/pre-push`; resultado no `verification.yaml`/`run-manifest` (rastreia: REQ-15/§2.6; paths: `template/.forge/FORGE.md`, `template/.forge/scripts/spec-verify.sh`, `template/.forge/hooks/git/pre-push`; depende: TASK-14, TASK-15, TASK-16; DoD: gates aparecem como checks no verify e no run-manifest; `gates:` legível pelo awk existente — AN-01).

## Wave 6 — Plugin, docs e verificação final

- [X] TASK-18 — Regenerar `plugin/forge/**` (`npm run build:plugin`) + atualizar `CHANGELOG.md` + rodar `tests/run-all.sh` completo garantindo 100% verde (gates novos + `gw3` + `w20`) (rastreia: REQ-17/NFR-04; paths: `plugin/forge/`, `CHANGELOG.md`; depende: TASK-01..TASK-17; DoD: run-all 100% verde; plugin reflete rules novas).

## Rastreabilidade

| REQ / NFR | Tasks |
|---|---|
| REQ-01 | TASK-06 |
| REQ-02 | TASK-10 |
| REQ-03 | TASK-11 |
| REQ-04 | TASK-11 |
| REQ-05 | TASK-14 |
| REQ-06 | TASK-14 |
| REQ-07 | TASK-14 |
| REQ-08 | TASK-12, TASK-14 |
| REQ-09 | TASK-12, TASK-15 |
| REQ-10 | TASK-08, TASK-15 |
| REQ-11 | TASK-03, TASK-07 |
| REQ-12 | TASK-01, TASK-16 |
| REQ-13 | TASK-04, TASK-09 |
| REQ-14 | TASK-08 |
| REQ-15 | TASK-17 |
| REQ-16 | TASK-13 |
| REQ-17 | TASK-05, TASK-18 |
| NFR-01 (zero-dep) | TASK-01, TASK-07, TASK-14 (validado em run-all) |
| NFR-02 (determinismo) | TASK-14, TASK-15, TASK-16 (fixtures repetíveis) |
| NFR-03 (proporcionalidade) | TASK-04, TASK-09 |
| NFR-04 (sem regressão) | TASK-01, TASK-18 |
