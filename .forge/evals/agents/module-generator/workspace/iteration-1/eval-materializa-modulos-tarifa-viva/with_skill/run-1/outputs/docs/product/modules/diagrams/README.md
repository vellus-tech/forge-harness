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
| PCI DSS | compliance-pci-dss.md | Sim | A recarga com cartão de crédito/débito processa PAN no `tokenizacao-cartao-adapter` (NFR-02) |
| LGPD / Privacidade | compliance-lgpd.md | Sim | O cadastro de passageiro armazena CPF, data de nascimento e comprovante de matrícula (NFR-03) |
| Outro | — | Não identificado | Nenhuma outra obrigação regulatória citada nos artefatos de entrada |

## 4. Visualização navegável

`index.html`, neste mesmo diretório, é um visualizador estático dos cinco diagramas Mermaid acima para abertura direta no navegador, sem dependências externas além da CDN do Mermaid.
