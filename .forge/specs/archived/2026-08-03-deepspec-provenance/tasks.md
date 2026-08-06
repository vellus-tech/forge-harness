# Tasks — deepspec-provenance

> Retroativo: implementação já commitada em 6 commits atômicos antes deste artefato (auditada,
> 40/40 testes verdes). Tasks marcadas `[X]` refletem o trabalho real já feito.

## Wave 1 — Núcleo de proveniência

- [X] TASK-01 — `run-manifest.schema.json` + `run-manifest.sh`/`lib/run-manifest.mjs` (proveniência segura, sem diff bruto) (rastreia: REQ-01, REQ-02; paths: `template/.forge/schemas/run-manifest.schema.json`, `template/.forge/scripts/run-manifest.sh`, `template/.forge/scripts/lib/run-manifest.mjs`; depende: —)

## Wave 2 — Contratos de estágio

- [X] TASK-02 — `.forge/contracts/stages/*.yaml` (5 estágios) + `validate-stage-contract.sh`/`lib/stage-contract.mjs` + wiring em `validate-harness.sh` (rastreia: REQ-03, REQ-04; paths: `template/.forge/contracts/stages/`, `template/.forge/scripts/validate-stage-contract.sh`, `template/.forge/scripts/lib/stage-contract.mjs`, `template/.forge/scripts/validate-harness.sh`; depende: TASK-01)

## Wave 3 — Integração nos comandos + budget preflight

- [X] TASK-03 — Integração bloqueante em `spec-verify.sh`/`archive-spec.sh`; best-effort/documentada em `eval.md`/`skill-lifecycle.md`/`run-spec-pipeline.md`; `budget-preflight.sh`/`lib/budget-preflight.mjs` (perfis + precedência) (rastreia: REQ-05, REQ-06, REQ-09, REQ-11; paths: `template/.forge/scripts/{archive-spec,spec-verify}.sh`, `template/.forge/commands/{specs/archive,specs/verify,specs/run-spec-pipeline,skills/skill-lifecycle,quality/eval}.md`, `template/.forge/scripts/budget-preflight.sh`, `template/.forge/scripts/lib/budget-preflight.mjs`; depende: TASK-02)

## Wave 4 — Benchmark registry

- [X] TASK-04 — 5 casos canônicos + `benchmark-eval.sh`/`lib/benchmark-eval.mjs` + `/forge:eval benchmark <case|suite>` + `--set` restrito (rastreia: REQ-07, REQ-08, REQ-10; paths: `template/.forge/evals/benchmarks/`, `template/.forge/scripts/benchmark-eval.sh`, `template/.forge/scripts/lib/benchmark-eval.mjs`, `template/.forge/scripts/{eval-aggregate,meta-aggregate}.sh`; depende: TASK-03)

## Wave 5 — Testes

- [X] TASK-05 — Gates `w90-w93` (run-manifest, contratos, benchmark registry, perfis/budget) + `w80-suite-gate` atualizado (rastreia: REQ-01..11, REQ-12; paths: `tests/w90-run-manifest-gate.sh`, `tests/w91-stage-contract-gate.sh`, `tests/w92-benchmark-registry-gate.sh`, `tests/w93-profiles-budget-gate.sh`, `tests/w80-suite-gate.sh`; depende: TASK-04)

## Wave 6 — Docs

- [X] TASK-06 — CHANGELOG, `docs/refer/forge-project-harness.md` §17.8.5, `slash-commands.md`, README, plugin regenerado (rastreia: REQ-12; paths: `CHANGELOG.md`, `docs/refer/forge-project-harness.md`, `docs/refer/slash-commands.md`, `README.md`, `template/.forge/README.md`, `bin/forge.mjs`, `plugin/forge/`; depende: TASK-05)

## Rastreabilidade

| REQ / Design § | Tasks |
|---|---|
| REQ-01/02 §2.1 | TASK-01 |
| REQ-03/04 §2.2 | TASK-02 |
| REQ-05/06/09/11 §2.3/2.6 | TASK-03 |
| REQ-07/08/10 §2.4/2.5 | TASK-04 |
| REQ-12 §4 | TASK-05, TASK-06 |
