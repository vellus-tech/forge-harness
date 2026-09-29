# Compliance Flows

## 1. Objetivo

Documentar os fluxos regulatórios, normativos ou legais que impactam a arquitetura modular da solução Tarifa Viva.

## 2. Compliance Aplicável

| Compliance / Norma / Lei | Aplicável? | Motivo | Diagrama |
|---|---|---|---|
| PCI DSS | Sim | A recarga com cartão processa PAN; somente tokenizacao-cartao-adapter pode recebê-lo (NFR-02) | compliance-pci-dss.md |
| LGPD / GDPR / Privacidade | Sim | cadastro-passageiro-api trata CPF, data de nascimento e comprovante de matrícula, com retenção de 5 anos e direitos do titular em até 15 dias (NFR-03) | compliance-lgpd.md |
| Outro | Não identificado | Nenhuma outra obrigação regulatória foi identificada no PRD, FRD, NFRD, TRD ou DDD aprovados | — |

## 3. Observações

- Apenas diagramas aplicáveis foram criados (PCI DSS e LGPD).
- Nenhum outro compliance foi inferido sem evidência nos artefatos de entrada.
