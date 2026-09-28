using Recarga.Domain.Entities;

namespace Recarga.Domain.Repositories;

public interface IRecargaRepository
{
    Task<long> ObterTotalConfirmadoNoDiaAsync(string numeroLogicoCartao, DateTime data, CancellationToken ct);

    Task AdicionarAsync(RecargaCartao recarga, CancellationToken ct);
}
