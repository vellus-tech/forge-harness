package br.com.axis.validador.hardware.serial

/**
 * Framing do protocolo serial da catraca Gertec TC-400 (docs/vendor/gertec-tc400-serial.md).
 *
 * `STX | CMD | LEN | DATA | CRC8 | ETX`, RS-232 9600 8N1.
 *
 * O documento do fabricante não especifica o polinômio do CRC8; foi adotado CRC-8/SMBUS
 * (polinômio 0x07, sem reflexão, init 0x00), o padrão mais comum em protocolos seriais
 * industriais simples. Se a integração real com o hardware da linha 8012 rejeitar os frames
 * (NACK por "CRC inválido"), o polinômio deve ser confirmado com o fabricante e ajustado aqui —
 * é o primeiro ponto a verificar em bancada antes do piloto de segunda.
 */
internal object GertecTc400Protocol {
    private const val STX: Byte = 0x02
    private const val ETX: Byte = 0x03

    const val CMD_LIBERA_GIRO: Byte = 0x31
    const val CMD_STATUS: Byte = 0x35

    const val RESP_GIRO_CONSUMADO: Byte = 0x41
    const val RESP_GIRO_EXPIRADO: Byte = 0x42
    const val RESP_NACK: Byte = 0x4E

    /** Monta o frame LIBERA_GIRO com o timeout (em segundos) como payload de 1 byte. */
    fun buildLiberaGiroFrame(timeoutSeconds: Int): ByteArray {
        require(timeoutSeconds in 1..255) { "timeoutSeconds deve caber em 1 byte (1..255)" }
        val data = byteArrayOf(timeoutSeconds.toByte())
        return buildFrame(CMD_LIBERA_GIRO, data)
    }

    /** Monta o frame STATUS, usado para consultar o estado da catraca antes de reenviar um comando. */
    fun buildStatusFrame(): ByteArray = buildFrame(CMD_STATUS, ByteArray(0))

    private fun buildFrame(cmd: Byte, data: ByteArray): ByteArray {
        val body = byteArrayOf(cmd, data.size.toByte()) + data
        val crc = crc8(body)
        return byteArrayOf(STX) + body + byteArrayOf(crc) + byteArrayOf(ETX)
    }

    /**
     * Extrai o byte de comando/resposta (`CMD`) de um frame de resposta recebido, validando
     * delimitadores STX/ETX e o CRC8. Retorna `null` se o frame estiver malformado ou o CRC
     * não bater (mesmo tratamento de "resposta desconhecida" que um NACK silencioso).
     */
    fun parseResponseCommand(buffer: ByteArray, length: Int): Byte? {
        if (length < 5) return null
        if (buffer[0] != STX || buffer[length - 1] != ETX) return null
        val len = buffer[2].toInt() and 0xFF
        val expectedLength = 3 + len + 2
        if (length != expectedLength) return null
        // body para o CRC é [CMD, LEN, DATA...], sem o STX (índice 0) — começa em 1, termina antes da CRC.
        val body = buffer.copyOfRange(1, 3 + len)
        val receivedCrc = buffer[3 + len]
        if (crc8(body) != receivedCrc) return null
        return buffer[1]
    }

    /** CRC-8/SMBUS: polinômio 0x07, sem reflexão, valor inicial 0x00. */
    fun crc8(bytes: ByteArray): Byte {
        var crc = 0
        for (b in bytes) {
            crc = crc xor (b.toInt() and 0xFF)
            repeat(8) {
                crc = if (crc and 0x80 != 0) (crc shl 1) xor 0x07 else crc shl 1
                crc = crc and 0xFF
            }
        }
        return crc.toByte()
    }
}
