package br.com.axis.validador.hardware.catraca

import br.com.axis.validador.domain.TurnstileNotConfirmedReason
import br.com.axis.validador.domain.TurnstilePort
import br.com.axis.validador.domain.TurnstileReleaseOutcome
import br.com.axis.validador.domain.TurnstileReleaseRequest
import br.com.axis.validador.hardware.serial.SerialLink
import java.io.IOException

/**
 * Adapter [TurnstilePort] para a Gertec TC-400, catraca homologada para a linha 8012
 * (DD-002, `docs/product/modules/catraca/design.md`, aprovado em 2026-08-20).
 *
 * `docs/product/modules/catraca/tasks.md` (TASK-03) descreve acionamento por GPIO do Telpo
 * TPS508; o design.md diverge explicitamente e é mais específico para esta linha — o TPS508
 * da 8012 não tem o chicote de GPIO instalado, então esse caminho nem é fisicamente viável
 * aqui. Este adapter segue o design.md (fonte de maior autoridade entre os dois: decisão
 * aprovada e específica ao hardware real da linha). Ver `outputs/transcript.md` para o registro
 * completo da divergência e a recomendação de corrigir tasks.md.
 *
 * Sem retentativa automática de `LIBERA_GIRO`: o fabricante alerta que reenviar sem ter recebido
 * resposta pode liberar dois giros — comando físico para catraca nunca leva retry cego.
 */
class GertecTc400TurnstileAdapter(
    private val serialLink: SerialLink,
    private val ioTimeoutMillis: Int = DEFAULT_IO_TIMEOUT_MILLIS,
) : TurnstilePort {

    override suspend fun releaseSingleTurn(request: TurnstileReleaseRequest): TurnstileReleaseOutcome {
        val frame = GertecFrame.encode(
            command = GertecFrame.CMD_LIBERA_GIRO,
            data = byteArrayOf(request.confirmationTimeoutSeconds.toByte()),
        )

        val writeFailure = writeFrame(request.eventId, frame)
        if (writeFailure != null) return writeFailure

        return readOutcome(request)
    }

    private fun writeFrame(eventId: String, frame: ByteArray): TurnstileReleaseOutcome.DeviceUnavailable? {
        return try {
            serialLink.write(frame, ioTimeoutMillis)
            null
        } catch (error: IOException) {
            TurnstileReleaseOutcome.DeviceUnavailable(eventId, cause = "erro_escrita_serial: ${error.message}")
        }
    }

    private fun readOutcome(request: TurnstileReleaseRequest): TurnstileReleaseOutcome {
        val buffer = ByteArray(RESPONSE_BUFFER_SIZE)
        val readTimeoutMillis = request.confirmationTimeoutSeconds * MILLIS_PER_SECOND

        val bytesRead = try {
            serialLink.read(buffer, readTimeoutMillis)
        } catch (error: IOException) {
            return TurnstileReleaseOutcome.DeviceUnavailable(request.eventId, cause = "erro_leitura_serial: ${error.message}")
        }

        if (bytesRead <= 0) {
            return TurnstileReleaseOutcome.DeviceUnavailable(request.eventId, cause = "timeout_sem_resposta")
        }

        val response = GertecFrame.decode(buffer, bytesRead)
            ?: return TurnstileReleaseOutcome.DeviceUnavailable(request.eventId, cause = "frame_invalido")

        return outcomeFor(request.eventId, response.command)
    }

    private fun outcomeFor(eventId: String, command: Byte): TurnstileReleaseOutcome = when (command) {
        GertecFrame.RESP_GIRO_CONSUMADO -> TurnstileReleaseOutcome.Released(eventId)

        GertecFrame.RESP_GIRO_EXPIRADO ->
            TurnstileReleaseOutcome.NotConfirmed(eventId, TurnstileNotConfirmedReason.EXPIRED)

        GertecFrame.RESP_NACK ->
            TurnstileReleaseOutcome.DeviceUnavailable(eventId, cause = "nack_catraca_ocupada_ou_crc_invalido")

        else ->
            TurnstileReleaseOutcome.DeviceUnavailable(eventId, cause = "resposta_desconhecida_0x${command.toString(16)}")
    }

    private companion object {
        const val DEFAULT_IO_TIMEOUT_MILLIS = 2_000
        const val RESPONSE_BUFFER_SIZE = 16
        const val MILLIS_PER_SECOND = 1_000
    }
}
