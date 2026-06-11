# Proposal — baseline-spec-lifecycle

> Change `baseline-spec-lifecycle` (type: `feature`, scale 0) — criado em 2026-06-11 por milton.
> Primeiro change real arquivado pelo próprio harness (dogfooding do /forge:archive — MVP3).

## 1. Por quê (problema / motivação)

O baseline do workspace (`.forge/product/current/`) nasceu vazio no MVP3. As capacidades reais já entregues pelo template precisam existir como capabilities com IDs estáveis — começando pelo spec lifecycle (MVP2/MVP3), para que os próximos changes evoluam requisitos em vez de redescobri-los.

## 2. O que muda

Registra a capability `spec-lifecycle` no baseline com os dois requisitos centrais já verificados por gate: criação de change válida por schema (w20) e archive com delta apply determinista (w32).

## 3. O que NÃO muda (fora de escopo)

Nenhum código do template; apenas o baseline do workspace.

## 4. Impacto

- **Capacidades afetadas:** spec-lifecycle
- **Paths afetados:** `.forge/product/current/capabilities/spec-lifecycle/`
- **Riscos:** nenhum (operação de baseline, reversível por rollback formal)
