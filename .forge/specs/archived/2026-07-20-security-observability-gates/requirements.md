# Requirements — security-observability-gates

> Requisitos do change `security-observability-gates`. Cada requisito é verificável e rastreável à proposal.
> Escopo: **camada de imposição no harness** (`template/.forge/**` + `plugin/`). Comportamento observável = o harness passa a *declarar*, *impor* (gate que quebra o build) e *evidenciar* as quatro famílias transversais (observabilidade, audit trail, PII/PCI, RBAC/ABAC). Artefatos de runtime dos projetos consumidores são fora de escopo (proposal §3).
> Convenção de fixture: "código real" = arquivo-fonte na linguagem alvo (`.rego`, `.go`, `.kt`, `.ts`), **não** spec `.md`. Isso é deliberado — os gates varrem código, o que exige generalizar o coletor do `check-data-governance` (proposal §2).

## Camada normativa (constitution + rules)

## REQ-01 — Invariantes de segurança e observabilidade na constitution

- **Quando** o harness é instalado ou atualizado, **o sistema deve** carregar uma constitution que declara como invariantes inegociáveis: (a) toda decisão de acesso passa por um Policy Decision Point (PDP); (b) deny-by-default e fail-closed; (c) toda mutação e toda decisão de acesso é auditável (trilha append-only); (d) nenhum PII/PAN em log; (e) todo boundary de serviço é instrumentado (trace + log estruturado + métrica).
- **Critérios de aceite:**
  - [ ] `template/.forge/constitution.md` contém as cinco cláusulas acima, ancoradas em um item "Security by default".
  - [ ] `validate-rules.sh` não acusa drift após a emenda.
  - [ ] A cláusula (a)/(b) referencia explicitamente que a garantia de aplicação exige a **tríade** gate estático + teste de contrato negativo + evidência de decision-log (o gate estático prova importação, não aplicação — ver REQ-08/REQ-14).
- **Rastreia:** proposal §2 (Constitution), §4 (risco falso-negativo).
- **Notas:** emenda ao item existente, não item novo redundante.
- **Decisão de escopo — audit trail:** das quatro famílias (proposal §1), *audit trail* é imposta de forma **declarativa**, não por gate de varredura de código. Motivo: "toda mutação emite audit event" não é detectável estaticamente de forma genérica sem falso-positivo alto (exigiria saber quais funções são mutações). A imposição de audit trail é a tríade: (i) invariante REQ-01(c) na constitution; (ii) o **mapa de eventos auditáveis** obrigatório no template (REQ-13), conferido pelo `validate-spec`; (iii) a rule `domain/audit-immutability.md` existente, referenciada por `pii-pci-classification.md` (REQ-03). A execução/emissão real do evento é do projeto consumidor (fora de escopo).

## REQ-02 — Rule-pack authz-pdp-pep

- **Quando** um agente ou humano especifica uma superfície de acesso, **o sistema deve** oferecer a rule `rules/architecture/authz-pdp-pep.md` que define o padrão PDP/PEP, OPA/Rego como substrato recomendado (OpenFGA como runner-up para ReBAC), deny-by-default, fail-closed, e que claims JWT são **insumo** do PEP — nunca o mecanismo de decisão.
- **Critérios de aceite:**
  - [ ] Arquivo existe com frontmatter padrão; `based_on: []` (convenção G3 — o template não traz ADRs) com o ADR-0002 de substrato referenciado **em prosa**; o projeto adotante ancora num ADR próprio.
  - [ ] Indexado em `rules/README.md`; `validate-rules.sh` passa.
  - [ ] A rule `jwt-permissions.md` é atualizada para deixar claro que claims são insumo do PEP.
- **Rastreia:** proposal §2 (Rule-packs).
- **Notas:** coerência com `security-and-compliance.md` e `jwt-authentication.md` existentes.

## REQ-03 — Rule-pack pii-pci-classification

