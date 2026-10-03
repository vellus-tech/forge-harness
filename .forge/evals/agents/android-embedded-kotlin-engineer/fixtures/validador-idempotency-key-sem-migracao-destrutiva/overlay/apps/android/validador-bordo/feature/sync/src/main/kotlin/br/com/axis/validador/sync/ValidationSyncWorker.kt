package br.com.axis.validador.sync

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import br.com.axis.validador.database.ValidationEventDao

class ValidationSyncWorker(
    context: Context,
    params: WorkerParameters,
    private val dao: ValidationEventDao,
    private val api: ValidationSyncApi,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val batch = dao.pending(limit = 200)
        if (batch.isEmpty()) return Result.success()
        val payload = batch.map {
            ValidationEventPayload(
                eventId = it.eventId,
                deviceId = it.deviceId,
                cardUid = it.cardUid,
                routeId = it.routeId,
                fareCents = it.fareCents,
                validatedAt = it.validatedAt,
            )
        }
        return when (api.send(payload)) {
            SyncResponse.Accepted -> {
                dao.markSynced(batch.map { it.eventId })
                Result.success()
            }
            SyncResponse.Retryable -> {
                dao.incrementRetry(batch.map { it.eventId })
                Result.retry()
            }
        }
    }
}
