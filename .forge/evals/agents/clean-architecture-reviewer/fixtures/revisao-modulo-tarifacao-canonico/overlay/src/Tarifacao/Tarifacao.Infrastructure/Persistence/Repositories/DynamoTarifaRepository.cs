using Amazon.DynamoDBv2.DataModel;
using Tarifacao.Domain.Entities;
using Tarifacao.Domain.Repositories;

namespace Tarifacao.Infrastructure.Persistence.Repositories;

public sealed class DynamoTarifaRepository : ITarifaRepository
{
    private readonly IDynamoDBContext _contexto;

    public DynamoTarifaRepository(IDynamoDBContext contexto) => _contexto = contexto;

    public Task<Tarifa?> ObterPorLinhaAsync(string linha, CancellationToken ct) =>
        _contexto.LoadAsync<Tarifa?>(linha, ct);

    public Task SalvarAsync(Tarifa tarifa, CancellationToken ct) => _contexto.SaveAsync(tarifa, ct);
}
