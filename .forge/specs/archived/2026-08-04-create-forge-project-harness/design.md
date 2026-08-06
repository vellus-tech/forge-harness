# Design — create-forge-project-harness

> Design técnico do change. As decisões duráveis estão registradas nos artefatos referenciados (gate `design_reviewed: true` — decisões HITL registradas nos planos).

## 1. Contexto e restrições

- Fonte canônica agnóstica em `.forge/**`; ferramentas leem projeções geradas (nunca editadas à mão).
- Compatibilidade com o template legado congelada por contrato (`contracts/claude-adapter-contract.md`, cláusulas C1–C10) até o teste manual C10 aprovar a substituição.
- Zero dependências nos projetos-alvo (bash + Node ≥ 20); `ajv`/`yaml` só no workspace.

## 2. Decisões técnicas (registro)

| Decisão | Onde está registrada |
|---|---|
| `AGENTS.md` gerado (não symlink de FORGE.md); header §7.4 | doc de projeto §7 |
| Projeção por cópia para recursos de runtime; contexto não duplicado | nota "materialização dos adapters" no `docs/plans/01-mvp1-forge-canonico.md` |
| Instalação seletiva de adapters (ativo ≠ disponível; reconcile/prune) | nota W1.4b no plano 01 |
| Template universal; identificadores reais saem, exemplos didáticos ficam | `docs/plans/revisao-agents-skills.md` v1.1 (W1.5) |
| Manifest de change validado por schema + validador zero-dep espelhado | `template/.forge/schemas/spec-manifest.schema.json` + `scripts/lib/validate-spec.mjs` (W2.0) |
| `.forge/templates/` preserva placeholders (install/doctor os excluem) | nota W1.5 no plano 01 |

## 3. Contratos e integrações afetados

- Contrato Claude (`claude-contract.bats`, modos source/generated) — gate permanente.
- Schemas draft 2020-12 (`forge`, `adapter-capability`, `spec-manifest`) validados por ajv no workspace (`tools/validate-forge.mjs`).

## 4. Plano de migração / rollout

Fases 0–8 com gates por wave (`docs/plans/00-master-plan.md`, caminho crítico W1.1→W1.2→W3.2); rollout final na W8.3 (tag `v0.1.0` + delegação do `/init-project`).

## 5. Riscos e mitigação

Tabela de riscos consolidada no `docs/plans/00-master-plan.md` (resíduos de path, drift template↔workspace, symlinks em Windows, testes LLM não-determinísticos).

## 6. Rastreabilidade

| REQ | Design |
|---|---|
| REQ-01 | §2 (linhas 1–4), contrato C1–C10 |
| REQ-02 | §2 (linha 5), schemas §3 |
| REQ-03..06 | planos 03–06 (design detalhado nasce nas waves respectivas) |
