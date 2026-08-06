# Epic context — security-observability-gates

> Gerado por epic-context agent. Leitura rápida — não substitui os artefatos originais.

## Objetivo

Estender o harness (`template/.forge/**` + `plugin/`) com uma camada de imposição determinista para quatro preocupações transversais — observabilidade, audit trail, PII/PCI, RBAC/ABAC — atravessando constitution → rules → templates/schemas → gates policy-as-code → verify/pre-push/CI. Fecha o risco de compliance PCI DSS 4.0.1 de depender de revisor humano lembrar de checar essas famílias.

## Decisões de design

- **Engine compartilhado, três matrizes** (`lib/source-scan.mjs`): extrai `collect`/`scan` de `check-data-governance.mjs` para um módulo zero-dep parametrizável por `exts` (default `.md`, retrocompat provada por `gw3-data-governance-gate.sh`). Cada gate declara sua própria matriz `ANTI` local — não há engine novo por gate.
- **`yaml-lite.mjs` ganha strip de comentário final de linha** (` #…` fora de aspas) no `parseScalar` — retrocompatível, necessário porque `graph-build.mjs` passa a ler o frontmatter inteiro do `FORGE.md` (que tem comentários finais em campos existentes) via o mesmo parser que `validate-spec.mjs` já usa.
- **Blocos declarativos `authz:`/`observability:`** no frontmatter do `FORGE.md`, escritos em block-sequence (nunca array inline, nunca comentário final) — dialeto que `yaml-lite` parseia com segurança. `graph-build.mjs` os lê, taggeia nodes com `roles: ["pep"]`/`["otel-wrapper"]` por glob e emite `governance: {authz, observability}` no `graph.json`. Ausência dos blocos ⇒ `governance` ausente ⇒ gates dependentes em no-op.
- **Chave `gates:` é CSV escalar** (não block-sequence) dentro de `runtime:` — assimetria intencional: quem lê `gates:` é awk (`get_runtime` em `spec-verify.sh`, `fm_field` em `pre-push`), que só extrai `key: value` de uma linha; quem lê `authz:`/`observability:` é `graph-build.mjs` via `yaml-lite`, que parseia sequências.
- **`graph-govern.mjs`** é motor interno (biblioteca, não gate público): reusa reachability de `graph-deps.mjs` sobre `graph.json` para decidir se um node `layer:api` alcança (edge direto/transitivo) um node `roles:pep`/`roles:otel-wrapper`. Prova só *importação*, nunca *aplicação* — a aplicação é responsabilidade da tríade (gate estático + `negative_contract_test` no `authz-map` + evidência de decision-log no CI do consumidor).
- **`gate-mode.mjs`**: lê `mode: warn|enforce` + `allowlist` do bloco de governance correspondente; rebaixa a `warn` apenas findings marcados `enforceable=false` no código do gate. REQ-05 (deny-by-default) e REQ-12(a) (PAN/PII em log) são **sempre enforce**, nunca rebaixáveis — invariantes PCI, coerentes com REQ-01(b)/(d).
- **Gates de adoção nascem `mode: warn`** (REQ-06/07/08/09/10) — replica a lição das issues #20/#21: não travar brownfield sem PEP/wrapper. Promoção `warn`→`enforce` é decisão operacional via ledger, fora de escopo temporal deste change.
- **Schemas aditivos**: `graph.schema.json` (`roles` no node, `governance` no topo) e `forge.schema.json` (`authz`/`observability` opcionais no `$defs/forgeFrontmatter`, `gates` opcional em `runtime`) — sem bump de versão, `additionalProperties: false` preservado onde já existia.
- **`authz-map.schema.json` exige `negative_contract_test`** obrigatório por endpoint (`{unauthenticated_401, forbidden_403}`) — é a parte declarativa da tríade anti-falso-negativo.
- **Proporcionalidade via `affects_surfaces`** no `manifest.yaml` (campo declarativo, não heurística de texto) — dispara as 4 seções obrigatórias do template de requirements só quando o change toca `layer:api`/dados.
- **ADR de substrato** (via `/forge:adr`): OPA/Rego principal, OpenFGA runner-up para ReBAC; stack OSS OTel Collector → Tempo/Loki/Prometheus/Grafana; fronteira explícita PCI Req 7 (esta capability) vs Req 8 (auth-service, fora de escopo).

## Contratos externos

- `template/.forge/schemas/authz-map.schema.json` — lista de endpoints `{method, path, action, resource, policy, negative_contract_test}`.
- `template/.forge/schemas/data-classification.schema.json` — mapa `field → {classification, masking, tokenization_boundary}`.
- `template/.forge/schemas/alerts-as-code.schema.json` — `{service, alerts: [{name, expr, severity, for}]}`.
- Bloco `governance: {authz, observability}` novo em `graph.json` (`graph/v0`, aditivo).
- Chave `gates:` (CSV) em `runtime:` do `FORGE.md`, consumida por `spec-verify.sh`/`pre-push`.

## ADRs

- ADR de substrato (a criar via TASK-05) — OPA/Rego (principal) / OpenFGA (runner-up ReBAC); stack OSS OTel Collector→Tempo/Loki/Prometheus/Grafana; fronteira PCI Req 7/8. Rules `authz-pdp-pep.md`/`pii-pci-classification.md` referenciam via `based_on:`.

## Rules

- `template/.forge/rules/architecture/authz-pdp-pep.md` (nova, REQ-02) — padrão PDP/PEP, deny-by-default, claims JWT como insumo não decisão.
- `template/.forge/rules/architecture/pii-pci-classification.md` (nova, REQ-03) — mapa controle→PCI 3/4/7/8/10, ref a `domain/audit-immutability.md`.
- `template/.forge/rules/architecture/observability.md` (estendida, REQ-04) — golden signals + alerts-as-code + stack OSS.
- `template/.forge/rules/architecture/jwt-permissions.md` (estendida, REQ-02) — claims são insumo do PEP.
- `template/.forge/rules/README.md` — índice atualizado a cada rule nova/estendida.

## Invariantes críticas

- Zero-dependência (NFR-01): todo `lib/*.mjs` novo roda em Node puro — nada de `opa`/pacote npm novo em runtime.
- Determinismo (NFR-02): mesma entrada ⇒ mesma saída/exit code em execuções repetidas.
- Proporcionalidade (NFR-03): change que não toca `layer:api`/dados sensíveis não sofre exigência nova.
- Sem regressão (NFR-04): `tests/run-all.sh` permanece 100% verde — `gw3-data-governance-gate.sh` e `w20-spec-gate.sh` em particular não podem quebrar.
- Awk de `spec-verify.sh`/`pre-push` só lê `runtime:` — blocos novos (`authz:`/`observability:`) nunca são varridos por eles, só por `graph-build.mjs` via `yaml-lite`.
- REQ-05 (deny-by-default) e REQ-12(a) (PAN/PII em log) são sempre `enforce`, nunca rebaixáveis a `warn`.
- Ausência de bloco declarativo (`authz:`/`observability:`) ⇒ gate dependente em no-op — nunca falso-positivo.
