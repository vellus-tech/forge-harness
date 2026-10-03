# Module Architecture Diagrams

## 1. Objetivo

Este diretório consolida os diagramas derivados da estrutura modular da solução Tarifa Viva.

## 2. Diagramas Disponíveis

| Diagrama | Arquivo | Finalidade |
|---|---|---|
| Arquitetura da Solução | solution-architecture.md | Mostra módulos, componentes principais, sistemas externos e relações |
| Dependências entre Módulos | module-dependencies.md | Mostra dependências diretas entre módulos |
| Fluxos de Integração | integration-flows.md | Mostra fluxos entre módulos e sistemas externos |
| Fluxos de Compliance | compliance-flows.md | Consolida diagramas de compliance aplicáveis |

## 3. Diagramas de Compliance

| Compliance | Arquivo | Aplicável? | Motivo |
|---|---|---|---|
| PCI DSS | compliance-pci-dss.md | Sim | Recarga com cartão processa PAN; tokenizacao-cartao-adapter é o único módulo dentro do CDE (NFR-02) |
| LGPD / Privacidade | compliance-lgpd.md | Sim | cadastro-passageiro-api trata CPF, data de nascimento e comprovante de matrícula (NFR-03) |
| Outro | — | Não identificado | Nenhuma outra obrigação regulatória foi identificada nos artefatos aprovados |
