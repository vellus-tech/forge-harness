# Context Map

## 1. Visão Geral
A Tarifa Viva é composta por três Core Domains (Fare & Boarding, Wallet & Recharge, Settlement & Clearing), um Supporting Subdomain (Card & Identity) e um Generic Subdomain (Notification). A integração entre eles é feita por evento de domínio e por read models/projeções — nenhum contexto escreve diretamente no banco de outro, e não há um banco único compartilhado (ver `docs/product/data-model/data-model.md` para a justificativa desta decisão frente ao pedido original de `core_db` único).

## 2. Artefatos
- [Relações](./relations.md)
- [Padrões](./patterns.md)
- [Diagrama](./diagram.md)

## 3. Pontos a Validar
- SLA de propagação de bloqueio de cartão até o validador (não definido no FRD).
- Regra de decisão de estorno de recarga (FR-11 pendente).
