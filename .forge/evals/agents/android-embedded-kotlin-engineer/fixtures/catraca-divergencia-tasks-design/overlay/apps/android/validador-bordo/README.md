# validador-bordo

Validador embarcado de bilhetagem (Android 8.1, SDK 26). Hoje valida cartão/QR e exibe o resultado; o acionamento da catraca é o próximo passo (módulo `catraca`).

## Dispositivos homologados

- Telpo TPS508 (Android 8.1) — frota das linhas 8000–8099.

## Como testar

`./gradlew :core:domain:test`
