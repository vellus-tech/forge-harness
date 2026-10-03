using Carteira.Domain;

namespace Carteira.Application.Abstractions;

public interface ICarteiraRepository
{
    Task<CarteiraPrePaga?> ObterAsync(Guid carteiraId, CancellationToken ct);
    Task AtualizarAsync(CarteiraPrePaga carteira, CancellationToken ct);
}
