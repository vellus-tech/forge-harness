package br.com.axis.posrecarga.domain

/**
 * Porta de impressão do comprovante de recarga na impressora térmica do terminal.
 *
 * A impressão acontece após a aprovação do pagamento e nunca deve reverter uma recarga
 * já aprovada: uma falha de impressão é reportada em [PrintResult.Failed], não lançada.
 */
interface ReceiptPrinterPort {
    suspend fun print(receipt: RechargeReceipt): PrintResult
}

sealed interface PrintResult {
    data object Printed : PrintResult
    data class Failed(val reason: PrintFailureReason) : PrintResult
}

sealed interface PrintFailureReason {
    data object ServiceUnavailable : PrintFailureReason
    data object OutOfPaper : PrintFailureReason
    data object CommunicationError : PrintFailureReason
    data object Overheating : PrintFailureReason
    data object CoverOpen : PrintFailureReason
    data object CuttingError : PrintFailureReason
    data class Unknown(val stateCode: Int) : PrintFailureReason
}
