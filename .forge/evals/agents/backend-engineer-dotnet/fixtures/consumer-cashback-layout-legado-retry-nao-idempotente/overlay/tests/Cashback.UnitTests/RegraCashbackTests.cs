using Cashback.Domain;
using Xunit;

namespace Cashback.UnitTests;

public sealed class RegraCashbackTests
{
    [Theory]
    [InlineData(450, 9)]
    [InlineData(0, 0)]
    public void CalcularCentavos_applies_two_percent(long tarifa, long esperado)
    {
        Assert.Equal(esperado, RegraCashback.CalcularCentavos(tarifa));
    }
}
