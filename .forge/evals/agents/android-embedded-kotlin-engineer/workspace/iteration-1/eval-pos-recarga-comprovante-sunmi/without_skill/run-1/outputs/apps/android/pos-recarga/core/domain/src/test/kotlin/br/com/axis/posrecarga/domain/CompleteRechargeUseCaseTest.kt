package br.com.axis.posrecarga.domain

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CompleteRechargeUseCaseTest {
    private val approvedGateway = object : PaymentGatewayPort {
        override suspend fun authorize(request: RechargeRequest) =
            PaymentApproval.Approved("4111111111111111", "000123", "A1B2C3", 1_700_000_000_000)
    }

    private val deniedGateway = object : PaymentGatewayPort {
        override suspend fun authorize(request: RechargeRequest) =
            PaymentApproval.Denied("cartao_invalido")
    }

    private val succeedingPrinter = object : ReceiptPrinterPort {
        override suspend fun print(receipt: RechargeReceipt) = PrintResult.Printed
    }

    private val failingPrinter = object : ReceiptPrinterPort {
        override suspend fun print(receipt: RechargeReceipt) =
            PrintResult.Failed(PrintFailureReason.OutOfPaper)
    }

    @Test
    fun `approved payment yields receipt and prints it`() = runTest {
        val outcome = CompleteRechargeUseCase(approvedGateway, succeedingPrinter)(
            RechargeRequest("corr-1", "T-01", "04A1B2C3", 1_000),
        )
        assertTrue(outcome is RechargeOutcome.Approved)
        assertEquals(PrintResult.Printed, (outcome as RechargeOutcome.Approved).printResult)
    }

    @Test
    fun `print failure does not revert an approved recharge`() = runTest {
        val outcome = CompleteRechargeUseCase(approvedGateway, failingPrinter)(
            RechargeRequest("corr-2", "T-01", "04A1B2C3", 1_000),
        )
        assertTrue(outcome is RechargeOutcome.Approved)
        assertEquals(
            PrintResult.Failed(PrintFailureReason.OutOfPaper),
            (outcome as RechargeOutcome.Approved).printResult,
        )
    }

    @Test
    fun `declined payment never calls the printer`() = runTest {
        var printCalled = false
        val trackingPrinter = object : ReceiptPrinterPort {
            override suspend fun print(receipt: RechargeReceipt): PrintResult {
                printCalled = true
                return PrintResult.Printed
            }
        }
        val outcome = CompleteRechargeUseCase(deniedGateway, trackingPrinter)(
            RechargeRequest("corr-3", "T-01", "04A1B2C3", 1_000),
        )
        assertTrue(outcome is RechargeOutcome.Declined)
        assertFalse(printCalled)
    }
}
