namespace Cashback.Worker.Contracts;

/// <summary>
/// Evento publicado pela validadora na exchange <c>bilhetagem.viagens</c> quando uma viagem é validada.
/// Contrato de outro serviço (não editar sem alinhar com o time da validadora) — ver
/// contracts/asyncapi/cashback.yaml para a cópia documentada do payload consumido aqui.
/// </summary>
public sealed record ViagemValidada(
    Guid EventoId,
    Guid PassageiroId,
    long TarifaCentavos,
    DateTimeOffset ValidadaEm,
    string CorrelationId);
