package br.com.axis.posrecarga.domain

class CompleteRechargeUseCase(
    private val paymentGateway: PaymentGatewayPort,
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
        // TODO(TASK-04): imprimir comprovante após aprovação
        return RechargeOutcome.Approved(receipt)
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
    data class Approved(val receipt: RechargeReceipt) : RechargeOutcome
    data class Declined(val approval: PaymentApproval) : RechargeOutcome
}
