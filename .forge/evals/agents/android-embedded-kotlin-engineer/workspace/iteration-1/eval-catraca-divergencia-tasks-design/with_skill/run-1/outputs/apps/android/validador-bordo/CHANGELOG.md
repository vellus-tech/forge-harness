# Changelog

## [Não publicado]

### Adicionado

- TASK-03 (módulo catraca): liberação de um giro da catraca após validação aprovada, via novo
  módulo `hardware/catraca` (`GertecTc400TurnstileAdapter`), seguindo o protocolo serial Gertec
  TC-400 homologado para a linha 8012 (DD-002). Diverge do GPIO Telpo TPS508 descrito em
  `docs/product/modules/catraca/tasks.md` — ver `TurnstileNotConfirmedReason`/`README.md` e a nota
  de divergência no design.md; recomenda-se atualizar TASK-03 para refletir o hardware real.
- `SerialLink`: interface extraída de `UsbSerialLink` (`hardware/serial`) para permitir teste de
  adapters de protocolo com fake, sem dependência do USB real.

## [2.3.0] - 2026-08-12

### Adicionado

- Link serial USB genérico (`hardware/serial`), ainda sem consumidor.
