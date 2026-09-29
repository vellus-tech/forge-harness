namespace Tarifa.Application;

public sealed record TarifaResponse(Guid LinhaId, long ValorCentavos);

public sealed class GetTarifaHandler(ITarifaRepository repository)
{
    public async Task<TarifaResponse?> HandleAsync(Guid linhaId, CancellationToken cancellationToken)
    {
        var tarifa = await repository.FindAsync(linhaId, cancellationToken);
        return tarifa is null ? null : new TarifaResponse(tarifa.LinhaId, tarifa.ValorCentavos);
    }
}
