# Requirements — deepspec-provenance

## REQ-01 — Schema e gerador do run-manifest/v1

- **Quando** um comando crítico grava evidência, **o sistema deve** produzir um `run-manifest.json`
  validado contra `run-manifest.schema.json` com os campos `schema, run_id, stage, status, started_at,
  finished_at, duration_ms, git, inputs, commands, outputs, runner, budgets`.
- **Critérios de aceite:**
  - [ ] Schema com `additionalProperties: false` em todos os níveis.
  - [ ] Change ativo → `evidence/runs/<run-id>/run-manifest.json`; sem change →
        `.forge/runs/<run-id>/run-manifest.json`.
- **Rastreia:** proposal §2.1

## REQ-02 — Proveniência segura (sem diff bruto)

- **Quando** o run-manifest registra estado git, **o sistema deve** gravar branch, HEAD SHA, dirty
  flag, arquivos alterados, `diff --stat` e hash do diff — **nunca** o diff completo/bruto.
- **Critérios de aceite:**
  - [ ] Nenhum caminho de código persiste o texto do diff (`git diff` sem `--stat`).
  - [ ] Um segredo inserido no diff de trabalho não aparece no manifesto persistido (testável).
  - [ ] Validador interno rejeita manifesto cujo JSON contenha marcador de diff bruto (`"diff --git"`).
- **Rastreia:** proposal §2.1, §4 (risco de vazamento)

## REQ-03 — Contratos de I/O por estágio

- **Quando** um estágio (`verify|archive|eval|run-spec-pipeline|skill-lifecycle-eval`) roda,
  **o sistema deve** ter um contrato declarativo em `.forge/contracts/stages/*.yaml` com
  `stage, required_inputs, required_outputs, validators, budget_class, evidence_required`.
- **Critérios de aceite:**
  - [ ] 5 arquivos de contrato presentes, um por estágio listado.
  - [ ] `validate-harness.sh` falha se um contrato estiver ausente/inválido.
- **Rastreia:** proposal §2.2

## REQ-04 — Validador determinístico de contrato

- **Quando** `validate-stage-contract` roda para um estágio, **o sistema deve** conferir se os
  artefatos obrigatórios (`required_outputs`) foram produzidos antes de permitir a transição de
  status/arquivamento.
- **Critérios de aceite:**
  - [ ] Comando `check <stage>` funcional (testável isoladamente).
  - [ ] Falha quando um output obrigatório está ausente.
- **Rastreia:** proposal §2.2

## REQ-05 — Integração bloqueante em verify e archive

- **Quando** `/forge:verify` ou `/forge:archive` roda, **o sistema deve** gravar o run-manifest e
  validar o contrato do estágio como parte **bloqueante** do fluxo (falha de contrato impede a
  conclusão).
- **Critérios de aceite:**
  - [ ] `spec-verify.sh` chama `run-manifest.sh write` e `validate-stage-contract.sh check`.
  - [ ] `archive-spec.sh` idem.
  - [ ] Falha de contrato aborta o script (exit ≠ 0), não só loga aviso.
- **Rastreia:** proposal §2.3

## REQ-06 — Integração documentada/best-effort em eval, skill-lifecycle, run-spec-pipeline

- **Quando** `/forge:eval`, `/forge:skill-lifecycle eval|optimize` ou `/forge:run-spec-pipeline`
  rodam, **o sistema deve** citar e usar `budget-preflight`/run-manifest, sem bloquear o fluxo em caso
  de falha de gravação de evidência (não-crítico fora de verify/archive/evals).
- **Critérios de aceite:**
  - [ ] Os 3 comandos citam `budget-preflight`/`run-manifest` no corpo (`.md`) e no script chamado.
  - [ ] Falha de manifesto nesses fluxos não é bloqueante (design: só verify/archive/evals bloqueiam).
- **Rastreia:** proposal §2.3

## REQ-07 — Benchmark registry (5 casos canônicos)

- **Quando** o benchmark registry é consultado, **o sistema deve** expor os casos
  `greenfield-small, brownfield-bugfix, refactor-invariant, docs-only, multi-module-scale3` em
  `.forge/evals/benchmarks/`, cada um validado contra `benchmark-case.schema.json`.
- **Critérios de aceite:**
  - [ ] 5 diretórios com `case.json` válido.
  - [ ] Casos pequenos e versionáveis (não fixtures gigantes).
- **Rastreia:** proposal §2.4

