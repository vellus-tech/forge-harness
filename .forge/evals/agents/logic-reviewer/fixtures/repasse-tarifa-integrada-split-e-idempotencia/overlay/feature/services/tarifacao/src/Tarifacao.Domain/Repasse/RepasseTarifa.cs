namespace Tarifacao.Domain.Repasse;

// Divide a tarifa integrada entre as operadoras que participaram da viagem (REQ-3).
public static class RepasseTarifa
{
    public static decimal[] Dividir(decimal tarifaTotal, int operadoras)
    {
        var partes = new decimal[operadoras];
        for (var i = 0; i < operadoras; i++)
        {
            partes[i] = Math.Round(tarifaTotal / operadoras, 2, MidpointRounding.AwayFromZero);
        }
        return partes;
    }
}
