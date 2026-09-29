# validador-bordo

Validador embarcado de bilhetagem (Android 8.1, SDK 26). Valida cartão/QR, exibe o resultado e,
quando aprovado, libera um giro da catraca (módulo `catraca`).

## Dispositivos homologados

- Telpo TPS508 (Android 8.1) — frota das linhas 8000–8099.
- Catraca Gertec TC-400 (RS-232 via conversor USB) — linha 8012, onde o TPS508 não tem o chicote
  de GPIO instalado (DD-002, `docs/product/modules/catraca/design.md`).

## Módulos

- `core/domain`: regras de negócio, independentes de Android/SDK de fabricante.
- `hardware/serial`: link serial USB-RS232 genérico (`SerialLink`/`UsbSerialLink`).
- `hardware/catraca`: adapter `GertecTc400TurnstileAdapter` para a Gertec TC-400 (linha 8012).

## Como testar

`./gradlew :core:domain:test :hardware:catraca:test`
