package br.com.axis.validador.database

import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

val MIGRATION_1_2 = object : Migration(1, 2) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE validation_event ADD COLUMN route_id TEXT NOT NULL DEFAULT ''")
    }
}

val MIGRATION_2_3 = object : Migration(2, 3) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE validation_event ADD COLUMN retry_count INTEGER NOT NULL DEFAULT 0")
        db.execSQL("CREATE INDEX IF NOT EXISTS index_validation_event_sync_status_validated_at ON validation_event (sync_status, validated_at)")
    }
}

val MIGRATION_3_4 = object : Migration(3, 4) {
    override fun migrate(db: SupportSQLiteDatabase) {
        // Contrato validation-sync/v2 exige idempotency_key em todo evento enviado (REQ-SYNC-07).
        // Backfill com event_id: já é estável e único por evento, então eventos PENDING antigos
        // (potencialmente dias de validação em campo, REQ-SYNC-03) mantêm uma chave estável no
        // primeiro reenvio pós-atualização, sem gerar valor novo a cada tentativa nem exigir
        // fallbackToDestructiveMigration — que apagaria a fila local de ~3 mil validadores em campo.
        db.execSQL("ALTER TABLE validation_event ADD COLUMN idempotency_key TEXT NOT NULL DEFAULT ''")
        db.execSQL("UPDATE validation_event SET idempotency_key = event_id WHERE idempotency_key = ''")
    }
}

val ALL_MIGRATIONS = arrayOf(MIGRATION_1_2, MIGRATION_2_3, MIGRATION_3_4)
