# REC — Recarga de Cartão Transporte
**Requisitos Funcionais e Não-Funcionais**

- Versão: 1.1.0
- Data: 2026-09-26
- Status: Rascunho
- Referência pai: docs/product/prd-bilhetagem.md § 5

## Histórico de Versões

| Versão | Data | Status | Descrição da alteração |
|--------|------|--------|------------------------|
| 1.0.0 | 2026-09-02 | Aprovado para desenvolvimento | Aprovação inicial |
| 1.1.0 | 2026-09-26 | Rascunho | Reabertura do documento para retrabalho: ajuste do Req 1 para refletir o retorno em double/reais do SDK de pagamento (convertido para centavos na borda) e reversão de status para Rascunho a pedido do time do app, que vai iterar bastante nas próximas semanas. Versão incrementada (não mantida em 1.0.0) porque o documento já estava Aprovado — toda alteração a partir desse status exige bump, conforme `.forge/rules/conventions/document-versioning.md` |

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

- 1.1 O SDK de pagamento retorna o valor da Recarga como número double em reais (ex.: `25.50`). Esse valor é convertido para centavos (inteiro) imediatamente na borda de integração com o SDK, antes de entrar em qualquer lógica de domínio — o domínio da Recarga continua armazenando e operando o valor exclusivamente em centavos (inteiro), entre 500 e 50000 centavos.
- 1.2 A conversão double → centavos usa arredondamento bancário (NBR 5891 — `.forge/rules/domain/nbr-5891-rounding.md`), nunca truncamento simples, para evitar perda ou ganho de centavo por erro de representação de ponto flutuante.
- 1.3 Recarga confirmada muda para `CREDITED` e o saldo aumenta exatamente o valor em centavos.

**Nota de conformidade:** o pedido original era armazenar o valor da Recarga como double em reais no domínio. Isso conflita diretamente com a regra `.forge/rules/domain/money-as-cents.md` (prioridade alta), que proíbe `double`/`float`/`decimal` em lógica financeira por causa de erros de representação de ponto flutuante. Mantive a necessidade real (o SDK devolve double) mas empurrei a conversão para a borda de integração, preservando `long`/inteiro em centavos no domínio — que é o que os demais requisitos e o RNF de auditoria desta página já assumem. Se o time do app quiser propagar double além da borda, isso precisa de uma exceção documentada e aprovada à regra de domínio, não uma mudança silenciosa neste requirements.

**Cross-ref:** rule `.forge/rules/domain/money-as-cents.md`, rule `.forge/rules/domain/nbr-5891-rounding.md`

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

### PBT-02 — Conversão double → centavos sem perda

**Mapeia para:** Req 1.1, Req 1.2
**Tipo:** Arredondamento / conversão de representação

**Propriedade:**

> Para qualquer valor double retornado pelo SDK dentro da faixa válida (R$ 5,00 a R$ 500,00), a conversão para centavos seguida da formatação de exibição de volta para reais reproduz o valor original com precisão de centavo, usando arredondamento bancário no ponto de conversão.

## 8. Glossário local

Não aplicável nesta versão.

## 9. Fora do escopo do MVP

- Recarga recorrente automática.

## 10. Referências cruzadas

- docs/product/modules/validacao/requirements.md

---

> **Nota sobre esta cópia:** este arquivo é uma cópia manual de `docs/product/modules/recarga/requirements.md`, gerada a pedido do time do app para uso no Kiro. É uma cópia estática, não sincronizada automaticamente — se o documento fonte mudar de novo, esta cópia fica desatualizada até alguém repetir a cópia manualmente. Isso cria duas fontes da verdade para o mesmo requisito. Recomendo, antes da próxima mudança, decidir um mecanismo de sincronização (script/symlink/CI) em vez de cópia manual recorrente.
