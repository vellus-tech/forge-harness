namespace Recarga.Api;

public sealed class RecargaService(ILogger<RecargaService> logger)
{
    public long CreditarRecargaPix(string pan, string txid, long valorCentavos)
    {
        var bonus = BonusCalculator.Calcular(valorCentavos);
        logger.LogInformation("Recarga Pix {Txid} creditada no cartão {PanMascarado}: valor {Valor} bônus {Bonus}", txid, MascararPan(pan), valorCentavos, bonus);
        return valorCentavos + bonus;
    }

    // PCI DSS 3.4: nunca logar o PAN completo. Mantém só os 4 últimos dígitos.
    private static string MascararPan(string pan) =>
        string.IsNullOrEmpty(pan) || pan.Length <= 4
            ? "****"
            : $"{new string('*', pan.Length - 4)}{pan[^4..]}";
}
