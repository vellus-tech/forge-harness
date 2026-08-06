# Verification — deepspec-provenance

- **Commit sob verificação:** `6454285` (`6454285537aa43e382c88f8cd4006ac980b741d5`), branch `feat/deepspec-provenance`
- **Verificado em:** 2026-07-09
- **Método:** reverificação cética REQ a REQ contra o estado COMMITADO (6 commits atômicos
  `dc66d14..6454285`), rodando gates e scripts diretamente — não confiando na auditoria anterior
  (que rodou com stash fora de commit).
- **Veredito global: PASS** (12/12 REQ + 3/3 NFR). Nenhum FAIL/PARTIAL.

## Suíte de testes

```
PASS=40  FAIL=0  SKIP=0  (70s) — suíte 100% verde
```

Inclui `w80-suite-gate` atualizado e os 4 gates novos `w90`–`w93`, todos verdes rodados
isoladamente também.

## Tabela REQ a REQ

| REQ | Veredito | Evidência |
|---|---|---|
| REQ-01 — schema/gerador run-manifest/v1 | PASS | `lib/run-manifest.mjs` grava todos os campos exigidos; `manifestPath()` roteia change ativo → `evidence/runs/<id>/`, sem change → `.forge/runs/<id>/`. Schema com `additionalProperties:false` (6 níveis). w90[1] valida manifesto contra schema. |
| REQ-02 — proveniência segura (sem diff bruto) | PASS | `gitProvenance()` persiste só `diff_stat` + `diff_sha256` (hash do `git diff --binary`, nunca o texto). `validateManifest()` rejeita JSON contendo `"diff --git"`. **w90[2] injeta `TOPSECRET-DO-NOT-PERSIST` no diff de trabalho e confirma ausência no manifesto** (rodado: OK). Nenhum caminho grava `git diff` sem `--stat`. |
| REQ-03 — contratos de I/O por estágio | PASS | 5 contratos presentes (`verify,archive,eval,run-spec-pipeline,skill-lifecycle-eval`.yaml) com todos os campos. `validate-harness.sh:26` chama `validate-contracts` (falha → `fail=1`). w91[1] OK. |
| REQ-04 — validador determinístico de contrato | PASS | `stage-contract.mjs check` confere `required_outputs`; w91[2] confirma que falha sem output e passa com evidência. |
| REQ-05 — integração BLOQUEANTE em verify/archive | PASS | `spec-verify.sh:105-108` e `archive-spec.sh:85-88`: `if ! validate-stage-contract check ...; then echo FAIL; exit 1`. `run-manifest.sh write` chamado sem `\|\| true` sob `set -e` (também bloqueante). Falha de contrato **aborta** (exit≠0), não só loga. |
| REQ-06 — não-bloqueante em eval/skill-lifecycle/run-spec-pipeline | PASS | Nenhum desses fluxos chama `validate-stage-contract check` (só verify/archive o fazem — grep confirmou). `eval.md`, `skill-lifecycle.md`, `run-spec-pipeline.md` citam `budget-preflight`/`run-manifest`; `eval-aggregate.sh`/`meta-aggregate.sh` gravam manifesto sem gate bloqueante. |
| REQ-07 — benchmark registry (5 casos) | PASS | 5 dirs com `case.json` (`greenfield-small, brownfield-bugfix, refactor-invariant, docs-only, multi-module-scale3`); w92[1] valida contra `benchmark-case.schema.json`. Casos pequenos/versionáveis. |
| REQ-08 — `/forge:eval benchmark <case\|suite>` | PASS | `eval.md` documenta modo benchmark; `benchmark-eval.sh`/`.mjs` reusa runners/grading; w92[2] (caso único → aggregate+run-manifest) e w92[3] (suite) OK. |
| REQ-09 — perfis e precedência | PASS | `budget-preflight.mjs:76` = `opts.profile \|\| manifestProfile \|\| forgeProfile \|\| 'standard'`. w93[1-4] confirmam os 4 níveis (default→standard, forge.yaml, manifest vence forge, flag vence manifest). |
| REQ-10 — `--set` restrito | PASS (c/ ressalva) | `--set key=value` funciona em `run-manifest.mjs`/`budget-preflight.mjs`/`benchmark-eval.mjs`; w93[5] OK. Nenhum outro script lê o override `key.path=value`. Ressalva: `sync-adapters.mjs` tem um flag `--set` **pré-existente e de semântica distinta** (lista de adapters, não override) — fora do diff deste change; não conflita com a semântica de REQ-10. |
| REQ-11 — budget preflight | PASS | `budget-preflight.sh` emite `BUDGET stage=... profile=... runner=... runs=... timeout_s=... budget=... outputs=... llm=... subagent=...`; chamado em `spec-verify.sh:23` e `archive-spec.sh:22` (com `\|\| true`, não-bloqueante como preflight). |
| REQ-12 — suíte verde + docs | PASS | `npm test` 40/40. Docs tocados: `CHANGELOG.md`, `docs/refer/forge-project-harness.md`, `docs/refer/slash-commands.md`, `README.md` (todos citam run-manifest/benchmark/budget). |
| NFR-01 — zero-dep | PASS | Scripts novos usam só node builtins (`node:fs/path/crypto/child_process`) + `yaml-lite.mjs` local + bash. |
| NFR-02 — segurança por padrão | PASS | Coberto por REQ-02 (segredo real não vaza; hash/stat apenas; validação de defesa em profundidade). |
| NFR-03 — retrocompatibilidade | PASS | `forge.yaml`/`manifest.yaml` sem os campos novos resolvem para `standard` via precedência (w93[1]). Integração aditiva. |

## Observações (não bloqueantes)

1. `skill-lifecycle.md:20` afirma que a ausência de `aggregate.json`/`run-manifest.json` "bloqueia o
   contrato `skill-lifecycle-eval`" — porém esse contrato **não** é chamado como gate bloqueante em
   nenhum script do fluxo skill-lifecycle (só verify/archive chamam `check`). A prosa é aspiracional;
   o comportamento efetivo é best-effort, consistente com o design (§2). Não afeta REQ-06.
2. `sync-adapters.mjs` reúsa o token `--set` para outra finalidade (reescrever lista de adapters).
   É pré-existente e não está no diff; a semântica de override de REQ-10 permanece restrita aos 3
   scripts previstos.

## Comandos executados

- `npm test` → PASS=40 FAIL=0 SKIP=0
- `bash tests/w90-run-manifest-gate.sh` → OK (inclui injeção de segredo)
- `bash tests/w91-stage-contract-gate.sh` → OK
- `bash tests/w92-benchmark-registry-gate.sh` → OK
- `bash tests/w93-profiles-budget-gate.sh` → OK
- `FORGE_ROOT=$(pwd) bash template/.forge/scripts/validate-spec.sh deepspec-provenance` → `OK deepspec-provenance` (antes e depois de gravar os artefatos)
