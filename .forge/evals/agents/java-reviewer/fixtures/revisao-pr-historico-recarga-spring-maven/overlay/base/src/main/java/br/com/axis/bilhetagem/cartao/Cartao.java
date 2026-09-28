package br.com.axis.bilhetagem.cartao;

public record Cartao(long id, String titularId, String numeroMascarado, long saldoCentavos) {
}
