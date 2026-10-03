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
| 1.3.0 | 2026-09-26 | Aprovado para desenvolvimento | Adição dos Reqs 5–8 (modo offline do Validador, decisão da reunião com a Operadora Rota Sul de 2026-09-20) |

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
| `DENIED_OFFLINE_LIMIT` | Limite de Validações offline atingido (200 Validações ou 24 horas, o que ocorrer primeiro) |

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

### Req 5 — Continuar validando embarque em Modo Offline

**Como** Validador **quero** continuar autorizando ou negando embarques quando perco a conexão com a central **para** não interromper o serviço de embarque.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | docs/product/ata-2026-09-20-operadora.md (decisão 1) |
| **Módulo** | validacao |

**Critérios de Aceite:**

- 5.1 Ao perder a conexão com a central, o Validador entra em Modo Offline e continua processando Validações sem interrupção perceptível ao Passageiro.
- 5.2 Em Modo Offline, as regras dos Reqs 1, 3 e 4 continuam sendo aplicadas com os dados disponíveis localmente no Validador.

**Cross-ref:** Req 1.1, Req 1.2, Req 3.1, Req 4.1

### Req 6 — Limitar Validações em Modo Offline

**Como** Operadora **quero** limitar a quantidade e o tempo de Validações aceitas em Modo Offline **para** conter o risco de fraude e de perda de compensação tarifária enquanto o Validador está desconectado.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | docs/product/ata-2026-09-20-operadora.md (decisão 2) |
| **Módulo** | validacao |

**Critérios de Aceite:**

- 6.1 Em Modo Offline, o Validador aceita no máximo 200 Validações desde o início do Modo Offline.
- 6.2 Em Modo Offline, o Validador aceita Validações por no máximo 24 horas desde o início do Modo Offline.
- 6.3 Ao atingir o primeiro dos limites de 6.1 ou 6.2, toda nova tentativa de embarque em Modo Offline resulta em `DENIED_OFFLINE_LIMIT`, sem novas tentativas de débito.
- 6.4 O contador de Validações e o cronômetro de 24 horas do Modo Offline são reiniciados quando o Validador entra novamente em Modo Offline após reconectar-se à central.

**Cross-ref:** Req 5.1

### Req 7 — Sincronizar Validações offline sem duplicar débito

**Como** Operadora **quero** que as Validações realizadas em Modo Offline sejam enviadas à central assim que a conexão for restabelecida, sem duplicar débito em caso de reenvio **para** manter a compensação tarifária correta.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | docs/product/ata-2026-09-20-operadora.md (decisão 3) |
| **Módulo** | validacao |

**Critérios de Aceite:**

- 7.1 Ao restabelecer a conexão com a central, o Validador envia todas as Validações realizadas em Modo Offline ainda não confirmadas pela central.
- 7.2 O reenvio de uma Validação offline já registrada pela central não gera novo débito nem novo registro duplicado.

**Cross-ref:** Req 2.1

### Req 8 — Manter bloqueio por lista de restrição em Modo Offline

**Como** Operadora **quero** que cartões em lista de restrição continuem bloqueados em Modo Offline **para** conter fraude mesmo sem conexão com a central.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | docs/product/ata-2026-09-20-operadora.md (decisão 4) |
| **Módulo** | validacao |

**Critérios de Aceite:**

- 8.1 Em Modo Offline, o Validador aplica a última lista de restrição recebida da central antes da perda de conexão.
- 8.2 Cartão presente nessa última lista de restrição recebida resulta em `DENIED_BLOCKED`, mesmo em Modo Offline.

**Cross-ref:** Req 3.1, Req 5.1

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

### PBT-02 — Reenvio de Validação offline não duplica débito

**Mapeia para:** Req 7.1, Req 7.2
**Tipo:** Idempotência

**Propriedade:**

> Para qualquer sequência de reenvios de uma mesma Validação offline à central, o número de débitos e de registros gerados para essa Validação é igual a um.

### PBT-03 — Limite de Modo Offline é uma máquina de estados monotônica

**Mapeia para:** Req 6.1, Req 6.2, Req 6.3

**Tipo:** State machine

**Propriedade:**

> Para qualquer sequência de tentativas de embarque em Modo Offline, uma vez atingido o limite de 200 Validações ou de 24 horas, toda tentativa subsequente dentro do mesmo período de Modo Offline resulta em `DENIED_OFFLINE_LIMIT`, sem retorno a um estado que autorize novas Validações antes de o Validador reconectar-se à central.

## 8. Glossário local

| Termo | Definição |
|-------|-----------|
| Modo Offline | Estado do Validador em que ele opera sem conexão ativa com a central, aplicando as regras de negócio com os dados disponíveis localmente. Origem: docs/product/ata-2026-09-20-operadora.md. |
| Validação Offline | Validação realizada pelo Validador enquanto em Modo Offline, pendente de envio e confirmação pela central. Origem: docs/product/ata-2026-09-20-operadora.md. |

## 9. Fora do escopo do MVP

- Validação biométrica.

## 10. Referências cruzadas

- docs/product/modules/tarifacao/requirements.md
