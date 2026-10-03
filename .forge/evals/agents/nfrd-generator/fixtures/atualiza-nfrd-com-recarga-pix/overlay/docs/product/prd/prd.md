# PRD - App Cartão Cidade

## Controle de Versão

Rafael Costa - 2026-06-02 - Versão 1.0 aprovada.
Rafael Costa - 2026-09-22 - Versão 1.1: inclusão da seção 7 (recarga via Pix).

## 1. Visão

App do passageiro para consultar saldo e extrato do cartão de bilhetagem Cartão Cidade.

## 2. Objetivos

- OBJ-01: Reduzir em 40% o atendimento presencial nos postos para consulta de saldo.
- OBJ-02 (v1.1): Migrar 25% das recargas do balcão para Pix em 6 meses.

## 3. KPIs

- KPI-01: Consulta de saldo responde em até 800 ms no p95.
- KPI-02 (v1.1): Crédito da recarga Pix disponível no cartão em até 10 s após a confirmação do pagamento pelo PSP, no p95.

## 4. Volumetria

- 350 mil usuários ativos por mês; pico de 120 consultas por segundo às 7h.
- (v1.1) Estimativa de 60 mil recargas Pix por dia, pico de 15 recargas por segundo no dia 5 de cada mês.

## 5. Restrições

- R-01: Dados pessoais sujeitos à LGPD.
- R-02: Backend com disponibilidade de 99,5% ao mês.

## 6. Jornadas

- J-01: Passageiro consulta saldo e extrato.

## 7. Recarga via Pix (v1.1)

- J-02: Passageiro escolhe o valor, o app gera QR Code Pix dinâmico via PSP parceiro, o PSP notifica o pagamento por webhook e o saldo é creditado no cartão.
- R-03: Comprovantes de recarga devem ser retidos por 5 anos (exigência do contrato de concessão).
- R-04: Uma mesma notificação de pagamento do PSP pode chegar mais de uma vez; o crédito não pode ser duplicado.
- R-05: O webhook do PSP é autenticado por mTLS com certificado emitido pelo PSP.