- **Quando** um change manipula dados, **o sistema deve** oferecer a rule `rules/architecture/pii-pci-classification.md` que exige classificação de dados como código, mascaramento em log, fronteira de tokenização, e mapeia os controles aos requisitos PCI DSS 4.0.1 (Req 3 storage, Req 4 transit, Req 7 acesso, Req 8 identidade — fronteira explícita, Req 10 audit trail).
- **Critérios de aceite:**
  - [ ] Arquivo existe, indexado, `validate-rules.sh` passa.
  - [ ] Mapa explícito controle→requisito PCI presente na rule.
  - [ ] A fronteira "esta capability cobre Req 7 e a parte de audit de Req 10; identidade/Req 8 fica no auth-service" está documentada.
  - [ ] A rule referencia `domain/audit-immutability.md` (imposição declarativa de audit trail, rastreando PCI Req 10) — sustenta a tríade de audit trail declarada em REQ-01.
- **Rastreia:** proposal §2 (Rule-packs), §3 (Req 8 fora de escopo).

## REQ-04 — Extensão da rule de observabilidade (inclui alerts-as-code)

- **Quando** um change adiciona um boundary de serviço, **o sistema deve** exigir, via `rules/architecture/observability.md` estendida, que o boundary emita span + log estruturado + métrica (golden signals) e que alertas sejam definidos como código versionado (alerts-as-code), na stack OSS OTel Collector → Tempo/Loki/Prometheus/Grafana.
- **Critérios de aceite:**
  - [ ] `observability.md` cobre os três sinais por boundary + alerts-as-code + a stack OSS nomeada.
  - [ ] `validate-rules.sh` passa; sem regressão nas seções pré-existentes.
- **Rastreia:** proposal §2 (Rule-packs — observability).

## Camada de imposição (gates deterministas)

## REQ-05 — Gate check-authz: deny-by-default

- **Quando** o gate `check-authz` roda sobre um diretório de política, **o sistema deve** reprovar (`CONFLICT`/exit≠0) se qualquer package Rego não contiver `default allow := false` ou contiver `allow` incondicional/`default allow := true`; e aprovar quando todos os packages são deny-by-default.
- **Critérios de aceite:**
  - [ ] Fixture `.rego` (código real) com package sem deny-by-default → gate FAIL nomeando o arquivo.
  - [ ] Fixture `.rego` deny-by-default → gate PASS.
  - [ ] Implementado como `check-authz.sh` + `lib/check-authz.mjs` (zero-dep), sobre o coletor de código generalizado (ver REQ-12/Notas).
- **Rastreia:** proposal §2 (Gates — check-authz), risco fail-closed §4.

## REQ-06 — Gate check-authz: nenhuma decisão imperativa fora do PEP

- **Quando** o gate `check-authz` roda sobre o código, **o sistema deve** reprovar quando encontra anti-padrões de decisão de acesso imperativa (ex.: `hasRole(`, `user.role ==`, `claims["permissions"]`, decorators de role ad-hoc) **fora** do diretório do PEP declarado.
- **Critérios de aceite:**
  - [ ] Lista `ANTI` por stack (Go/Kotlin/TS) no molde de `check-data-governance.mjs`.
  - [ ] Fixture de código real com ocorrência fora do PEP → FAIL; a mesma dentro do diretório do PEP → PASS.
  - [ ] O diretório do PEP é lido do bloco declarativo `authz:` (REQ-11); este gate respeita o modo warn/enforce (REQ-16).
- **Rastreia:** proposal §2 (Gates — check-authz).

## REQ-07 — Gate check-authz: cobertura de teste de política

- **Quando** o gate `check-authz` roda e o bloco `authz:` declara um `policy_coverage_threshold`, **o sistema deve** reprovar se a cobertura de teste de política reportada estiver abaixo do threshold, e aprovar quando igual ou acima.
- **Critérios de aceite:**
  - [ ] Fixture com relatório de cobertura abaixo do threshold declarado → FAIL indicando cobertura×threshold.
  - [ ] Fixture com cobertura ≥ threshold → PASS.
  - [ ] Ausência de threshold declarado → check em no-op (não falso-positivo). O ramo de FAIL (cobertura < threshold) respeita o modo warn/enforce (REQ-16).
- **Rastreia:** proposal §2 (Gates — check-authz: "cobertura de teste de política").
- **Notas:** o harness verifica o **valor reportado** contra o threshold; a geração da cobertura (ex.: `opa test --coverage`) é do projeto consumidor.

