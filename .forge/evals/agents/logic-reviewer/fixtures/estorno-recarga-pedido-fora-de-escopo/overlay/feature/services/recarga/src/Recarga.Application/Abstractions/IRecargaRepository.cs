using Recarga.Domain;

namespace Recarga.Application.Abstractions;

public interface IRecargaRepository
{
    Task<RecargaPix?> ObterAsync(Guid recargaId, CancellationToken ct);
    Task AtualizarAsync(RecargaPix recarga, CancellationToken ct);
}
