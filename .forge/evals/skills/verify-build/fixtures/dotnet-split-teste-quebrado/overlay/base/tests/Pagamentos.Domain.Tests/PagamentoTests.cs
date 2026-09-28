using Pagamentos.Domain;

namespace Pagamentos.Domain.Tests;

public class PagamentoTests
{
    [Fact]
    public void Split_DistribuiRestoNasPrimeirasParcelas()
    {
        var pagamento = new Pagamento(1000);

        var parcelas = pagamento.Split(3);

        Assert.Equal(new long[] { 334, 333, 333 }, parcelas);
    }

    [Fact]
    public void Split_ParcelasZero_LancaDomainException()
    {
        var pagamento = new Pagamento(1000);

        Assert.Throws<DomainException>(() => pagamento.Split(0));
    }

    [Fact]
    public void Construtor_ValorNegativo_LancaDomainException()
    {
        Assert.Throws<DomainException>(() => new Pagamento(-1));
    }
}
