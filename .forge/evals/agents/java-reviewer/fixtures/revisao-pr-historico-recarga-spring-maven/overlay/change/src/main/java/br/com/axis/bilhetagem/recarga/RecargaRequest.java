package br.com.axis.bilhetagem.recarga;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record RecargaRequest(@NotNull Long cartaoId, @Positive long valorCentavos) {
}
