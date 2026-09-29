namespace Tarifa.Domain;

/// <summary>Resultado de um reajuste percentual aplicado a uma <see cref="TarifaLinha"/>.</summary>
public readonly record struct ReajusteTarifa(long ValorAnteriorCentavos, long ValorNovoCentavos);

/// <summary>Tarifa vigente de uma linha. Valores monetários sempre em centavos (minor units, BRL).</summary>
public sealed class TarifaLinha
{
    private const int PercentualBpMinimo = 1;
    private const int PercentualBpMaximo = 5000;
    private const long PontosBasePorInteiro = 10_000L;

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
    /// Reajusta a tarifa vigente pelo percentual informado em pontos-base (1 bp = 0,01%).
    /// A aritmética é toda inteira sobre centavos × pontos-base; o arredondamento ocorre uma
    /// única vez, no final, pelo critério half-even (bancário) — ver DD-001/DD-002.
    /// </summary>
    public ReajusteTarifa Reajustar(int percentualBp)
    {
        if (percentualBp < PercentualBpMinimo || percentualBp > PercentualBpMaximo)
        {
            throw new ArgumentOutOfRangeException(
                nameof(percentualBp),
                percentualBp,
                $"O percentual deve estar entre {PercentualBpMinimo} e {PercentualBpMaximo} pontos-base (0,01% a 50%).");
        }

        var valorAnterior = ValorCentavos;
        var numerador = valorAnterior * (PontosBasePorInteiro + percentualBp);
        var quociente = Math.DivRem(numerador, PontosBasePorInteiro, out var resto);

        var restoDobrado = resto * 2;
        if (restoDobrado > PontosBasePorInteiro || (restoDobrado == PontosBasePorInteiro && quociente % 2 != 0))
        {
            quociente += 1;
        }

        ValorCentavos = quociente;
        return new ReajusteTarifa(valorAnterior, quociente);
    }
}
