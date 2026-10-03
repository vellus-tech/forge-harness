package br.com.axis.tarifa;

public record Tarifa(long id, String linha, String modal, long valorCentavos, long valorIntegracaoCentavos) {
}
