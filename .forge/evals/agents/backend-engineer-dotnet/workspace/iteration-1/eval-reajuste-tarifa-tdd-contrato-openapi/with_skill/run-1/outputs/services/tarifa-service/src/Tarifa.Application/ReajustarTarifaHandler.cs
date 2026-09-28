namespace Tarifa.Application;

public sealed record ReajustarTarifaRequest(int PercentualBp);

public sealed record ReajusteTarifaResponse(Guid LinhaId, long ValorAnteriorCentavos, long ValorNovoCentavos);

/// <summary>Erro de validação do reajuste — percentual fora do intervalo permitido (1 a 5000 bp).</summary>
public sealed class PercentualInvalidoException(string message) : ArgumentOutOfRangeException(message);

public sealed class ReajustarTarifaHandler(ITarifaRepository repository)
{
    public async Task<ReajusteTarifaResponse?> HandleAsync(
        Guid linhaId,
        ReajustarTarifaRequest request,
        CancellationToken cancellationToken)
    {
        var tarifa = await repository.FindAsync(linhaId, cancellationToken);
        if (tarifa is null)
        {
            return null;
        }

        try
        {
            var resultado = tarifa.Reajustar(request.PercentualBp);
            await repository.SaveAsync(tarifa, cancellationToken);
            return new ReajusteTarifaResponse(linhaId, resultado.ValorAnteriorCentavos, resultado.ValorNovoCentavos);
        }
        catch (ArgumentOutOfRangeException ex)
        {
            throw new PercentualInvalidoException(ex.Message);
        }
    }
}
