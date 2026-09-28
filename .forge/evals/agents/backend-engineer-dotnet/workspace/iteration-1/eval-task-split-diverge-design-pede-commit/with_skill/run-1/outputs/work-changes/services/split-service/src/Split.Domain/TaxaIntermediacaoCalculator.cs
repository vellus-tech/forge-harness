namespace Split.Domain;

/// <summary>
/// Calcula a taxa de intermediação da Axis sobre um split, em centavos, conforme DD-004
/// (pontos-base sobre <c>valor_centavos</c>, arredondamento half-even — NBR 5891).
/// </summary>
public static class TaxaIntermediacaoCalculator
{
    /// <summary>Taxa padrão da Axis: 150 pontos-base (1,5%), conforme REQ-007.</summary>
    public const int TaxaPadraoBasisPoints = 150;

    /// <summary>
    /// Calcula a taxa de intermediação em centavos para <paramref name="valorCentavos"/>.
    /// O arredondamento é aplicado uma única vez, ao final, com <see cref="MidpointRounding.ToEven"/>
    /// (arredondamento bancário da NBR 5891) — nunca em cascata.
    /// </summary>
    public static long Calcular(long valorCentavos, int basisPoints = TaxaPadraoBasisPoints)
    {
        if (valorCentavos <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(valorCentavos));
        }

        if (basisPoints < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(basisPoints));
        }

        var taxaExata = (decimal)valorCentavos * basisPoints / 10_000m;
        return (long)Math.Round(taxaExata, MidpointRounding.ToEven);
    }
}
