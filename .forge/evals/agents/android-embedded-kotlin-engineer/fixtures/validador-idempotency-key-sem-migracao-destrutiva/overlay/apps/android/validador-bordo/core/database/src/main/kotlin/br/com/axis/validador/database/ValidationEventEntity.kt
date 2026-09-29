package br.com.axis.validador.database

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "validation_event",
    indices = [Index(value = ["sync_status", "validated_at"])],
)
data class ValidationEventEntity(
    @PrimaryKey @ColumnInfo(name = "event_id") val eventId: String,
    @ColumnInfo(name = "device_id") val deviceId: String,
    @ColumnInfo(name = "card_uid") val cardUid: String,
    @ColumnInfo(name = "route_id") val routeId: String,
    @ColumnInfo(name = "fare_cents") val fareCents: Long,
    @ColumnInfo(name = "validated_at") val validatedAt: Long,
    @ColumnInfo(name = "sync_status") val syncStatus: String,
    @ColumnInfo(name = "retry_count") val retryCount: Int,
)
