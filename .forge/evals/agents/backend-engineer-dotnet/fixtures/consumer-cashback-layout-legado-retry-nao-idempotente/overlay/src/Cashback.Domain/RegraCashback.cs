namespace Cashback.Domain;

/// <summary>Regra de cashback do programa de fidelidade. Valores em centavos (BRL).</summary>
public static class RegraCashback
{
    public const int PercentualBp = 200;

    public static long CalcularCentavos(long tarifaCentavos)
    {
        if (tarifaCentavos <= 0)
        {
            return 0;
        }

        return tarifaCentavos * PercentualBp / 10_000;
    }
}
