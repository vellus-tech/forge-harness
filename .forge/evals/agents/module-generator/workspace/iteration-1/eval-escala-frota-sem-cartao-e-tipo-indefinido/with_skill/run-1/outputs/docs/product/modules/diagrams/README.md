# Module Architecture Diagrams

## 1. Objetivo

Este diretório consolida os diagramas derivados da estrutura modular do Frota Certa.

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
| PCI DSS | — (não criado) | Não | NFR-03 e o PRD declaram que o produto não trata dados de cartão nem movimenta dinheiro |
| LGPD / Privacidade | compliance-lgpd.md | Sim | NFR-01 — CPF, CNH e telefone do motorista são dados pessoais, com retenção obrigatória de 5 anos após desligamento |
| Outro | — | Não identificado nesta base | — |
