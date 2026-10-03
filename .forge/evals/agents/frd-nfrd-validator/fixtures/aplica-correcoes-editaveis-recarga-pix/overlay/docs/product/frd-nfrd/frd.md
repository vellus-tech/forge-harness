# FRD — RecargaJá
**Requisitos Funcionais**

- **Versão:** 1.0.0
- **Data:** 2026-09-10
- **Status:** Aprovado para desenvolvimento
- **Referência pai:** ../prd/prd.md

### Histórico de Versões

| Versão | Data | Status | Descrição da alteração |
|--------|------|--------|----------------------|
| 1.0.0 | 2026-09-10 | Atual | Aprovação para desenvolvimento |

## 1. Requisitos Funcionais

### FRD-REC-01 — Recarga via Pix (PRD F1, BR-01, BR-02, BR-03)

O passageiro informa o valor (R$ 5,00 a R$ 300,00) e o app exibe um QR Code Pix dinâmico válido por 15 minutos. Após a confirmação do Pix pelo PSP, o crédito é disponibilizado no cartão. A confirmação é implementada com um consumidor Kafka no tópico `pix.confirmacoes`, em Spring Boot 3.3 com Resilience4j, gravando no PostgreSQL 16 particionado por mês.

Critérios de aceite:
- CA-01: valor fora da faixa exibe MSG-001 e não gera QR Code.
- CA-02: QR Code expirado não gera crédito e exibe MSG-002.
- CA-03: crédito só aparece no saldo após a confirmação do PSP.

### FRD-REC-02 — Consulta de saldo (PRD F2)

O passageiro consulta o saldo atual do cartão selecionado na tela inicial do app.

### FRD-XX — Histórico de recargas (PRD F3)

O passageiro e o atendente do SAC consultam as últimas 90 recargas, com data, valor, status e cartão. Para o SAC, o CPF do passageiro aparece mascarado.

Critérios de aceite:
- CA-01: a lista mostra no máximo 90 recargas, da mais recente para a mais antiga.
- CA-02: o atendente vê o CPF no formato ***.456.789-**.

## 2. Mensagens

| Código | Texto |
|---|---|
| MSG-001 | O valor da recarga deve estar entre R$ 5,00 e R$ 300,00. |
| MSG-002 | Este QR Code expirou. Gere um novo para concluir a recarga. |

## 3. Matriz de rastreabilidade

| Item PRD | Requisito FRD |
|---|---|
| F1 | FRD-REC-01 |
| F2 | FRD-XX |
| F3 | FRD-REC-02 |
