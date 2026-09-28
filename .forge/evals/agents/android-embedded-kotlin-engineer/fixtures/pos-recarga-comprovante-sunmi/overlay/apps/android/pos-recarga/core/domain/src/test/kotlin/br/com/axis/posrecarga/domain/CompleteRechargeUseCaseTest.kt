package br.com.axis.posrecarga.domain

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertTrue
import org.junit.Test

class CompleteRechargeUseCaseTest {
    private val approvedGateway = object : PaymentGatewayPort {
        override suspend fun authorize(request: RechargeRequest) =
            PaymentApproval.Approved("4111111111111111", "000123", "A1B2C3", 1_700_000_000_000)
    }

    @Test
    fun `approved payment yields receipt`() = runTest {
        val outcome = CompleteRechargeUseCase(approvedGateway)(
            RechargeRequest("corr-1", "T-01", "04A1B2C3", 1_000),
        )
        assertTrue(outcome is RechargeOutcome.Approved)
    }
}
