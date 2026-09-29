package br.com.axis.validador.domain

/**
 * Porta de domínio para o acionamento físico da catraca. O adapter concreto (GPIO, serial, etc.)
 * é escolhido por linha/dispositivo homologado — ver DD-002 em docs/product/modules/catraca/design.md.
 */
interface TurnstilePort {
    suspend fun releaseSingleTurn(request: TurnstileReleaseRequest): TurnstileReleaseOutcome
}

data class TurnstileReleaseRequest(val eventId: String, val confirmationTimeoutSeconds: Int = 8)

sealed interface TurnstileReleaseOutcome {
    data class Released(val eventId: String) : TurnstileReleaseOutcome
    data class NotConfirmed(val eventId: String, val reason: TurnstileNotConfirmedReason) : TurnstileReleaseOutcome
    data class DeviceUnavailable(val eventId: String, val cause: String) : TurnstileReleaseOutcome
}

enum class TurnstileNotConfirmedReason { EXPIRED, DEVICE_BUSY }
