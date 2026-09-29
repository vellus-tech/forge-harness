# RCG — Recarga de Cartão de Transporte
**Requisitos**

- Versão: 0.3.0
- Data: 2026-09-24
- Status: Rascunho
- Aprovação: pendente (@carla-mendes, @joao-reis)

## 1. Contexto

O usuário do app Mobi recarrega o cartão de transporte da operadora. O pagamento é feito no gateway PagFacil (Pix ou cartão de crédito), que confirma por webhook. Após a confirmação, o saldo é creditado e a bilhetagem embarcada é avisada para atualizar a lista de créditos pendentes dos validadores.

## 2. Requisitos Funcionais

- **RF-01 — Solicitar recarga:** o app envia `numero_cartao`, valor e meio de pagamento; o sistema cria a recarga com status `pendente_pagamento` e devolve os dados de cobrança do PagFacil (QR Pix ou URL de checkout).
- **RF-02 — Valor permitido:** [NEEDS CLARIFICATION: faixa de valores e limite diário por cartão ainda não definidos pela operadora; jurídico avalia teto por CPF]
- **RF-03 — Confirmar pagamento:** ao receber o webhook do PagFacil com status pago, a recarga passa a `paga` e o saldo do cartão é creditado exatamente uma vez, mesmo se o webhook chegar repetido.
- **RF-04 — Expirar recarga:** recarga `pendente_pagamento` expira após um prazo. [NEEDS CLARIFICATION: prazo de expiração e se pagamento após a expiração credita saldo ou gera reembolso automático]
- **RF-05 — Consultar recargas:** o usuário lista as recargas dos próprios cartões, paginadas, ordenadas da mais recente para a mais antiga.

## 3. Requisitos Não-Funcionais

- **RNF-01 — Latência:** p95 de RF-01 abaixo de 400 ms, excluída a latência do PagFacil (timeout de 3 s).
- **RNF-02 — Isolamento:** um usuário nunca vê recargas de cartões que não são dele, nem de outra operadora.
- **RNF-03 — Auditoria:** toda mudança de status de recarga é auditável por 5 anos, com autor, instante e origem.
- **RNF-04 — Notificação da bilhetagem:** [NEEDS CLARIFICATION: canal de integração com a bilhetagem embarcada (evento ou API do fornecedor do validador) e SLA de propagação]

## 4. Propriedades (PBT)

- **PBT-01:** para qualquer sequência de N webhooks de pagamento da mesma recarga (N ≥ 1), o saldo final é o saldo inicial + valor da recarga.
- **PBT-02:** [NEEDS CLARIFICATION: depende de RF-02]
