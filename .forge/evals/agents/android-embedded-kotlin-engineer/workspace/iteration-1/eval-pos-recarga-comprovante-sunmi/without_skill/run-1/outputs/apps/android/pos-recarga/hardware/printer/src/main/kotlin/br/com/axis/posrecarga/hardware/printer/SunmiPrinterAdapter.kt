package br.com.axis.posrecarga.hardware.printer

import android.content.Context
import br.com.axis.posrecarga.domain.PrintFailureReason
import br.com.axis.posrecarga.domain.PrintResult
import br.com.axis.posrecarga.domain.ReceiptPrinterPort
import br.com.axis.posrecarga.domain.RechargeReceipt
import com.sunmi.printer.InnerPrinterCallback
import com.sunmi.printer.InnerPrinterManager
import com.sunmi.printer.SunmiPrintCallback
import com.sunmi.printer.SunmiPrinterService
import kotlinx.coroutines.suspendCancellableCoroutine
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.coroutines.resume

/**
 * Adaptador da impressora térmica do Sunmi P2 (`com.sunmi:printerlibrary:1.0.23`).
 *
 * Toda chamada ao SDK é assíncrona via AIDL — nunca deve ser feita na main thread — por
 * isso cada etapa (bind, init, print, corte) é suspensa até o callback correspondente.
 * A largura útil da impressora é de 32 colunas em fonte padrão.
 */
class SunmiPrinterAdapter(
    private val context: Context,
) : ReceiptPrinterPort {

    private companion object {
        const val RECEIPT_WIDTH = 32
        const val STATE_NORMAL = 1
        const val STATE_PREPARING = 2
        const val STATE_COMMUNICATION_ERROR = 3
        const val STATE_OUT_OF_PAPER = 4
        const val STATE_OVERHEATING = 5
        const val STATE_COVER_OPEN = 6
        const val STATE_CUTTING_ERROR = 7
    }

    override suspend fun print(receipt: RechargeReceipt): PrintResult {
        val service = bindPrinterService() ?: return PrintResult.Failed(PrintFailureReason.ServiceUnavailable)
        return try {
            val stateFailure = failureForState(service.updatePrinterState())
            if (stateFailure != null) {
                return PrintResult.Failed(stateFailure)
            }
            initPrinter(service)
            printText(service, formatReceipt(receipt))
            lineWrap(service, 4)
            PrintResult.Printed
        } catch (error: PrinterOperationException) {
            failureForState(service.updatePrinterState()) ?: PrintResult.Failed(PrintFailureReason.CommunicationError)
        } finally {
            unbindPrinterService()
        }
    }

    private fun failureForState(state: Int): PrintResult.Failed? = when (state) {
        STATE_NORMAL, STATE_PREPARING -> null
        STATE_OUT_OF_PAPER -> PrintResult.Failed(PrintFailureReason.OutOfPaper)
        STATE_COMMUNICATION_ERROR -> PrintResult.Failed(PrintFailureReason.CommunicationError)
        STATE_OVERHEATING -> PrintResult.Failed(PrintFailureReason.Overheating)
        STATE_COVER_OPEN -> PrintResult.Failed(PrintFailureReason.CoverOpen)
        STATE_CUTTING_ERROR -> PrintResult.Failed(PrintFailureReason.CuttingError)
        else -> PrintResult.Failed(PrintFailureReason.Unknown(state))
    }

    private fun formatReceipt(receipt: RechargeReceipt): String {
        val dateFormat = SimpleDateFormat("dd/MM/yyyy HH:mm:ss", Locale("pt", "BR"))
        val maskedPan = maskPan(receipt.paymentCardPan)
        val separator = "-".repeat(RECEIPT_WIDTH)
        return buildString {
            appendLine(center("COMPROVANTE DE RECARGA"))
            appendLine(separator)
            appendLine("Terminal: ${receipt.terminalId}")
            appendLine("Data: ${dateFormat.format(Date(receipt.approvedAtEpochMillis))}")
            appendLine("Cartao transporte: ${receipt.transportCardUid}")
            appendLine("Cartao pagamento: $maskedPan")
            appendLine("Valor: ${formatCents(receipt.amountCents)}")
            appendLine("NSU: ${receipt.nsu}")
            appendLine("Autorizacao: ${receipt.authorizationCode}")
            appendLine(separator)
            appendLine("ID: ${receipt.correlationId}")
        }
    }

    private fun center(text: String): String {
        val padding = ((RECEIPT_WIDTH - text.length) / 2).coerceAtLeast(0)
        return " ".repeat(padding) + text
    }

    private fun maskPan(pan: String): String =
        if (pan.length <= 4) pan else "**** **** **** ${pan.takeLast(4)}"

    private fun formatCents(amountCents: Long): String {
        val reais = amountCents / 100
        val cents = amountCents % 100
        return "R$ %d,%02d".format(reais, cents)
    }

    private suspend fun bindPrinterService(): SunmiPrinterService? = suspendCancellableCoroutine { continuation ->
        val callback = object : InnerPrinterCallback() {
            override fun onConnected(service: SunmiPrinterService) {
                continuation.resume(service)
            }

            override fun onDisconnected() {
                if (continuation.isActive) continuation.resume(null)
            }
        }
        val bound = InnerPrinterManager.getInstance().bindService(context, callback)
        if (!bound && continuation.isActive) {
            continuation.resume(null)
        }
    }

    private fun unbindPrinterService() {
        runCatching { InnerPrinterManager.getInstance().unBindService(context) }
    }

    private suspend fun initPrinter(service: SunmiPrinterService) = suspendCancellableCoroutine<Unit> { continuation ->
        service.printerInit(resultCallback(continuation))
    }

    private suspend fun printText(service: SunmiPrinterService, text: String) = suspendCancellableCoroutine<Unit> { continuation ->
        service.printText(text, resultCallback(continuation))
    }

    private suspend fun lineWrap(service: SunmiPrinterService, lines: Int) = suspendCancellableCoroutine<Unit> { continuation ->
        service.lineWrap(lines, resultCallback(continuation))
    }

    private fun resultCallback(continuation: kotlin.coroutines.Continuation<Unit>) = object : SunmiPrintCallback() {
        override fun onRunResult(isSuccess: Boolean) {
            if (isSuccess) {
                continuation.resume(Unit)
            } else {
                continuation.resumeWith(Result.failure(PrinterOperationException()))
            }
        }

        override fun onReturnString(result: String) = Unit

        override fun onRaiseException(code: Int, msg: String) {
            continuation.resumeWith(Result.failure(PrinterOperationException(msg)))
        }
    }

    private class PrinterOperationException(message: String? = null) : Exception(message)
}
