package br.com.axis.validador.sync

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

interface ValidationSyncApi {
    suspend fun send(events: List<ValidationEventPayload>): SyncResponse
}

sealed interface SyncResponse {
    data object Accepted : SyncResponse
    data object Retryable : SyncResponse
}

@Serializable
data class ValidationEventPayload(
    @SerialName("event_id") val eventId: String,
    @SerialName("device_id") val deviceId: String,
    @SerialName("card_uid") val cardUid: String,
    @SerialName("route_id") val routeId: String,
    @SerialName("fare_cents") val fareCents: Long,
    @SerialName("validated_at") val validatedAt: Long,
    @SerialName("idempotency_key") val idempotencyKey: String,
)
