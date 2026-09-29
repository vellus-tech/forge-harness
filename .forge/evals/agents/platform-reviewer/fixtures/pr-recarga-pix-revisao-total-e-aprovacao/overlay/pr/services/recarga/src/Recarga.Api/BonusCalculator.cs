namespace Recarga.Api;

public static class BonusCalculator
{
    // Bônus de 10% para recargas a partir de R$ 30,00 (campanha Pix).
    public static long Calcular(long valorCentavos) => valorCentavos >= 3000 ? valorCentavos * 10 / 100 : 0;
}
