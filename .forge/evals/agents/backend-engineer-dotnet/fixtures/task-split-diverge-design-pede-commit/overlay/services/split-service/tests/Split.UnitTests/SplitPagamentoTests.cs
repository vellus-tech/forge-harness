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
}
