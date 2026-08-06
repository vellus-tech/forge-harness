# Verification — security-observability-gates

## Resultado: APROVADO

Checkpoint review REQ a REQ contra o código real (não contra o tracker). Os 17 REQ e as 4
NFR foram conferidos abrindo os arquivos citados em `paths` de cada task, os `lib/*.mjs`, os
`tests/*-gate.sh` correspondentes e rodando `tests/run-all.sh` de ponta a ponta. Nenhum REQ
reprovado; três observações de desvio registradas abaixo (nenhuma bloqueante — todas já
documentadas em prosa pelo próprio change ou consequência de uma restrição estrutural do
harness que o design já reconhecia).

## Evidências por requisito

| REQ | Implementado em | Verificado por | Status |
|---|---|---|---|
| REQ-01 | `template/.forge/constitution.md` item 7 "Security by default" — princípio universal + remissão aos rule-packs opt-in `authz`/`pii-pci` (ver desvio 5) | `validate-rules.sh` (sem drift); inspeção manual do texto | OK |
| REQ-02 | `template/.forge/rules/architecture/authz-pdp-pep.md` (PDP/PEP, OPA/Rego, OpenFGA runner-up, deny-by-default, fail-closed, claims=insumo) + `jwt-permissions.md` atualizada | `validate-rules.sh`; indexação em `rules/README.md:55` | OK |
| REQ-03 | `template/.forge/rules/architecture/pii-pci-classification.md` (mapa controle→PCI 3/4/7/8/10; fronteira Req 7 vs Req 8; referencia `domain/audit-immutability.md`) | `validate-rules.sh`; indexação em `rules/README.md:56` | OK |
| REQ-04 | `template/.forge/rules/architecture/observability.md` estendida (golden signals + alerts-as-code + stack OTel Collector→Tempo/Loki/Prometheus/Grafana, Jaeger como alternativa) | `validate-rules.sh`; indexação em `rules/README.md:52` | OK |
| REQ-05 | `template/.forge/scripts/lib/check-authz.mjs:53-72` (DENY_DEFAULT_RE/ALLOW_TRUE_DEFAULT_RE/UNCONDITIONAL_ALLOW_RE, sempre `enforceable:true`) | `tests/check-authz-gate.sh` [1]-[4] | OK |
| REQ-06 | `check-authz.mjs:74-89` (matriz `ANTI_IMPERATIVE` Go/Kotlin/TS via `scan()`, filtra fora de `pep_paths`) | `tests/check-authz-gate.sh` [5]-[7] | OK |
| REQ-07 | `check-authz.mjs:91-110` (lê `--coverage-report`, compara com `policy_coverage_threshold`; ausência ⇒ no-op) | `tests/check-authz-gate.sh` [8]-[9] | OK |
| REQ-08 | `template/.forge/scripts/lib/graph-govern.mjs` (`checkRole`/`reaches`/`govern`, role `pep`) consumido em `check-authz.mjs:112-117` | `tests/check-authz-gate.sh` [10]; `tests/graph-govern-gate.sh` [1]-[5] | OK |
| REQ-09 | `template/.forge/scripts/lib/check-observability.mjs` — REQ-09a via `graph-govern` (role `otel-wrapper`), REQ-09b via matriz `ANTI` (`console.log`/`fmt.Println`/`print(`) em `checkRawLoggers` | `tests/check-observability-gate.sh` [2],[3],[5],[8]-[11]; `tests/graph-govern-gate.sh` [6] | OK |
| REQ-10 | `check-observability.mjs:65-159` (`validateAlertsAsCode`, `boundaryOf`, `collectAlertsServices`) | `tests/check-observability-gate.sh` [4],[6],[8]-[9] | OK |
| REQ-11 | `template/.forge/scripts/lib/graph-build.mjs:43-91,265-266,328-334` (lê `authz:`/`observability:` via `parseYamlSubset`, taggeia `roles`, emite `governance`); `graph.schema.json` (`roles`, `governance`); `forge.schema.json` (`authz`, `observability`, `runtime.gates`) | `tests/w20-spec-gate.sh` [7]; `tests/w41-graph-gate.sh`; `tests/yaml-lite-gate.sh` [4] | OK |
| REQ-12 | `template/.forge/scripts/lib/check-data-governance.mjs:51-107` (REQ-12a `LOG_TAINT` PAN/CPF/e-mail; REQ-12b `SENSITIVE_MARKER_RE` + `data-classification.json`), sobre `lib/source-scan.mjs` (coletor generalizado, `exts` ampliado) | `tests/req12-pii-log-gate.sh` [1]-[5]; `tests/gw3-data-governance-gate.sh` (retrocompat) | OK |
| REQ-13 | `template/.forge/templates/spec/requirements.md` (4 seções: endpoint→policy, dado→classificação, sinais OTel, mapa auditável); `validate-spec.mjs:158-203` (regra condicionada a `affects_surfaces` incluindo `"api"`) | `tests/req13-affects-surfaces-gate.sh` [1]-[3] | OK |
| REQ-14 | `template/.forge/schemas/authz-map.schema.json` (`negative_contract_test` required), `data-classification.schema.json`, `alerts-as-code.schema.json` | `tests/w30-schemas-gate.sh` [6] (fixtures válido/inválido para os três) | OK |
| REQ-15 | `spec-verify.sh:70-87` e `hooks/git/pre-push:67-85` (loop `gates:` CSV, `run_check`, resultado em `verification.yaml`/run-manifest) | `tests/w90-run-manifest-gate.sh`; `run-manifest.json` real desta verify (`evidence/runs/20260720232649-dea3d309/run-manifest.json`) com `commands[0].status: passed` | OK |
| REQ-16 | `template/.forge/scripts/lib/gate-mode.mjs` (`readMode` default `warn`, `applyMode` respeita `enforceable`) consumido pelos 3 gates da Wave 4 | `tests/gate-mode-gate.sh` [1]-[5]; `tests/check-authz-gate.sh` [2],[6],[10]; `tests/check-observability-gate.sh` [7],[9]-[10] | OK |
| REQ-17 | `plugin/forge/**` regenerado (`npm run build:plugin` → diff vazio, ver desvio 3 abaixo); ADR `.forge/product/current/adr/0002-authz-observability-substrate.md` indexado; `CHANGELOG.md` (seção `[Unreleased]`) | `npm run build:plugin` (rodado nesta verificação — `OK plugin 'forge' v0.1.0-rc22 → plugin/forge`, sem diff); `.forge/product/current/adr/README.md:9` | OK (ver desvio 3) |
| NFR-01 (zero-dep) | Todos os `lib/*.mjs` novos usam só `node:fs`/`node:path`; `git diff package.json` vazio (nenhuma dependência nova) | inspeção de imports + `tests/run-all.sh` em ambiente sem instalação nova | OK |
| NFR-02 (determinismo) | Fixtures determinísticas (regex/BFS sem I/O não-determinístico) | `tests/check-authz-gate.sh` rodado 3× manualmente nesta verificação — saída byte-idêntica nas 3 execuções | OK |
| NFR-03 (proporcionalidade) | `affects_surfaces` opcional no manifest; ausência ⇒ nenhuma seção nova exigida | `tests/req13-affects-surfaces-gate.sh` [3] | OK |
| NFR-04 (sem regressão) | `source-scan.collect` mantém `exts={'.md'}` default; `gw3`/`w20`/`w30`/`w41`/`gw2`/`w90` inalterados em comportamento | `tests/run-all.sh` completo — ver "Checks deterministas" | OK |

