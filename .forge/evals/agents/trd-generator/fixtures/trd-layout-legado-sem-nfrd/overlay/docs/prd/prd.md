# PRD - Tarifa Aberta

**Produto:** Tarifa Aberta
**Versão:** v0.9
**Status:** Aprovado
**Data:** 2026-09-10

## 1. Visão

Permitir que o passageiro pague a tarifa de ônibus encostando o cartão de crédito ou débito contactless (EMV) no validador embarcado, sem cadastro prévio e sem cartão de transporte. A operadora de transporte recebe o valor pela adquirente parceira e concilia diariamente.

## 2. Objetivos

- OBJ-01: reduzir o tempo de embarque em relação ao pagamento em dinheiro.
- OBJ-02: eliminar o manuseio de dinheiro pelo motorista.
- OBJ-03: permitir que o passageiro consulte as viagens pagas pelo app.

## 3. Funcionalidades

| Código | Funcionalidade | Prioridade |
|---|---|---|
| F-01 | Tap do cartão EMV no validador e liberação da catraca | Must |
| F-02 | Autorização agregada das viagens junto à adquirente | Must |
| F-03 | Consulta de viagens pagas pelo passageiro no app | Should |
| F-04 | Lista de restrição (deny list) de cartões com cobrança recusada | Must |
| F-05 | Conciliação diária com a adquirente | Must |

## 4. Regras de Negócio

- RN-01: a tarifa é fixa de R$ 4,40 por embarque.
- RN-02: o validador precisa liberar o embarque mesmo sem conectividade, por até 30 minutos, consultando a deny list local.
- RN-03: os taps de um mesmo cartão no mesmo dia são agregados em uma única cobrança, enviada à adquirente até as 23h59.
- RN-04: cartão com cobrança recusada entra na deny list até a dívida ser quitada.

## 5. Fora de Escopo

- Integração com o bilhete estudantil.
- Integração tarifária entre linhas.
- Pagamento via QR Code.
