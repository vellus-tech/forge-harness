package br.com.axis.posrecarga.domain

class CompleteRechargeUseCase(
    private val paymentGateway: PaymentGatewayPort,
    private val receiptPrinter: ReceiptPrinterPort,
) {
    suspend operator fun invoke(request: RechargeRequest): RechargeOutcome {
        val approval = paymentGateway.authorize(request)
        if (approval !is PaymentApproval.Approved) {
            return RechargeOutcome.Declined(approval)
        }
        val receipt = RechargeReceipt(
            correlationId = request.correlationId,
            terminalId = request.terminalId,
            transportCardUid = request.transportCardUid,
            paymentCardPan = approval.pan,
            amountCents = request.amountCents,
            nsu = approval.nsu,
            authorizationCode = approval.authorizationCode,
            approvedAtEpochMillis = approval.approvedAtEpochMillis,
        )
        // A recarga já foi aprovada pelo gateway; uma falha de impressão é reportada,
        // mas nunca reverte a aprovação (o comprovante pode ser reimprimido depois).
        val printResult = receiptPrinter.print(receipt)
        return RechargeOutcome.Approved(receipt, printResult)
    }
}

data class RechargeRequest(
    val correlationId: String,
    val terminalId: String,
    val transportCardUid: String,
    val amountCents: Long,
)

interface PaymentGatewayPort {
    suspend fun authorize(request: RechargeRequest): PaymentApproval
}

sealed interface PaymentApproval {
    data class Approved(
        val pan: String,
        val nsu: String,
        val authorizationCode: String,
        val approvedAtEpochMillis: Long,
    ) : PaymentApproval
    data class Denied(val reason: String) : PaymentApproval
}

sealed interface RechargeOutcome {
    data class Approved(val receipt: RechargeReceipt, val printResult: PrintResult) : RechargeOutcome
    data class Declined(val approval: PaymentApproval) : RechargeOutcome
}
