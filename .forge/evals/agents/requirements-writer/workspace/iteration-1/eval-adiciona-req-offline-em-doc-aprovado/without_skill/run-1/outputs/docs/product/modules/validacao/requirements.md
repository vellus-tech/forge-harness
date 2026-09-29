# VAL — Validação de Embarque
**Requisitos Funcionais e Não-Funcionais**

- Versão: 1.3.0
- Data: 2026-09-26
- Status: Aprovado para desenvolvimento
- Referência pai: docs/product/prd-bilhetagem.md § 3

## Histórico de Versões

| Versão | Data | Status | Descrição da alteração |
|--------|------|--------|------------------------|
| 1.0.0 | 2026-07-02 | Aprovado para desenvolvimento | Aprovação inicial |
| 1.1.0 | 2026-08-05 | Aprovado para desenvolvimento | Adição do Req 3 (bloqueio por lista de restrição) |
| 1.2.0 | 2026-08-28 | Aprovado para desenvolvimento | Adição do Req 4 (QR Code de embarque) |
| 1.3.0 | 2026-09-26 | Aprovado para desenvolvimento | Adição dos Req 5-7 (modo offline do Validador), conforme ata da reunião com a Operadora Rota Sul de 2026-09-20 |

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
| `DENIED_OFFLINE_LIMIT` | Limite de Validações em modo offline atingido |

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

### Req 5 — Validar embarque em modo offline

**Como** Operadora **quero** que o Validador continue validando embarques quando perder a conexão com a central **para** não interromper o serviço por instabilidade de rede.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | docs/product/ata-2026-09-20-operadora.md, decisão 1 |
| **Módulo** | validacao |

**Critérios de Aceite:**

- 5.1 Ao perder a conexão com a central, o Validador continua aceitando Cartão Transporte e QR Code de embarque em modo offline, aplicando as mesmas regras de autorização e negação já definidas nos Req 1, 3 e 4.
- 5.2 Toda Validação realizada em modo offline gera um registro local com resultado da lista canônica, para posterior sincronização (Req 7).

**Cross-ref:** docs/product/ata-2026-09-20-operadora.md, decisão 1

### Req 6 — Limitar Validações em modo offline

**Como** Operadora **quero** limitar a quantidade e o tempo de Validações aceitas em modo offline **para** conter o risco de fraude e inconsistência quando a central está inacessível.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | docs/product/ata-2026-09-20-operadora.md, decisão 2 |
| **Módulo** | validacao |

**Critérios de Aceite:**

- 6.1 Em modo offline, o Validador aceita no máximo 200 Validações ou 24 horas contadas a partir da perda de conexão, o que ocorrer primeiro.
- 6.2 Ao atingir o limite de quantidade ou de tempo definido em 6.1, toda nova tentativa de embarque em modo offline resulta em `DENIED_OFFLINE_LIMIT`.
- 6.3 Cartões em lista de restrição continuam bloqueados em modo offline, usando a última lista de restrição recebida da central antes da perda de conexão (Req 3).

**Cross-ref:** docs/product/ata-2026-09-20-operadora.md, decisões 2 e 4

### Req 7 — Sincronizar Validações offline com a central

**Como** Operadora **quero** que as Validações feitas em modo offline sejam enviadas à central assim que a conexão for restabelecida **para** manter o registro de embarques completo para a compensação tarifária.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | docs/product/ata-2026-09-20-operadora.md, decisão 3 |
| **Módulo** | validacao |

**Critérios de Aceite:**

- 7.1 Assim que a conexão com a central é restabelecida, toda Validação registrada localmente em modo offline (Req 5.2) é enviada à central.
- 7.2 O reenvio de uma Validação offline já recebida pela central não gera débito duplicado nem registro duplicado.

**Cross-ref:** docs/product/ata-2026-09-20-operadora.md, decisão 3

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
- docs/product/ata-2026-09-20-operadora.md
