# PRD — Tarifa Viva

## Controle de Versão
| Versão | Data | Descrição |
|---|---|---|
| v1.0 | 2026-08-10 | Versão inicial |

## 1. Visão
Tarifa Viva é a plataforma de bilhetagem eletrônica do consórcio municipal de ônibus de Vale do Sereno. O passageiro usa um cartão pré-pago (físico ou virtual no app) para embarcar; o validador embarcado debita a tarifa no momento do embarque.

## 2. Objetivos
- OBJ-01: reduzir o tempo médio de embarque para menos de 2 segundos por passageiro.
- OBJ-02: permitir recarga do cartão pelo app e em pontos de venda credenciados.
- OBJ-03: aplicar integração tarifária temporal (segunda viagem com desconto dentro de 60 minutos).
- OBJ-04: repassar a receita às 3 operadoras do consórcio (clearing diário) com trilha auditável.

## 3. Atores
- Passageiro (app ou cartão físico).
- Validador embarcado (equipamento no ônibus, opera offline e sincroniza em lote).
- Operadora de ônibus (Viação Serrana, Expresso Vale, TransSereno).
- Gestor do consórcio (backoffice).
- Adquirente de cartão de crédito e PSP de Pix (externos).

## 4. Jornadas
- JRN-01 Embarque: passageiro aproxima o cartão do validador; o validador valida o cartão (lista de bloqueio + saldo) e debita a tarifa.
- JRN-02 Recarga: passageiro compra créditos no app (cartão de crédito) ou no ponto de venda.
- JRN-03 Integração: segunda viagem em até 60 minutos paga 50% da tarifa.
- JRN-04 Clearing: ao fim do dia o consórcio apura quanto cada operadora recebe.
- JRN-05 Notificação: o passageiro recebe aviso de saldo baixo por push.

## 5. Retenção
- O app exibe ao passageiro o histórico de viagens dos últimos 30 dias.
