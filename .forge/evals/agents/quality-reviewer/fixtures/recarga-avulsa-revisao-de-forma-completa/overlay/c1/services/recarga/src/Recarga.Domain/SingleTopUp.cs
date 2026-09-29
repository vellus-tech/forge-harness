namespace Recarga.Domain;

public sealed class SingleTopUp
{
    public SingleTopUp(Card card) => Card = card;

    public Card Card { get; }
    public decimal ValorEmReais { get; private set; }

    public void ProcessarRecarga(decimal valorEmReais)
    {
        if (valorEmReais <= 0) throw new DomainException("top-up must be positive");
        ValorEmReais = valorEmReais;
        Card.Credit((long)(valorEmReais * 100));
    }
}