## REQ-08 — Gate de grafo: rota sem caminho ao PEP

- **Quando** o code-graph é construído, **o sistema deve** reprovar todo node `layer:api` que não alcance (edge direto ou transitivo) o módulo PEP declarado — com exceções só por allowlist versionada.
- **Critérios de aceite:**
  - [ ] Fixture com rota sem import ao PEP → FAIL nomeando o arquivo.
  - [ ] Rota na allowlist (ex.: health, metrics) → PASS.
  - [ ] Usa `lib/graph-deps.mjs` sobre `graph.json`; respeita o modo warn/enforce (REQ-16).
- **Rastreia:** proposal §2 (code-graph), risco falso-negativo §4.
- **Notas:** este gate prova *importação*, não *aplicação* — a prova comportamental (401/403) fica em REQ-14.

## REQ-09 — Gate check-observability: boundary não instrumentado e logger cru

- **Quando** o gate `check-observability` roda, **o sistema deve** reprovar (a) node `layer:api` sem caminho ao wrapper de instrumentação declarado e (b) uso de logger cru (`fmt.Println`, `console.log`, `print(` em contexto de serviço) fora do wrapper.
- **Critérios de aceite:**
  - [ ] Fixture de código real: boundary sem wrapper → FAIL; com wrapper → PASS.
  - [ ] Fixture com logger cru → FAIL; via logger estruturado → PASS.
  - [ ] `check-observability.sh` + `lib/check-observability.mjs` zero-dep; respeita o modo warn/enforce (REQ-16).
- **Rastreia:** proposal §2 (Gates — check-observability).

## REQ-10 — Gate check-observability: alerts-as-code por serviço

- **Quando** o gate `check-observability` roda sobre um serviço novo (boundary declarado), **o sistema deve** reprovar se não existir ao menos um artefato `alerts-as-code` válido (schema REQ-14) associado ao serviço.
- **Critérios de aceite:**
  - [ ] Fixture: serviço com boundary e sem artefato alerts-as-code → FAIL nomeando o serviço.
  - [ ] Serviço com artefato alerts-as-code válido → PASS.
  - [ ] Respeita o modo warn/enforce (REQ-16) — nasce `warn` em brownfield.
- **Rastreia:** proposal §2 (Gates — check-observability: "alerts-as-code presentes").

## REQ-11 — Blocos declarativos authz/observability no FORGE.md + extensão do code-graph

- **Quando** o code-graph é construído a partir do `FORGE.md`, **o sistema deve** reconhecer blocos de frontmatter `authz:` (paths do módulo PEP, allowlist, `mode`, `policy_coverage_threshold`) e `observability:` (paths do wrapper, allowlist, `mode`) e materializá-los para os gates (REQ-06/07/08/09/10) consumirem.
- **Critérios de aceite:**
  - [ ] `graph-build.mjs` lê os blocos sem quebrar o parsing do bloco `runtime:` existente.
  - [ ] Ausência dos blocos ⇒ gates dependentes em no-op (não falso-positivo).
  - [ ] Schema do `FORGE.md`/graph atualizado e validando.
- **Rastreia:** proposal §2 (code-graph). Habilita REQ-06, REQ-07, REQ-08, REQ-09, REQ-10.

## REQ-12 — Extensão do check-data-governance: PII/PAN em log e classificação obrigatória

- **Quando** o gate de data-governance roda, **o sistema deve** reprovar (a) PAN/PII em log via regex/taint (ex.: PAN de 13–19 dígitos, CPF, e-mail em chamada de log) e (b) campo marcado sensível sem classificação declarada no artefato `data-classification`.
- **Critérios de aceite:**
  - [ ] Fixture de código real com PAN em `log.info(...)` → FAIL; mascarado → PASS.
  - [ ] Campo sensível sem classificação → FAIL.
  - [ ] Estende `lib/check-data-governance.mjs` sem regressão nos checks atuais.
- **Rastreia:** proposal §2 (Gates — extensão do check-data-governance).
- **Notas de escopo (decisão):** o coletor atual do `check-data-governance` varre apenas `.md`. Este change **generaliza o coletor** para um leitor de código-fonte parametrizável por extensão/glob, reusado por `check-authz` (REQ-05/06), `check-observability` (REQ-09) e por esta extensão. É extensão do engine existente, não engine novo paralelo.

