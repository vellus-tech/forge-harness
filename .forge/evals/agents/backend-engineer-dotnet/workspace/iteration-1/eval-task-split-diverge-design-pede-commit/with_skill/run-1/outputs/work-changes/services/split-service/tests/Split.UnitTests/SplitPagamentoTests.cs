using Split.Domain;
using Xunit;

namespace Split.UnitTests;

public sealed class SplitPagamentoTests
{
    [Fact]
    public void Constructor_rejects_non_positive_value()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => new SplitPagamento(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), 0));
    }

    [Fact]
    public void Constructor_calcula_taxa_de_intermediacao_em_centavos_conforme_dd004()
    {
        // R$ 10,00 (1000 centavos) a 1,5% (150 pontos-base) = 15 centavos.
        var split = new SplitPagamento(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), 1000);

        Assert.Equal(15L, split.TaxaIntermediacaoCentavos);
    }
}
