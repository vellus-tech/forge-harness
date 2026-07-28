# 0002. Substrato de autorização e observabilidade: OPA/Rego + stack OSS OTel

- **Status:** accepted
- **Data:** 2026-07-20
- **Decisores:** Milton (gate HITL de design do change `security-observability-gates`)

## Contexto e Problema

O change `security-observability-gates` estende o harness com uma camada de imposição determinista para quatro preocupações transversais — RBAC/ABAC, observabilidade, audit trail e PII/PCI — atravessando constitution → rules → gates policy-as-code → verify/pre-push/CI, fechando o risco de compliance PCI DSS 4.0.1 de depender de revisor humano lembrar de checar essas famílias em cada serviço fintech consumidor. Era preciso fixar, antes das rules `authz-pdp-pep.md` e `pii-pci-classification.md` (que referenciam esta decisão em prosa — `based_on: []` por convenção G3, já que o template não traz ADRs; o projeto adotante ancora via `based_on` num ADR próprio), qual substrato de política de autorização e qual stack de observabilidade o harness recomenda e sobre qual desenho os gates deterministas (`check-authz.sh`, `check-observability.sh`) são escritos.

## Drivers da Decisão

- **Zero-dependency em runtime dos projetos-alvo** (NFR-01 do change) — os gates do harness rodam em Node puro; nenhum binário (`opa`) ou pacote novo é obrigatório para o harness em si, ainda que o substrato recomendado ao consumidor use ferramentas externas.
- **Testabilidade e auditabilidade da decisão de autorização** — PCI DSS 4.0.1 Req 7 exige controle de acesso formal, revisável e comprovável; decisão de autorização espalhada em `if`s imperativos não é auditável nem testável de forma centralizada.
- **Deny-by-default / fail-closed** como invariante inegociável (REQ-05, sempre enforce) — o substrato precisa suportar esse padrão de forma nativa e verificável por regex/gate estático.
- **Padrão de mercado com ecossistema OSS maduro** para PDP (Policy Decision Point) e observabilidade, reduzindo custo de manutenção do harness e dos times consumidores.
- **Necessidade futura de ReBAC** (compartilhamento por objeto, ex.: "usuário X pode ver a fatura Y porque pertence ao mesmo tenant") — cenário que RBAC/ABAC puro modela com dificuldade.
- **Greenfield da stack de observabilidade** — o harness ainda não impunha um padrão de coleta/armazenamento de telemetria; a escolha precisa ser OSS, autoalojável e coerente com o zero-dep do harness (o harness gera rules/gates, não roda a stack).

## Opções Consideradas

1. **OPA/Rego (Open Policy Agent) como PDP/PEP principal** — engine de política declarativa, linguagem Rego, deny-by-default nativo, adotado amplamente em Kubernetes/API gateways/microsserviços.
2. **OpenFGA como substrato principal** — motor ReBAC (baseado no Zanzibar do Google), forte para compartilhamento por objeto/relacionamento, mas menos maduro para RBAC/ABAC genérico de linha de negócio.
3. **Cedar (AWS)** — linguagem de política formalmente verificável, boa ergonomia, mas majoritariamente amarrada ao ecossistema AWS gerenciado (Amazon Verified Permissions); adoção fora da AWS é nascente.
4. **Enforcement imperativo espalhado** (`if user.role == "admin"` em cada handler) — sem engine dedicado, decisão embutida no código de negócio.
5. **Stack de observabilidade**: OTel Collector → Tempo/Loki/Prometheus/Grafana (OSS, CNCF) vs. Jaeger (tracing isolado, sem Loki/Prometheus/Grafana integrados) vs. stacks proprietárias gerenciadas (Datadog, New Relic).

## Decisão

