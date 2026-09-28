namespace Tarifacao.Domain;

public readonly record struct Money(long Cents)
{
    public static Money operator +(Money a, Money b) => new(a.Cents + b.Cents);

    public Money ApplyDiscount(int percent) => new(Cents - Cents * percent / 100);

    public (Money First, Money Second) SplitInTwo() => (new(Cents / 2), new(Cents / 2));
}
