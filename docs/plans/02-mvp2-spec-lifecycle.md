# Plano MVP2 — Spec Lifecycle

| | |
|---|---|
| **Versão** | 1.1 |
| **Data** | 2026-06-10 |
| **Status** | Aprovado para desenvolvimento |
| **Fases do doc** | Fase 4 (§22.5) + inventário brownfield mínimo (§16.1, antecipação do #15) |
| **MVP** | MVP2 (§23.2) |
| **Depende de** | MVP1 (W1.3) |
| **Backlog (§24)** | #1, #9, #10, #15 (parte lite), #17 (resolução I2) |

## Objetivo

Implementar o ciclo de vida de specs change-based: criação de change ativo com manifest validado, pipeline SDD com loops builder→validator, implementação com checkpoints, verificação e encerramento sem baseline (`close`). Inclui o **dogfooding**: a partir daqui, o próprio desenvolvimento do Forge é rastreado como change ativo.

## Escopo

**Inclui:** `spec-manifest.schema.json` (com `scale` e `dev_loop`), templates de spec/bugfix/refactor, `/forge:spec new`, `/forge:clarify`, `/forge:requirements`, `/forge:design` (ambos com loop), `/forge:tasks`, `/forge:analyze`, `/forge:implement`, `/forge:verify`, `/forge:close`, gates deterministas mínimos, `/forge:discover` lite.

**Não inclui:** `spec-delta.yaml`/archive/baseline (MVP3 — `/forge:archive` ainda não existe; o ciclo termina em `verified` ou `close`), graph completo (MVP4), shard/waves (MVP5).

---

## Waves

### W2.0 — Manifesto, templates de spec e dogfooding

- **Objetivo:** change ativo nasce válido por schema.
- **Entregáveis:**
  - `schemas/spec-manifest.schema.json` — campos da §10.2: id, type, mode, rigor, **scale (0..4)**, status, gates, **dev_loop**, quick_plan, archive.
  - Tabela scale-adaptive (§10.3) codificada como regra: quais fases são obrigatórias por nível; níveis abaixo do risco registram fases puladas + justificativa no manifest.
  - `templates/spec/` (proposal.md, requirements.md, design.md, tasks.md), `templates/bugfix/` (bugfix.md: comportamento atual/esperado/inalterado, root cause, testes de regressão — §11.4), `templates/refactor/` (refactor.md: invariantes, riscos, migração — §11.5).
  - `/forge:spec new --type feature|bugfix|refactor|greenfield|brownfield` — cria `.forge/specs/active/<change-id>/` com manifest validado e template do tipo.
  - `forge validate spec` **versão mínima** (manifest válido + artefatos exigidos pelo tipo/scale presentes); versão completa na W3.1.
  - **Dogfooding (#1):** criar `.forge/specs/active/create-forge-project-harness/` no próprio workspace (type: greenfield, rigor: spec-anchored, scale: 3) e migrar o tracking das waves restantes deste projeto para lá (proposal.md aponta para `docs/plans/`; waves.json/progress.json entram na W5.1 — até lá, tasks.md do change espelha as waves).
- **Depende de:** W1.3
- **Gate:** `forge validate spec` → `OK` no change criado pelo comando; manifest inválido é recusado com mensagem clara.

### W2.1 — Pipeline SDD com loops builder→validator

- **Objetivo:** requirements/design confiáveis com sinal externo (resolução I2: o mecanismo do loop entra aqui, não no MVP5).
- **Entregáveis:**
  - `/forge:clarify` — elicitação de ambiguidades (one-question-at-a-time, regra anti-inferência; remove `NEEDS CLARIFICATION`).
  - `/forge:requirements` e `/forge:design` com loop interno (§14.6): builder gera; validator emite relatório `Status: PASS|FAIL` + `[MISS]`/`[CONFLICT]`/`[CLARIFY]`; **max 3 iterações**; persistindo FAIL, escalonar para humano. Migrar/adaptar os agentes validadores existentes do template (requirements/design validators).
  - Gates HITL via AskUserQuestion (§12.1): opções canônicas Approve/Review/Reject/Supersede/Abandon/Block; tudo que não é Approve exige motivo, gravado em `approvals.yaml` (`decision` + `reason`); resumo de 2-3 linhas, sem despejar artefato no chat.
  - Migração do `run-spec-pipeline`/`specs-loop` para operar sobre o change ativo (§22.5) — pipeline amplo (Discovery → PRD → FRD/NFRD → DDD → Modules → TRD) disponível para scale 4. **É aqui que a saída dos commands de spec deixa de ser `docs/product/`** (preservada no MVP1 por compatibilidade — W1.1) e passa a ser a pasta do change ativo; os agents de specification que leem o estado vigente só são reescritos no MVP3/W3.3, quando o baseline existe.
  - `/forge:tasks` — tasks rastreáveis, ordenadas por dependência (sharding em stories fica para W5.0).
  - `/forge:analyze` — análise cross-artifact (spec/design/tasks/constitution) antes de implementar.
- **Depende de:** W2.0
- **Gate:** validador de cada artefato retorna PASS na fixture; decisão HITL registrada em `approvals.yaml` com schema correto; loop interrompe em 3 iterações (teste com validator forçado a FAIL).

### W2.2 — Implement, verify, close

- **Objetivo:** o ciclo fecha sem tocar baseline.
- **Entregáveis:**
  - `/forge:implement` — migração do `coding-loop` atual: executa tasks com checkpoints, atualiza status no manifest (`implementing` → `implemented`).
  - `/forge:verify` — checkpoint review guiado (modelo BMAD §4.3); executa os checks definidos no FORGE.md (test/typecheck/lint); grava `verification.md` + `verification.yaml` (§10.10); transição para `verified`.
  - `/forge:close <change-id> --reason abandoned|rejected|superseded` — move a pasta para `specs/archived/YYYY-MM-DD-<change-id>/` com `archive.kind: closed_without_baseline_update` (§13), **sem** delta apply.
  - Máquina de estados mínima (subset da §12 — schema completo na W3.0): transições válidas verificadas antes de cada comando.
  - Gates deterministas mínimos (§17.5) como skill `gate-runner` v0: parseabilidade, grep positivo/negativo, anti-empty; saída de **uma linha** `OK`/`FAIL`; output bruto em `/tmp` + `tail -20`.
- **Depende de:** W2.1
- **Gate:** state machine respeitada — `close --reason abandoned|rejected` só é aceito em estados pré-`implementing` (§10.7 + lacuna L3 do master plan); `superseded` é o único encerramento permitido de qualquer estado (`any -> superseded`); spec `verified` aguarda `/forge:archive` (MVP3) ou `close --reason superseded`; `verify` com tasks incompletas → `FAIL`; `close` não altera nada fora da pasta do change.

### W2.3 — Inventário brownfield mínimo (paralela a W2.2)

- **Objetivo:** pré-graph barato (§16.1), antecipação intencional do #15.
- **Entregáveis:**
  - `/forge:discover` versão lite: stack, comandos run/test/build, estrutura e boundaries, changed files, fingerprints, affected paths → `.forge/graph/manifest.json` (sem `graph.json` ainda).
- **Depende de:** W2.0
- **Gate:** discover roda na fixture brownfield e produz manifest válido por schema.

---

## Definition of Done do MVP2

1. `spec new` cria change válido por schema, para os 5 tipos.
2. `requirements`/`design` com loop (≤3 iterações, escalonamento HITL via AskUserQuestion, registro em `approvals.yaml`).
3. `verify` grava `verification.{md,yaml}` e transiciona para `verified`.
4. `close` move para archived sem tocar baseline.
5. `discover` lite gera `.forge/graph/manifest.json`.
6. Spec `create-forge-project-harness` ativa no workspace (dogfooding operante).

## Verificação end-to-end

- Fixture `feature-only` percorre: `spec new → clarify → requirements → design → tasks → analyze → implement → verify` — `verified` é o estado final alcançável no MVP2 (o archive nasce no MVP3). Em **spec separada**: `close --reason abandoned` a partir de `tasks-ready` e `close --reason superseded` a partir de `verified`, com aprovações registradas.
- Bats cobre transições proibidas da state machine (ex.: `design` antes de `requirements-ready` em scale ≥2; `verify` sem `implemented`).

## Pendências/observações

- O fim natural do ciclo (`archive`) só existe no MVP3; até lá, changes do dogfooding param em `verified`.
- `tasks.md` do change de dogfooding espelha as waves deste plano até `waves.json` existir (W5.1).
- Fixtures mínimas `feature-only` e `brownfield` **nascem neste MVP** (primeiros usos nos gates W2.x); consolidação final na W8.0.
- **Notas de execução (2026-06-11, MVP2 code-complete):** (1) os **validators do loop builder→validator foram embutidos nos commands** `/forge:requirements` e `/forge:design` (subagent independente com prompt embutido) em vez de virarem agents novos — preserva a contagem do contrato C2 no MVP2; promoção a agents dedicados pode ocorrer na W3.3 se o piloto justificar. (2) A skill `gate-runner` (v0, §17.5) motivou o **contrato v1.1**: cláusulas C2/C4 aditivas no modo generated (`>= 35`/`>= 4`), espelhando C1. (3) `/forge:discover` ganhou sincronia opcional com o `FORGE.md runtime:` (preenche stack/comandos detectados mediante aprovação — cobre a etapa 6 do init em brownfield). (4) A validação **semântica** dos loops (qualidade de PASS/FAIL dos validators, ≤3 iterações na prática) fica para o piloto real (azim-crm) — os gates w21/w22 cobrem toda a camada determinista (state machine, approvals, verify, close, isolamento). (5) Timeout portátil via `perl alarm` (macOS sem `timeout`); expansão `${arr[@]+...}` para bash 3.2.

## Controle de versão do documento

- Milton Silva - 2026-06-10 - Versão 1.0: plano inicial do MVP2.
- Milton Silva - 2026-06-10 - Versão 1.1: review crítico — E2E corrigido para terminar em `verified` (close de spec verificada violaria §10.7; `abandoned`/`rejected` só pré-`implementing`, `superseded` de qualquer estado); explicitada a transição da saída do pipeline `docs/product` → change ativo nesta fase; fixtures mínimas registradas. Aprovado para desenvolvimento.
