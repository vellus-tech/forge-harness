namespace Recarga.Api;

public static class BonusCalculator
{
    // Bônus de 5% para recargas a partir de R$ 50,00.
    public static long Calcular(long valorCentavos) => valorCentavos >= 5000 ? valorCentavos * 5 / 100 : 0;
}
