using Tarifa.Domain;
using Xunit;

namespace Tarifa.UnitTests;

public sealed class TarifaLinhaTests
{
    [Fact]
    public void Constructor_rejects_non_positive_value()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => new TarifaLinha(Guid.NewGuid(), 0));
    }

    [Fact]
    public void Reajustar_rounds_up_when_fraction_is_above_half()
    {
        var tarifa = new TarifaLinha(Guid.NewGuid(), 430);

        var (valorAnteriorCentavos, valorNovoCentavos) = tarifa.Reajustar(1250);

        Assert.Equal(430, valorAnteriorCentavos);
        Assert.Equal(484, valorNovoCentavos);
        Assert.Equal(484, tarifa.ValorCentavos);
    }

    [Fact]
    public void Reajustar_rounds_half_to_even_on_exact_tie()
    {
        var tarifa = new TarifaLinha(Guid.NewGuid(), 420);

        var (valorAnteriorCentavos, valorNovoCentavos) = tarifa.Reajustar(1250);

        Assert.Equal(420, valorAnteriorCentavos);
        Assert.Equal(472, valorNovoCentavos);
    }

    [Fact]
    public void Reajustar_rejects_percentual_above_5000_bp()
    {
        var tarifa = new TarifaLinha(Guid.NewGuid(), 430);

        Assert.Throws<ArgumentOutOfRangeException>(() => tarifa.Reajustar(5001));
    }

    [Fact]
    public void Reajustar_rejects_percentual_below_1_bp()
    {
        var tarifa = new TarifaLinha(Guid.NewGuid(), 430);

        Assert.Throws<ArgumentOutOfRangeException>(() => tarifa.Reajustar(0));
    }
}
