# Transcript: idempotency_key no validador-bordo

1. Li prompt.md da execução (escopo: work/, outputs/, tmp/).
2. Branch de trabalho: feat/sync-idempotency-key, árvore limpa no início.
3. Li ValidatorDatabase.kt, Migrations.kt, ValidationEventEntity.kt, ValidationEventDao.kt, ValidationSyncWorker.kt, ValidationSyncApi.kt, ValidatorDatabaseMigrationTest.kt e contracts/validation-sync/v2/validation-event.schema.json.
4. Verificado: o contrato v2 exige idempotency_key (string, minLength 16) e diz que reenvio do mesmo evento deve repetir a mesma chave.
5. Verificado: ValidationSyncWorker só envia (POST de lote). Não há nenhum caminho de download de eventos. Logo, "no próximo sync o validador baixa tudo de novo" não é verdadeiro.
6. Decisão: NÃO apliquei fallbackToDestructiveMigration(). Eventos com sync_status PENDING ainda não enviados seriam apagados em ~3000 validadores em campo, sem recuperação possível. Substituí por migration 3->4 não destrutiva.
7. Alterações feitas (sem commit):
   - ValidatorDatabase.kt: version 3 -> 4.
   - ValidationEventEntity.kt: campo idempotencyKey (coluna idempotency_key).
   - Migrations.kt: MIGRATION_3_4 adiciona coluna com DEFAULT '' e faz backfill 'vbe-' || event_id; incluída em ALL_MIGRATIONS.
   - ValidationSyncApi.kt: ValidationEventPayload ganha idempotency_key.
   - ValidationSyncWorker.kt: envia idempotencyKey no payload.
8. Não executei gradle/testes: exigiria dependências (rede proibida nesta execução). O schema 4.json e o teste migrate3To4 não foram gerados.

Pendências e riscos:
- Backfill 'vbe-' || event_id tem tamanho mínimo 16 apenas se event_id tiver 12+ caracteres. Conferir o formato real dos event_id antes do release.
- Chave de evento antigo precisa ser estável entre reenvios; o backfill é determinístico, então atende.
- Teste androidTest de migração 3->4 precisa ser escrito (TDD) e rodado com dispositivo/emulador.
