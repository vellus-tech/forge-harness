# FRD - Tarifa Aberta

**Versão:** v1.0 | **Status:** Aprovado | **Fonte Principal:** docs/product/prd/prd.md

## Requisitos Funcionais

| Código | Requisito | Origem | Prioridade |
|---|---|---|---|
| FRD-tap-01 | Capturar o tap EMV no validador e registrar a viagem com linha, veículo e horário | F-01 | Must Have |
| FRD-tap-02 | Liberar a catraca offline por até 30 minutos consultando a deny list local | F-01, RN-02 | Must Have |
| FRD-aut-01 | Agregar os taps do dia por cartão em uma cobrança única | F-02, RN-03 | Must Have |
| FRD-aut-02 | Enviar a cobrança agregada à adquirente até as 23h59 | F-02, RN-03 | Must Have |
| FRD-cons-01 | Exibir ao passageiro as viagens pagas, identificando o cartão pelos 4 últimos dígitos | F-03 | Should Have |
| FRD-den-01 | Incluir na deny list o cartão com cobrança recusada e distribuí-la aos validadores | F-04, RN-04 | Must Have |
| FRD-den-02 | Remover o cartão da deny list após quitação | F-04, RN-04 | Must Have |
| FRD-conc-01 | Conciliar diariamente as cobranças com o arquivo de liquidação da adquirente | F-05 | Must Have |

## Regras de Negócio

| Código | Regra | Fonte |
|---|---|---|
| BR-01 | Tarifa fixa de R$ 4,40 | RN-01 |
| BR-02 | Offline por no máximo 30 minutos | RN-02 |
| BR-03 | Uma cobrança por cartão por dia | RN-03 |
