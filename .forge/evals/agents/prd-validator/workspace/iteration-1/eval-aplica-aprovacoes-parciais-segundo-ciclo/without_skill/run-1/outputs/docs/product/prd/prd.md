# PRD — Recarga do Cartão Via Norte pelo App

## 1. Resumo Executivo

### 1.1 Descrição do Produto

Funcionalidade do app Via Norte que permite ao passageiro recarregar o cartão de transporte pagando com Pix, sem precisar ir ao guichê.

### 1.4 Resultado Esperado

Reduzir as filas nos guichês e aumentar a satisfação do passageiro.

## 2. Contexto e Problema

### 2.2 Problema a Ser Resolvido

62% das recargas acontecem nos 14 guichês físicos e a fila média no pico do terminal Centro chega a 22 minutos (contagem de agosto/2026).

## 3. Personas

### P-01 — Passageiro recorrente

Usa o ônibus diariamente e recarrega o cartão uma vez por semana.

### P-02 — Operador de guichê

Atende as recargas presenciais.

## 4. Visão do Produto e Objetivos

### OBJ-01 — [Nome do Objetivo]

Aumentar a participação das recargas digitais.

### OBJ-02 — Satisfação do passageiro

Atingir NPS ≥ 70 no app em 3 meses após o lançamento.

## 5. Escopo do Produto

### 5.1 Dentro do Escopo

- Recarga por Pix (QR Code dinâmico e Pix Copia e Cola).
- Histórico de recargas no app.

### 5.2 Fora do Escopo

- Venda de novos cartões pelo app.
- Recarga por cartão de crédito ou débito (fica para uma fase futura por causa do custo de adquirência, sem data definida).

## 7. Requisitos Funcionais

### RF-01 — Gerar cobrança Pix

O app deve gerar um QR Code dinâmico e um código Pix Copia e Cola para o valor escolhido pelo passageiro.

### RF-02 — Creditar a recarga no cartão

Após a confirmação do pagamento, o crédito deve ficar disponível para o validador do ônibus na próxima sincronização, em até 30 minutos. Detalhes técnicos de implementação (mensageria, persistência e modelagem de dados) ficam remetidos ao `TRD.md`.

### RF-03 — Histórico de recargas

O passageiro deve visualizar no app as recargas realizadas, com data, valor e status.

## 9. Restrições, Premissas e Lacunas

### 9.3 Lacunas e Pontos a Validar

- Valor mínimo e máximo de recarga ainda não definidos.

## 10. Riscos e Mitigações

### RISCO-P01 — Baixa adesão ao app

Passageiros podem continuar preferindo o guichê.