## Checks deterministas

- `bash tests/run-all.sh` (rodado nesta verificação): **PASS=56 FAIL=0 SKIP=0** (119s) — 54 gates + 2 suítes bats, 100% verde. Inclui os 8 gates novos deste change (`check-authz-gate.sh`, `check-observability-gate.sh`, `gate-mode-gate.sh`, `graph-govern-gate.sh`, `req12-pii-log-gate.sh`, `req13-affects-surfaces-gate.sh`, `yaml-lite-gate.sh`, além das extensões em `w20`/`w30`/`w41`/`w90`) e prova a retrocompatibilidade (`gw3-data-governance-gate.sh`, `w20-spec-gate.sh` continuam verdes).
- `node template/.forge/scripts/lib/stage-contract.mjs check --root <repo> --stage verify --change security-observability-gates` → `OK stage-contract verify`.
- `node template/.forge/scripts/lib/stage-contract.mjs validate-contracts --root <repo>` → `OK stage-contracts (5)`.
- `npm run build:plugin` → `OK plugin 'forge' v0.1.0-rc22 → plugin/forge` (52 comandos), diff vazio (esperado — ver desvio 3).
- Determinismo (NFR-02): `tests/check-authz-gate.sh` executado 3× em sequência — `diff` byte-a-byte entre as 3 saídas confirma saída idêntica.
- `run-manifest` real: `.forge/specs/active/security-observability-gates/evidence/runs/20260720232649-dea3d309/run-manifest.json` — `stage: verify`, `status: passed`, comando `spec-verify.sh security-observability-gates` com `status: passed`.