## Camada de declaração (templates) e contratos (schemas)

## REQ-13 — Seções obrigatórias no template de requirements/NFRD

- **Quando** um change toca uma superfície `layer:api` ou manipula dados, **o sistema deve** exigir, via template, o preenchimento de: mapa endpoint→ação→recurso→policy, tabela dado→classificação, checklist de sinais OTel por boundary, e **mapa de eventos auditáveis (mutação→audit event append-only)** — esta última é a superfície declarativa de imposição da família *audit trail*; e `validate-spec` deve reprovar o change que toca `layer:api` sem o mapa endpoint→policy nem o mapa de eventos auditáveis.
- **Critérios de aceite:**
  - [ ] Template `templates/spec/requirements.md` ganha as quatro seções.
  - [ ] `lib/validate-spec.mjs` reprova change `layer:api` sem mapa endpoint→policy nem mapa de eventos auditáveis.
  - [ ] Change que não toca `layer:api`/dados passa sem exigir as seções (proporcionalidade — NFR-03).
- **Rastreia:** proposal §2 (Templates).

## REQ-14 — Schemas authz-map, data-classification, alerts-as-code

- **Quando** os artefatos declarativos são validados, **o sistema deve** oferecer schemas JSON para `authz-map`, `data-classification` e `alerts-as-code`, cada um validando um exemplo canônico e reprovando um exemplo inválido; e o `authz-map` deve exigir, por endpoint, a **declaração** de um teste de contrato negativo (401 sem token, 403 sem permission).
- **Critérios de aceite:**
  - [ ] Três schemas em `template/.forge/schemas/`.
  - [ ] Fixture válido passa; fixture inválido reprova, para cada schema.
  - [ ] `authz-map` reprova entrada de endpoint sem o campo de teste de contrato negativo declarado.
- **Rastreia:** proposal §2 (Schemas), §4 (tríade anti-falso-negativo).
- **Notas de fronteira:** o harness exige a **declaração** e o **mapeamento** do teste de contrato; a **execução** do teste (e a coleta de evidência de decision-log) roda no CI do projeto consumidor — fora de escopo deste change (proposal §3).

## Integração, plugin e fricção de brownfield

## REQ-15 — Gates integrados a verify, pre-push e CI

- **Quando** um change é verificado (`spec-verify.sh`), empurrado (`pre-push`) ou roda no CI, **o sistema deve** executar os novos gates (`check-authz`, `check-observability`, data-governance estendido) via declaração no `FORGE.md`, registrando resultado no run-manifest.
- **Critérios de aceite:**
  - [ ] Os gates aparecem como checks no `spec-verify.sh` e no `pre-push`.
  - [ ] Resultado (pass/fail por gate) consta do `run-manifest.json`.
  - [ ] `tests/run-all.sh` cobre os novos gates e permanece verde (baseline atual + novos).
- **Rastreia:** proposal §2 (integração).

## REQ-16 — Modo warn + allowlist para brownfield (gates de adoção)

- **Quando** um gate de **adoção** — os que reprovam por ausência de estrutura nova que o repo brownfield ainda não incorporou: REQ-06 (anti-imperativo fora do PEP), REQ-07 (cobertura de política), REQ-08 (rota→PEP), REQ-09 (boundary→wrapper), REQ-10 (alerts-as-code) — roda em repo brownfield, **o sistema deve** suportar modo `warn` (reporta sem bloquear) + allowlist versionada, com default seguro para não travar repos que ainda não têm PEP/wrapper/threshold — replicando a lição das issues #20/#21.
- **Critérios de aceite:**
  - [ ] Modo lido do bloco `authz:`/`observability:` do `FORGE.md` (`mode: warn|enforce`), aplicado aos cinco gates de adoção (REQ-06/07/08/09/10).
  - [ ] `mode: warn` → exit 0 com aviso; `mode: enforce` → exit≠0 no achado.
  - [ ] Os gates **inegociáveis** REQ-05 (deny-by-default no Rego) e REQ-12 (PAN/PII em log) **nunca** são rebaixáveis a warn — sempre enforce, coerente com REQ-01(b)/(d) e proposal §4 (fail-closed é invariante; PAN em log é violação PCI direta).
  - [ ] Comportamento documentado nas rules `authz-pdp-pep.md` e `observability.md`.
