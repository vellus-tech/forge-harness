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
}
