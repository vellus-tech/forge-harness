package br.com.bilhetagem.qrcode;

public final class ValidadorQrCode {
    private ValidadorQrCode() {
    }

    public static boolean payloadValido(String payload) {
        return payload != null && payload.startsWith("BQR1:") && payload.length() >= 21;
    }
}
