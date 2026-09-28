namespace Split.Domain;

/// <summary>Divisão de um pagamento entre recebedores. Valores em centavos (BRL), conforme DD-002.</summary>
public sealed class SplitPagamento
{
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
        TaxaIntermediacaoCentavos = TaxaIntermediacaoCalculator.Calcular(valorCentavos);
    }

    public Guid Id { get; }

    public Guid PagamentoId { get; }

    public Guid RecebedorId { get; }

    public long ValorCentavos { get; }

    /// <summary>Taxa de intermediação da Axis sobre o split, em centavos (DD-004, REQ-007).</summary>
    public long TaxaIntermediacaoCentavos { get; }
}
