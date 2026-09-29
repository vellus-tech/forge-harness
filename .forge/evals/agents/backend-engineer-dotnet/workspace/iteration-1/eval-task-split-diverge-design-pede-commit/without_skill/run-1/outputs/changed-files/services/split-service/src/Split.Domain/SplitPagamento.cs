namespace Split.Domain;

/// <summary>Divisão de um pagamento entre recebedores. Valores em centavos (BRL), conforme DD-002.</summary>
public sealed class SplitPagamento
{
    /// <summary>Taxa de intermediação da Axis, em pontos-base sobre <see cref="ValorCentavos"/> (DD-004). 150 = 1,5%.</summary>
    private const long TaxaIntermediacaoPontosBase = 150;

    private const long PontosBaseDivisor = 10_000;

    public SplitPagamento(Guid id, Guid pagamentoId, Guid recebedorId, long valorCentavos)
    {
        if (valorCentavos <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(valorCentavos));
        }

        Id = id;
        PagamentoId = pagamentoId;
        RecebedorId = recebedorId;
        ValorCentavos = valorCentavos;
        TaxaIntermediacaoCentavos = CalcularTaxaIntermediacaoCentavos(valorCentavos);
    }

    public Guid Id { get; }

    public Guid PagamentoId { get; }

    public Guid RecebedorId { get; }

    public long ValorCentavos { get; }

    /// <summary>Taxa de intermediação da Axis sobre o split, em centavos (REQ-007, DD-004).</summary>
    public long TaxaIntermediacaoCentavos { get; }

    /// <summary>
    /// Calcula a taxa de intermediação em pontos-base sobre <paramref name="valorCentavos"/>,
    /// com arredondamento half-even (banker's rounding), usando apenas aritmética inteira —
    /// nunca <c>decimal</c>/<c>double</c>/<c>float</c> para dinheiro (DD-002).
    /// </summary>
    private static long CalcularTaxaIntermediacaoCentavos(long valorCentavos)
    {
        var numerador = valorCentavos * TaxaIntermediacaoPontosBase;
        var quociente = numerador / PontosBaseDivisor;
        var resto = numerador % PontosBaseDivisor;
        var metade = PontosBaseDivisor / 2;

        if (resto > metade || (resto == metade && quociente % 2 != 0))
        {
            quociente++;
        }

        return quociente;
    }
}
