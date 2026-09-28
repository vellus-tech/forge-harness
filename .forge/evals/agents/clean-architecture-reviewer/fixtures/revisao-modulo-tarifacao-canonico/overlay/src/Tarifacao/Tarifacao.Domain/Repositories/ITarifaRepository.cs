using Tarifacao.Domain.Entities;

namespace Tarifacao.Domain.Repositories;

public interface ITarifaRepository
{
    Task<Tarifa?> ObterPorLinhaAsync(string linha, CancellationToken ct);
    Task SalvarAsync(Tarifa tarifa, CancellationToken ct);
}
