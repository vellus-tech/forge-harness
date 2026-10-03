# VAL — Validação de Embarque
**Requisitos Funcionais e Não-Funcionais**

- Versão: 1.2.0
- Data: 2026-08-28
- Status: Aprovado para desenvolvimento
- Referência pai: docs/product/prd-bilhetagem.md § 3

## Histórico de Versões

| Versão | Data | Status | Descrição da alteração |
|--------|------|--------|------------------------|
| 1.0.0 | 2026-07-02 | Aprovado para desenvolvimento | Aprovação inicial |
| 1.1.0 | 2026-08-05 | Aprovado para desenvolvimento | Adição do Req 3 (bloqueio por lista de restrição) |
| 1.2.0 | 2026-08-28 | Aprovado para desenvolvimento | Adição do Req 4 (QR Code de embarque) |

## 1. Visão Geral

O módulo validacao autoriza ou nega o embarque do Passageiro no Validador a partir do Cartão Transporte ou do QR Code de embarque.

## 2. Escopo

### 2.1 Incluído

- Validação por Cartão Transporte e por QR Code.

### 2.2 Excluído

- Cálculo tarifário (módulo tarifacao).

### 2.3 Fora do escopo do MVP

- Validação biométrica.

## 3. Personas / Atores

- Passageiro
- Validador
- Operadora

## 4. Lista canônica de resultados de Validação

| Código | Significado |
|--------|-------------|
| `AUTHORIZED` | Embarque autorizado |
| `DENIED_BALANCE` | Saldo insuficiente |
| `DENIED_BLOCKED` | Cartão em lista de restrição |
| `DENIED_INVALID` | Credencial ilegível ou inválida |

## 5. Requisitos Funcionais

### Req 1 — Autorizar embarque com saldo suficiente

**Como** Passageiro **quero** apresentar meu Cartão Transporte **para** embarcar quando tenho saldo.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | docs/product/prd-bilhetagem.md § 3.1 |
| **Módulo** | validacao |

**Critérios de Aceite:**

- 1.1 Com saldo maior ou igual ao valor calculado, o resultado é `AUTHORIZED`.
- 1.2 Com saldo menor, o resultado é `DENIED_BALANCE` e nenhum débito ocorre.

**Cross-ref:** Não aplicável nesta versão

### Req 2 — Registrar toda Validação

**Como** Operadora **quero** que toda Validação fique registrada **para** conciliar a compensação tarifária.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | docs/product/prd-bilhetagem.md § 3.2 |
| **Módulo** | validacao |

**Critérios de Aceite:**

- 2.1 Toda Validação, autorizada ou negada, gera um registro com resultado da lista canônica.

**Cross-ref:** Não aplicável nesta versão

### Req 3 — Bloquear cartão em lista de restrição

**Como** Operadora **quero** negar o embarque de cartões em lista de restrição **para** conter fraude.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | docs/product/prd-bilhetagem.md § 3.3 |
| **Módulo** | validacao |

**Critérios de Aceite:**

- 3.1 Cartão presente na lista de restrição vigente resulta em `DENIED_BLOCKED`.

**Cross-ref:** Não aplicável nesta versão

### Req 4 — Validar por QR Code de embarque

**Como** Passageiro **quero** embarcar com QR Code **para** não depender do cartão físico.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Should |
| **Origem** | docs/product/prd-bilhetagem.md § 3.4 |
| **Módulo** | validacao |

**Critérios de Aceite:**

- 4.1 QR Code expirado ou com assinatura inválida resulta em `DENIED_INVALID`.

**Cross-ref:** Não aplicável nesta versão

## 6. Requisitos Não-Funcionais

### RNF 1 — Latência da Validação

| Campo | Valor |
|-------|-------|
| **Categoria** | Performance |
| **Prioridade** | Must |
| **Origem** | docs/product/prd-bilhetagem.md § 4 |
| **Módulo** | validacao |

**Descrição:**

A decisão de embarque deve ser exibida rapidamente no Validador.

**Critérios de Aceite:**

- RNF-1.1 p95 da decisão de embarque em até 300 ms no Validador.

**Cross-ref:** Não aplicável nesta versão

## 7. Property-Based Testing

### PBT-01 — Débito nunca torna saldo negativo

**Mapeia para:** Req 1.1, Req 1.2
**Tipo:** Invariante matemática

**Propriedade:**

> Para qualquer saldo e valor de tarifa em centavos, após uma Validação o saldo resultante é maior ou igual a zero.

## 8. Glossário local

Não aplicável nesta versão.

## 9. Fora do escopo do MVP

- Validação biométrica.

## 10. Referências cruzadas

- docs/product/modules/tarifacao/requirements.md
