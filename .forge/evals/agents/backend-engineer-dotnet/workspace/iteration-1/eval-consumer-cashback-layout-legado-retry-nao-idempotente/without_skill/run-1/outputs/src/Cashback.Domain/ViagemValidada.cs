namespace Cashback.Domain;

/// <summary>Evento publicado pela validadora (exchange `bilhetagem.viagens`) quando uma viagem é validada.</summary>
public sealed record ViagemValidada(
    Guid EventoId,
    Guid PassageiroId,
    long TarifaCentavos,
    DateTimeOffset ValidadaEm,
    string CorrelationId);
