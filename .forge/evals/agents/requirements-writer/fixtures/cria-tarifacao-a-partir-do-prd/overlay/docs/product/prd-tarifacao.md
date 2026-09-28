# PRD — Tarifação da Bilhetagem Municipal

- Versão: 1.0.0
- Data: 2026-09-10
- Status: Aprovado

## 1. Contexto

A prefeitura publicou o Decreto 18.442/2026 fixando a Tarifa Base em R$ 4,85 a partir de 2026-11-01. O sistema de bilhetagem precisa calcular o valor debitado em cada Validação conforme o Perfil Tarifário do Passageiro e a Integração Temporal.

## 2. Regras de negócio

- RN-01: a Tarifa Base é de R$ 4,85 e deve ser configurável por vigência (nova tarifa entra em vigor numa data futura sem afetar Validações anteriores).
- RN-02: Integração Temporal — a segunda Validação dentro de uma Janela de Integração de 60 minutos contados da primeira paga 50% da Tarifa Base; a terceira Validação na mesma janela paga tarifa cheia.
- RN-03: Perfil estudante paga meia tarifa (50% da Tarifa Base), limitado a 60 Validações por mês civil.
- RN-04: Perfil idoso (65 anos ou mais) e PcD têm Gratuidade.
- RN-05: benefícios não se acumulam: estudante em integração paga o menor entre os dois valores, nunca um desconto sobre o outro.
- RN-06: cada cálculo de tarifa deve ser auditável pela Operadora e pela SEMOB (Secretaria Municipal de Mobilidade) por 5 anos, identificando Cartão Transporte, perfil, regra aplicada e valor.

## 3. Requisitos de qualidade

- O cálculo precisa responder em até 150 ms (p95) no validador, mesmo com 3.000 Validações por minuto no pico da manhã.
- O número do Cartão Transporte não pode aparecer completo em logs.

## 4. Fora do escopo do MVP

- Tarifa diferenciada por linha ou por distância.
- Bilhete único mensal.

## 5. Notas técnicas do time (rascunho)

O Rafael sugeriu persistir as regras na tabela `tarifa_regra` do PostgreSQL, com o valor numa coluna `NUMERIC(10,2)`, e expor o cálculo em `POST /v1/tarifas/calcular` usando a lib `decimal.js`.
