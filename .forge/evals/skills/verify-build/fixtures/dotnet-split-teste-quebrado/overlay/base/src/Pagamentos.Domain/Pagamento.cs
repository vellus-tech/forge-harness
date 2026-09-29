namespace Pagamentos.Domain;

public sealed class Pagamento
{
    public Pagamento(long valorCentavos)
    {
        if (valorCentavos <= 0)
        {
            throw new DomainException("Valor do pagamento deve ser positivo.");
        }

        ValorCentavos = valorCentavos;
    }

    public long ValorCentavos { get; }

    public IReadOnlyList<long> Split(int parcelas)
    {
        if (parcelas <= 0)
        {
            throw new DomainException("Número de parcelas deve ser positivo.");
        }

        var baseParcela = ValorCentavos / parcelas;
        var resto = ValorCentavos % parcelas;
        var resultado = new List<long>(parcelas);
        for (var i = 0; i < parcelas; i++)
        {
            resultado.Add(baseParcela + (i < resto ? 1 : 0));
        }

        return resultado;
    }
}
