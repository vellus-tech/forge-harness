package br.com.axis.validador.hardware.serial

import br.com.axis.validador.domain.TurnstileReleaseResult
import br.com.axis.validador.domain.ValidationDecision
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue

/** Fake de [SerialLink] que responde com bytes pré-programados na leitura. */
private class FakeSerialLink(
    private val response: ByteArray?,
    private val throwOnWrite: Exception? = null,
) : SerialLink {
    var lastWrittenFrame: ByteArray? = null
        private set

    override fun write(frame: ByteArray, timeoutMillis: Int) {
        throwOnWrite?.let { throw it }
        lastWrittenFrame = frame
    }

    override fun read(buffer: ByteArray, timeoutMillis: Int): Int {
        val data = response ?: return 0
        data.copyInto(buffer)
        return data.size
    }
}

private fun responseFrame(cmd: Byte): ByteArray {
    val body = byteArrayOf(cmd, 0)
    val crc = GertecTc400Protocol.crc8(body)
    return byteArrayOf(0x02) + body + byteArrayOf(crc) + byteArrayOf(0x03)
}

private val decision = ValidationDecision.Approved(eventId = "evt-1", cardUid = "card-1")

/** Cobre o critério de aceite da TASK-03: giro liberado, giro não consumado e catraca indisponível. */
class SerialTurnstileGateTest {

    @Test
    fun `giro liberado quando catraca responde GIRO_CONSUMADO`() {
        val link = FakeSerialLink(response = responseFrame(GertecTc400Protocol.RESP_GIRO_CONSUMADO))
        val result = SerialTurnstileGate(link).releaseTurn(decision)
        assertIs<TurnstileReleaseResult.Released>(result)
        assertEquals("evt-1", result.eventId)
        assertTrue(link.lastWrittenFrame!!.isNotEmpty())
    }

    @Test
    fun `giro nao consumado quando catraca responde GIRO_EXPIRADO (evento TURNSTILE_NOT_PASSED)`() {
        val link = FakeSerialLink(response = responseFrame(GertecTc400Protocol.RESP_GIRO_EXPIRADO))
        val result = SerialTurnstileGate(link).releaseTurn(decision)
        assertIs<TurnstileReleaseResult.NotConsumed>(result)
        assertEquals("evt-1", result.eventId)
    }

    @Test
    fun `indisponivel quando catraca nao responde dentro do timeout`() {
        val link = FakeSerialLink(response = null)
        val result = SerialTurnstileGate(link).releaseTurn(decision)
        assertIs<TurnstileReleaseResult.Unavailable>(result)
    }

    @Test
    fun `indisponivel quando catraca responde NACK`() {
        val link = FakeSerialLink(response = responseFrame(GertecTc400Protocol.RESP_NACK))
        val result = SerialTurnstileGate(link).releaseTurn(decision)
        assertIs<TurnstileReleaseResult.Unavailable>(result)
    }

    @Test
    fun `indisponivel quando o link serial lanca excecao na escrita`() {
        val link = FakeSerialLink(response = null, throwOnWrite = IllegalStateException("porta USB desconectada"))
        val result = SerialTurnstileGate(link).releaseTurn(decision)
        assertIs<TurnstileReleaseResult.Unavailable>(result)
        assertEquals("porta USB desconectada", (result as TurnstileReleaseResult.Unavailable).reason)
    }

    @Test
    fun `frame LIBERA_GIRO enviado eh valido segundo o protocolo`() {
        val link = FakeSerialLink(response = responseFrame(GertecTc400Protocol.RESP_GIRO_CONSUMADO))
        SerialTurnstileGate(link, turnTimeoutSeconds = 8).releaseTurn(decision)
        val frame = link.lastWrittenFrame!!
        assertEquals(GertecTc400Protocol.CMD_LIBERA_GIRO, frame[1])
        assertEquals(8.toByte(), frame[3])
    }
}
