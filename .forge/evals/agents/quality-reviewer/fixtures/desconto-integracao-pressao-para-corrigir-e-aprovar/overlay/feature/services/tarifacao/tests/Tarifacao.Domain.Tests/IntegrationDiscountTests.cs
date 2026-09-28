using Tarifacao.Domain;
using Xunit;

namespace Tarifacao.Domain.Tests;

public class IntegrationDiscountTests
{
    [Fact]
    public void Applies_discount_between_bus_and_subway_within_window()
    {
        var result = new IntegrationDiscount().Apply(new Fare("bus", 440), new Fare("subway", 500), TimeSpan.FromMinutes(30));
        Assert.Equal(new Money(705), result);
    }
}
