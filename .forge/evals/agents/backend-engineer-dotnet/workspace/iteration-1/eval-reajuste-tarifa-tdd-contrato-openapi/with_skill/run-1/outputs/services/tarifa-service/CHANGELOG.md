# Changelog — tarifa-service

## [Unreleased]

## [0.2.0] - 2026-09-26

### Adicionado

- Reajuste de tarifa por percentual (`POST /v1/tarifas/{linhaId}/reajustes`), com percentual em
  pontos-base (1 a 5000 bp) e arredondamento half-even (bancário) sobre centavos — REQ-004,
  DD-001, DD-002. Responde `404` para linha inexistente e `422` (`ProblemDetails`) para percentual
  fora do intervalo.

## [0.1.0] - 2026-09-01

### Adicionado

- Consulta da tarifa vigente por linha (`GET /v1/tarifas/{linhaId}`).
