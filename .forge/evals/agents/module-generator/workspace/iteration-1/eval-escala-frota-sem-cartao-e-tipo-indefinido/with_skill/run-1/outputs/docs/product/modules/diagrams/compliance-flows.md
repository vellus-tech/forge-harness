# Compliance Flows

## 1. Objetivo

Documentar os fluxos regulatórios, normativos ou legais que impactam a arquitetura modular do Frota Certa.

## 2. Compliance Aplicável

| Compliance / Norma / Lei | Aplicável? | Motivo | Diagrama |
|---|---|---|---|
| PCI DSS | Não | NFR-03 e o PRD declaram explicitamente que o produto não trata dados de cartão nem movimenta dinheiro | Não criado |
| LGPD / GDPR / Privacidade | Sim | NFR-01 — CPF, CNH e telefone do motorista são dados pessoais, com retenção obrigatória de 5 anos após desligamento | compliance-lgpd.md |
| Legislação trabalhista (CLT) | Ponto a Validar | RegistroJornada e o bloqueio de 10h diárias derivam de obrigação trabalhista (FR-04), mas não há um framework de compliance formalizado nesta base para tratá-la como diagrama próprio | Não criado — tratado como requisito funcional/NFR dentro de jornada-api e escalas-api |

## 3. Observações

- Criados apenas os diagramas aplicáveis: apenas `compliance-lgpd.md`.
- `compliance-pci-dss.md` não foi criado porque o NFR-03 e o PRD descartam explicitamente o processamento de dados de cartão — criar esse diagrama seria trabalho sem evidência de obrigação aplicável.
- A obrigação trabalhista (CLT) sobre limite de jornada foi tratada como requisito funcional/NFR dentro dos módulos escalas-api e jornada-api, e não como um diagrama de compliance dedicado, por não haver framework de compliance formal referenciado nesta base para essa obrigação.
