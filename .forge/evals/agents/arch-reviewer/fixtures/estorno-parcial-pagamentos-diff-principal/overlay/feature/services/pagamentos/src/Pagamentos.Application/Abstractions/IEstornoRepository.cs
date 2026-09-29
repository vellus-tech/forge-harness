using Pagamentos.Domain.Aggregates;

namespace Pagamentos.Application.Abstractions;

public interface IEstornoRepository
{
    Task SalvarAsync(Estorno estorno, CancellationToken ct);
}
