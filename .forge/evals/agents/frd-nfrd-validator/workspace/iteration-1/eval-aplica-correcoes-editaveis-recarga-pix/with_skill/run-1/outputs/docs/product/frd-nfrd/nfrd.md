# NFRD — RecargaJá
**Requisitos Não Funcionais**

- **Versão:** 1.0.1
- **Data:** 2026-09-26
- **Status:** Aprovado para desenvolvimento
- **Referência pai:** ../prd/prd.md

### Histórico de Versões

| Versão | Data | Status | Descrição da alteração |
|--------|------|--------|----------------------|
| 1.0.1 | 2026-09-26 | Atual | Aplicação de FIND-004 do relatório de validação 2026-09-26 (métrica de NFRD-PERF-01 sem meta mensurável — substituída pela meta já definida em PRD §6) |
| 1.0.0 | 2026-09-10 | Anterior | Aprovação para desenvolvimento |

## 1. Requisitos Não Funcionais

| ID | Categoria | Requisito | Métrica / Critério | Método de validação | Origem |
|---|---|---|---|---|---|
| NFRD-PERF-01 | Performance | A disponibilização do crédito após a confirmação do Pix deve ser rápida. | 95% das recargas com crédito disponível em até 10 segundos após a confirmação do Pix pelo PSP (p95 ≤ 10s) | Teste de carga medindo o intervalo entre a confirmação do PSP e a disponibilização do crédito no cartão, com amostra representativa de transações | PRD §6 |
| NFRD-SEC-01 | Privacidade | O CPF do passageiro deve ser exibido mascarado nas telas do SAC. | 100% das telas do SAC exibem CPF mascarado | Teste funcional e revisão de UI | PRD §6 |
| NFRD-AUD-01 | Auditabilidade | Toda recarga gera registro de auditoria imutável com autor, data/hora, valor e cartão. | 100% das recargas com registro | Inspeção da trilha de auditoria | PRD §6 |
