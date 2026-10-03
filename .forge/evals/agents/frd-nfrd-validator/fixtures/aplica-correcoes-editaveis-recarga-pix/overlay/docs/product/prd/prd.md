# PRD — RecargaJá
**Recarga de cartão de transporte via Pix**

- **Versão:** 1.0.0
- **Data:** 2026-09-01
- **Status:** Aprovado para desenvolvimento

## 1. Objetivo

Permitir que passageiros do sistema de bilhetagem metropolitano recarreguem o cartão de transporte pelo aplicativo usando Pix, sem ir a um posto de recarga.

## 2. Escopo

- F1 — Recarga de cartão via Pix (QR Code dinâmico gerado no app).
- F2 — Consulta de saldo do cartão.
- F3 — Histórico das últimas 90 recargas do passageiro.

## 3. Fora de escopo

- Recarga por cartão de crédito.
- Venda de cartão novo.

## 4. Personas

- P-01 Passageiro com cartão cadastrado no app.
- P-02 Atendente do SAC da operadora (consulta histórico para atender reclamação).

## 5. Regras de negócio

- BR-01 — Valor da recarga entre R$ 5,00 e R$ 300,00 por transação.
- BR-02 — O crédito só fica disponível no cartão após a confirmação do Pix pelo PSP.
- BR-03 — QR Code expira em 15 minutos; recarga expirada não gera crédito.

## 6. Requisitos de qualidade esperados

- 95% das recargas devem ter o crédito disponível em até 10 segundos após a confirmação do Pix.
- CPF do passageiro deve aparecer mascarado em qualquer tela do SAC (LGPD).
- Toda recarga deve deixar trilha de auditoria imutável (quem, quando, valor, cartão).
