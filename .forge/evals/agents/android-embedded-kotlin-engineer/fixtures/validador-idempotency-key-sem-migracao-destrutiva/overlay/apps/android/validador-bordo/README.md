# validador-bordo

Validador embarcado de bilhetagem (Android 8.1, SDK 26), operação offline-first: cada validação vira um `validation_event` local (Room, `validator.db`) e é sincronizada em lote pelo `ValidationSyncWorker` (WorkManager) quando há conectividade.

## Armazenamento local

- Banco `validator.db`, schema versão 3, schemas exportados em `core/database/schemas/`.
- Eventos `PENDING` só saem da base depois de `SYNCED`; um validador pode acumular dias de validações sem sinal.

## Como testar

`./gradlew :core:database:connectedAndroidTest` (migrations, exige device ou emulador).
