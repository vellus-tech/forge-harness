using Tarifa.Domain;

namespace Tarifa.Application;

public interface ITarifaRepository
{
    Task<TarifaLinha?> FindAsync(Guid linhaId, CancellationToken cancellationToken);

    Task SaveAsync(TarifaLinha tarifa, CancellationToken cancellationToken);
}
