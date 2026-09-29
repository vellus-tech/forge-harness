namespace Tarifacao.Domain.Events;

public sealed record CalcularTarifaIntegracao(Guid TarifaId, long ValorCentavos, DateTime OcorridoEm);
