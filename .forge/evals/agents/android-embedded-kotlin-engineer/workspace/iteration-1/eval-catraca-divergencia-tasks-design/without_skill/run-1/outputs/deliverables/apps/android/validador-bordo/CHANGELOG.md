# Changelog

## [Não publicado]

### Adicionado

- TASK-03: liberação de giro da catraca após validação aprovada (`hardware/serial`), via
  protocolo serial da Gertec TC-400 (linha 8012) — `SerialTurnstileGate` consumindo
  `UsbSerialLink`, conforme DD-002 (docs/product/modules/catraca/design.md). A TASK-03 em
  docs/product/modules/catraca/tasks.md descreve GPIO do Telpo TPS508, divergente do design
  aprovado; foi seguido o design, mais recente e específico para a linha 8012 (ver README e
  transcript do PR).

## [2.3.0] - 2026-08-12

### Adicionado

- Link serial USB genérico (`hardware/serial`), ainda sem consumidor.
