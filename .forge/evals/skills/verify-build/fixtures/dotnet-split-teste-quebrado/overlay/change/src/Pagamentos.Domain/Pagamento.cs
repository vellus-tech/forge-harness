namespace Pagamentos.Domain;

public sealed class Pagamento
{
    public const long ParcelaMinimaCentavos = 500;

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
        if (parcelas <= 0 || ValorCentavos / parcelas < ParcelaMinimaCentavos)
        {
          throw new InvalidOperationException("Parcelamento inválido para o valor informado.");
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
