# pos-recarga

App Android embarcado de recarga de cartão de transporte no POS Sunmi P2 (Android 7.1, SDK 25). Pagamento por cartão via gateway da adquirente; leitura do cartão de transporte por NFC.

## Dispositivos homologados

- Sunmi P2 (Android 7.1.2) — SDK NFC `com.sunmi:nfclibrary` 2.3.1.

## Periféricos

- NFC: `hardware/nfc` (`SunmiNfcReaderAdapter`).
- Impressora térmica: `hardware/printer` (`SunmiPrinterAdapter`) — imprime o comprovante após a recarga ser aprovada.

## Como testar

`./gradlew :core:domain:test`
