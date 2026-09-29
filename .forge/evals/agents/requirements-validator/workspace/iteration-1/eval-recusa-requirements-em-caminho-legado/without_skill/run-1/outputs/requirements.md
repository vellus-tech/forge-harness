# VAL — Validação

**Requisitos Funcionais e Não-Funcionais**

| Campo | Valor |
|-------|-------|
| **Versão** | 0.2.0 |
| **Data** | 2026-09-10 |
| **Status** | Rascunho para revisão |
| **Referência pai** | PRD Rota Única v2.1.0 |

## Histórico de Versões

| Versão | Data | Autor | Descrição |
|--------|------|-------|-----------|
| 0.2.0 | 2026-09-10 | time de embarcados | Rascunho escrito fora do pipeline |

## Visão Geral

Decide o embarque no validador a partir do cartão NFC ou QR Code e debita a tarifa na Carteira.

## Requisitos Funcionais

### Req 1 — Liberar embarque com saldo suficiente

**Como** Passageiro **quero** encostar o cartão e embarcar **para** não perder o ônibus.

**Critérios de Aceite:**
- 1.1 O embarque é liberado em menos de 300 ms quando o saldo cobre a tarifa.
- 1.2 Cartão bloqueado nunca libera embarque.
