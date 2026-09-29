namespace Pagamentos.Domain.Events;

public sealed record EstornarPagamento(Guid PagamentoId, decimal Valor, DateTimeOffset OcorridoEm);
