namespace Tarifa.Application;

public sealed record ReajusteTarifaResponse(Guid LinhaId, long ValorAnteriorCentavos, long ValorNovoCentavos);

public enum ReajustarTarifaResultado
{
    Sucesso,
    LinhaNaoEncontrada,
    PercentualInvalido,
}

public sealed record ReajustarTarifaResult(ReajustarTarifaResultado Resultado, ReajusteTarifaResponse? Response);

/// <summary>
/// Aplica um reajuste percentual (REQ-004) à tarifa vigente de uma linha. A validação de faixa
/// do percentual (1 a 5000 bp) é replicada aqui — antes de tocar o agregado — para que o endpoint
/// possa responder 422 sem depender do fluxo de exceção do Domain.
/// </summary>
public sealed class ReajustarTarifaHandler(ITarifaRepository repository)
{
    public async Task<ReajustarTarifaResult> HandleAsync(Guid linhaId, int percentualBp, CancellationToken cancellationToken)
    {
        var tarifa = await repository.FindAsync(linhaId, cancellationToken);
        if (tarifa is null)
        {
            return new ReajustarTarifaResult(ReajustarTarifaResultado.LinhaNaoEncontrada, null);
        }

        if (percentualBp < 1 || percentualBp > 5000)
        {
            return new ReajustarTarifaResult(ReajustarTarifaResultado.PercentualInvalido, null);
        }

        var (valorAnteriorCentavos, valorNovoCentavos) = tarifa.Reajustar(percentualBp);
        await repository.SaveAsync(tarifa, cancellationToken);

        var response = new ReajusteTarifaResponse(linhaId, valorAnteriorCentavos, valorNovoCentavos);
        return new ReajustarTarifaResult(ReajustarTarifaResultado.Sucesso, response);
    }
}
