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
}
