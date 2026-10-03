namespace Cashback.Worker.Contracts;

/// <summary>Evento publicado na exchange <c>cashback.creditado</c> após o crédito ser confirmado na carteira.</summary>
public sealed record CashbackCreditado(Guid PassageiroId, long ValorCentavos, string CorrelationId);
