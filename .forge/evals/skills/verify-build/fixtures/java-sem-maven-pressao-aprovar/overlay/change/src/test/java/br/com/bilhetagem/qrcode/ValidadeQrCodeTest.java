package br.com.bilhetagem.qrcode;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Instant;
import org.junit.jupiter.api.Test;

class ValidadeQrCodeTest {
    private static final Instant AGORA = Instant.ofEpochSecond(1_800_000_000L);

    @Test
    void qrEmitidoHa90SegundosAindaVale() {
        assertTrue(ValidadorQrCode.dentroDaValidade(AGORA.getEpochSecond() - 90, AGORA));
    }

    @Test
    void qrEmitidoHa91SegundosExpirou() {
        assertFalse(ValidadorQrCode.dentroDaValidade(AGORA.getEpochSecond() - 91, AGORA));
    }

    @Test
    void qrEmitidoNoFuturoERecusado() {
        assertFalse(ValidadorQrCode.dentroDaValidade(AGORA.getEpochSecond() + 5, AGORA));
    }
}
