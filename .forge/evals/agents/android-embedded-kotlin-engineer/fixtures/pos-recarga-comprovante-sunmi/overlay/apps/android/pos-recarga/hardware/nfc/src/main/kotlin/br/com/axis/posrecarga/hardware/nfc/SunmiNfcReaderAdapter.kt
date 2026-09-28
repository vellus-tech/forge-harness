package br.com.axis.posrecarga.hardware.nfc

import br.com.axis.posrecarga.domain.NfcReadResult
import br.com.axis.posrecarga.domain.NfcReaderPort
import com.sunmi.nfc.SunmiNfcClient

class SunmiNfcReaderAdapter(
    private val client: SunmiNfcClient,
) : NfcReaderPort {
    override suspend fun readCardUid(timeoutMillis: Long): NfcReadResult {
        if (!client.isConnected()) return NfcReadResult.ReaderUnavailable
        val uid = client.pollUid(timeoutMillis) ?: return NfcReadResult.Timeout
        return NfcReadResult.Read(uid)
    }
}
