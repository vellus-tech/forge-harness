package br.com.axis.validador.hardware.serial

/**
 * Abstração mínima de um link serial ponto-a-ponto. Existe para que adapters de protocolo
 * (ex.: `hardware/catraca`) possam ser testados com um fake, sem depender do USB real nem de
 * instrumentação em dispositivo.
 */
interface SerialLink {
    fun write(frame: ByteArray, timeoutMillis: Int)

    fun read(buffer: ByteArray, timeoutMillis: Int): Int
}
