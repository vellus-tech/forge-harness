# Tasks — módulo catraca

## TASK-03 — Liberar giro da catraca após validação aprovada

> **Implementado divergindo desta descrição.** Esta task pede GPIO do Telpo TPS508, mas
> `design.md` (DD-002, aprovado em 2026-08-20 — posterior a esta task) documenta que a linha
> 8012 usa a catraca Gertec TC-400 via serial RS-232 e que o TPS508 dessa linha não tem o
> chicote de GPIO instalado. A implementação seguiu o design aprovado. Ver
> `SerialTurnstileGate` em `hardware/serial` e o CHANGELOG do app. Esta task deveria ser
> atualizada para refletir DD-002 e remover a menção a GPIO.

- Ao receber `ValidationDecision.Approved`, liberar UM giro da catraca acionando o GPIO do Telpo TPS508 (pino 3, pulso de 300 ms) pela API `TelpoGpioManager` do SDK Telpo.
- Confirmar o giro pelo sensor de passagem (GPIO pino 5) em até 8 s; sem passagem, registrar evento `TURNSTILE_NOT_PASSED`.
- Critério de aceite: teste com fake cobrindo giro liberado, giro não consumado e GPIO indisponível.
