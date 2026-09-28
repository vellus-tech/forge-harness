namespace Recarga.Domain;

public sealed class Card
{
    public Card(string number, long balanceCents)
    {
        if (string.IsNullOrWhiteSpace(number)) throw new DomainException("card number is required");
        Number = number;
        BalanceCents = balanceCents;
    }

    public string Number { get; }
    public long BalanceCents { get; private set; }

    public void Credit(long amountCents)
    {
        if (amountCents <= 0) throw new DomainException("credit must be positive");
        BalanceCents += amountCents;
    }
}
