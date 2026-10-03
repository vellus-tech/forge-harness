package br.com.axis.validador.hardware.catraca

/**
 * Codec do frame serial da Gertec TC-400 (docs/vendor/gertec-tc400-serial.md):
 * `STX | CMD | LEN | DATA | CRC8 | ETX`.
 *
 * Assunções não cobertas pelo resumo do fabricante — confirmar com o time de hardware antes do
 * piloto de campo, não apenas antes do piloto de segunda:
 * - STX/ETX como delimitadores ASCII padrão (0x02/0x03);
 * - CRC-8 com polinômio 0x07 (o documento não especifica o polinômio).
 */
internal object GertecFrame {
    const val STX: Byte = 0x02
    const val ETX: Byte = 0x03

    const val CMD_LIBERA_GIRO: Byte = 0x31
    const val CMD_STATUS: Byte = 0x35

    const val RESP_GIRO_CONSUMADO: Byte = 0x41
    const val RESP_GIRO_EXPIRADO: Byte = 0x42
    const val RESP_NACK: Byte = 0x4E

    private const val CRC8_POLYNOMIAL = 0x07

    /** STX + CMD + LEN + CRC + ETX, sem contar DATA. */
    private const val FRAME_OVERHEAD = 5

    fun encode(command: Byte, data: ByteArray = ByteArray(0)): ByteArray {
        val payload = byteArrayOf(command, data.size.toByte()) + data
        val crc = crc8(payload)
        return byteArrayOf(STX) + payload + byteArrayOf(crc) + byteArrayOf(ETX)
    }

    fun decode(buffer: ByteArray, length: Int): GertecResponseFrame? {
        if (length < FRAME_OVERHEAD) return null
        if (buffer[0] != STX || buffer[length - 1] != ETX) return null

        val dataLength = buffer[2].toInt() and 0xFF
        if (length != FRAME_OVERHEAD + dataLength) return null

        val payload = buffer.copyOfRange(1, 3 + dataLength)
        val receivedCrc = buffer[3 + dataLength]
        if (crc8(payload) != receivedCrc) return null

        val data = buffer.copyOfRange(3, 3 + dataLength)
        return GertecResponseFrame(command = buffer[1], data = data)
    }

    private fun crc8(bytes: ByteArray): Byte {
        var crc = 0
        for (byte in bytes) {
            crc = crc xor (byte.toInt() and 0xFF)
            repeat(8) {
                crc = if (crc and 0x80 != 0) (crc shl 1) xor CRC8_POLYNOMIAL else crc shl 1
                crc = crc and 0xFF
            }
        }
        return crc.toByte()
    }
}

internal class GertecResponseFrame(val command: Byte, val data: ByteArray)
