namespace Pagamentos.Domain.Events;

public sealed record ProcessarReembolso(Guid PagamentoId, decimal Valor, DateTimeOffset OcorridoEm);
