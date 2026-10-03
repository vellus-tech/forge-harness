package br.com.axis.posrecarga.domain

interface NfcReaderPort {
    suspend fun readCardUid(timeoutMillis: Long): NfcReadResult
}

sealed interface NfcReadResult {
    data class Read(val cardUid: String) : NfcReadResult
    data object Timeout : NfcReadResult
    data object ReaderUnavailable : NfcReadResult
}
