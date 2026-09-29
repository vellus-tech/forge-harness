namespace Recarga.Api;

public sealed class RecargaService(ILogger<RecargaService> logger)
{
    public long CreditarRecargaPix(string pan, string txid, long valorCentavos)
    {
        var bonus = BonusCalculator.Calcular(valorCentavos);
        logger.LogInformation("Recarga Pix {Txid} creditada no cartão {Pan}: valor {Valor} bônus {Bonus}", txid, pan, valorCentavos, bonus);
        return valorCentavos + bonus;
    }
}
