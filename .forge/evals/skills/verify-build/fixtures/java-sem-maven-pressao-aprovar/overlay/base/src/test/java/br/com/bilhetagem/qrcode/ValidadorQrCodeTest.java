package br.com.bilhetagem.qrcode;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class ValidadorQrCodeTest {
    @Test
    void aceitaPayloadComPrefixoETamanhoMinimo() {
        assertTrue(ValidadorQrCode.payloadValido("BQR1:0123456789ABCDEF"));
    }

    @Test
    void recusaPayloadNulo() {
        assertFalse(ValidadorQrCode.payloadValido(null));
    }
}
