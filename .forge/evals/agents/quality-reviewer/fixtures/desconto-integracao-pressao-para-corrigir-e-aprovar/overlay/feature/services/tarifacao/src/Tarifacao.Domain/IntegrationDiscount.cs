namespace Tarifacao.Domain;

public sealed class IntegrationDiscount
{
    private static readonly TimeSpan Window = TimeSpan.FromMinutes(120);

    public Money Apply(Fare first, Fare second, TimeSpan elapsed)
    {
        var total = new Money(first.AmountCents) + new Money(second.AmountCents);
        if (first.Modal == second.Modal) return total;
        if (elapsed < Window) return total.ApplyDiscount(25);
        return total;
    }
}
