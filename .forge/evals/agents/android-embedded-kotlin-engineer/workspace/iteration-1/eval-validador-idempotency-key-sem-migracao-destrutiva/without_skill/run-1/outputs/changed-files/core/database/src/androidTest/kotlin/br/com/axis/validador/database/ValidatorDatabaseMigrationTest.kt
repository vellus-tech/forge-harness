package br.com.axis.validador.database

import androidx.room.testing.MigrationTestHelper
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class ValidatorDatabaseMigrationTest {
    @get:Rule
    val helper = MigrationTestHelper(
        InstrumentationRegistry.getInstrumentation(),
        ValidatorDatabase::class.java,
    )

    @Test
    fun migrate2To3_keepsPendingEvents() {
        helper.createDatabase("migration-test", 2).apply {
            execSQL("INSERT INTO validation_event (event_id, device_id, card_uid, route_id, fare_cents, validated_at, sync_status) VALUES ('e1', 'd1', 'c1', '8012', 480, 1700000000000, 'PENDING')")
            close()
        }
        val db = helper.runMigrationsAndValidate("migration-test", 3, true, MIGRATION_2_3)
        db.query("SELECT retry_count FROM validation_event WHERE event_id = 'e1'").use {
            it.moveToFirst()
            assertEquals(0, it.getInt(0))
        }
    }

    @Test
    fun migrate3To4_backfillsIdempotencyKeyWithoutDroppingData() {
        helper.createDatabase("migration-test-3-4", 3).apply {
            execSQL("INSERT INTO validation_event (event_id, device_id, card_uid, route_id, fare_cents, validated_at, sync_status, retry_count) VALUES ('e1', 'd1', 'c1', '8012', 480, 1700000000000, 'PENDING', 0)")
            execSQL("INSERT INTO validation_event (event_id, device_id, card_uid, route_id, fare_cents, validated_at, sync_status, retry_count) VALUES ('e2', 'd1', 'c2', '8012', 480, 1700000001000, 'SYNCED', 0)")
            close()
        }
        val db = helper.runMigrationsAndValidate("migration-test-3-4", 4, true, MIGRATION_3_4)

        // Nenhum evento perdido na migração (nem os já sincronizados, nem os pendentes).
        db.query("SELECT COUNT(*) FROM validation_event").use {
            it.moveToFirst()
            assertEquals(2, it.getInt(0))
        }

        // Toda linha recebe uma idempotency_key não vazia e com pelo menos 16 caracteres,
        // como o contrato validation-sync/v2 exige.
        db.query("SELECT idempotency_key FROM validation_event ORDER BY event_id").use { cursor ->
            val keys = mutableListOf<String>()
            while (cursor.moveToNext()) {
                keys += cursor.getString(0)
            }
            assertEquals(2, keys.size)
            keys.forEach { key -> assertTrue(key.length >= 16) }
            // Chaves distintas por evento (backfill não gera colisão entre linhas diferentes).
            assertEquals(keys.toSet().size, keys.size)
        }
    }
}
