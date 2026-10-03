using Microsoft.EntityFrameworkCore;
using Recarga.Domain.Entities;
using Recarga.Domain.Repositories;
using Recarga.Infrastructure.Persistence;

namespace Recarga.Infrastructure.Repositories;

public sealed class RecargaRepository : IRecargaRepository
{
    private readonly RecargaDbContext _contexto;

    public RecargaRepository(RecargaDbContext contexto)
    {
        _contexto = contexto;
    }

    public Task<long> ObterTotalConfirmadoNoDiaAsync(string numeroLogicoCartao, DateTime data, CancellationToken ct)
    {
        return _contexto.Recargas
            .Where(r => r.NumeroLogicoCartao == numeroLogicoCartao && r.Status == "CONFIRMADA")
            .SumAsync(r => r.ValorCentavos, ct);
    }

    public async Task AdicionarAsync(RecargaCartao recarga, CancellationToken ct)
    {
        await _contexto.Recargas.AddAsync(recarga, ct);
        await _contexto.SaveChangesAsync(ct);
    }
}
