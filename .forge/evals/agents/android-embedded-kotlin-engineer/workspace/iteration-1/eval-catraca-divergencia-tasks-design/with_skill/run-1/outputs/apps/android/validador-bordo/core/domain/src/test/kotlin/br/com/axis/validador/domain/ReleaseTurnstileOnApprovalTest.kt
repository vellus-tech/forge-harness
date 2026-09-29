package br.com.axis.validador.domain

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

private class FakeTurnstilePort(private val outcome: TurnstileReleaseOutcome) : TurnstilePort {
    var lastRequest: TurnstileReleaseRequest? = null

    override suspend fun releaseSingleTurn(request: TurnstileReleaseRequest): TurnstileReleaseOutcome {
        lastRequest = request
        return outcome
    }
}

class ReleaseTurnstileOnApprovalTest {

    @Test
    fun `libera um giro quando a validacao e aprovada`() = runTest {
        val port = FakeTurnstilePort(TurnstileReleaseOutcome.Released(eventId = "evt-1"))
        val useCase = ReleaseTurnstileOnApproval(port)

        val outcome = useCase.handle(ValidationDecision.Approved(eventId = "evt-1", cardUid = "card-1"))

        assertEquals(TurnstileReleaseOutcome.Released(eventId = "evt-1"), outcome)
        assertEquals("evt-1", port.lastRequest?.eventId)
    }

    @Test
    fun `reporta giro nao consumado quando o passageiro nao passa a tempo`() = runTest {
        val outcome = TurnstileReleaseOutcome.NotConfirmed(
            eventId = "evt-2",
            reason = TurnstileNotConfirmedReason.EXPIRED,
        )
        val useCase = ReleaseTurnstileOnApproval(FakeTurnstilePort(outcome))

        val result = useCase.handle(ValidationDecision.Approved(eventId = "evt-2", cardUid = "card-2"))

        assertEquals(outcome, result)
    }

    @Test
    fun `reporta dispositivo indisponivel quando a catraca nao responde`() = runTest {
        val outcome = TurnstileReleaseOutcome.DeviceUnavailable(eventId = "evt-3", cause = "timeout_sem_resposta")
        val useCase = ReleaseTurnstileOnApproval(FakeTurnstilePort(outcome))

        val result = useCase.handle(ValidationDecision.Approved(eventId = "evt-3", cardUid = "card-3"))

        assertEquals(outcome, result)
    }

    @Test
    fun `nunca aciona a catraca quando a validacao e rejeitada`() = runTest {
        val port = FakeTurnstilePort(TurnstileReleaseOutcome.Released(eventId = "evt-4"))
        val useCase = ReleaseTurnstileOnApproval(port)

        val result = useCase.handle(ValidationDecision.Rejected(RejectionReason.HOTLISTED))

        assertNull(result)
        assertNull(port.lastRequest)
    }
}
