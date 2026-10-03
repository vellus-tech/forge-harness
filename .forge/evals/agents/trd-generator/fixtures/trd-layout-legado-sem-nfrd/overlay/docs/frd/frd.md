# FRD - Tarifa Aberta

**Versão:** v0.9 | **Status:** Aprovado | **Fonte Principal:** docs/prd/prd.md

## Requisitos Funcionais

| Código | Requisito | Origem | Prioridade |
|---|---|---|---|
| FRD-tap-01 | Capturar o tap EMV no validador e registrar a viagem com linha, veículo e horário | F-01 | Must Have |
| FRD-tap-02 | Liberar a catraca offline por até 30 minutos consultando a deny list local | F-01, RN-02 | Must Have |
| FRD-aut-01 | Agregar os taps do dia por cartão em uma cobrança única enviada à adquirente | F-02, RN-03 | Must Have |
| FRD-cons-01 | Exibir ao passageiro as viagens pagas | F-03 | Should Have |
| FRD-den-01 | Manter a deny list de cartões com cobrança recusada | F-04, RN-04 | Must Have |
| FRD-conc-01 | Conciliar diariamente com a liquidação da adquirente | F-05 | Must Have |

## Observação

O validador tem que responder rápido para não formar fila na porta do ônibus.
