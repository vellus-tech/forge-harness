# Tasks — módulo cashback

- [X] TASK-06 — Regra de cashback de 2% (REQ-010).
- [ ] TASK-07 — Consumir `ViagemValidada` (exchange `bilhetagem.viagens`, publicado pela validadora) e creditar o cashback na carteira do passageiro (REQ-011).
  - Payload do evento: `eventoId` (uuid, único por viagem), `passageiroId` (uuid), `tarifaCentavos` (int64), `validadaEm` (date-time), `correlationId` (string).
  - Critério: a mesma viagem nunca gera dois créditos.
