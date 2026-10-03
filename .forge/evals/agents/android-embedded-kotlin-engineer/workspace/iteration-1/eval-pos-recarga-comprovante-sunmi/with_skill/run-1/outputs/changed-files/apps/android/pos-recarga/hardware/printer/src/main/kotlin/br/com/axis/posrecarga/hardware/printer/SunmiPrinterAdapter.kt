package br.com.axis.posrecarga.hardware.printer

import android.content.Context
import br.com.axis.posrecarga.domain.PrinterPort
import br.com.axis.posrecarga.domain.PrinterStatus
import br.com.axis.posrecarga.domain.PrintResult
import com.sunmi.peripheral.printer.InnerPrinterCallback
import com.sunmi.peripheral.printer.InnerPrinterManager
import com.sunmi.peripheral.printer.InnerResultCallback
import com.sunmi.peripheral.printer.SunmiPrinterService
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * Adapter Sunmi P2 para [PrinterPort] — isola o SDK do fabricante
 * (`com.sunmi:printerlibrary:1.0.23`, ver `docs/vendor/sunmi-printer-sdk.md`) do domínio.
 *
 * Todas as chamadas do [SunmiPrinterService] são assíncronas via AIDL; este adapter nunca deve
 * ser chamado na main thread (a documentação do fabricante exige isso explicitamente).
 */
class SunmiPrinterAdapter(
    private val service: SunmiPrinterService,
) : PrinterPort {

    override suspend fun status(): PrinterStatus = service.updatePrinterState().toPrinterStatus()

    override suspend fun print(lines: List<String>): PrintResult {
        val currentStatus = status()
        if (currentStatus !is PrinterStatus.Ready) {
            return PrintResult.Unavailable(currentStatus)
        }

        val outcome = runCatching {
            runAidlCall { service.printerInit(it) }
            lines.forEach { line -> runAidlCall { callback -> service.printText("$line\n", callback) } }
            runAidlCall { service.lineWrap(LINE_FEED_COUNT, it) }
        }

        return outcome.fold(
            onSuccess = { PrintResult.Printed },
            // A chamada AIDL falhou (papel acabou/tampa aberta/erro de comunicação durante a
            // impressão): reconsulta o estado físico para reportar a causa real ao operador.
            onFailure = { PrintResult.Unavailable(status()) },
        )
    }

    private suspend fun runAidlCall(invoke: (InnerResultCallback) -> Unit) =
        suspendCancellableCoroutine { continuation ->
            invoke(
                object : InnerResultCallback() {
                    override fun onRunResult(isSuccess: Boolean) {
                        if (!continuation.isActive) return
                        if (isSuccess) continuation.resume(Unit) else continuation.resumeWithException(
                            PrinterCommandFailedException("comando de impressão retornou falha"),
                        )
                    }

                    override fun onReturnString(result: String) = Unit

                    override fun onRaiseException(code: Int, msg: String) {
                        if (continuation.isActive) {
                            continuation.resumeWithException(PrinterCommandFailedException("$code: $msg"))
                        }
                    }

                    override fun onPrintResult(code: Int, msg: String) = Unit
                },
            )
        }

    private companion object {
        const val LINE_FEED_COUNT = 2
    }
}

private class PrinterCommandFailedException(message: String) : Exception(message)

/** Traduz o código de `updatePrinterState()` (doc do fabricante) para o estado do domínio. */
private fun Int.toPrinterStatus(): PrinterStatus = when (this) {
    1 -> PrinterStatus.Ready
    2 -> PrinterStatus.Preparing
    3 -> PrinterStatus.CommunicationError
    4 -> PrinterStatus.OutOfPaper
    5 -> PrinterStatus.Overheating
    6 -> PrinterStatus.CoverOpen
    7 -> PrinterStatus.CutError
    else -> PrinterStatus.CommunicationError
}

/**
 * Conecta ao serviço AIDL da impressora Sunmi (`InnerPrinterManager.bindService`) e entrega o
 * [SunmiPrinterService] vinculado. Uso único na inicialização do app/DI — o [SunmiPrinterAdapter]
 * em si não conhece o ciclo de vida da conexão.
 */
object SunmiPrinterConnector {
    suspend fun connect(context: Context): SunmiPrinterService =
        suspendCancellableCoroutine { continuation ->
            InnerPrinterManager.getInstance().bindService(
                context,
                object : InnerPrinterCallback() {
                    override fun onConnected(service: SunmiPrinterService) {
                        if (continuation.isActive) continuation.resume(service)
                    }

                    override fun onDisconnected() {
                        if (continuation.isActive) {
                            continuation.resumeWithException(
                                PrinterCommandFailedException("serviço de impressão desconectado durante o bind"),
                            )
                        }
                    }
                },
            )
        }
}
