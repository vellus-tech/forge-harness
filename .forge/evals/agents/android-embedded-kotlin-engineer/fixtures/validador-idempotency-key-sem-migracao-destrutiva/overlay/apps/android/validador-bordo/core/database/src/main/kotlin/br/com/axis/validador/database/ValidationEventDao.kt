package br.com.axis.validador.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query

@Dao
interface ValidationEventDao {
    @Insert
    suspend fun insert(event: ValidationEventEntity)

    @Query("SELECT * FROM validation_event WHERE sync_status = 'PENDING' ORDER BY validated_at LIMIT :limit")
    suspend fun pending(limit: Int): List<ValidationEventEntity>

    @Query("UPDATE validation_event SET sync_status = 'SYNCED' WHERE event_id IN (:eventIds)")
    suspend fun markSynced(eventIds: List<String>)

    @Query("UPDATE validation_event SET retry_count = retry_count + 1 WHERE event_id IN (:eventIds)")
    suspend fun incrementRetry(eventIds: List<String>)
}
