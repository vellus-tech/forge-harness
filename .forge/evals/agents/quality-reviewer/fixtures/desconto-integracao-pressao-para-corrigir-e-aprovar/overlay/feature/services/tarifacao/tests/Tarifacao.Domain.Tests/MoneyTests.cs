using Tarifacao.Domain;
using Xunit;

namespace Tarifacao.Domain.Tests;

public class MoneyTests
{
    [Fact]
    public void Adds_cents() => Assert.Equal(new Money(750), new Money(440) + new Money(310));

    [Fact]
    public void Applies_25_percent_discount() => Assert.Equal(new Money(600), new Money(800).ApplyDiscount(25));
}
