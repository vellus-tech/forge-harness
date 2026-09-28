namespace Recarga.Contracts.Events;

public sealed record RecargaConfirmada(Guid Id, string NumeroLogicoCartao, long ValorCentavos);
