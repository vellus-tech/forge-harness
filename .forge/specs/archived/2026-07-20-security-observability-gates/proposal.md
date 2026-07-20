# Proposal — security-observability-gates

> Change `security-observability-gates` (type: `feature`, scale 3) — criado em 2026-07-20 por milton.

## 1. Por quê (problema / motivação)

Quatro famílias de preocupações transversais precisam de imposição: (1) **observabilidade** — tracing, logging estruturado, metrics, alerts; (2) **audit trail** — trilha append-only de mutações e decisões; (3) **controles de dados sensíveis** — PII/PCI; (4) **autorização granular** — RBAC/ABAC. Num pipeline spec-driven todas falham do mesmo jeito: são *mencionadas* no NFRD e nunca *verificadas contra o código*. Hoje o harness não impõe nenhuma delas de forma determinista — depende de um revisor (humano ou LLM) lembrar de checar. Para operações fintech sob PCI DSS 4.0.1 Nível 1 (Vellus, e por extensão Axis/Ger7), isso é risco de compliance e de segurança não controlado.

A garantia não vem de pedir a um revisor que lembre; vem de transformar cada preocupação numa **capability deterministicamente verificável imposta em várias camadas**, com os *dentes* em policy-as-code que quebra o build. O harness já provou esse padrão com `check-data-governance.sh` + `lib/check-data-governance.mjs` (grep determinista contra matriz normativa, bloqueio com `CONFLICT`). Este change estende esse padrão às quatro preocupações.

## 2. O que muda

Adiciona ao harness (`template/.forge/**` + `plugin/`) a **camada de imposição** das quatro preocupações, atravessando as camadas existentes: constitution (intenção inegociável) → template de NFRD/requirements (declaração obrigatória) → gate policy-as-code (dentes) → `/forge:verify` (evidência REQ a REQ + run-manifest) → testes de contrato (prova comportamental).

Concretamente:

- **Constitution** — emenda ao item "Security by default": toda decisão de acesso passa pelo PDP; deny-by-default; toda mutação/decisão é auditável; nenhum PII/PAN em log; todo boundary é instrumentado.
- **Rule-packs** (`rules/architecture/`) — `authz-pdp-pep.md` (padrão PDP/PEP, OPA/Rego como substrato recomendado, claims JWT são insumo do PEP e não mecanismo de decisão); `pii-pci-classification.md` (classificação de dados como código, mascaramento, fronteira de tokenização, mapeamento aos requisitos PCI 3/4/7/8/10); extensão da `observability.md` existente (span+log estruturado+métrica por boundary, alerts-as-code).
- **Gates deterministas** (`scripts/` + `scripts/lib/*.mjs`) — três gates, todos varrendo **arquivos de código-fonte reais** (Rego, Go, Kotlin, TS) e não apenas specs `.md`, o que exige **generalizar o engine de coleta do `check-data-governance`** (hoje filtra `.md`) para um coletor de código parametrizável reusado pelos três:
  - `check-authz` — deny-by-default no Rego; anti-decisão-imperativa fora do PEP; rota `layer:api` sem caminho ao PEP; cobertura de teste de política abaixo do threshold.
  - `check-observability` — boundary sem instrumentação; logger cru banido; alerts-as-code ausente por serviço.
  - **extensão do `check-data-governance`** (PII/PCI) — PAN/PII em log; campo sensível sem classificação declarada.
  Declarados no bloco `runtime:`/novos blocos do `FORGE.md` para rodarem no pre-push, no `spec-verify.sh` e no CI.
- **Extensão do code-graph** (`scripts/lib/graph-build.mjs`) — reconhecer edges de import até o módulo PEP/wrapper de instrumentação declarado em frontmatter `authz:`/`observability:` do `FORGE.md`, para os gates de grafo reprovarem boundary sem caminho ao PEP/wrapper.
- **Templates de NFRD/requirements** — seção obrigatória: mapa endpoint→ação→recurso→policy, tabela dado→classificação, checklist de sinais OTel por boundary.
- **Schemas** — `authz-map`, `data-classification`, `alerts-as-code`.
- **Plugin** — regenerar `plugin/forge/**` refletindo comandos/rules novos.
- **Docs/ADR** — ADR no baseline registrando a decisão do substrato (OPA/Rego, runner-up OpenFGA para ReBAC; stack OSS greenfield OTel Collector → Tempo/Loki/Prometheus/Grafana).

## 3. O que NÃO muda (fora de escopo)

- **Artefatos de runtime que os projetos consumidores geram usando esta capability** — PEP libs concretas em Go/Kotlin/TS, o repositório de política OPA, a `authz-console` UI, os wrappers OTel concretos. Moram nos projetos (axis-go-cloud etc.), não no template do harness. São follow-up cross-repo.
- **O piloto no axis-go-cloud** — outro repo, outro pipeline; registrado no ledger como follow-up.
- **Autenticação/identidade (PCI Req 8)** — continua no auth-service e nas rules JWT existentes. Esta capability cobre autorização (Req 7) e a parte de audit de Req 10; a fronteira fica explícita no ADR para o QSA não supor que o OPA "faz auth".
- Comportamento dos comandos forge existentes fora dos pontos de extensão listados.

## 4. Impacto

- **Capacidades afetadas:** `forge-harness-template`.
- **Paths afetados:** `template/.forge/constitution.md`, `template/.forge/rules/architecture/`, `template/.forge/scripts/` (+ `lib/`), `template/.forge/schemas/`, `template/.forge/templates/spec/`, `template/.forge/commands/`, `plugin/forge/`, `docs/`, `CHANGELOG.md`, `tests/`.
- **Dependências:** nenhuma spec/código bloqueante; reusa o padrão `check-data-governance` e o engine `graph-build.mjs` existentes.
- **Riscos:**
  - *Falso-negativo estrutural do gate de grafo* (import ≠ aplicação) — mitigar exigindo a tríade gate estático + teste de contrato negativo + evidência de decision-log; nunca vender o gate de grafo sozinho.
  - *Fricção de brownfield* — o gate de grafo deve nascer em modo `warn` + allowlist por N dias, senão repete a fricção das issues #20/#21 no pre-push e trava repos sem PEP/wrapper.
  - *Fail-closed vs disponibilidade* — deny em falha do PDP é inegociável (PCI); documentar como invariante, não como opção.
  - *PII/PAN no input de decisão logado* — mascaramento no PEP antes do log; o decision-log do OPA entra explicitamente no regime anti-PII.

## 5. Próximos passos

`/forge:requirements` → `/forge:design` → `/forge:analyze` (scale 3) → `/forge:tasks` → `/forge:shard` → `/forge:implement` → `/forge:verify` → `/forge:archive` + `/forge:publish-docs`. Execução autônoma (yolo): gates de aprovação decididos por `yolo-gate`; falhas de execução param.
