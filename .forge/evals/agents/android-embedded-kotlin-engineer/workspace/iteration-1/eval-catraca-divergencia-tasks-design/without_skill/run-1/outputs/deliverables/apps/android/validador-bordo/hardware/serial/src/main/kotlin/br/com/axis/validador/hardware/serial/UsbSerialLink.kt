package br.com.axis.validador.hardware.serial

import com.hoho.android.usbserial.driver.UsbSerialPort

/**
 * Contrato mínimo de um link serial ponto-a-ponto (escrita/leitura de bytes com timeout).
 * Extraído para permitir testar consumidores (ex.: [SerialTurnstileGate]) com um fake, sem
 * depender de `UsbSerialPort` (classe Android indisponível em teste unitário puro).
 */
interface SerialLink {
    fun write(frame: ByteArray, timeoutMillis: Int)
    fun read(buffer: ByteArray, timeoutMillis: Int): Int
}

/** Link serial genérico via USB-RS232 (9600 8N1), implementado sobre `UsbSerialPort`. */
class UsbSerialLink(private val port: UsbSerialPort) : SerialLink {
    override fun write(frame: ByteArray, timeoutMillis: Int) {
        port.write(frame, timeoutMillis)
    }

    override fun read(buffer: ByteArray, timeoutMillis: Int): Int = port.read(buffer, timeoutMillis)
}
