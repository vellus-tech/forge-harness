# NFRD — Portal do Lojista
**Requisitos Não Funcionais**

- **Versão:** 0.2.0
- **Data:** 2026-09-15
- **Status:** Rascunho para revisão
- **Referência pai:** ../prd/prd.md

### Histórico de Versões

| Versão | Data | Status | Descrição da alteração |
|--------|------|--------|----------------------|
| 0.2.0 | 2026-09-15 | Atual | Revisão de segurança |
| 0.1.0 | 2026-09-05 | Anterior | Versão inicial |

## 1. Requisitos Não Funcionais

| ID | Categoria | Requisito | Métrica / Critério | Método de validação | Origem |
|---|---|---|---|---|---|
| NFRD-SEC-01 | Segurança | Senhas armazenadas de forma segura. | — | Revisão de código | PRD BR-03 |
| NFRD-SEC-02 | Compliance | Nenhum PAN completo exibido ou exportado (PCI DSS 4.0.1 req. 3.4). | 0 ocorrências de PAN completo em telas e CSV | Varredura de PAN nas telas e nos CSV gerados | PRD §5 |
| NFRD-RET-01 | Retenção | Dados de vendas retidos pelo prazo regulatório. | — | — | PRD §5 |
| NFRD-PERF-01 | Performance | Consulta de 90 dias responde rapidamente. | p95 ≤ 3 s para até 50 mil vendas | Teste de carga | PRD F2 |
