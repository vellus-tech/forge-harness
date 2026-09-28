namespace Tarifa.Domain;

/// <summary>Tarifa vigente de uma linha. Valores monetários sempre em centavos (minor units, BRL).</summary>
public sealed class TarifaLinha
{
    public TarifaLinha(Guid linhaId, long valorCentavos)
    {
        if (valorCentavos <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(valorCentavos), "A tarifa deve ser positiva.");
        }

        LinhaId = linhaId;
        ValorCentavos = valorCentavos;
    }

    public Guid LinhaId { get; }

    public long ValorCentavos { get; private set; }

    /// <summary>
    /// Aplica um reajuste percentual à tarifa vigente. O percentual é expresso em pontos-base
    /// (1 bp = 0,01%) e deve estar entre 1 e 5000 bp (0,01% a 50%). O novo valor é calculado com
    /// aritmética inteira sobre centavos × pontos-base e arredondado uma única vez, no final,
    /// pelo critério half-even (arredondamento bancário).
    /// </summary>
    /// <returns>O valor anterior e o novo valor, em centavos.</returns>
    public (long ValorAnteriorCentavos, long ValorNovoCentavos) Reajustar(int percentualBp)
    {
        if (percentualBp < 1 || percentualBp > 5000)
        {
            throw new ArgumentOutOfRangeException(nameof(percentualBp), "O percentual deve estar entre 1 e 5000 bp (0,01% a 50%).");
        }

        var valorAnteriorCentavos = ValorCentavos;
        var numerador = valorAnteriorCentavos * (10_000L + percentualBp);
        var valorNovoCentavos = DividirComArredondamentoHalfEven(numerador, 10_000L);

        ValorCentavos = valorNovoCentavos;
        return (valorAnteriorCentavos, valorNovoCentavos);
    }

    private static long DividirComArredondamentoHalfEven(long numerador, long denominador)
    {
        var quociente = numerador / denominador;
        var resto = numerador % denominador;
        var restoDobrado = resto * 2;

        if (restoDobrado > denominador || (restoDobrado == denominador && quociente % 2 != 0))
        {
            quociente += 1;
        }

        return quociente;
    }
}
