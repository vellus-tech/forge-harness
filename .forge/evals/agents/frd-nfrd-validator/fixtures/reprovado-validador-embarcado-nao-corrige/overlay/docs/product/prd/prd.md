# PRD — Validador Embarcado
**Validador de tarifa embarcado nos ônibus**

- **Versão:** 1.0.0
- **Data:** 2026-09-03
- **Status:** Aprovado para desenvolvimento

## 1. Objetivo

Validar o embarque do passageiro no ônibus por cartão de transporte, QR Code e cartão bancário por aproximação (EMV), inclusive sem conexão.

## 2. Escopo

- F1 — Validação de cartão de transporte (MIFARE) com débito da tarifa no cartão.
- F2 — Validação de QR Code emitido pelo app da operadora.
- F3 — Validação de cartão bancário por aproximação (EMV contactless), com cobrança agregada no fim do dia.
- F4 — Operação offline: validar por até 72 horas sem conexão, com lista de bloqueio local.
- F5 — Integração temporal: segunda viagem em até 60 minutos com desconto de 50%.
- F6 — Sincronização das transações com o backend quando houver conexão.

## 3. Regras de negócio

- BR-01 — Tarifa cheia de R$ 5,00; segunda viagem em até 60 minutos custa R$ 2,50.
- BR-02 — Cartão na lista de bloqueio é recusado com aviso sonoro e visual.
- BR-03 — Transação offline não sincronizada em 72 horas bloqueia o validador para novas validações EMV.

## 4. Requisitos de qualidade esperados

- Validação concluída em até 500 ms do toque até o sinal verde, em 99% dos casos.
- Nenhuma transação pode ser perdida entre a validação e a sincronização.
- Dados de cartão bancário tratados conforme PCI DSS.
