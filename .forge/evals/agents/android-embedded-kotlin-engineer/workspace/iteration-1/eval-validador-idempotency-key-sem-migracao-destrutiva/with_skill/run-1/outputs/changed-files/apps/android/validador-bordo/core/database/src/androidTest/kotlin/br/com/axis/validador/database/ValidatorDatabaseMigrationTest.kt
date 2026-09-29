package br.com.axis.validador.database

import androidx.room.testing.MigrationTestHelper
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
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
    fun migrate3To4_backfillsIdempotencyKeyFromEventIdAndKeepsPendingEvents() {
        helper.createDatabase("migration-test", 3).apply {
            execSQL(
                "INSERT INTO validation_event (event_id, device_id, card_uid, route_id, fare_cents, validated_at, sync_status, retry_count) " +
                    "VALUES ('e1', 'd1', 'c1', '8012', 480, 1700000000000, 'PENDING', 0)",
            )
            close()
        }
        val db = helper.runMigrationsAndValidate("migration-test", 4, true, MIGRATION_3_4)
        db.query("SELECT idempotency_key, sync_status FROM validation_event WHERE event_id = 'e1'").use {
            it.moveToFirst()
            // REQ-SYNC-07: evento pré-existente ganha chave estável (event_id) em vez de perder a fila
            // local, que é o efeito de fallbackToDestructiveMigration() — proibido por REQ-SYNC-03.
            assertEquals("e1", it.getString(0))
            assertEquals("PENDING", it.getString(1))
        }
    }
}
