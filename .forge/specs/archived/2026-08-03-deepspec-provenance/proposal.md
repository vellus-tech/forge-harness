# Proposal — deepspec-provenance

> Change `deepspec-provenance` (type: `feature`, scale 3) — criado em 2026-07-09 por milton.
> Retroativo: implementação já existente (iniciada por uma sessão Codex, thread
> `019f477d-64b7-73c0-8872-214b43b08db5`), formalizada aqui para rastreabilidade SDD
> (verify/archive exigem manifest.yaml/tasks.md/traceability). Auditada e commitada em
> 6 commits atômicos antes deste retrofit; suíte 40/40 verde.

## 1. Por quê (problema / motivação)

O harness Forge não deixa evidência auditável de *como* um comando crítico (`verify`, `archive`,
`eval`) foi executado — apenas o resultado final (`verification.yaml`, baseline atualizado). Não há
como comparar mudanças do harness contra casos canônicos de referência, nem estimar custo/risco antes
de rodar um comando caro. Um estudo do projeto DeepSpec (proveniência de execução, contratos de
estágio, benchmarks) inspirou um plano de absorção seletiva — trazendo as ideias úteis sem herdar as
dependências pesadas (Python/CUDA, hardware defaults, storage massivo) nem os riscos (log de diff
completo por default vazaria segredo).

## 2. O que muda

1. **`run-manifest/v1`** — artefato padrão de evidência para comandos críticos, com proveniência
   segura (branch/HEAD/dirty/arquivos alterados/diff *stat*/hash do diff — nunca o diff bruto).
2. **Contratos de I/O por estágio** (`.forge/contracts/stages/*.yaml`) + validador determinístico
   `validate-stage-contract` — confere artefatos obrigatórios antes de transicionar status/arquivar.
3. **Integração bloqueante em `verify`/`archive`**, best-effort/documentada em `eval`,
   `skill-lifecycle eval|optimize`, `run-spec-pipeline`.
4. **Benchmark registry** (`.forge/evals/benchmarks/`) com 5 casos canônicos pequenos e
   `/forge:eval benchmark <case|suite>`.
5. **Perfis de execução** (`standard/quick/regulated/brownfield-heavy`) com precedência
   flag > manifest.yaml > forge.yaml > default, e `--set key.path=value` restrito a eval/benchmark.
6. **`budget preflight`** — linha de estimativa (runs/timeout/budget/uso de LLM) antes de comandos caros.

## 3. O que NÃO muda (fora de escopo)

- Núcleo SDD (lifecycle de changes, gates HITL) intacto — isto é camada de execução/qualidade.
- Sem dependências Python/CUDA, hardware defaults, storage massivo, config executável como fonte.
- Sem logging de diff completo por default (só hash + stat).
- `--set` não vaza para comandos fora de eval/benchmark neste primeiro ciclo.
- `forge update` não muda: não reescreve `forge.yaml` além do já existente (`template_version`).
- Projetos existentes sem os campos novos continuam funcionando (retrocompatível).

## 4. Impacto

- **Capacidades afetadas:** `forge-harness-template`
- **Paths afetados:** `template/.forge/schemas/`, `template/.forge/contracts/`, `template/.forge/scripts/`,
  `template/.forge/evals/benchmarks/`, `template/.forge/commands/{specs,quality,skills}/`, `tests/`,
  `docs/`, `plugin/forge/`, `README.md`, `CHANGELOG.md`
- **Dependências:** nenhuma
- **Riscos:**
  - Vazamento de segredo via run-manifest — mitigado (hash/stat apenas; testado com segredo real no
    diff, w90).
  - Contrato de estágio bloqueante pode travar `verify`/`archive` em projetos legados sem os artefatos
    esperados — mitigado por design (contratos pequenos e declarativos, `required_inputs` tolerantes).
  - `budget-preflight` heurístico (não é estimativa de custo monetário precisa) — aceito por design.

## 5. Próximos passos

`/forge:analyze` (cross-artifact, obrigatório em scale 3) → `/forge:verify` → `/code-review` →
`/forge:ship`. Requirements/design/tasks escritos retroativamente a partir do código já implementado
e testado (40/40 verde).
