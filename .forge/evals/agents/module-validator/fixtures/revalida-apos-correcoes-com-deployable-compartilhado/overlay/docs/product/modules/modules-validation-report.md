# Relatório de Validação — Módulos

- **Versão:** 1.0.0
- **Data:** 2026-09-02
- **Status:** Reprovado
- **Validador:** module-validator

## Resumo Executivo

4 módulos validados. Achados: 1 Crítica (MOD-OWN-001, cartoes_transporte com dois donos), 1 Alta (MOD-DEP-TRD-001, recarga sem deployable), 1 Média (MOD-DOC-001, notificacoes sem diagrama de dependências). Parecer Reprovado pela Crítica não corrigível.

## 5. Achados

| ID | Descrição | Arquivo | Severidade | Ação |
|---|---|---|---|---|
| MOD-OWN-001 | cartoes_transporte declarado como dono por cadastro-passageiro e recarga | docs/product/modules/recarga/README.md | Crítica | Conflito Arquitetural |
| MOD-DEP-TRD-001 | recarga não declara deployable | docs/product/modules/recarga/README.md | Alta | [CORRIGIDO] |
| MOD-DOC-001 | notificacoes sem diagrama de dependências | docs/product/modules/notificacoes/README.md | Média | [CORRIGIDO] |

## 10. Parecer Final

**Reprovado** — a Crítica MOD-OWN-001 depende de decisão de ownership; module-generator deve ser re-executado após a decisão.
