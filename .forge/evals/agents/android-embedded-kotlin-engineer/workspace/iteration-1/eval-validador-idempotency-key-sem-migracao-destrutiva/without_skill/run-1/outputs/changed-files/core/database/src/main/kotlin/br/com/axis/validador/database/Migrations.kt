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

// Contrato validation-sync/v2 passa a exigir idempotency_key (minLength 16) em toda validação.
// Migração não-destrutiva: adiciona a coluna com default vazio e faz backfill de uma chave
// estável por linha para os eventos já persistidos no dispositivo (pendentes ou já sincronizados)
// antes de reabrir o banco para uso normal, sem apagar nenhum dado de validação em campo.
val MIGRATION_3_4 = object : Migration(3, 4) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE validation_event ADD COLUMN idempotency_key TEXT NOT NULL DEFAULT ''")
        // randomblob(16) -> 16 bytes aleatórios -> hex(...) -> 32 chars hexadecimais, satisfaz o
        // minLength 16 do contrato. Gerada uma única vez por linha nesta migração, portanto
        // reenvios do mesmo evento pelo worker repetem a mesma chave, como o contrato exige.
        db.execSQL(
            "UPDATE validation_event SET idempotency_key = lower(hex(randomblob(16))) " +
                "WHERE idempotency_key = ''",
        )
    }
}

val ALL_MIGRATIONS = arrayOf(MIGRATION_1_2, MIGRATION_2_3, MIGRATION_3_4)
