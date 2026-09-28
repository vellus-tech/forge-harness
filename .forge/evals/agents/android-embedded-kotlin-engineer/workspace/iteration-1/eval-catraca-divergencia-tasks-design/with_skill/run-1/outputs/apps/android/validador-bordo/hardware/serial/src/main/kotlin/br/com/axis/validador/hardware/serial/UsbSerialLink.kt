package br.com.axis.validador.hardware.serial

import com.hoho.android.usbserial.driver.UsbSerialPort

/** Link serial genérico via USB-RS232 (9600 8N1). Consumido por `hardware/catraca` (Gertec TC-400). */
class UsbSerialLink(private val port: UsbSerialPort) : SerialLink {
    override fun write(frame: ByteArray, timeoutMillis: Int) {
        port.write(frame, timeoutMillis)
    }

    override fun read(buffer: ByteArray, timeoutMillis: Int): Int = port.read(buffer, timeoutMillis)
}