## REQ-08 — `/forge:eval benchmark <case|suite>`

- **Quando** o usuário roda `/forge:eval benchmark <case|suite>`, **o sistema deve** rodar o(s)
  caso(s) reusando `runners.yaml`, `grading.schema.json`, `meta-count.sh`, `meta-aggregate.sh` já
  existentes do eval harness.
- **Critérios de aceite:**
  - [ ] `eval.md` documenta o modo `benchmark` (case único e suite).
  - [ ] `benchmark-eval.sh`/`.mjs` funcional, com runner stub testável.
- **Rastreia:** proposal §2.4

## REQ-09 — Perfis de execução e precedência

- **Quando** um comando resolve seu perfil de execução, **o sistema deve** aplicar a precedência
  flag do comando > `manifest.yaml` > `forge.yaml` > default `standard`, entre os perfis
  `standard, quick, regulated, brownfield-heavy`.
- **Critérios de aceite:**
  - [ ] `budget-preflight.mjs` implementa exatamente essa precedência (testável nos 4 níveis).
- **Rastreia:** proposal §2.5

## REQ-10 — Overrides `--set key.path=value` (restrito)

- **Quando** o usuário passa `--set key.path=value` a um comando de eval/benchmark, **o sistema deve**
  aplicar o override pontual; **quando** passado a outro comando, **não deve** ter efeito algum (não
  implementado fora do escopo eval/benchmark neste ciclo).
- **Critérios de aceite:**
  - [ ] `--set` funcional em `run-manifest.mjs`/`budget-preflight.mjs`/`benchmark-eval.mjs`.
  - [ ] Nenhum outro script/comando do harness lê essa flag.
- **Rastreia:** proposal §2.5, §3

## REQ-11 — `budget preflight`

- **Quando** um comando caro (verify/archive/eval/skill-lifecycle/run-spec-pipeline) inicia,
  **o sistema deve** emitir uma linha de estimativa (runs, timeout, budget, artefatos esperados,
  uso de LLM/subagente) antes de executar.
- **Critérios de aceite:**
  - [ ] `budget-preflight.sh` roda e emite a linha `BUDGET stage=... profile=... runs=...
        timeout_s=... budget=... outputs=... llm=... subagent=...`.
  - [ ] Heurística simples (não precisão monetária) — aceito por design.
- **Rastreia:** proposal §2.6

## REQ-12 — Suíte verde e documentação

- **Quando** `npm test` roda, **o sistema deve** passar, incluindo os 4 gates novos
  (`w90-w93`) e o `w80-suite-gate` atualizado. Documentação (README, CHANGELOG, doc de referência,
  catálogo de slash commands) deve refletir as features novas.
- **Critérios de aceite:**
  - [ ] `npm test`: 40/40 verde.
  - [ ] CHANGELOG `[Unreleased]`, `docs/refer/forge-project-harness.md`, `slash-commands.md`
        atualizados.
- **Rastreia:** proposal §2, §4

## Requisitos não funcionais do change

- **NFR-01 —** Zero-dep: só node builtins + bash nos scripts novos (consistente com o resto do harness).
- **NFR-02 —** Segurança por padrão: nenhum caminho de execução persiste segredo/diff bruto (REQ-02).
- **NFR-03 —** Retrocompatibilidade: projetos existentes sem os campos novos em `forge.yaml`/`manifest.yaml`
  continuam funcionando sem erro.

## Checklist de cobertura de superfície

| REQ | Parâmetro/config exposto | Superfície | Coberto por task |
|---|---|---|---|
| REQ-08 | `benchmark <case\|suite>` | CLI/slash `/forge:eval` | TASK (benchmark) |
| REQ-09 | perfil (`standard\|quick\|regulated\|brownfield-heavy`) | flag de comando, `manifest.yaml`, `forge.yaml` | TASK (budget-preflight) |
| REQ-10 | `--set key.path=value` | CLI (só eval/benchmark) | TASK (benchmark/budget) |
| REQ-01/02/03/04/05/06/07/11/12 | sem parâmetro configurável adicional | — (comportamento interno/artefatos) | TASKs correspondentes |

## Fora de escopo (reafirmação)

- Dependências Python/CUDA, hardware defaults, storage massivo, config executável como fonte
  primária, logging de diff completo por default (proposal §3).
- `--set` fora de eval/benchmark.
- Mudança no comportamento de `forge update`.
