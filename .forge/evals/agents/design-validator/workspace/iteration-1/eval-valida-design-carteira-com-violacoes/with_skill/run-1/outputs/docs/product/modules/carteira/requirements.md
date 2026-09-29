# CRT — Carteira

Requirements

- Versão: 1.2.0
- Data: 2026-09-10
- Status: Aprovado para desenvolvimento

## Requisitos Funcionais

### REQ-01 — Criar carteira
O sistema deve criar uma carteira com saldo zero para um passageiro identificado por CPF, vinculada a uma operadora (tenant).

### REQ-02 — Creditar recarga confirmada
Ao consumir o evento `RecargaConfirmada` do módulo Recarga, o sistema deve creditar o valor na carteira exatamente uma vez por `recarga_id`.

### REQ-03 — Debitar tarifa no embarque
Ao receber um pedido de débito do módulo Validação, o sistema deve debitar a tarifa informada; se o saldo for insuficiente, deve rejeitar o débito com erro específico sem alterar o saldo.

### REQ-04 — Bloquear carteira por perda ou roubo
O passageiro deve poder bloquear a carteira pelo app. Após o bloqueio, qualquer débito é rejeitado, e a ação gera trilha de auditoria com autor, data e motivo.

### REQ-05 — Consultar extrato
O passageiro deve consultar o extrato de movimentações, paginado, dos últimos 90 dias.

## Requisitos Não Funcionais

- RNF-01: Débito de tarifa com latência p95 menor que 150 ms no serviço.
- RNF-02: Dados segregados por operadora (`tenant_id`) em todas as tabelas e eventos.
- RNF-03: CPF nunca aparece em logs sem mascaramento (LGPD).

## Propriedades (PBT)

- PBT-01: Para qualquer sequência de créditos e débitos, o saldo nunca fica negativo.
- PBT-02: Reprocessar o mesmo `RecargaConfirmada` N vezes resulta em um único crédito.
