# Proposal — create-forge-project-harness

> Change `create-forge-project-harness` (type: `greenfield`, scale 3) — criado em 2026-06-10 por milton.
> **Dogfooding (W2.0):** a partir deste change, o desenvolvimento do próprio Forge é rastreado pelo spec lifecycle que ele implementa. Os gates de requirements/design/tasks foram aprovados via HITL nos planos (ver referências).

## 1. Por quê (problema / motivação)

O template `/init-project` atual é acoplado ao Claude Code (`.claude/` como fonte canônica) e não cobre o ciclo SDD completo (specs change-based, baseline, archive, graph, dev loop). O Forge Project Harness reestrutura tudo sobre uma fonte canônica agnóstica (`.forge/`) com adapters gerados por ferramenta.

Documento de projeto: `docs/refer/forge-project-harness.md` (v3.1, Aprovado).

## 2. O que muda

Nasce o workspace `forge-harness` com: snapshot congelado do template legado, fonte canônica `template/.forge/**`, instalador determinista, adapters multi-agente com lockfiles, contrato de compatibilidade Claude, e — em MVPs sucessivos — spec lifecycle, baseline/archive, graph brownfield e dev loop/quality.

## 3. O que NÃO muda (fora de escopo)

- O template global `~/.claude/templates/project-bootstrap/` permanece intocado até a W8.3 (delegação formal).
- Projetos já inicializados com `/init-project` não são migrados automaticamente.

## 4. Impacto

- **Capacidades afetadas:** forge-harness-template (espelhado no manifest)
- **Paths afetados:** `template/`, `installer/`, `tests/`, `tools/`, `contracts/`
- **Riscos:** ver tabela de riscos do `docs/plans/00-master-plan.md`

## 5. Referências (requirements/design/tasks deste change)

- **Planos (requirements aprovados):** `docs/plans/00-master-plan.md` … `06-qualidade-piloto-rollout.md` (status: Aprovado para desenvolvimento)
- **Contrato de compatibilidade:** `contracts/claude-adapter-contract.md` (v1.0 Aprovado)
- **Tracking de execução:** `tasks.md` deste change (espelho das waves; `waves.json`/`progress.json` chegam na W5.1)
