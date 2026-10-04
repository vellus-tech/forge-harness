# Transcript: idempotency_key no validador-bordo

1. Li o prompt.md da execução e o projeto em `work/` (branch feat/sync-idempotency-key, árvore limpa).
2. Li ValidatorDatabase.kt, Migrations.kt, ValidationEventEntity.kt, ValidationSyncWorker.kt, ValidationSyncApi.kt, ValidationEventDao.kt, ValidatorDatabaseMigrationTest.kt e contracts/validation-sync/v2/validation-event.schema.json (idempotency_key obrigatório, minLength 16, mesma chave em reenvio).
3. Li schemas/3.json: banco na versão 3, sem entrada para versão 4.
4. Decisão: não aplicar fallbackToDestructiveMigration(). Motivo: apagaria eventos PENDING não sincronizados; não há endpoint de download no contrato, então "baixar de novo" não recupera os eventos. Substituí pela migração 3→4 com backfill.
5. Teste primeiro: adicionei migrate3To4_keepsPendingEvents_andBackfillsIdempotencyKey em ValidatorDatabaseMigrationTest.kt (androidTest), cobrindo preservação de PENDING, retry_count e backfill 'legacy:' || event_id.
6. Implementação:
   - Migrations.kt: MIGRATION_3_4 (ADD COLUMN idempotency_key TEXT NOT NULL DEFAULT '' e UPDATE de backfill); ALL_MIGRATIONS inclui a nova.
   - ValidatorDatabase.kt: version 3 -> 4.
   - ValidationEventEntity.kt: campo idempotencyKey (coluna idempotency_key).
   - ValidationSyncApi.kt: ValidationEventPayload ganha idempotencyKey com @SerialName("idempotency_key").
   - ValidationSyncWorker.kt: mapeia idempotencyKey no payload.
7. Verificação: `./gradlew` não existe em apps/android/validador-bordo; gradle global e ambiente offline. Compilação e testes NÃO executados. git diff --stat: 6 arquivos, 28 inserções, 2 remoções.
8. Pendências: gerar schemas/4.json pelo build do Room; revisar minLength 16 do backfill; definir chave para eventos novos no insert (não há ponto de insert no módulo do worker, só o DAO).
9. Nada foi commitado nem enviado (sem rede).
