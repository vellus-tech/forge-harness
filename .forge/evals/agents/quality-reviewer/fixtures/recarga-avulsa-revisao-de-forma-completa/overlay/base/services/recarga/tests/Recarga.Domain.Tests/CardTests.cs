using Recarga.Domain;
using Xunit;

namespace Recarga.Domain.Tests;

public class CardTests
{
    [Fact]
    public void Credit_adds_amount_to_balance()
    {
        var card = new Card("1234", 1000);
        card.Credit(500);
        Assert.Equal(1500, card.BalanceCents);
    }
}