- **Rastreia:** proposal §4 (risco brownfield). Corrige os conflitos das iterações 1 e 2 (cobertura de warn para REQ-07 e a fronteira rebaixável×inegociável).
- **Notas:** os estados `warn|enforce` são estáticos. A **política de transição temporal** (quando/quem promove `warn`→`enforce`) é decisão operacional registrada no ledger via `/forge:defer`/roadmap — não um flip automático deste change.

## REQ-17 — Plugin regenerado e ADR de decisão

- **Quando** o change é publicado, **o sistema deve** regenerar `plugin/forge/**` refletindo rules/comandos novos, e registrar um ADR no baseline documentando a decisão de substrato (OPA/Rego; OpenFGA runner-up; stack OSS OTel).
- **Critérios de aceite:**
  - [ ] `npm run build:plugin` passa e o diff do plugin reflete as rules novas.
  - [ ] ADR criado no baseline; rules `based_on:` apontam a ele; `validate-rules.sh` sem drift.
  - [ ] `CHANGELOG.md` atualizado.
- **Rastreia:** proposal §2 (Plugin, Docs/ADR).

## Requisitos não funcionais do change

- **NFR-01 —** Gates zero-dependência: todos os `lib/*.mjs` novos rodam com Node puro, sem instalar pacote (método: `npm test` em ambiente limpo; fonte: CI).
- **NFR-02 —** Determinismo: mesma entrada ⇒ mesma saída/exit code em execuções repetidas (método: rodar o gate 3× sobre a mesma fixture; fonte: teste).
- **NFR-03 —** Proporcionalidade: change que não toca `layer:api` nem dados sensíveis não sofre exigência nova (método: fixture de change trivial passa sem as seções; fonte: teste).
- **NFR-04 —** Sem regressão: `tests/run-all.sh` permanece 100% verde após o change (método: run-all; fonte: CI).

## Checklist de cobertura de superfície

| REQ | Parâmetro/config exposto | Superfície (arquivo/config) | Coberto por task |
|---|---|---|---|
| REQ-11/16 | bloco `authz:` (paths, allowlist, `mode: warn\|enforce`, `policy_coverage_threshold`) | frontmatter do `FORGE.md` (block-sequence, lido por `yaml-lite`) | TASK-03 (schema), TASK-07 (parsing) |
| REQ-11/16 | bloco `observability:` (paths, allowlist, `mode`) | frontmatter do `FORGE.md` (block-sequence, lido por `yaml-lite`) | TASK-03 (schema), TASK-07 (parsing) |
| REQ-15 | chave `gates:` (CSV escalar, lida por awk) | bloco `runtime:` do `FORGE.md` | TASK-03 (schema), TASK-17 (loop) |
| REQ-13 | seções obrigatórias | `templates/spec/requirements.md` | TASK-09 |
| REQ-13/NFR-03 | `affects_surfaces` | `manifest.yaml` | TASK-04 |
| REQ-01 | invariantes | `constitution.md` | TASK-06 |
| REQ-14 | artefatos declarativos | schemas `authz-map`/`data-classification`/`alerts-as-code` | TASK-08 |

- Nenhum parâmetro sem superfície mapeada. As demais REQs (rules, gates, engine) entregam arquivos determinísticos sem parâmetro configurável exposto — "sem parâmetro exposto".

## Fora de escopo (reafirmação)

- PEP libs concretas (Go/Kotlin/TS), repositório de política OPA, `authz-console` UI, wrappers OTel concretos — runtime dos projetos consumidores, follow-up cross-repo.
- Piloto no axis-go-cloud — outro repo, outro pipeline.
- Autenticação/identidade (PCI Req 8) — permanece no auth-service e nas rules JWT existentes.
- Execução dos testes de contrato negativos e coleta de evidência de decision-log — rodam no CI do projeto consumidor (o harness exige declaração/mapeamento, não execução).
- Flip temporal automático de `warn`→`enforce` — decisão operacional via ledger.
