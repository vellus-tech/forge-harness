# Compliance Flows

## 1. Objetivo

Documentar os fluxos regulatórios, normativos ou legais que impactam a arquitetura modular da solução Tarifa Viva.

## 2. Compliance Aplicável

| Compliance / Norma / Lei | Aplicável? | Motivo | Diagrama |
|---|---|---|---|
| PCI DSS | Sim | A recarga com cartão de crédito/débito processa PAN, restrito ao tokenizacao-cartao-adapter (NFR-02) | compliance-pci-dss.md |
| LGPD / GDPR / Privacidade | Sim | O cadastro de passageiro armazena CPF, data de nascimento e comprovante de matrícula (NFR-03) | compliance-lgpd.md |
| Outro | Não identificado | Nenhuma outra obrigação regulatória (ex.: SOX) é citada explicitamente nos artefatos de entrada, embora liquidação e recarga movimentem valores financeiros (ver Pontos a Validar em cada README de módulo) | — |

## 3. Observações

- Apenas os diagramas PCI DSS e LGPD foram criados por terem obrigação explícita nos artefatos de entrada (NFR-02 e NFR-03).
- Riscos de auditoria financeira (SOX) foram registrados como Ponto a Validar nos módulos `recarga-api` e `liquidacao-operadoras-worker`, sem diagrama próprio por falta de obrigação confirmada.
