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
    public void TaxaIntermediacaoCentavos_divisao_exata()
    {
        var split = new SplitPagamento(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), 1_000);

        Assert.Equal(15, split.TaxaIntermediacaoCentavos);
    }

    [Fact]
    public void TaxaIntermediacaoCentavos_empate_arredonda_para_par_acima()
    {
        // 100 * 150 / 10_000 = 1,5 (empate entre 1 e 2) — half-even arredonda para o par: 2.
        var split = new SplitPagamento(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), 100);

        Assert.Equal(2, split.TaxaIntermediacaoCentavos);
    }

    [Fact]
    public void TaxaIntermediacaoCentavos_empate_mantem_par()
    {
        // 300 * 150 / 10_000 = 4,5 (empate entre 4 e 5) — half-even mantém o par: 4.
        var split = new SplitPagamento(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), 300);

        Assert.Equal(4, split.TaxaIntermediacaoCentavos);
    }
}
