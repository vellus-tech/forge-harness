# Tasks — módulo tarifa

- [X] TASK-01 — Consulta de tarifa por linha (REQ-001).
- [X] TASK-02 — Health check (REQ-002).
- [ ] TASK-03 — Reajuste de tarifa por percentual (REQ-004, DD-001, DD-002).
  - Red: teste unitário de `TarifaLinha` cobrindo os exemplos abaixo, escrito e falhando antes da implementação.
  - Exemplo 1: 430 centavos com 1250 bp → 483,75 → 484 centavos.
  - Exemplo 2 (empate, half-even): 420 centavos com 1250 bp → 472,50 → 472 centavos.
  - Exemplo 3: 5001 bp é rejeitado.
  - Green: `TarifaLinha.Reajustar(int percentualBp)` + handler na Application + endpoint na Api.
  - Contrato: `contracts/openapi/tarifa-service.yaml` atualizado com o endpoint novo.
  - Docs: CHANGELOG do serviço.
