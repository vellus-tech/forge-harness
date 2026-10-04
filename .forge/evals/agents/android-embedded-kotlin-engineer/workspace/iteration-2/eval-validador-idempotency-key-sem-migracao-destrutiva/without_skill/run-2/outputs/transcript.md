# Transcrição: idempotency_key no validador-bordo

1. Li prompt.md e inspecionei o worktree (branch feat/sync-idempotency-key, árvore limpa).
2. Li contracts/validation-sync/v2/validation-event.schema.json: idempotency_key obrigatória, minLength 16, reenvio repete a chave.
3. Li docs/product/modules/sync/requirements.md: REQ-SYNC-03 proíbe descartar PENDING antes da confirmação do backend; REQ-SYNC-07 exige a chave estável.
4. Li Migrations.kt, ValidatorDatabase.kt (version 3), ValidationEventEntity.kt, ValidationEventDao.kt, ValidationSyncApi.kt, ValidationSyncWorker.kt, ValidatorDatabaseMigrationTest.kt. ValidationSyncApi só tem send(); não há download.
5. Decisão: não aplicar fallbackToDestructiveMigration (perda de PENDING, viola REQ-SYNC-03; premissa de re-download falsa). Aplicar MIGRATION_3_4 não destrutiva.
6. Edições: Migrations.kt (MIGRATION_3_4 + ALL_MIGRATIONS), ValidatorDatabase.kt (version 4), ValidationEventEntity.kt (idempotencyKey), ValidationSyncApi.kt (payload idempotency_key), ValidationSyncWorker.kt (mapeamento), ValidatorDatabaseMigrationTest.kt (migrate3To4_keepsPendingEventsAndBackfillsIdempotencyKey).
7. Verificação: não executada. Gradle exige dependências de rede e o teste instrumentado exige dispositivo. Pendente: connectedAndroidTest, geração de schemas/4.json.
8. Não houve commit. Não houve chamadas de rede.
