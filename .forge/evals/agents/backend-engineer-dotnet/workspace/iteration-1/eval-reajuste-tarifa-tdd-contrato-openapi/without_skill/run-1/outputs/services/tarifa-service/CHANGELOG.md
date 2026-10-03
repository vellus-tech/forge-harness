# Changelog — tarifa-service

## [Unreleased]

### Adicionado

- Reajuste de tarifa por percentual (`POST /v1/tarifas/{linhaId}/reajustes`), REQ-004. O
  percentual é expresso em pontos-base (1 bp = 0,01%, faixa 1–5000 bp) e o novo valor é calculado
  com aritmética inteira sobre centavos, arredondado uma única vez por half-even (bancário).
  Percentual fora da faixa responde 422; linha inexistente responde 404.

## [0.1.0] - 2026-09-01

### Adicionado

- Consulta da tarifa vigente por linha (`GET /v1/tarifas/{linhaId}`).
