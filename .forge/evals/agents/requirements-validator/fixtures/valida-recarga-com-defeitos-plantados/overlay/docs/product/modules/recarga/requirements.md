# RCG — Recarga

**Requisitos Funcionais e Não-Funcionais**

| Campo | Valor |
|-------|-------|
| **Versão** | 1.1.0 |
| **Data** | 2026-09-18 |
| **Status** | Aprovado para desenvolvimento |
| **Referência pai** | PRD Rota Única v2.1.0 (`docs/product/prd/prd.md`) |

## Histórico de Versões

| Versão | Data | Autor | Descrição |
|--------|------|-------|-----------|
| 0.1.0 | 2026-08-20 | requirements-writer | Rascunho inicial |
| 1.0.0 | 2026-09-02 | requirements-writer | Aprovado para desenvolvimento após revisão do PO |

## Visão Geral

O módulo Recarga permite ao passageiro adicionar créditos à Carteira por Pix, com confirmação assíncrona do PSP e crédito imediato após a liquidação. Atende o PRD Rota Única, que define a Carteira pré-paga recarregada por Pix.

## Escopo

- Geração de cobrança Pix (QR Code dinâmico) para recarga da Carteira.
- Confirmação de pagamento e crédito na Carteira.
- Estorno de recarga não creditada.

## Personas / Atores

| Persona | Descrição |
|---------|-----------|
| Passageiro | Usuário do app que recarrega a própria Carteira |
| Operador de SAC | Atendente do consórcio que consulta e estorna recargas |
| PSP | Prestador de serviço de pagamento que liquida o Pix |

## Requisitos Funcionais

### Req 1 — Gerar cobrança Pix de recarga

**Como** Passageiro **quero** gerar um QR Code Pix com o valor da recarga **para** adicionar saldo à minha Carteira.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | PRD Rota Única v2.1.0 — Visão |
| **Módulo** | recarga |

**Critérios de Aceite:**
- 1.1 O valor da recarga deve estar entre R$ 5,00 e R$ 500,00 (500 a 50.000 centavos).
- 1.2 A cobrança gerada expira em 30 minutos.
- 1.3 A cobrança deve ser gravada na tabela `tb_recarga_pix`, coluna `vl_recarga NUMERIC(10,2)`, e publicada no tópico Kafka `recarga.criada` usando a biblioteca `spring-kafka`.

**Cross-ref:** Req 2 do módulo Carteira (CRT)

### Req 2 — Creditar Carteira após confirmação do PSP

**Como** Passageiro **quero** que o saldo apareça na Carteira assim que o Pix for pago **para** poder embarcar em seguida.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | PRD Rota Única v2.1.0 — Visão |
| **Módulo** | recarga |

**Critérios de Aceite:**
- 2.1 Uma confirmação de pagamento do PSP gera exatamente um crédito na Carteira, mesmo que a confirmação chegue repetida.
- 2.2 O crédito usa o VO Money em centavos.
- 2.3 A tela de recarga deve ser intuitiva e o crédito deve aparecer rápido.

### Req 4 — Estornar recarga não creditada

**Como** Operador de SAC **quero** estornar uma recarga paga que não foi creditada **para** devolver o dinheiro ao Passageiro.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Should |
| **Módulo** | recarga |

**Critérios de Aceite:**
- 4.1 Só recargas com status pago e não creditado podem ser estornadas.
- 4.2 O Fiscal de catraca pode solicitar o estorno em nome do Passageiro.

### Req 5 — Recarga agendada recorrente

**Como** Passageiro **quero** agendar uma recarga mensal automática **para** não ficar sem saldo.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Could |
| **Origem** | Pedido do comercial em 2026-09-15 |
| **Módulo** | recarga |

**Critérios de Aceite:**
- 5.1 O Passageiro escolhe o dia do mês e o valor.
- 5.2 A recarga é gerada automaticamente no dia escolhido.

## Requisitos Não-Funcionais

- **RNF-01 (Segurança):** Toda notificação do PSP deve ter assinatura verificada antes de qualquer crédito; notificação com assinatura inválida é rejeitada e gera evento auditável `recarga.notificacao_rejeitada`.
- **RNF-02 (Performance):** O sistema deve ser performático e escalável.
- **RNF-03 (Auditoria):** Toda recarga, crédito e estorno gera registro imutável com timestamp, ator e valor em centavos, retido por 5 anos.

## Property-Based Testing

### PBT-01 — Idempotência do crédito por confirmação

**Tipo:** Idempotência
**Propriedade:**

> Para qualquer sequência de confirmações do PSP com o mesmo identificador de transação, o saldo final da Carteira aumenta exatamente uma vez o valor da recarga.

### PBT-02 — Faixa de valor

**Mapeia para:** Req 1.1
**Tipo:** Invariante matemática
**Propriedade:**

> O sistema deve funcionar bem com valores de recarga.

## Glossário local

| Termo | Definição |
|-------|-----------|
| Cobrança Pix | QR Code dinâmico emitido pelo PSP para uma recarga |
| PSP | Prestador de serviço de pagamento |

## Referências cruzadas

- PRD Rota Única v2.1.0
- ADR-0002 — Valores monetários em centavos inteiros
- ADR-0003 — Mensageria via outbox
