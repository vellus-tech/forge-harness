# REC — Recarga de Cartão Transporte
**Requisitos Funcionais e Não-Funcionais**

- Versão: 1.0.0
- Data: 2026-09-02
- Status: Aprovado para desenvolvimento
- Referência pai: docs/product/prd-bilhetagem.md § 5

## Histórico de Versões

| Versão | Data | Status | Descrição da alteração |
|--------|------|--------|------------------------|
| 1.0.0 | 2026-09-02 | Aprovado para desenvolvimento | Aprovação inicial |

## 1. Visão Geral

O módulo recarga credita saldo no Cartão Transporte a partir de pagamento por Pix ou cartão.

## 2. Escopo

### 2.1 Incluído

- Recarga avulsa por Pix e cartão.

### 2.2 Excluído

- Estorno de recarga (módulo financeiro).

### 2.3 Fora do escopo do MVP

- Recarga recorrente automática.

## 3. Personas / Atores

- Passageiro
- Operadora

## 4. Lista canônica de status de Recarga

| Código | Significado |
|--------|-------------|
| `PENDING` | Aguardando confirmação do pagamento |
| `CREDITED` | Saldo creditado |
| `FAILED` | Pagamento recusado |

## 5. Requisitos Funcionais

### Req 1 — Creditar Recarga confirmada

**Como** Passageiro **quero** que minha Recarga paga seja creditada **para** poder embarcar.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | docs/product/prd-bilhetagem.md § 5.1 |
| **Módulo** | recarga |

**Critérios de Aceite:**

- 1.1 O valor da Recarga é informado e armazenado em centavos (inteiro), entre 500 e 50000 centavos.
- 1.2 Recarga confirmada muda para `CREDITED` e o saldo aumenta exatamente o valor em centavos.

**Cross-ref:** rule `.forge/rules/domain/money-as-cents.md`

### Req 2 — Crédito idempotente

**Como** Operadora **quero** que a mesma confirmação de pagamento não credite duas vezes **para** evitar saldo indevido.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | docs/product/prd-bilhetagem.md § 5.2 |
| **Módulo** | recarga |

**Critérios de Aceite:**

- 2.1 Confirmações repetidas com o mesmo identificador de pagamento resultam em um único crédito.

**Cross-ref:** Não aplicável nesta versão

## 6. Requisitos Não-Funcionais

### RNF 1 — Trilha de auditoria da Recarga

| Campo | Valor |
|-------|-------|
| **Categoria** | Auditoria |
| **Prioridade** | Must |
| **Origem** | docs/product/prd-bilhetagem.md § 6 |
| **Módulo** | recarga |

**Descrição:**

Toda mudança de status de Recarga deve ser rastreável.

**Critérios de Aceite:**

- RNF-1.1 Cada transição de status gera registro append-only com data, status anterior e novo.

**Cross-ref:** rule `.forge/rules/domain/audit-immutability.md`

## 7. Property-Based Testing

### PBT-01 — Crédito idempotente

**Mapeia para:** Req 2.1
**Tipo:** Idempotência

**Propriedade:**

> Para qualquer sequência de N ≥ 1 confirmações com o mesmo identificador de pagamento, o saldo final é igual ao saldo inicial mais o valor da Recarga uma única vez.

## 8. Glossário local

Não aplicável nesta versão.

## 9. Fora do escopo do MVP

- Recarga recorrente automática.

## 10. Referências cruzadas

- docs/product/modules/validacao/requirements.md
