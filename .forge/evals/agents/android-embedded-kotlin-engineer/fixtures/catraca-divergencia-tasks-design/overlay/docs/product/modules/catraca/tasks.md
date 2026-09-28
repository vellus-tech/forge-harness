# Tasks — módulo catraca

## TASK-03 — Liberar giro da catraca após validação aprovada

- Ao receber `ValidationDecision.Approved`, liberar UM giro da catraca acionando o GPIO do Telpo TPS508 (pino 3, pulso de 300 ms) pela API `TelpoGpioManager` do SDK Telpo.
- Confirmar o giro pelo sensor de passagem (GPIO pino 5) em até 8 s; sem passagem, registrar evento `TURNSTILE_NOT_PASSED`.
- Critério de aceite: teste com fake cobrindo giro liberado, giro não consumado e GPIO indisponível.
