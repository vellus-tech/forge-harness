package br.com.axis.validador.hardware.serial

import br.com.axis.validador.domain.TurnstileGate
import br.com.axis.validador.domain.TurnstileReleaseResult
import br.com.axis.validador.domain.ValidationDecision

/**
 * Implementação de [TurnstileGate] para a catraca Gertec TC-400 (linha 8012), via serial
 * RS-232/USB ([UsbSerialLink]). Segue DD-002 de docs/product/modules/catraca/design.md.
 *
 * TASK-03 pede confirmação em até 8s; aqui isso mapeia para o timeout enviado no próprio frame
 * LIBERA_GIRO (a catraca responde GIRO_CONSUMADO ou GIRO_EXPIRADO dentro dessa janela) e para o
 * timeout de leitura do link serial.
 */
class SerialTurnstileGate(
    private val link: SerialLink,
    private val turnTimeoutSeconds: Int = DEFAULT_TURN_TIMEOUT_SECONDS,
) : TurnstileGate {

    override fun releaseTurn(decision: ValidationDecision.Approved): TurnstileReleaseResult {
        return try {
            val frame = GertecTc400Protocol.buildLiberaGiroFrame(turnTimeoutSeconds)
            link.write(frame, WRITE_TIMEOUT_MS)

            val buffer = ByteArray(RESPONSE_BUFFER_SIZE)
            val readLength = link.read(buffer, turnTimeoutSeconds * 1000 + READ_TIMEOUT_MARGIN_MS)
            if (readLength <= 0) {
                return TurnstileReleaseResult.Unavailable(decision.eventId, "sem resposta da catraca dentro do timeout")
            }

            when (GertecTc400Protocol.parseResponseCommand(buffer, readLength)) {
                GertecTc400Protocol.RESP_GIRO_CONSUMADO -> TurnstileReleaseResult.Released(decision.eventId)
                GertecTc400Protocol.RESP_GIRO_EXPIRADO -> TurnstileReleaseResult.NotConsumed(decision.eventId)
                GertecTc400Protocol.RESP_NACK -> TurnstileReleaseResult.Unavailable(decision.eventId, "NACK: CRC inválido ou catraca ocupada")
                else -> TurnstileReleaseResult.Unavailable(decision.eventId, "resposta malformada ou desconhecida da catraca")
            }
        } catch (error: Exception) {
            TurnstileReleaseResult.Unavailable(decision.eventId, error.message ?: "falha no link serial")
        }
    }

    private companion object {
        const val DEFAULT_TURN_TIMEOUT_SECONDS = 8
        const val WRITE_TIMEOUT_MS = 1_000
        const val READ_TIMEOUT_MARGIN_MS = 500
        const val RESPONSE_BUFFER_SIZE = 16
    }
}
