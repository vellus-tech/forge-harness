package br.com.axis.validador.hardware.catraca

import br.com.axis.validador.domain.TurnstileNotConfirmedReason
import br.com.axis.validador.domain.TurnstileReleaseOutcome
import br.com.axis.validador.domain.TurnstileReleaseRequest
import br.com.axis.validador.hardware.serial.SerialLink
import java.io.IOException
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

private class FakeSerialLink(private val response: ByteArray?) : SerialLink {
    var writtenFrame: ByteArray? = null
        private set

    override fun write(frame: ByteArray, timeoutMillis: Int) {
        writtenFrame = frame
    }

    override fun read(buffer: ByteArray, timeoutMillis: Int): Int {
        val data = response ?: return 0
        data.copyInto(buffer)
        return data.size
    }
}

private class ThrowingSerialLink(private val failOnWrite: Boolean) : SerialLink {
    override fun write(frame: ByteArray, timeoutMillis: Int) {
        if (failOnWrite) throw IOException("porta_fechada")
    }

    override fun read(buffer: ByteArray, timeoutMillis: Int): Int {
        if (!failOnWrite) throw IOException("leitura_falhou")
        return 0
    }
}

class GertecTc400TurnstileAdapterTest {

    @Test
    fun `libera o giro quando recebe GIRO_CONSUMADO`() = runTest {
        val response = GertecFrame.encode(GertecFrame.RESP_GIRO_CONSUMADO)
        val serialLink = FakeSerialLink(response)
        val adapter = GertecTc400TurnstileAdapter(serialLink)

        val outcome = adapter.releaseSingleTurn(TurnstileReleaseRequest(eventId = "evt-1"))

        assertEquals(TurnstileReleaseOutcome.Released("evt-1"), outcome)
        assertEquals(GertecFrame.CMD_LIBERA_GIRO, serialLink.writtenFrame?.get(1))
    }

    @Test
    fun `reporta giro nao consumado quando recebe GIRO_EXPIRADO`() = runTest {
        val response = GertecFrame.encode(GertecFrame.RESP_GIRO_EXPIRADO)
        val adapter = GertecTc400TurnstileAdapter(FakeSerialLink(response))

        val outcome = adapter.releaseSingleTurn(TurnstileReleaseRequest(eventId = "evt-2"))

        assertEquals(
            TurnstileReleaseOutcome.NotConfirmed("evt-2", TurnstileNotConfirmedReason.EXPIRED),
            outcome,
        )
    }

    @Test
    fun `reporta dispositivo indisponivel quando a catraca nao responde a tempo`() = runTest {
        val adapter = GertecTc400TurnstileAdapter(FakeSerialLink(response = null))

        val outcome = adapter.releaseSingleTurn(TurnstileReleaseRequest(eventId = "evt-3"))

        assertTrue(outcome is TurnstileReleaseOutcome.DeviceUnavailable)
        assertEquals("timeout_sem_resposta", (outcome as TurnstileReleaseOutcome.DeviceUnavailable).cause)
    }

    @Test
    fun `reporta dispositivo indisponivel quando recebe NACK`() = runTest {
        val response = GertecFrame.encode(GertecFrame.RESP_NACK)
        val adapter = GertecTc400TurnstileAdapter(FakeSerialLink(response))

        val outcome = adapter.releaseSingleTurn(TurnstileReleaseRequest(eventId = "evt-4"))

        assertTrue(outcome is TurnstileReleaseOutcome.DeviceUnavailable)
    }

    @Test
    fun `reporta dispositivo indisponivel quando a escrita serial falha`() = runTest {
        val adapter = GertecTc400TurnstileAdapter(ThrowingSerialLink(failOnWrite = true))

        val outcome = adapter.releaseSingleTurn(TurnstileReleaseRequest(eventId = "evt-5"))

        assertTrue(outcome is TurnstileReleaseOutcome.DeviceUnavailable)
    }

    @Test
    fun `reporta dispositivo indisponivel quando a leitura serial falha`() = runTest {
        val adapter = GertecTc400TurnstileAdapter(ThrowingSerialLink(failOnWrite = false))

        val outcome = adapter.releaseSingleTurn(TurnstileReleaseRequest(eventId = "evt-6"))

        assertTrue(outcome is TurnstileReleaseOutcome.DeviceUnavailable)
    }

    @Test
    fun `descarta frame corrompido com CRC invalido`() = runTest {
        val validFrame = GertecFrame.encode(GertecFrame.RESP_GIRO_CONSUMADO)
        val corrupted = validFrame.copyOf().also { it[it.size - 2] = (it[it.size - 2] + 1).toByte() }
        val adapter = GertecTc400TurnstileAdapter(FakeSerialLink(corrupted))

        val outcome = adapter.releaseSingleTurn(TurnstileReleaseRequest(eventId = "evt-7"))

        assertTrue(outcome is TurnstileReleaseOutcome.DeviceUnavailable)
        assertEquals("frame_invalido", (outcome as TurnstileReleaseOutcome.DeviceUnavailable).cause)
    }
}