**OPA/Rego como substrato principal de política (PDP/PEP)** para autorização RBAC/ABAC, com **OpenFGA registrado como runner-up** para cenários de ReBAC (compartilhamento por objeto) quando/se um consumidor precisar desse modelo — não substitui OPA, complementa-o num boundary específico. Para observabilidade, a stack recomendada é **OSS greenfield: OTel Collector como ponto único de coleta, com Tempo (traces), Loki (logs) e Prometheus (métricas) como backends e Grafana como camada de visualização**; Jaeger permanece como alternativa compatível via OTLP para quem já o tem em produção, mas deixa de ser o padrão nas rules novas do harness. Rego permite expressar deny-by-default de forma literal e detectável por gate estático (regex sobre o padrão estrutural do arquivo `.rego`), é o padrão de fato para PDP externo ao código de negócio, e mantém o harness em si zero-dep (o gate lê e varre texto Rego, nunca invoca o binário `opa`). Cedar fica descartado como padrão atual e reavaliado apenas se um consumidor migrar para AWS Verified Permissions gerenciado — nesse caso a rule `authz-pdp-pep.md` seria revisitada com `superseded by` ou emenda pontual, nunca herdada silenciosamente. Enforcement imperativo espalhado é rejeitado como padrão: não é testável centralmente, não é auditável por gate estático de forma confiável, e é exatamente o anti-padrão que a rule `authz-pdp-pep.md` (REQ-02) e o gate `check-authz.sh` (REQ-06) existem para detectar e reprovar.

### Fronteira PCI

Esta capability cobre **PCI DSS 4.0.1 Req 7** (restringir acesso a componentes do sistema e dados de titular de cartão por necessidade de conhecimento — modelado pelo par PDP/PEP em Rego) e a parcela de **Req 10** referente a audit trail e append-only logging das decisões de autorização (decision-log do PDP, sujeito ao mesmo regime anti-PII/PAN do `check-data-governance`, REQ-12(a), sempre enforce). **Req 8** (identificação e autenticação de usuários e componentes do sistema) permanece explicitamente **fora de escopo** deste change e desta decisão — é responsabilidade do `auth-service` de cada consumidor; os claims de um JWT emitido pelo `auth-service` são consumidos pelo PEP apenas como **insumo** de contexto, nunca como mecanismo de decisão de autorização (rule `jwt-permissions.md`, estendida por REQ-02).

## Consequências

- **Positivas:** as rules `authz-pdp-pep.md` (REQ-02) e `pii-pci-classification.md` (REQ-03) referenciam esta decisão em prosa (`based_on: []`, convenção G3; a ancoragem formal é opt-in do projeto adotante), dando aos consumidores um substrato único e testável em vez de reinventar PDP a cada serviço; os gates deterministas `check-authz.sh` (deny-by-default sempre enforce, anti-decisão-imperativa fora do PEP, cobertura vs. threshold) e `check-observability.sh` (logger cru, boundary→wrapper, alerts-as-code) têm um alvo estrutural estável para regex/reachability; a fronteira PCI Req 7/8/10 fica documentada num único lugar, evitando que cada consumidor redesenhe a mesma divisão de responsabilidade entre PDP de autorização e `auth-service`; OpenFGA fica disponível como caminho já avaliado para ReBAC, sem exigir nova pesquisa de mercado quando o cenário aparecer.
- **Negativas/débitos:** o gate `check-authz.sh` faz parsing de Rego por regex sobre padrão textual, não por AST real — fragilidade documentada como limitação conhecida na rule `authz-pdp-pep.md` e coberta por fixtures pass/fail; o harness não valida em runtime que a política Rego é semanticamente correta (isso é responsabilidade do `opa test` do consumidor, fora do zero-dep do harness); adotar dois motores de política (OPA para RBAC/ABAC, OpenFGA como runner-up ReBAC) introduz superfície de decisão dupla para quem eventualmente precisar de ambos, mitigada por manter OpenFGA estritamente como complemento, nunca substituto, do PDP principal; a promoção de Jaeger para "alternativa compatível" (em vez de padrão) exige nota de reconciliação na rule `observability.md` para consumidores que já rodam Jaeger em produção, sem forçar migração.

## Links

- Change de origem: `security-observability-gates` (TASK-05, REQ-17, §2.7 de `design.md`)
- Rules que ancoram nesta decisão: `template/.forge/rules/architecture/authz-pdp-pep.md`, `template/.forge/rules/architecture/pii-pci-classification.md`, `template/.forge/rules/architecture/observability.md` (todas referenciam este ADR em prosa, com `based_on: []` — convenção G3; a ancoragem formal via `based_on` é opt-in do projeto adotante)
