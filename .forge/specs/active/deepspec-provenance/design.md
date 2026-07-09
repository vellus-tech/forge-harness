# Design — deepspec-provenance

## 1. Contexto e restrições

- Zero-dep: scripts novos seguem o padrão `template/.forge/scripts/*.sh` (wrapper fino) +
  `lib/*.mjs` (node builtins).
- Segurança > fidelidade ao DeepSpec: proveniência é hash/metadado, nunca conteúdo bruto.
- Só `verify`/`archive` são bloqueantes por design; `eval`/`skill-lifecycle`/`run-spec-pipeline`
  usam a camada de forma best-effort/documentada.

## 2. Decisão técnica (arquitetura implementada)

### 2.1 `run-manifest/v1` — REQ-01/02
`template/.forge/scripts/run-manifest.sh` (wrapper) + `lib/run-manifest.mjs` (núcleo). Comandos
`start`/`write` capturam: `run_id` (gerado), `stage`, `status`, timestamps, `git` (branch, HEAD sha,
dirty, arquivos alterados, `diff --stat`, hash sha256 do diff — nunca o diff em si), `inputs`/
`outputs` (paths + hash), `commands` (o que rodou), `runner`, `budgets`. Validação interna rejeita
qualquer manifesto cujo JSON serializado contenha o marcador `"diff --git"` (defesa em profundidade
contra regressão futura). Destino: `evidence/runs/<run-id>/run-manifest.json` sob o change ativo, ou
`.forge/runs/<run-id>/` sem change.

### 2.2 Contratos de estágio — REQ-03/04
`.forge/contracts/stages/{verify,archive,eval,run-spec-pipeline,skill-lifecycle-eval}.yaml`.
`validate-stage-contract.sh check <stage>` (+ `lib/stage-contract.mjs`) confere `required_outputs`
contra o que de fato foi produzido. `validate-harness.sh` inclui a validação de schema/presença dos
contratos no gate geral do harness.

### 2.3 Integração nos comandos — REQ-05/06
- **Bloqueante:** `spec-verify.sh` e `archive-spec.sh` chamam `run-manifest.sh write` +
  `validate-stage-contract.sh check` antes de concluir; falha de contrato aborta (exit ≠ 0).
- **Best-effort/documentada:** `eval.md`, `skill-lifecycle.md`, `run-spec-pipeline.md` citam e chamam
  `budget-preflight`/run-manifest, sem abortar o fluxo se a gravação de evidência falhar.

### 2.4 Benchmark registry — REQ-07/08
`.forge/evals/benchmarks/{greenfield-small,brownfield-bugfix,refactor-invariant,docs-only,
multi-module-scale3}/case.json`, validados por `benchmark-case.schema.json`.
`benchmark-eval.sh`/`lib/benchmark-eval.mjs` reusam `runners.yaml`, `grading.schema.json`,
`meta-count.sh`, `meta-aggregate.sh` já existentes. `/forge:eval benchmark <case|suite>` documentado
em `eval.md`.

### 2.5 Perfis e overrides — REQ-09/10
`lib/budget-preflight.mjs` define `PROFILES = {standard, quick, regulated, brownfield-heavy}` e
resolve com `opts.profile || manifestProfile || forgeProfile || 'standard'`. `--set key.path=value`
implementado em `run-manifest.mjs`/`budget-preflight.mjs`/`benchmark-eval.mjs` apenas — nenhum outro
script lê essa flag (escopo restrito por design).

### 2.6 Budget preflight — REQ-11
`budget-preflight.sh` emite `BUDGET stage=... profile=... runs=... timeout_s=... budget=...
outputs=... llm=... subagent=...` antes de rodar; chamado de dentro de `spec-verify.sh`,
`archive-spec.sh`, e citado nos demais comandos.

## 3. Alternativas consideradas

| Alternativa | Prós | Contras | Por que não |
|---|---|---|---|
| Copiar arquitetura DeepSpec (Python) | fidelidade total | quebra zero-dep, exige Python/CUDA | descartado por design (proposal §3) |
| Diff bruto no manifesto | debugging mais rico | vazamento de segredo real | descartado; hash+stat basta |
| Contrato bloqueante em todos os comandos | uniformidade | trava fluxos exploratórios (eval/skill-lifecycle) | só verify/archive bloqueiam |
| `--set` global | flexibilidade ampla | superfície de configuração difusa | restrito a eval/benchmark no 1º ciclo |

## 4. Contratos e integrações afetados

- **Novos schemas:** `run-manifest.schema.json`, `benchmark-case.schema.json`.
- **Novo diretório:** `.forge/contracts/stages/`.
- **Scripts existentes modificados:** `archive-spec.sh`, `spec-verify.sh`, `eval-aggregate.sh`,
  `meta-aggregate.sh`, `validate-harness.sh` — todos aditivos (chamam os novos scripts, não alteram
  o comportamento funcional core quando a gravação de evidência é best-effort).
- **5 comandos `.md` modificados** (prosa + wiring): `verify`, `archive`, `eval`, `skill-lifecycle`,
  `run-spec-pipeline`. Plugin regenerado (contagem inalterada, 51 — comandos existentes, não novos).

## 5. Plano de migração / rollout

Aditivo. Projetos existentes sem os campos novos em `forge.yaml`/`manifest.yaml` continuam
funcionando (defaults resolvidos pela precedência). `forge update` propaga a maquinaria nova
(contracts/, schemas/, scripts/) da mesma forma que qualquer outra atualização de maquinaria.

## 6. Riscos e mitigação

| Risco | Prob. | Impacto | Mitigação / detecção |
|---|---|---|---|
| Vazamento de segredo via manifesto | Baixa | Alto | hash/stat apenas; validação interna + teste w90 com segredo real |
| Contrato bloqueante trava verify/archive em projeto legado | Média | Médio | contratos pequenos/tolerantes; só 2 comandos bloqueiam |
| budget-preflight impreciso gera falsa confiança de custo | Média | Baixo | heurística documentada como estimativa, não precisão monetária |
| `--set` vazar escopo no futuro | Baixa | Médio | gate w93 testa que só os 3 scripts leem a flag |

## 7. Rastreabilidade

| REQ | Seção do design |
|---|---|
| REQ-01/02 | §2.1 |
| REQ-03/04 | §2.2 |
| REQ-05/06 | §2.3 |
| REQ-07/08 | §2.4 |
| REQ-09/10 | §2.5 |
| REQ-11 | §2.6 |
| REQ-12 | §4, verificação via `npm test` |
