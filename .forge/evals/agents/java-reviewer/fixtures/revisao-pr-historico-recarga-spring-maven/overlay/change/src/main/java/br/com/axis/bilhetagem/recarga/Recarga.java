package br.com.axis.bilhetagem.recarga;

import java.time.OffsetDateTime;

public record Recarga(long id, long cartaoId, long valorCentavos, String status, OffsetDateTime criadaEm) {
}
