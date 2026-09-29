# RCG — Recarga de Cartão de Transporte
**Requisitos**

- Versão: 1.3.0
- Data: 2026-09-25
- Status: Aprovado
- Aprovado por: @carla-mendes (Produto), @joao-reis (Arquitetura)

## 1. Contexto

O usuário do app Mobi recarrega o cartão de transporte da operadora. O pagamento é feito no gateway PagFacil (Pix ou cartão de crédito), que confirma por webhook. Após a confirmação, o saldo é creditado e a bilhetagem embarcada é avisada para atualizar a lista de créditos pendentes dos validadores.

## 2. Requisitos Funcionais

- **RF-01 — Solicitar recarga:** o app envia `numero_cartao`, valor e meio de pagamento; o sistema cria a recarga com status `pendente_pagamento` e devolve os dados de cobrança do PagFacil (QR Pix ou URL de checkout).
- **RF-02 — Valor permitido:** o valor da recarga deve estar entre R$ 5,00 e R$ 500,00, em múltiplos de R$ 0,50.
- **RF-03 — Confirmar pagamento:** ao receber o webhook do PagFacil com status pago, a recarga passa a `paga` e o saldo do cartão é creditado exatamente uma vez, mesmo se o webhook chegar repetido.
- **RF-04 — Expirar recarga:** recarga `pendente_pagamento` há mais de 30 minutos passa a `expirada`; webhook de pagamento posterior é registrado para conciliação e não credita saldo.
- **RF-05 — Consultar recargas:** o usuário lista as recargas dos próprios cartões, paginadas, ordenadas da mais recente para a mais antiga.
- **RF-06 — Estornar recarga:** o usuário pode pedir estorno de uma recarga `paga` em até 7 dias corridos, desde que o saldo atual do cartão seja maior ou igual ao valor da recarga; o sistema debita o saldo, solicita o reembolso ao PagFacil e a recarga passa a `estornada` quando o PagFacil confirmar. A bilhetagem embarcada deve ser avisada do débito.

## 3. Requisitos Não-Funcionais

- **RNF-01 — Latência:** p95 de RF-01 abaixo de 400 ms, excluída a latência do PagFacil (timeout de 3 s).
- **RNF-02 — Isolamento:** um usuário nunca vê recargas de cartões que não são dele, nem de outra operadora.
- **RNF-03 — Auditoria:** toda mudança de status de recarga é auditável por 5 anos, com autor, instante e origem.
- **RNF-04 — Notificação da bilhetagem:** a bilhetagem embarcada recebe o crédito em até 60 s após a confirmação, com entrega ao menos uma vez.

## 4. Propriedades (PBT)

- **PBT-03:** para qualquer recarga, a soma dos créditos e débitos de saldo gerados por ela é 0 (estornada) ou o valor da recarga (paga), nunca outro valor.

- **PBT-01:** para qualquer sequência de N webhooks de pagamento da mesma recarga (N ≥ 1), o saldo final é o saldo inicial + valor da recarga.
- **PBT-02:** para qualquer valor em centavos, a validação de RF-02 aceita se e somente se 500 ≤ v ≤ 50000 e v mod 50 = 0.

## Histórico

| Versão | Data | Descrição |
|---|---|---|
| 1.2.0 | 2026-09-18 | Aprovação inicial |
| 1.3.0 | 2026-09-25 | Inclui RF-06 (estorno) e PBT-03, aprovado por @carla-mendes |
