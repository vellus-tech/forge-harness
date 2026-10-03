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
}