## Desvios e observações

1. **`graph-govern.mjs` reimplementa reachability em vez de importar `graph-deps.mjs`.** `lib/graph-govern.mjs:1-20` documenta explicitamente a razão: `graph-deps.mjs` é um script CLI top-level (não exporta símbolos), então a adjacência/BFS é reconstruída localmente em vez de importada. Desvio do texto do design (§1: "reusa essa maquinaria de reachability, não a reinventa") em relação à letra, mas coerente com a intenção (mesma técnica, granularidade nó-a-nó em vez de módulo-a-módulo) — decisão documentada no próprio código-fonte, não um gap silencioso.

2. **`gates:` vazio no `FORGE.md` do template, e o harness (`forge-harness` repo) não tem `.forge/FORGE.md` próprio na raiz.** `template/.forge/FORGE.md:24` ship com `gates:` em branco — consistente com todos os outros campos de `runtime:` (`primary_stack`, `run`, `test`, `typecheck`, `lint`), que também nascem em branco por ser o scaffold para o `/forge:init` preencher. Como consequência, o harness-repo (dogfood) não tem um `FORGE.md` na raiz e portanto não exercita `spec-verify`/`pre-push` chamando os gates novos sobre si mesmo — a evidência de integração (REQ-15) vem de `tests/w90-run-manifest-gate.sh` (que fabrica um `FORGE.md` de fixture) e do `run-all.sh`, não de uma execução real do `pre-push` deste repo. Não é um bug: é uma limitação conhecida do modo dogfood do harness (o harness não é ele mesmo um "projeto consumidor" com stack própria).

3. **REQ-17 AC "o diff do plugin reflete as rules novas" não é literalmente satisfazível.** `plugin-build.mjs:1-16` só empacota `template/.forge/commands/**` (slash commands) — rules não fazem parte do conteúdo do plugin. Como este change não adicionou nenhum comando novo, `npm run build:plugin` roda limpo e produz diff vazio em `plugin/forge/**`, o que é o comportamento correto dado o mecanismo, mas não corresponde à leitura literal do critério de aceite (que conflates "rules" com "commands novos"). DoD da TASK-18 (build:plugin passa + run-all 100% verde) está satisfeito; o texto do REQ-17 merece ajuste de redação num próximo change.

4. **ADR-0002, seção "Links", menciona `based_on: [ADR-0002]` para as rules novas** — mas as rules shipadas usam `based_on: []` por design (convenção G3, confirmada pelo próprio REQ-02 AC). É uma imprecisão textual pontual dentro do ADR (a nota de contexto do ADR fala do estado futuro do projeto adotante, não do template), não uma inconsistência de comportamento — `validate-rules.sh` não acusa drift porque `based_on: []` é o valor correto para uma rule shipada pelo template.

5. **REQ-01 reconciliado pré-merge (2026-07-20) — cláusulas específicas deixam de ser invariante universal.** A verificação original acima aprovou a redação com as cinco cláusulas (a)-(e) na constitution como invariante de todo projeto instalador do harness. Decisão do Milton, pré-merge da branch: tornar as cláusulas específicas (PDP, deny-by-default, fail-closed, no-PII-in-log) **opt-in por família de projeto**, não obrigatórias por default (ex.: `axis-fare-validator` não deve herdar a obrigatoriedade que faz sentido para `axis-go-cloud`). `constitution.md` item 7 foi reescrito para o princípio genérico + remissão aos rule-packs `authz`/`pii-pci` (marcados `pack:`/`opt_in: true` no frontmatter de `authz-pdp-pep.md`/`pii-pci-classification.md`); `rules/README.md` documenta o mecanismo. `tests/run-all.sh` recontado 100% verde após a mudança. Requirements/spec.yaml do baseline foram atualizados em conjunto para não afirmar mais a obrigatoriedade universal. A maquinaria de ativação dos packs (installer materializando só os ativos) fica para um change futuro.

Nenhum dos cinco itens acima é bloqueante: são registros de decisão/redação, não falhas de comportamento observável.
