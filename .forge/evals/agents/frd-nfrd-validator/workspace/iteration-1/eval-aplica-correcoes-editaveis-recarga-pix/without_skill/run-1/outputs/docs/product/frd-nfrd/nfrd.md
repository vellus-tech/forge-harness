# NFRD — RecargaJá
**Requisitos Não Funcionais**

- **Versão:** 1.0.1
- **Data:** 2026-09-26
- **Status:** Aprovado para desenvolvimento
- **Referência pai:** ../prd/prd.md

### Histórico de Versões

| Versão | Data | Status | Descrição da alteração |
|--------|------|--------|----------------------|
| 1.0.0 | 2026-09-10 | Substituída | Aprovação para desenvolvimento |
| 1.0.1 | 2026-09-26 | Atual | Validação contra o PRD: NFRD-PERF-01 estava vago ("rápida", sem métrica) — substituído pelo limiar quantitativo do PRD §6 (95% das recargas com crédito disponível em até 10 segundos após a confirmação do Pix), com método de validação mensurável. |

## 1. Requisitos Não Funcionais

| ID | Categoria | Requisito | Métrica / Critério | Método de validação | Origem |
|---|---|---|---|---|---|
| NFRD-PERF-01 | Performance | A disponibilização do crédito após a confirmação do Pix deve atender a um limiar de latência mensurável em produção. | 95% das recargas com crédito disponível no cartão em até 10 segundos após a confirmação do Pix pelo PSP (p95 ≤ 10s). | Teste de carga com medição de percentil p95 na janela confirmação-PSP → crédito-disponível; validado também com telemetria de produção. | PRD §6 |
| NFRD-SEC-01 | Privacidade | O CPF do passageiro deve ser exibido mascarado nas telas do SAC. | 100% das telas do SAC exibem CPF mascarado (formato ***.456.789-**). | Teste funcional e revisão de UI. | PRD §6 |
| NFRD-AUD-01 | Auditabilidade | Toda recarga gera registro de auditoria imutável com autor, data/hora, valor e cartão. | 100% das recargas com registro de auditoria imutável (append-only, sem UPDATE/DELETE possível). | Inspeção da trilha de auditoria. | PRD §6 |
