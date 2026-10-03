# NFRD — RecargaJá
**Requisitos Não Funcionais**

- **Versão:** 1.0.0
- **Data:** 2026-09-10
- **Status:** Aprovado para desenvolvimento
- **Referência pai:** ../prd/prd.md

### Histórico de Versões

| Versão | Data | Status | Descrição da alteração |
|--------|------|--------|----------------------|
| 1.0.0 | 2026-09-10 | Atual | Aprovação para desenvolvimento |

## 1. Requisitos Não Funcionais

| ID | Categoria | Requisito | Métrica / Critério | Método de validação | Origem |
|---|---|---|---|---|---|
| NFRD-PERF-01 | Performance | A disponibilização do crédito após a confirmação do Pix deve ser rápida. | Rápida | Teste de carga | PRD §6 |
| NFRD-SEC-01 | Privacidade | O CPF do passageiro deve ser exibido mascarado nas telas do SAC. | 100% das telas do SAC exibem CPF mascarado | Teste funcional e revisão de UI | PRD §6 |
| NFRD-AUD-01 | Auditabilidade | Toda recarga gera registro de auditoria imutável com autor, data/hora, valor e cartão. | 100% das recargas com registro | Inspeção da trilha de auditoria | PRD §6 |
