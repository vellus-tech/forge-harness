package br.com.axis.posrecarga.domain

data class RechargeReceipt(
    val correlationId: String,
    val terminalId: String,
    val transportCardUid: String,
    val paymentCardPan: String,
    val amountCents: Long,
    val nsu: String,
    val authorizationCode: String,
    val approvedAtEpochMillis: Long,
)
