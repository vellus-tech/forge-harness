# PRD - Validador de Embarque Contactless

## Controle de Versão

Joana Lima - 2026-09-10 - Versão 1.0 aprovada pelo comitê de produto.

## 1. Visão

Permitir que passageiros do transporte coletivo municipal paguem a tarifa aproximando cartão de débito/crédito contactless (EMV) ou carteira digital diretamente no validador do ônibus, sem cartão de bilhetagem próprio.

## 2. Objetivos de negócio

- OBJ-01: Atingir 30% das validações pagas por EMV em 12 meses.
- OBJ-02: Reduzir o tempo de embarque por passageiro.
- OBJ-03: Zerar perda de receita por validações não liquidadas.

## 3. KPIs

- KPI-01: Tempo de validação na catraca (aproximação até luz verde) de no máximo 500 ms no percentil 95.
- KPI-02: Taxa de validações recusadas por falha técnica abaixo de 0,5%.
- KPI-03: 100% das validações offline enviadas ao backend em até 24 h.

## 4. Volumetria

- 1.200 validadores embarcados em 1.050 ônibus.
- 900 mil validações por dia útil; pico de 250 validações por segundo entre 6h e 8h.
- Crescimento esperado de 20% ao ano.

## 5. Jornadas

- J-01: Passageiro aproxima o cartão, o validador aprova localmente (lista de restrição) e libera a catraca.
- J-02: O validador envia lotes de transações ao backend, que agrega por PAN tokenizado e submete à adquirente uma cobrança por dia (agregação de tarifas).
- J-03: Operador da gestora consulta no portal as validações de um veículo por período.
- J-04: Passageiro consulta seu extrato de viagens no app pelo cartão tokenizado.

## 6. Restrições e contexto regulatório

- R-01: O validador opera offline por até 72 h (áreas sem cobertura celular).
- R-02: Dados de cartão estão no escopo PCI DSS 4.0.1; PAN nunca pode ser armazenado em claro.
- R-03: Dados pessoais de passageiros sujeitos à LGPD; o extrato é acessível apenas ao titular.
- R-04: O contrato com a prefeitura exige disponibilidade do backend de 99,5% ao mês, com multa por descumprimento.
- R-05: Integração com a adquirente via API REST dela; a gestora recebe arquivos de conciliação diários.

## 7. Fora de escopo

- Venda de créditos de bilhetagem própria.
- Gratuidades e meia-passagem nesta fase.

## 8. Premissas

- O portal da gestora e o app do passageiro devem ser rápidos e fáceis de usar.
