# Context Map

## 1. Visão Geral
A Tarifa Viva tem seis bounded contexts. Três núcleos financeiros/operacionais (Fare Collection, Passenger Wallet, Settlement) formam o fluxo principal de receita: o embarque gera evento que alimenta tanto a conciliação de saldo quanto a apuração de repasse. Recharge alimenta o Wallet de forma assíncrona a partir de dois canais externos (adquirente e ponto de venda). Identity and Access e Notification são contextos genéricos e finos, consumidos ou consumindo eventos dos núcleos financeiros sem neles interferir.

A fronteira mais sensível do mapa é a de Fare Collection com o firmware ValidaBus (Anti-Corruption Layer obrigatória, TEC-03) e a relação Fare Collection ↔ Passenger Wallet, que carrega a tensão entre decisão local (offline) e saldo autoritativo (ver VAL-01).

## 2. Artefatos
- [Relações](./relations.md)
- [Padrões](./patterns.md)
- [Diagrama](./diagram.md)

## 3. Pontos a Validar
- VAL-01 — janela de saldo transitório negativo entre embarque offline e reconciliação
- VAL-03 — existência real da integração com PSP de Pix
