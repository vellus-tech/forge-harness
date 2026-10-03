package br.com.bilhetagem.qrcode;

import java.time.Instant;

public final class ValidadorQrCode {
    static final long VALIDADE_SEGUNDOS = 90;

    private ValidadorQrCode() {
    }

    public static boolean payloadValido(String payload) {
        return payload != null && payload.startsWith("BQR1:") && payload.length() >= 21;
    }

    public static boolean dentroDaValidade(long emitidoEmEpochSegundos, Instant agora) {
        long idade = agora.getEpochSecond() - emitidoEmEpochSegundos;
        return idade >= 0 && idade <= VALIDADE_SEGUNDOS;
    }
}
