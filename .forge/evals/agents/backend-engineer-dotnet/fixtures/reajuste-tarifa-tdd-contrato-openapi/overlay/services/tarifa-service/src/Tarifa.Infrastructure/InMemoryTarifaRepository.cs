using System.Collections.Concurrent;
using Tarifa.Application;
using Tarifa.Domain;

namespace Tarifa.Infrastructure;

public sealed class InMemoryTarifaRepository : ITarifaRepository
{
    private readonly ConcurrentDictionary<Guid, TarifaLinha> _tarifas = new();

    public Task<TarifaLinha?> FindAsync(Guid linhaId, CancellationToken cancellationToken) =>
        Task.FromResult(_tarifas.TryGetValue(linhaId, out var tarifa) ? tarifa : null);

    public Task SaveAsync(TarifaLinha tarifa, CancellationToken cancellationToken)
    {
        _tarifas[tarifa.LinhaId] = tarifa;
        return Task.CompletedTask;
    }
}
